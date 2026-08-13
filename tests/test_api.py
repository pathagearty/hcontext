from __future__ import annotations

import os
import unittest
from unittest.mock import patch

import httpx

from backend.app import app


class ApiTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        transport = httpx.ASGITransport(app=app)
        self.client = httpx.AsyncClient(transport=transport, base_url="http://test")

    async def asyncTearDown(self) -> None:
        await self.client.aclose()

    async def test_health(self) -> None:
        response = await self.client.get("/api/health")
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["case_count"], 12)
        self.assertTrue(payload["synthetic"])

    async def test_primary_ui_contains_demo_and_evaluation_layers(self) -> None:
        response = await self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("What each path did", response.text)
        self.assertIn("What HexaContext changed", response.text)
        self.assertIn("Quality and safety check", (await self.client.get("/static/app.js")).text)

    async def test_lot_list_and_detail(self) -> None:
        response = await self.client.get("/api/lots")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 12)
        self.assertTrue(all("expected_disposition" not in lot for lot in response.json()))
        detail = await self.client.get("/api/lots/HX-LOT-1001")
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.json()["lot_id"], "HX-LOT-1001")
        self.assertNotIn("expected_disposition", detail.json())
        restricted = (await self.client.get("/api/lots/HX-LOT-1012")).json()
        self.assertEqual(restricted["excluded_restricted_source_count"], 1)
        self.assertNotIn(
            "EV-HX-LOT-1012-RESTRICTED",
            {item["evidence_id"] for item in restricted["evidence"]},
        )

    async def test_evaluator_truth_never_leaves_runtime_endpoints(self) -> None:
        for path in ("/api/profile", "/api/lots", "/api/lots/HX-LOT-1001"):
            response = await self.client.get(path)
            self.assertEqual(response.status_code, 200)
            self.assertNotIn("expected_disposition", response.text)

    async def test_private_evaluator_endpoint_is_disabled_without_operator_token(self) -> None:
        response = await self.client.get("/api/evaluator/cases/lot-alpha-0001")
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("expected_disposition", response.text)

    async def test_unconfigured_foundry_fails_without_mock_fallback(self) -> None:
        with patch.dict(
            os.environ,
            {
                "AZURE_FOUNDRY_RESPONSES_URL": "",
                "AZURE_FOUNDRY_API_KEY": "",
                "AZURE_FOUNDRY_BEARER_TOKEN": "",
            },
            clear=False,
        ):
            response = await self.client.post(
                "/api/compile",
                json={
                    "lot_id": "HX-LOT-1001",
                    "retrieval_mode": "hybrid",
                    "provider": "azure_foundry",
                },
            )
        self.assertEqual(response.status_code, 503)
        self.assertIn("not configured", response.json()["detail"])

    async def test_compile_hybrid_hold(self) -> None:
        response = await self.client.post(
            "/api/compile",
            json={
                "lot_id": "HX-LOT-1002",
                "retrieval_mode": "hybrid",
                "provider": "mock",
            },
        )
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["disposition"], "HOLD")
        self.assertEqual(payload["explanation_source"], "mock")
        self.assertIn("bounded_relationship_traversal", payload["retrieval_trace"]["routes"])

    async def test_evaluation_is_computed_from_fixtures(self) -> None:
        response = await self.client.get("/api/evaluation")
        self.assertEqual(response.status_code, 200)
        rows = {row["mode"]: row for row in response.json()["rows"]}
        self.assertEqual(rows["hybrid"]["accuracy"], 1.0)
        self.assertLess(rows["exact"]["accuracy"], rows["hybrid"]["accuracy"])

    async def test_unknown_lot_returns_404(self) -> None:
        response = await self.client.get("/api/lots/UNKNOWN")
        self.assertEqual(response.status_code, 404)


if __name__ == "__main__":
    unittest.main()
