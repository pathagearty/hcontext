from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable, Mapping, Sequence
from dataclasses import dataclass
import os
import re
import time
from typing import Any, Literal, Protocol
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from azure.identity import AzureCliCredential, ManagedIdentityCredential
import httpx

from .settings import AppSettings, FoundryAgentConfig


FOUNDRY_TOKEN_SCOPE = "https://ai.azure.com/.default"
AgentName = Literal["direct_review", "hexacontext_compiler", "context_assisted_review"]
ResponseInput = str | list[dict[str, Any]]
_SCHEMA_NAME = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
_TRANSIENT_STATUS_CODES = {429, 500, 502, 503, 504}
_AZURE_IDENTITY_MARKERS = (
    "IDENTITY_ENDPOINT",
    "MSI_ENDPOINT",
    "IMDS_ENDPOINT",
    "WEBSITE_INSTANCE_ID",
)


@dataclass(frozen=True)
class RetryEvent:
    attempt: int
    reason: str
    status_code: int | None
    delay_seconds: float


class FoundryError(RuntimeError):
    """Base class for safe-to-surface Foundry client failures."""


class FoundryAuthenticationError(FoundryError):
    pass


class FoundryTransportError(FoundryError):
    def __init__(self, attempts: int, retries: tuple[RetryEvent, ...]) -> None:
        self.attempts = attempts
        self.retries = retries
        super().__init__(f"Foundry transport failed after {attempts} attempt(s)")


class FoundryProtocolError(FoundryError):
    pass


class FoundryHTTPError(FoundryError):
    def __init__(
        self,
        *,
        status_code: int,
        error_code: str | None,
        request_id: str | None,
        retryable: bool,
        attempts: int,
        retries: tuple[RetryEvent, ...],
    ) -> None:
        self.status_code = status_code
        self.error_code = error_code
        self.request_id = request_id
        self.retryable = retryable
        self.attempts = attempts
        self.retries = retries
        code_text = f", code={error_code}" if error_code else ""
        request_text = f", request_id={request_id}" if request_id else ""
        super().__init__(
            f"Foundry returned HTTP {status_code}{code_text}{request_text} after {attempts} attempt(s)"
        )


class TokenProvider(Protocol):
    async def get_token(self) -> str: ...

    async def aclose(self) -> None: ...


class EntraTokenProvider:
    """Uses the developer's Azure CLI identity locally and managed identity in Azure."""

    def __init__(self, settings: AppSettings) -> None:
        auth_mode = settings.foundry_auth_mode
        if auth_mode == "auto":
            auth_mode = (
                "managed_identity"
                if any(os.getenv(marker) for marker in _AZURE_IDENTITY_MARKERS)
                else "azure_cli"
            )
        if auth_mode == "managed_identity":
            self._credential = ManagedIdentityCredential(
                client_id=settings.foundry_managed_identity_client_id or None
            )
        else:
            self._credential = AzureCliCredential()

    async def get_token(self) -> str:
        try:
            access_token = await asyncio.to_thread(
                self._credential.get_token,
                FOUNDRY_TOKEN_SCOPE,
            )
        except Exception:
            raise FoundryAuthenticationError(
                "Unable to obtain a Microsoft Entra token for Foundry"
            ) from None
        if not access_token.token:
            raise FoundryAuthenticationError("Microsoft Entra returned an empty Foundry token")
        return access_token.token

    async def aclose(self) -> None:
        close = getattr(self._credential, "close", None)
        if close:
            await asyncio.to_thread(close)


@dataclass(frozen=True)
class FoundryCallMetadata:
    agent: AgentName
    agent_id: str
    model: str
    api_version: str
    response_id: str
    response_status: str
    http_status: int
    request_id: str | None
    elapsed_ms: int
    attempts: int
    retries: tuple[RetryEvent, ...]
    usage: dict[str, Any]


@dataclass(frozen=True)
class FoundryCallResult:
    payload: dict[str, Any]
    metadata: FoundryCallMetadata

    def log_summary(self) -> dict[str, Any]:
        return {
            "agent": self.metadata.agent,
            "agent_id": self.metadata.agent_id,
            "model": self.metadata.model,
            "api_version": self.metadata.api_version,
            "response_id": self.metadata.response_id,
            "response_status": self.metadata.response_status,
            "http_status": self.metadata.http_status,
            "request_id": self.metadata.request_id,
            "elapsed_ms": self.metadata.elapsed_ms,
            "attempts": self.metadata.attempts,
            "retry_count": len(self.metadata.retries),
            "usage": self.metadata.usage,
        }


