from __future__ import annotations

import unittest

from backend.comparison_models import ComparisonRequest, EvaluationStatus
from backend.comparison_service import comparison_cases, evaluation_summary, run_comparison


class ComparisonServiceTests(unittest.TestCase):
    def test_neutral_case_list_contains_all_fifteen_without_answers(self) -> None:
        cases = comparison_cases()
        self.assertEqual(len(cases), 15)
        self.assertEqual(cases[0].lot_id, "HX-V2-LOT-001")
        for case in cases:
            rendered = case.model_dump_json().casefold()
            self.assertNotIn("pass", rendered)
            self.assertNotIn("hold", rendered)
            self.assertNotIn("escalate", rendered)
            self.assertNotIn("conflict", rendered)

    def test_comparison_freezes_controls_and_keeps_arms_isolated(self) -> None:
        result = run_comparison(ComparisonRequest(lot_id="HX-V2-LOT-009"), persist=False)
        self.assertEqual(result.controls.snapshot_id, "hx-mfg-v1-snapshot-001")
        self.assertEqual(result.controls.dataset_version, "1.0.0")
        self.assertEqual(result.controls.decision_profile_version, "1.0")
        self.assertEqual(result.controls.tool_contract_version, "1.0")
        self.assertEqual(result.controls.execution_mode, "SIMULATED_LOCAL")
        self.assertEqual(result.evaluation.status, EvaluationStatus.SCORED)
        self.assertEqual(result.controls.workflow_id, "synthetic_material_deviation_readiness_v1")
        self.assertEqual(result.controls.context_core_id, "manufacturing_context_core")
        self.assertEqual(result.controls.context_core_version, "1.0")
        self.assertIn("fragmented source", result.controls.independent_variable)
        self.assertEqual(len(result.controls.controlled_invariants), 6)
        self.assertEqual([role.role_key for role in result.agent_roles], [
            "direct_review",
            "hexacontext_compiler",
            "context_assisted_review",
        ])
        self.assertIsNone(result.baseline.decision_packet_summary)
        self.assertIsNotNone(result.hexacontext.decision_packet_summary)
        self.assertIsNot(result.baseline.evidence, result.hexacontext.evidence)
        self.assertFalse(any(role.makes_final_decision for role in result.agent_roles))

    def test_enhanced_total_includes_both_model_stages(self) -> None:
        result = run_comparison(ComparisonRequest(lot_id="HX-V2-LOT-001"), persist=False)
        stages = result.hexacontext.metrics.stages
        self.assertEqual(result.hexacontext.metrics.model_calls, 2)
        self.assertEqual(sum(stage.model_calls for stage in stages), 2)
        self.assertEqual(
            result.hexacontext.metrics.total_tokens,
            sum(stage.total_tokens or 0 for stage in stages),
        )
        self.assertGreater(result.deltas.total_tokens or 0, 0)
        self.assertLess(result.deltas.tool_calls, 0)
        self.assertTrue(
            all(item.stage == "baseline.direct_review" for item in result.baseline.tool_timeline)
        )
        self.assertEqual(
            [item.tool_name for item in result.hexacontext.tool_timeline],
            [
                "get_context_core_manifest",
                "get_decision_profile_requirements",
                "query_context_projection",
            ],
        )
        self.assertNotEqual(
            [item.tool_name for item in result.baseline.tool_timeline],
            [item.tool_name for item in result.hexacontext.tool_timeline],
        )

    def test_governed_source_domains_projection_and_packet_only_assisted_agent(self) -> None:
        result = run_comparison(ComparisonRequest(lot_id="HX-V2-LOT-001"), persist=False)
        self.assertEqual(
            {item.source_domain for item in result.hexacontext.evidence},
            {
                "MANUFACTURING_EXECUTION",
                "QUALITY_MANAGEMENT",
                "ENGINEERING_LIFECYCLE",
                "EQUIPMENT_CALIBRATION",
                "SUPPLIER_QUALITY",
            },
        )
        packet = result.hexacontext.decision_packet_summary
        self.assertIsNotNone(packet)
        assert packet is not None
        self.assertTrue(packet["human_authority_retained"])
        self.assertEqual(packet["access_contract"], "CONTEXT_CORE_QUERY")
        self.assertEqual(packet["projection_strategy"], "MINIMUM_SUFFICIENT")
        self.assertEqual(packet["context_core_id"], "manufacturing_context_core")
        self.assertEqual(packet["selected_evidence_count"], len(result.hexacontext.evidence))
        self.assertGreater(packet["excluded_evidence_count"], 0)
        self.assertTrue(all(item.relationship_path for item in result.hexacontext.evidence))
        assisted = next(
            role for role in result.agent_roles if role.role_key == "context_assisted_review"
        )
        self.assertEqual(assisted.tool_access, "DECISION_PACKET_ONLY")

    def test_hidden_evaluator_scores_missing_stale_conflict_and_leakage_cases(self) -> None:
        for lot_id in ("HX-V2-LOT-009", "HX-V2-LOT-011", "HX-V2-LOT-012", "HX-V2-LOT-014"):
            with self.subTest(lot_id=lot_id):
                result = run_comparison(ComparisonRequest(lot_id=lot_id), persist=False)
                evaluation = result.evaluation.baseline
                self.assertIsNotNone(evaluation)
                assert evaluation is not None
                self.assertTrue(evaluation.disposition_correct)
                self.assertTrue(evaluation.missing_evidence_detected)
                self.assertTrue(evaluation.stale_evidence_detected)
                self.assertTrue(evaluation.conflicts_detected)
                self.assertEqual(evaluation.unauthorized_leakage, 0)
                self.assertEqual(evaluation.cross_tenant_leakage, 0)

    def test_aggregate_does_not_manufacture_a_quality_lift(self) -> None:
        summary = evaluation_summary()
        self.assertEqual(summary.attempted_cases, 15)
        self.assertEqual(summary.paired_complete_cases, 15)
        self.assertEqual(summary.baseline.correct, summary.hexacontext.correct)
        self.assertEqual(
            summary.baseline.mean_required_evidence_recall,
            summary.hexacontext.mean_required_evidence_recall,
        )
        self.assertGreater(summary.deltas.total_tokens or 0, 0)


if __name__ == "__main__":
    unittest.main()
