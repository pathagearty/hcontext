from __future__ import annotations

import json
import unittest

import httpx

from backend.settings import AppSettings
from backend.supabase_gateway import SupabaseToolGateway, ToolRequestContext


SNAPSHOT_ID = "hx-mfg-v1-snapshot-001"
AS_OF_TIME = "2026-08-01T12:00:00Z"


def settings() -> AppSettings:
    return AppSettings(
        _env_file=None,
        supabase_url="https://example.supabase.co",
        supabase_publishable_key="publishable-test-key",
        supabase_secret_key="secret-service-role-key",
        supabase_snapshot_id=SNAPSHOT_ID,
        supabase_as_of_time=AS_OF_TIME,
    )


def context(**overrides: str) -> ToolRequestContext:
    values = {
        "comparison_run_id": "9eaf3890-7bc0-43d7-91f0-63ab52e19575",
        "request_id": "17fc0fcb-caa1-4ef7-85c3-2773363257bb",
        "subject_lot_id": "HX-V2-LOT-011",
        "snapshot_id": SNAPSHOT_ID,
        "as_of_time": AS_OF_TIME,
        "access_token": "approved-user-jwt",
    }
    values.update(overrides)
    return ToolRequestContext(**values)


def response_envelope(tool_name: str, items: list[dict] | None = None) -> dict:
    return {
        "ok": True,
        "tool_name": tool_name,
        "tool_contract_version": "1.0",
        "data_snapshot_id": SNAPSHOT_ID,
        "items": items or [],
        "excluded_unauthorized_count": 0,
        "next_page_token": None,
        "warnings": [],
        "errors": [],
        "duration_ms": 0,
    }


class SupabaseToolGatewayTests(unittest.IsolatedAsyncioTestCase):
    async def test_server_binds_subject_snapshot_time_and_actor_token(self) -> None:
        captured: dict = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["path"] = request.url.path
            captured["headers"] = dict(request.headers)
            captured["payload"] = json.loads(request.content)
            return httpx.Response(200, json=response_envelope("get_supplier_quality_history"))

        gateway = SupabaseToolGateway(
            settings(), context(), transport=httpx.MockTransport(handler)
        )
        try:
            result = await gateway.get_supplier_quality_history(
                "HX-V2-SUP-011", "HX-V2-PART-011", lookback_days=90, limit=20
            )
        finally:
            await gateway.aclose()

        self.assertTrue(result["ok"])
        self.assertEqual(captured["path"], "/rest/v1/rpc/get_supplier_quality_history")
        self.assertEqual(captured["headers"]["apikey"], "publishable-test-key")
        self.assertEqual(captured["headers"]["authorization"], "Bearer approved-user-jwt")
        self.assertEqual(captured["payload"]["p_subject_lot_id"], "HX-V2-LOT-011")
        self.assertEqual(captured["payload"]["p_snapshot_id"], SNAPSHOT_ID)
        self.assertEqual(captured["payload"]["p_as_of_time"], AS_OF_TIME)
        self.assertNotIn("tenant_id", captured["payload"])
        self.assertNotIn("scopes", captured["payload"])
        self.assertNotIn("actor_id", captured["payload"])
        self.assertNotIn("secret-service-role-key", request_text(captured))

    async def test_successful_empty_result_is_not_a_source_failure(self) -> None:
        transport = httpx.MockTransport(
            lambda _: httpx.Response(200, json=response_envelope("get_open_deviations"))
        )
        gateway = SupabaseToolGateway(settings(), context(), transport=transport)
        try:
            result = await gateway.get_open_deviations(["part", "supplier", "equipment"])
        finally:
            await gateway.aclose()
        self.assertTrue(result["ok"])
        self.assertEqual(result["items"], [])
        self.assertEqual(result["errors"], [])

    async def test_source_failure_is_not_reported_as_missing_evidence(self) -> None:
        transport = httpx.MockTransport(lambda _: httpx.Response(503, json={"message": "db down"}))
        gateway = SupabaseToolGateway(settings(), context(), transport=transport)
        try:
            result = await gateway.get_equipment_calibration("HX-V2-EQP-011")
        finally:
            await gateway.aclose()
        self.assertFalse(result["ok"])
        self.assertEqual(result["items"], [])
        self.assertEqual(result["errors"][0]["code"], "SOURCE_UNAVAILABLE")
        self.assertNotIn("db down", str(result))

    async def test_invalid_or_cross_subject_call_never_reaches_source(self) -> None:
        calls = 0

        def handler(_: httpx.Request) -> httpx.Response:
            nonlocal calls
            calls += 1
            return httpx.Response(200, json=response_envelope("get_lot_record"))

        gateway = SupabaseToolGateway(
            settings(), context(), transport=httpx.MockTransport(handler)
        )
        try:
            result = await gateway.get_lot_record("HX-V2-LOT-012")
            search_result = await gateway.search_manufacturing_notes([], "")
        finally:
            await gateway.aclose()
        self.assertFalse(result["ok"])
        self.assertEqual(result["errors"][0]["code"], "INVALID_ARGUMENT")
        self.assertFalse(search_result["ok"])
        self.assertEqual(calls, 0)

    def test_service_role_key_is_rejected_as_query_identity(self) -> None:
        with self.assertRaisesRegex(ValueError, "service-role/secret key"):
            SupabaseToolGateway(
                settings(),
                context(access_token="secret-service-role-key"),
                transport=httpx.MockTransport(lambda _: httpx.Response(200)),
            )

    def test_cross_snapshot_or_time_context_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "snapshot"):
            SupabaseToolGateway(
                settings(),
                context(snapshot_id="wrong-snapshot"),
                transport=httpx.MockTransport(lambda _: httpx.Response(200)),
            )
        with self.assertRaisesRegex(ValueError, "pinned time"):
            SupabaseToolGateway(
                settings(),
                context(as_of_time="2026-08-02T12:00:00Z"),
                transport=httpx.MockTransport(lambda _: httpx.Response(200)),
            )


def request_text(captured: dict) -> str:
    return json.dumps(captured, sort_keys=True)


if __name__ == "__main__":
    unittest.main()
