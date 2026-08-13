from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
import re
from typing import Literal
from urllib.parse import unquote, urlsplit

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


ROOT = Path(__file__).resolve().parents[1]
ENV_LOCAL_PATH = ROOT / ".env.local"
_API_VERSION_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]*$")


class FoundryConfigurationError(ValueError):
    def __init__(self, issues: list[str]) -> None:
        self.issues = tuple(issues)
        super().__init__("Foundry configuration is invalid: " + "; ".join(issues))


class SupabaseConfigurationError(ValueError):
    def __init__(self, issues: list[str]) -> None:
        self.issues = tuple(issues)
        super().__init__("Supabase configuration is invalid: " + "; ".join(issues))


@dataclass(frozen=True)
class FoundryAgentConfig:
    name: Literal["direct_review", "hexacontext_compiler", "context_assisted_review"]
    agent_id: str
    endpoint: str
    model: str


class AppSettings(BaseSettings):
    """Server settings with explicit, repository-root .env.local loading.

    Environment variables override values in .env.local. Foundry can remain
    disabled for the deterministic harness; callers must explicitly validate
    the complete live configuration before constructing a Foundry client.
    """

    model_config = SettingsConfigDict(
        case_sensitive=False,
        extra="ignore",
        env_file=None,
    )

    model_provider: str = "mock"

    foundry_enabled: bool = False
    foundry_api_version: str = "2025-05-15-preview"
    foundry_project_endpoint: str = ""
    foundry_direct_review_agent_id: str = ""
    foundry_direct_review_agent_endpoint: str = ""
    foundry_direct_review_model: str = ""
    foundry_hexacontext_compiler_agent_id: str = ""
    foundry_hexacontext_compiler_agent_endpoint: str = ""
    foundry_hexacontext_compiler_model: str = ""
    foundry_context_review_agent_id: str = ""
    foundry_context_review_agent_endpoint: str = ""
    foundry_context_review_model: str = ""
    foundry_auth_mode: Literal["auto", "azure_cli", "managed_identity"] = "auto"
    foundry_managed_identity_client_id: str = ""
    foundry_timeout_seconds: float = Field(default=120.0, gt=0, le=300)
    foundry_max_retries: int = Field(default=2, ge=0, le=2)
    foundry_max_output_tokens: int = Field(default=1800, ge=1, le=100_000)

    applicationinsights_connection_string: str = ""
    supabase_project_ref: str = ""
    supabase_url: str = ""
    supabase_publishable_key: str = ""
    supabase_secret_key: str = ""
    supabase_jwks_url: str = ""
    supabase_snapshot_id: str = "hx-mfg-v2-snapshot-001"
    supabase_as_of_time: str = "2026-08-01T12:00:00Z"
    supabase_timeout_seconds: float = Field(default=15.0, gt=0, le=60)
    evaluator_ui_token: str = ""

    @field_validator(
        "foundry_api_version",
        "foundry_project_endpoint",
        "foundry_direct_review_agent_id",
        "foundry_direct_review_agent_endpoint",
        "foundry_direct_review_model",
        "foundry_hexacontext_compiler_agent_id",
        "foundry_hexacontext_compiler_agent_endpoint",
        "foundry_hexacontext_compiler_model",
        "foundry_context_review_agent_id",
        "foundry_context_review_agent_endpoint",
        "foundry_context_review_model",
        "foundry_managed_identity_client_id",
        "supabase_project_ref",
        "supabase_url",
        "supabase_publishable_key",
        "supabase_secret_key",
        "supabase_jwks_url",
        "supabase_snapshot_id",
        "supabase_as_of_time",
        "evaluator_ui_token",
        mode="before",
    )
    @classmethod
    def strip_foundry_values(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @staticmethod
    def _url_issue(field_name: str, value: str, *, responses_endpoint: bool) -> str | None:
        try:
            parsed = urlsplit(value)
        except ValueError:
            return f"{field_name} must be a valid URL"
        if parsed.scheme != "https" or not parsed.netloc:
            return f"{field_name} must be an absolute HTTPS URL"
        if parsed.username or parsed.password:
            return f"{field_name} must not contain credentials"
        if parsed.fragment:
            return f"{field_name} must not contain a URL fragment"
        if responses_endpoint and not parsed.path.rstrip("/").endswith("/responses"):
            return f"{field_name} must be a per-agent /responses endpoint"
        return None

    def foundry_configuration_issues(self, *, require_enabled: bool = True) -> list[str]:
        issues: list[str] = []
        if require_enabled and not self.foundry_enabled:
            issues.append("FOUNDRY_ENABLED must be true for live calls")

        required = {
            "FOUNDRY_API_VERSION": self.foundry_api_version,
            "FOUNDRY_PROJECT_ENDPOINT": self.foundry_project_endpoint,
            "FOUNDRY_DIRECT_REVIEW_AGENT_ID": self.foundry_direct_review_agent_id,
            "FOUNDRY_DIRECT_REVIEW_AGENT_ENDPOINT": self.foundry_direct_review_agent_endpoint,
            "FOUNDRY_DIRECT_REVIEW_MODEL": self.foundry_direct_review_model,
            "FOUNDRY_HEXACONTEXT_COMPILER_AGENT_ID": self.foundry_hexacontext_compiler_agent_id,
            "FOUNDRY_HEXACONTEXT_COMPILER_AGENT_ENDPOINT": self.foundry_hexacontext_compiler_agent_endpoint,
            "FOUNDRY_HEXACONTEXT_COMPILER_MODEL": self.foundry_hexacontext_compiler_model,
            "FOUNDRY_CONTEXT_REVIEW_AGENT_ID": self.foundry_context_review_agent_id,
            "FOUNDRY_CONTEXT_REVIEW_AGENT_ENDPOINT": self.foundry_context_review_agent_endpoint,
            "FOUNDRY_CONTEXT_REVIEW_MODEL": self.foundry_context_review_model,
        }
        issues.extend(f"{name} is required" for name, value in required.items() if not value.strip())

        if self.foundry_api_version and not _API_VERSION_PATTERN.fullmatch(self.foundry_api_version):
            issues.append("FOUNDRY_API_VERSION contains invalid characters")

        for field_name, value, is_agent_endpoint in (
            ("FOUNDRY_PROJECT_ENDPOINT", self.foundry_project_endpoint, False),
            (
                "FOUNDRY_DIRECT_REVIEW_AGENT_ENDPOINT",
                self.foundry_direct_review_agent_endpoint,
                True,
            ),
            (
                "FOUNDRY_HEXACONTEXT_COMPILER_AGENT_ENDPOINT",
                self.foundry_hexacontext_compiler_agent_endpoint,
                True,
            ),
            (
                "FOUNDRY_CONTEXT_REVIEW_AGENT_ENDPOINT",
                self.foundry_context_review_agent_endpoint,
                True,
            ),
        ):
            if value:
                issue = self._url_issue(field_name, value, responses_endpoint=is_agent_endpoint)
                if issue:
                    issues.append(issue)

        endpoint_pairs = (
            (
                "direct_review",
                self.foundry_direct_review_agent_id,
                self.foundry_direct_review_agent_endpoint,
            ),
            (
                "hexacontext_compiler",
                self.foundry_hexacontext_compiler_agent_id,
                self.foundry_hexacontext_compiler_agent_endpoint,
            ),
            (
                "context_review",
                self.foundry_context_review_agent_id,
                self.foundry_context_review_agent_endpoint,
            ),
        )
        for label, agent_id, endpoint in endpoint_pairs:
            if agent_id and endpoint:
                try:
                    endpoint_path = unquote(urlsplit(endpoint).path)
                except ValueError:
                    continue
                if agent_id not in endpoint_path:
                    issues.append(
                        f"FOUNDRY_{label.upper()}_AGENT_ID does not match its configured endpoint"
                    )

        configured_ids = [agent_id for _, agent_id, _ in endpoint_pairs if agent_id]
        if len(configured_ids) != len(set(configured_ids)):
            issues.append("All three Foundry agent IDs must be distinct")
        configured_endpoints = [endpoint for _, _, endpoint in endpoint_pairs if endpoint]
        if len(configured_endpoints) != len(set(configured_endpoints)):
            issues.append("All three Foundry agent endpoints must be distinct")

        return issues

    def require_foundry(self) -> None:
        issues = self.foundry_configuration_issues(require_enabled=True)
        if issues:
            raise FoundryConfigurationError(issues)

    def foundry_agent(
        self,
        name: Literal["direct_review", "hexacontext_compiler", "context_assisted_review"],
    ) -> FoundryAgentConfig:
        self.require_foundry()
        if name == "direct_review":
            return FoundryAgentConfig(
                name=name,
                agent_id=self.foundry_direct_review_agent_id,
                endpoint=self.foundry_direct_review_agent_endpoint,
                model=self.foundry_direct_review_model,
            )
        if name == "hexacontext_compiler":
            return FoundryAgentConfig(
                name=name,
                agent_id=self.foundry_hexacontext_compiler_agent_id,
                endpoint=self.foundry_hexacontext_compiler_agent_endpoint,
                model=self.foundry_hexacontext_compiler_model,
            )
        if name == "context_assisted_review":
            return FoundryAgentConfig(
                name=name,
                agent_id=self.foundry_context_review_agent_id,
                endpoint=self.foundry_context_review_agent_endpoint,
                model=self.foundry_context_review_model,
            )
        raise ValueError(f"Unknown Foundry agent role: {name}")

    def foundry_public_status(self) -> dict:
        issues = self.foundry_configuration_issues(require_enabled=False)
        return {
            "enabled": self.foundry_enabled,
            "configured": self.foundry_enabled and not issues,
            "api_version_configured": bool(self.foundry_api_version),
            "project_endpoint_configured": bool(self.foundry_project_endpoint),
            "direct_review_agent": {
                "agent_id_configured": bool(self.foundry_direct_review_agent_id),
                "endpoint_configured": bool(self.foundry_direct_review_agent_endpoint),
                "model_configured": bool(self.foundry_direct_review_model),
            },
            "hexacontext_compiler_agent": {
                "agent_id_configured": bool(self.foundry_hexacontext_compiler_agent_id),
                "endpoint_configured": bool(self.foundry_hexacontext_compiler_agent_endpoint),
                "model_configured": bool(self.foundry_hexacontext_compiler_model),
            },
            "context_assisted_review_agent": {
                "agent_id_configured": bool(self.foundry_context_review_agent_id),
                "endpoint_configured": bool(self.foundry_context_review_agent_endpoint),
                "model_configured": bool(self.foundry_context_review_model),
            },
            "configuration_issues": issues,
        }

    def supabase_configuration_issues(self) -> list[str]:
        issues: list[str] = []
        for name, value in {
            "SUPABASE_URL": self.supabase_url,
            "SUPABASE_PUBLISHABLE_KEY": self.supabase_publishable_key,
            "SUPABASE_SNAPSHOT_ID": self.supabase_snapshot_id,
            "SUPABASE_AS_OF_TIME": self.supabase_as_of_time,
        }.items():
            if not value:
                issues.append(f"{name} is required")
        if self.supabase_url:
            issue = self._url_issue("SUPABASE_URL", self.supabase_url, responses_endpoint=False)
            if issue:
                issues.append(issue)
        if self.supabase_url and not self.supabase_url.rstrip("/").endswith(".supabase.co"):
            issues.append("SUPABASE_URL must identify a Supabase project origin")
        return issues

    def require_supabase_gateway(self) -> None:
        issues = self.supabase_configuration_issues()
        if issues:
            raise SupabaseConfigurationError(issues)

    def require_supabase_evaluator(self) -> None:
        issues = self.supabase_configuration_issues()
        if not self.supabase_secret_key:
            issues.append("SUPABASE_SECRET_KEY is required for the private evaluator")
        if issues:
            raise SupabaseConfigurationError(issues)

    def supabase_public_status(self) -> dict:
        issues = self.supabase_configuration_issues()
        return {
            "configured": not issues,
            "project_ref_configured": bool(self.supabase_project_ref),
            "url_configured": bool(self.supabase_url),
            "publishable_key_configured": bool(self.supabase_publishable_key),
            "jwks_url_configured": bool(self.supabase_jwks_url),
            "snapshot_id": self.supabase_snapshot_id,
            "as_of_time": self.supabase_as_of_time,
            "configuration_issues": issues,
        }


@lru_cache(maxsize=1)
def get_settings() -> AppSettings:
    env_file = ENV_LOCAL_PATH if ENV_LOCAL_PATH.is_file() else None
    return AppSettings(_env_file=env_file, _env_file_encoding="utf-8")


def clear_settings_cache() -> None:
    get_settings.cache_clear()