def build_foundry_url(endpoint: str, api_version: str) -> str:
    """Set api-version while retaining every other endpoint query parameter."""

    parsed = urlsplit(endpoint)
    query = [
        (key, value)
        for key, value in parse_qsl(parsed.query, keep_blank_values=True)
        if key.casefold() != "api-version"
    ]
    query.append(("api-version", api_version))
    return urlunsplit(
        (parsed.scheme, parsed.netloc, parsed.path, urlencode(query, doseq=True), parsed.fragment)
    )


def redact_for_log(value: Any) -> Any:
    """Return metadata safe for logs; request/content and credential values are removed."""

    if isinstance(value, Mapping):
        redacted: dict[str, Any] = {}
        for raw_key, item in value.items():
            key = str(raw_key)
            normalized = key.casefold().replace("-", "_")
            credential_key = (
                normalized in {"authorization", "password", "key"}
                or normalized.endswith("_key")
                or normalized == "token"
                or normalized.endswith("_token")
                or "secret" in normalized
                or "connection_string" in normalized
            )
            content_key = normalized in {
                "input",
                "output",
                "content",
                "evidence",
                "tool_output",
                "headers",
            }
            redacted[key] = "[REDACTED]" if credential_key or content_key else redact_for_log(item)
        return redacted
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return [redact_for_log(item) for item in value]
    if isinstance(value, str):
        return re.sub(r"(?i)Bearer\s+[^\s,;]+", "Bearer [REDACTED]", value)
    return value


