from __future__ import annotations

from datetime import datetime, timezone
import json
import unittest

import httpx

from backend.settings import AppSettings
from backend.supabase_evaluator import SupabaseEvaluatorStore


def settings() -> AppSettings:
    return AppSettings(
        _env_file=None,
        supabase_url="https://example.supabase.co",
        supabase_publishable_key="publishable-test-key",
        supabase_secret_key="secret-server-only-key",
        supabase_snapshot_id="hx-mfg-v2-snapshot-001",
        supabase_as_of_time="2026-08-01T12:00:00Z",
    )


class SupabaseEvaluatorStoreTests(unittest.IsolatedAsyncioTestCase):
    async def test_private_case_uses_only_the_service_role_rpc(self) -> None:
        captured: dict = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["path"] = request.url.path
            captured["headers"] = dict(request.headers)
            captured["payload"] = json.loads(request.content)
            return httpx.Response(
                200,
                json={
                    "case_id": "HX-V2-CASE-017",
                    "lot_id": "lot-alpha-0017",
                    "expected_disposition": "HOLD",
                    "expected_evidence": [],
                },
            )

        store = SupabaseEvaluatorStore(settings(), transport=httpx.MockTransport(handler))
        try:
            result = await store.get_case("lot-alpha-0017", "hx-mfg-v2-snapshot-001")
        finally:
            await store.aclose()

        self.assertEqual(result["expected_disposition"], "HOLD")
        self.assertEqual(captured["path"], "/rest/v1/rpc/get_private_case_evaluation")
        self.assertEqual(captured["headers"]["apikey"], "secret-server-only-key")
        self.assertEqual(captured["payload"]["p_lot_id"], "lot-alpha-0017")

    async def test_trace_run_starts_unapproved_for_fine_tuning(self) -> None:
        captured: dict = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured.update(json.loads(request.content))
            return httpx.Response(
                200,
                json={
                    "evaluation_run_id": "b9dba3e0-135b-4ec9-b6c0-89ed1c6f18f4",
                    "review_status": "DRAFT",
                    "approved_for_fine_tuning": False,
                },
            )

        now = datetime(2026, 8, 1, 12, tzinfo=timezone.utc)
        store = SupabaseEvaluatorStore(settings(), transport=httpx.MockTransport(handler))
        try:
            result = await store.store_run(
                comparison_run_id="comparison-001",
                lot_id="lot-alpha-0017",
                snapshot_id="hx-mfg-v2-snapshot-001",
                execution_mode="FOUNDRY_LIVE",
                request_hash="a" * 64,
                started_at=now,
                completed_at=now,
                model_versions={"baseline": "model-a", "hexacontext": "model-a"},
                baseline_result={"disposition": "PASS"},
                hexacontext_result={"disposition": "HOLD"},
                baseline_trace=[],
                hexacontext_trace=[],
                scores={"baseline_correct": False, "hexacontext_correct": True},
            )
        finally:
            await store.aclose()

        self.assertEqual(result["review_status"], "DRAFT")
        self.assertFalse(result["approved_for_fine_tuning"])
        self.assertNotIn("approved_for_fine_tuning", captured)


if __name__ == "__main__":
    unittest.main()
