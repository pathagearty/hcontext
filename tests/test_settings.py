from __future__ import annotations

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from backend.settings import AppSettings, FoundryConfigurationError, SupabaseConfigurationError


def valid_settings(**overrides: object) -> AppSettings:
    values: dict[str, object] = {
        "foundry_enabled": True,
        "foundry_api_version": "2025-05-15-preview",
        "foundry_project_endpoint": "https://example.services.ai.azure.com/api/projects/demo",
        "foundry_direct_review_agent_id": "direct-review-agent",
        "foundry_direct_review_agent_endpoint": (
            "https://example.services.ai.azure.com/api/projects/demo/agents/"
            "direct-review-agent/endpoint/protocols/openai/responses"
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
    }
    values.update(overrides)
    return AppSettings(_env_file=None, **values)


class SettingsTests(unittest.TestCase):
    def test_valid_saved_agent_configuration(self) -> None:
        settings = valid_settings()
        settings.require_foundry()
        self.assertEqual(settings.foundry_agent("direct_review").model, "gpt-5")
        self.assertTrue(settings.foundry_public_status()["configured"])

    def test_foundry_values_are_trimmed_and_unknown_role_is_rejected(self) -> None:
        settings = valid_settings(foundry_direct_review_model="  gpt-5  ")
        self.assertEqual(settings.foundry_direct_review_model, "gpt-5")
        with self.assertRaises(ValueError):
            settings.foundry_agent("unknown")  # type: ignore[arg-type]

    def test_missing_configuration_is_reported_without_values(self) -> None:
        settings = AppSettings(_env_file=None, foundry_enabled=True)
        with self.assertRaises(FoundryConfigurationError) as context:
            settings.require_foundry()
        self.assertIn("FOUNDRY_PROJECT_ENDPOINT is required", context.exception.issues)
        status_text = str(settings.foundry_public_status())
        self.assertNotIn("https://", status_text)

    def test_agent_id_must_match_endpoint(self) -> None:
        settings = valid_settings(foundry_direct_review_agent_id="different-agent")
        with self.assertRaises(FoundryConfigurationError) as context:
            settings.require_foundry()
        self.assertTrue(any("does not match" in issue for issue in context.exception.issues))

    def test_agent_endpoints_must_be_distinct(self) -> None:
        settings = valid_settings(
            foundry_context_review_agent_id="direct-review-agent",
            foundry_context_review_agent_endpoint=(
                "https://example.services.ai.azure.com/api/projects/demo/agents/"
                "direct-review-agent/endpoint/protocols/openai/responses"
            ),
        )
        issues = settings.foundry_configuration_issues()
        self.assertTrue(any("three Foundry agent IDs must be distinct" in issue for issue in issues))
        self.assertTrue(any("three Foundry agent endpoints must be distinct" in issue for issue in issues))

    def test_agent_endpoint_must_be_https_responses_url(self) -> None:
        settings = valid_settings(
            foundry_direct_review_agent_endpoint="http://example.test/direct-review-agent/invoke"
        )
        issues = settings.foundry_configuration_issues()
        self.assertTrue(any("absolute HTTPS" in issue for issue in issues))

        settings = valid_settings(
            foundry_direct_review_agent_endpoint="https://example.test/direct-review-agent/invoke"
        )
        issues = settings.foundry_configuration_issues()
        self.assertTrue(any("/responses endpoint" in issue for issue in issues))

    def test_explicit_env_file_loads_and_environment_wins(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            env_path = Path(directory) / ".env.local"
            env_path.write_text(
                "FOUNDRY_API_VERSION=from-file\nFOUNDRY_DIRECT_REVIEW_MODEL=file-model\n",
                encoding="utf-8",
            )
            with patch.dict(os.environ, {"FOUNDRY_DIRECT_REVIEW_MODEL": "environment-model"}):
                settings = AppSettings(_env_file=env_path, _env_file_encoding="utf-8")
        self.assertEqual(settings.foundry_api_version, "from-file")
        self.assertEqual(settings.foundry_direct_review_model, "environment-model")

    def test_supabase_gateway_requires_project_origin_and_publishable_key(self) -> None:
        settings = AppSettings(_env_file=None)
        with self.assertRaises(SupabaseConfigurationError):
            settings.require_supabase_gateway()

        settings = AppSettings(
            _env_file=None,
            supabase_url="https://example.supabase.co",
            supabase_publishable_key="publishable-key",
        )
        settings.require_supabase_gateway()
        status = settings.supabase_public_status()
        self.assertTrue(status["configured"])
        self.assertNotIn("publishable-key", str(status))


if __name__ == "__main__":
    unittest.main()