class FoundryClient:
    def __init__(
        self,
        settings: AppSettings,
        *,
        token_provider: TokenProvider | None = None,
        transport: httpx.AsyncBaseTransport | None = None,
        http_client: httpx.AsyncClient | None = None,
        sleep: Callable[[float], Awaitable[None]] = asyncio.sleep,
    ) -> None:
        settings.require_foundry()
        if transport is not None and http_client is not None:
            raise ValueError("Provide either transport or http_client, not both")
        self.settings = settings
        self._token_provider = token_provider or EntraTokenProvider(settings)
        self._owns_token_provider = token_provider is None
        self._client = http_client or httpx.AsyncClient(
            timeout=settings.foundry_timeout_seconds,
            transport=transport,
        )
        self._owns_client = http_client is None
        self._sleep = sleep

    async def __aenter__(self) -> FoundryClient:
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.aclose()

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()
        if self._owns_token_provider:
            await self._token_provider.aclose()

    @staticmethod
    def _request_id(response: httpx.Response) -> str | None:
        return response.headers.get("x-request-id") or response.headers.get("apim-request-id")

    @staticmethod
    def _error_code(response: httpx.Response) -> str | None:
        try:
            payload = response.json()
        except ValueError:
            return None
        if not isinstance(payload, dict):
            return None
        error = payload.get("error")
        if isinstance(error, dict) and isinstance(error.get("code"), str):
            code = error["code"][:120]
            return code if re.fullmatch(r"[A-Za-z0-9_.-]+", code) else "unknown"
        if isinstance(payload.get("code"), str):
            code = payload["code"][:120]
            return code if re.fullmatch(r"[A-Za-z0-9_.-]+", code) else "unknown"
        return None

    @staticmethod
    def _retry_delay(response: httpx.Response | None, retry_number: int) -> float:
        if response is not None:
            retry_after = response.headers.get("retry-after")
            if retry_after:
                try:
                    return max(0.0, min(float(retry_after), 30.0))
                except ValueError:
                    pass
        return min(0.5 * (2 ** (retry_number - 1)), 4.0)

    def _body(
        self,
        config: FoundryAgentConfig,
        *,
        input_value: ResponseInput,
        instructions: str | None,
        response_schema: dict[str, Any] | None,
        schema_name: str | None,
        tools: list[dict[str, Any]] | None,
        tool_choice: str | dict[str, Any] | None,
        max_output_tokens: int | None,
        metadata: dict[str, str] | None,
    ) -> dict[str, Any]:
        if isinstance(input_value, str):
            if not input_value.strip():
                raise ValueError("input_value must not be empty")
        elif not input_value:
            raise ValueError("input_value must not be empty")
        output_tokens = (
            self.settings.foundry_max_output_tokens
            if max_output_tokens is None
            else max_output_tokens
        )
        if not 1 <= output_tokens <= self.settings.foundry_max_output_tokens:
            raise ValueError(
                "max_output_tokens must be between 1 and the configured FOUNDRY_MAX_OUTPUT_TOKENS"
            )
        body: dict[str, Any] = {
            "model": config.model,
            "input": input_value,
            "max_output_tokens": output_tokens,
        }
        if instructions is not None:
            body["instructions"] = instructions
        if response_schema is not None:
            if not schema_name or not _SCHEMA_NAME.fullmatch(schema_name):
                raise ValueError("schema_name must contain 1-64 letters, numbers, underscores, or dashes")
            body["text"] = {
                "format": {
                    "type": "json_schema",
                    "name": schema_name,
                    "strict": True,
                    "schema": response_schema,
                }
            }
        elif schema_name is not None:
            raise ValueError("schema_name requires response_schema")
        if tools is not None:
            body["tools"] = tools
        if tool_choice is not None:
            if tools is None and tool_choice != "none":
                raise ValueError("tool_choice requires tools unless it is 'none'")
            body["tool_choice"] = tool_choice
        if metadata:
            body["metadata"] = metadata
        return body

    async def create_response(
        self,
        agent: AgentName,
        *,
        input_value: ResponseInput,
        instructions: str | None = None,
        response_schema: dict[str, Any] | None = None,
        schema_name: str | None = None,
        tools: list[dict[str, Any]] | None = None,
        tool_choice: str | dict[str, Any] | None = None,
        max_output_tokens: int | None = None,
        metadata: dict[str, str] | None = None,
    ) -> FoundryCallResult:
        config = self.settings.foundry_agent(agent)
        url = build_foundry_url(config.endpoint, self.settings.foundry_api_version)
        body = self._body(
            config,
            input_value=input_value,
            instructions=instructions,
            response_schema=response_schema,
            schema_name=schema_name,
            tools=tools,
            tool_choice=tool_choice,
            max_output_tokens=max_output_tokens,
            metadata=metadata,
        )
        started = time.perf_counter()
        try:
            token = await self._token_provider.get_token()
        except FoundryAuthenticationError:
            raise
        except Exception:
            raise FoundryAuthenticationError(
                "Unable to obtain a Microsoft Entra token for Foundry"
            ) from None
        if not token:
            raise FoundryAuthenticationError("Microsoft Entra returned an empty Foundry token")
        headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        retries: list[RetryEvent] = []
        max_attempts = self.settings.foundry_max_retries + 1
        for attempt in range(1, max_attempts + 1):
            response: httpx.Response | None = None
            try:
                response = await self._client.post(url, headers=headers, json=body)
            except httpx.TransportError:
                if attempt >= max_attempts:
                    raise FoundryTransportError(attempt, tuple(retries)) from None
                delay = self._retry_delay(None, attempt)
                retries.append(RetryEvent(attempt, "transport", None, delay))
                await self._sleep(delay)
                continue

            if response.is_success:
                try:
                    payload = response.json()
                except ValueError:
                    raise FoundryProtocolError("Foundry returned a non-JSON success response") from None
                if not isinstance(payload, dict):
                    raise FoundryProtocolError("Foundry returned an invalid response object")
                response_id = payload.get("id")
                if not isinstance(response_id, str) or not response_id:
                    raise FoundryProtocolError("Foundry success response did not include an ID")
                response_status = payload.get("status")
                usage = payload.get("usage")
                elapsed_ms = round((time.perf_counter() - started) * 1000)
                return FoundryCallResult(
                    payload=payload,
                    metadata=FoundryCallMetadata(
                        agent=agent,
                        agent_id=config.agent_id,
                        model=config.model,
                        api_version=self.settings.foundry_api_version,
                        response_id=response_id,
                        response_status=response_status if isinstance(response_status, str) else "unknown",
                        http_status=response.status_code,
                        request_id=self._request_id(response),
                        elapsed_ms=elapsed_ms,
                        attempts=attempt,
                        retries=tuple(retries),
                        usage=usage if isinstance(usage, dict) else {},
                    ),
                )

            retryable = response.status_code in _TRANSIENT_STATUS_CODES
            if retryable and attempt < max_attempts:
                delay = self._retry_delay(response, attempt)
                retries.append(RetryEvent(attempt, "http", response.status_code, delay))
                await self._sleep(delay)
                continue
            raise FoundryHTTPError(
                status_code=response.status_code,
                error_code=self._error_code(response),
                request_id=self._request_id(response),
                retryable=retryable,
                attempts=attempt,
                retries=tuple(retries),
            )

        raise AssertionError("Foundry retry loop ended unexpectedly")
