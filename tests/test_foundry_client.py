from __future__ import annotations

import json
import unittest

import httpx

from backend.foundry_client import (
    FoundryAuthenticationError,
    FoundryClient,
    FoundryHTTPError,
    build_foundry_url,
    redact_for_log,
)
from backend.settings import AppSettings


class FakeTokenProvider:
    def __init__(self, token: str = "test-token", *, error: Exception | None = None) -> None:
        self.token = token
        self.error = error
        self.calls = 0

    async def get_token(self) -> str:
        self.calls += 1
        if self.error:
            raise self.error
        return self.token

    async def aclose(self) -> None:
        return None


def settings(**overrides: object) -> AppSettings:
    values: dict[str, object] = {
        "foundry_enabled": True,
        "foundry_api_version": "2025-05-15-preview",
        "foundry_project_endpoint": "https://example.services.ai.azure.com/api/projects/demo",
        "foundry_direct_review_agent_id": "direct-review-agent",
        "foundry_direct_review_agent_endpoint": (
            "https://example.services.ai.azure.com/api/projects/demo/agents/"
            "direct-review-agent/endpoint/protocols/openai/responses?route=saved"
        ),
        "foundry_direct_review_model": "gpt-5",
        "foundry_hexacontext_compiler_agent_id": "hexacontext-compiler-agent",
        "foundry_hexacontext_compiler_agent_endpoint": (
            "https://example.services.ai.azure.com/api/projects/demo/agents/"
            "hexacontext-compiler-agent/endpoint/protocols/openai/responses"
        ),
        "foundry_hexacontext_compiler_model": "gpt-5",
        "foundry_context_review_agent_id": "context-review-agent",
        "foundry_context_review_agent_endpoint": (
            "https://example.services.ai.azure.com/api/projects/demo/agents/"
            "context-review-agent/endpoint/protocols/openai/responses"
        ),
        "foundry_context_review_model": "gpt-5",
        "foundry_max_retries": 2,
    }
    values.update(overrides)
    return AppSettings(_env_file=None, **values)


