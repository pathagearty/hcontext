from __future__ import annotations

import asyncio
import unittest

from backend.data_store import expected_dispositions, get_lot, load_dataset
from backend.engine import compile_decision
from backend.models import DecisionRequest, RetrievalMode
from backend.providers import AzureFoundryExplanationProvider
from backend.retrieval import retrieve_evidence


class EngineTests(unittest.TestCase):
    def test_dataset_is_designed_and_synthetic(self) -> None:
        dataset = load_dataset()
        self.assertTrue(dataset["dataset_metadata"]["synthetic"])
        self.assertFalse(dataset["dataset_metadata"]["contains_real_company_or_client_data"])
        self.assertEqual(len(dataset["lots"]), 12)
        self.assertEqual(len({lot["lot_id"] for lot in dataset["lots"]}), 12)

    def test_hybrid_mode_matches_all_answer_keys(self) -> None:
        answer_keys = expected_dispositions()
        for lot in load_dataset()["lots"]:
            with self.subTest(lot=lot["lot_id"]):
                packet = asyncio.run(
                    compile_decision(
                        DecisionRequest(
                            lot_id=lot["lot_id"],
                            retrieval_mode=RetrievalMode.HYBRID,
                            provider="mock",
                        )
                    )
                )
                self.assertEqual(packet.disposition.value, answer_keys[lot["lot_id"]])

    def test_restricted_distractor_is_excluded(self) -> None:
        lot = get_lot("HX-LOT-1012")
        evidence, trace = retrieve_evidence(lot, RetrievalMode.HYBRID, ["quality", "general"])
        ids = {item.evidence_id for item in evidence}
        self.assertNotIn("EV-HX-LOT-1012-RESTRICTED", ids)
        self.assertEqual(trace.excluded_unauthorized_count, 1)

    def test_graph_adds_relationship_context(self) -> None:
        lot = get_lot("HX-LOT-1002")
        exact, _ = retrieve_evidence(lot, RetrievalMode.EXACT, ["quality", "general"])
        graph, _ = retrieve_evidence(lot, RetrievalMode.GRAPH, ["quality", "general"])
        self.assertGreater(len(graph), len(exact))
        self.assertFalse(any("supplier_consecutive_failures" in item.signals for item in exact))
        self.assertTrue(any("supplier_consecutive_failures" in item.signals for item in graph))

    def test_foundry_response_text_extraction(self) -> None:
        payload = {"output": [{"content": [{"type": "output_text", "text": "Governed explanation."}]}]}
        self.assertEqual(AzureFoundryExplanationProvider._extract_text(payload), "Governed explanation.")


if __name__ == "__main__":
    unittest.main()
