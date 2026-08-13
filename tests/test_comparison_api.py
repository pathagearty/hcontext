from __future__ import annotations

import unittest

from fastapi.testclient import TestClient

from backend.app import app


class ComparisonApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)

    def test_create_and_read_comparison(self) -> None:
        created = self.client.post("/api/comparisons", json={"lot_id": "HX-V2-LOT-009"})
        self.assertEqual(created.status_code, 200)
        payload = created.json()
        self.assertEqual(payload["controls"]["execution_mode"], "SIMULATED_LOCAL")
        self.assertEqual(payload["baseline"]["decision"]["disposition"], "ESCALATE")
        self.assertEqual(payload["hexacontext"]["decision"]["disposition"], "ESCALATE")
        self.assertNotIn("expected_disposition", created.text)
        self.assertNotIn("primary_reason", created.text)

        fetched = self.client.get(f"/api/comparisons/{payload['comparison_run_id']}")
        self.assertEqual(fetched.status_code, 200)
        self.assertEqual(fetched.json()["comparison_run_id"], payload["comparison_run_id"])

    def test_browser_cannot_submit_actor_or_scope_fields(self) -> None:
        response = self.client.post(
            "/api/comparisons",
            json={
                "lot_id": "HX-V2-LOT-001",
                "actor_id": "attacker",
                "actor_scopes": ["restricted_hr"],
                "tenant_id": "HX-TENANT-BETA",
            },
        )
        self.assertEqual(response.status_code, 200)
        controls = response.json()["controls"]
        self.assertEqual(controls["actor_label"], "Synthetic quality reviewer")
        self.assertEqual(controls["tenant_id"], "HX-TENANT-ALPHA")

    def test_invalid_or_unknown_lot_is_rejected(self) -> None:
        malformed = self.client.post("/api/comparisons", json={"lot_id": "../../secrets"})
        self.assertEqual(malformed.status_code, 422)
        unknown = self.client.post("/api/comparisons", json={"lot_id": "HX-V2-LOT-999"})
        self.assertEqual(unknown.status_code, 404)

    def test_aggregate_summary_is_explicitly_synthetic(self) -> None:
        response = self.client.get("/api/evaluations/summary")
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["attempted_cases"], 15)
        self.assertEqual(payload["execution_mode"], "SIMULATED_LOCAL")
        self.assertIn("Foundry runs remain required", payload["note"])


if __name__ == "__main__":
    unittest.main()