class FoundryClientTests(unittest.IsolatedAsyncioTestCase):
    def test_url_builder_preserves_query_and_replaces_api_version(self) -> None:
        url = build_foundry_url(
            "https://example.test/responses?route=saved&api-version=old&empty=",
            "2025-05-15-preview",
        )
        parsed = httpx.URL(url)
        self.assertEqual(parsed.params["route"], "saved")
        self.assertEqual(parsed.params["empty"], "")
        self.assertEqual(parsed.params["api-version"], "2025-05-15-preview")
        self.assertEqual(list(parsed.params.multi_items()).count(("api-version", "2025-05-15-preview")), 1)

    async def test_success_uses_matching_model_schema_and_safe_metadata(self) -> None:
        seen: dict[str, object] = {}

        def handler(request: httpx.Request) -> httpx.Response:
            seen["url"] = str(request.url)
            seen["authorization"] = request.headers["authorization"]
            seen["body"] = json.loads(request.content)
            return httpx.Response(
                200,
                headers={"x-request-id": "request-123"},
                json={
                    "id": "response-123",
                    "status": "completed",
                    "usage": {"total_tokens": 42},
                    "output": [],
                },
            )

        provider = FakeTokenProvider()
        client = FoundryClient(
            settings(),
            token_provider=provider,
            transport=httpx.MockTransport(handler),
        )
        try:
            result = await client.create_response(
                "direct_review",
                input_value="Evaluate the validated request.",
                response_schema={"type": "object", "additionalProperties": False},
                schema_name="ManufacturingDecision",
                tool_choice="none",
                metadata={"comparison_run_id": "comparison-1"},
            )
        finally:
            await client.aclose()

        body = seen["body"]
        self.assertIsInstance(body, dict)
        assert isinstance(body, dict)
        self.assertEqual(body["model"], "gpt-5")
        self.assertEqual(body["max_output_tokens"], 1800)
        self.assertTrue(body["text"]["format"]["strict"])
        self.assertEqual(seen["authorization"], "Bearer test-token")
        self.assertIn("route=saved", seen["url"])
        self.assertIn("api-version=2025-05-15-preview", seen["url"])
        self.assertEqual(result.metadata.response_id, "response-123")
        self.assertEqual(result.metadata.attempts, 1)
        self.assertEqual(result.log_summary()["usage"], {"total_tokens": 42})
        self.assertNotIn("payload", result.log_summary())

    async def test_400_and_401_are_not_retried(self) -> None:
        for status_code in (400, 401):
            calls = 0

            def handler(_: httpx.Request) -> httpx.Response:
                nonlocal calls
                calls += 1
                return httpx.Response(
                    status_code,
                    headers={"x-request-id": "safe-request-id"},
                    json={"error": {"code": "invalid_payload", "message": "secret-value"}},
                )

            client = FoundryClient(
                settings(),
                token_provider=FakeTokenProvider(),
                transport=httpx.MockTransport(handler),
            )
            try:
                with self.subTest(status_code=status_code):
                    with self.assertRaises(FoundryHTTPError) as context:
                        await client.create_response("direct_review", input_value="hello")
                    self.assertEqual(context.exception.status_code, status_code)
                    self.assertEqual(context.exception.attempts, 1)
                    self.assertFalse(context.exception.retryable)
                    self.assertEqual(context.exception.retries, ())
                    self.assertNotIn("secret-value", str(context.exception))
                    self.assertEqual(calls, 1)
            finally:
                await client.aclose()

    async def test_429_retries_and_records_retry(self) -> None:
        calls = 0
        delays: list[float] = []

        def handler(_: httpx.Request) -> httpx.Response:
            nonlocal calls
            calls += 1
            if calls == 1:
                return httpx.Response(
                    429,
                    headers={"retry-after": "0"},
                    json={"error": {"code": "rate_limit"}},
                )
            return httpx.Response(200, json={"id": "response-2", "status": "completed"})

        async def record_sleep(delay: float) -> None:
            delays.append(delay)

        client = FoundryClient(
            settings(),
            token_provider=FakeTokenProvider(),
            transport=httpx.MockTransport(handler),
            sleep=record_sleep,
        )
        try:
            result = await client.create_response("hexacontext_compiler", input_value="hello")
        finally:
            await client.aclose()
        self.assertEqual(calls, 2)
        self.assertEqual(delays, [0.0])
        self.assertEqual(result.metadata.attempts, 2)
        self.assertEqual(result.metadata.retries[0].status_code, 429)

    async def test_5xx_stops_after_configured_retry_limit(self) -> None:
        calls = 0

        def handler(_: httpx.Request) -> httpx.Response:
            nonlocal calls
            calls += 1
            return httpx.Response(503, json={"error": {"code": "temporarily_unavailable"}})

        async def no_sleep(_: float) -> None:
            return None

        client = FoundryClient(
            settings(),
            token_provider=FakeTokenProvider(),
            transport=httpx.MockTransport(handler),
            sleep=no_sleep,
        )
        try:
            with self.assertRaises(FoundryHTTPError) as context:
                await client.create_response("direct_review", input_value="hello")
        finally:
            await client.aclose()
        self.assertEqual(calls, 3)
        self.assertEqual(context.exception.attempts, 3)
        self.assertTrue(context.exception.retryable)
        self.assertEqual(len(context.exception.retries), 2)

    async def test_transport_error_retries_and_invalid_budget_fails_before_auth(self) -> None:
        calls = 0

        def handler(request: httpx.Request) -> httpx.Response:
            nonlocal calls
            calls += 1
            if calls == 1:
                raise httpx.RemoteProtocolError("connection dropped", request=request)
            return httpx.Response(200, json={"id": "response-transport", "status": "completed"})

        async def no_sleep(_: float) -> None:
            return None

        provider = FakeTokenProvider()
        client = FoundryClient(
            settings(),
            token_provider=provider,
            transport=httpx.MockTransport(handler),
            sleep=no_sleep,
        )
        try:
            result = await client.create_response("direct_review", input_value="hello")
            self.assertEqual(result.metadata.attempts, 2)
            self.assertEqual(result.metadata.retries[0].reason, "transport")
            with self.assertRaises(ValueError):
                await client.create_response(
                    "direct_review",
                    input_value="hello",
                    max_output_tokens=0,
                )
        finally:
            await client.aclose()
        self.assertEqual(provider.calls, 1)

    async def test_token_failure_is_typed_and_redacted(self) -> None:
        provider = FakeTokenProvider(error=RuntimeError("raw-token-secret"))
        client = FoundryClient(settings(), token_provider=provider, transport=httpx.MockTransport(lambda _: None))
        try:
            with self.assertRaises(FoundryAuthenticationError) as context:
                await client.create_response("direct_review", input_value="hello")
        finally:
            await client.aclose()
        self.assertNotIn("raw-token-secret", str(context.exception))

    def test_log_redaction_removes_credentials_and_content(self) -> None:
        value = {
            "headers": {"Authorization": "Bearer top-secret"},
            "input": "restricted evidence",
            "SUPABASE_SECRET_KEY": "database-secret",
            "status": "completed",
            "message": "request used Bearer another-secret",
            "usage": {"input_tokens": 12, "output_tokens": 5},
        }
        redacted = redact_for_log(value)
        rendered = str(redacted)
        for secret in ("top-secret", "restricted evidence", "database-secret", "another-secret"):
            self.assertNotIn(secret, rendered)
        self.assertEqual(redacted["status"], "completed")
        self.assertEqual(redacted["usage"], {"input_tokens": 12, "output_tokens": 5})


if __name__ == "__main__":
    unittest.main()
