from __future__ import annotations

from datetime import datetime, timezone
from functools import lru_cache
import hashlib
from statistics import median
import time
import uuid
from typing import Any

from data.generate_supabase_v1 import (
    PRIMARY_SITE,
    PRIMARY_TENANT,
    build_dataset,
)

from .comparison_models import (
    AgentRoleSummary,
    ArmAggregate,
    ArmEvaluation,
    ArmMetrics,
    ComparisonArmResult,
    ComparisonCase,
    ComparisonDeltas,
    ComparisonEvaluation,
    ComparisonRequest,
    ComparisonResult,
    CostEstimate,
    DecisionSummary,
    EvaluationStatus,
    EvaluationSummary,
    EvidenceSummary,
    FindingSummary,
    FrozenControls,
    MetricAvailability,
    RunStatus,
    StageMetric,
    ToolTraceItem,
)
from .context_providers import (
    CONTEXT_CORE_ID,
    CONTEXT_CORE_VERSION,
    FragmentedSourceToolPlane,
    ManufacturingContextCoreProvider,
    runtime_dataset,
)
from .pricing import estimate_model_cost
from .supabase_gateway import TOOL_CONTRACT_VERSION
from .telemetry import NormalizedUsage, simulated_usage


_RUNS: dict[str, ComparisonResult] = {}
_WORKFLOW_ID = "synthetic_material_deviation_readiness_v1"

_AGENT_ROLES = [
    AgentRoleSummary(
        role_key="direct_review",
        label="Direct Review Agent",
        arm="DIRECT",
        responsibility="Gather and reconcile authorized evidence through fragmented source-domain tools, then recommend PASS, HOLD, or ESCALATE readiness.",
        input_contract="ContextRequest plus fragmented source-domain tools",
        tool_access="FRAGMENTED_SOURCE_TOOLS",
        output_contract="ReadinessRecommendation",
    ),
    AgentRoleSummary(
        role_key="hexacontext_compiler",
        label="HexaContext Compiler Agent",
        arm="WITH_HEXACONTEXT",
        responsibility="Apply a reusable Decision Profile to the persistent Manufacturing Context Core and compile a validated, source-linked Decision Packet without making final disposition.",
        input_contract="ContextRequest plus Decision Profile plus Manufacturing Context Core query contract",
        tool_access="CONTEXT_CORE_QUERY",
        output_contract="DecisionPacket",
    ),
    AgentRoleSummary(
        role_key="context_assisted_review",
        label="Context-Assisted Review Agent",
        arm="WITH_HEXACONTEXT",
        responsibility="Analyze the DecisionPacket and recommend PASS, HOLD, or ESCALATE readiness.",
        input_contract="DecisionPacket only",
        tool_access="DECISION_PACKET_ONLY",
        output_contract="ReadinessRecommendation",
    ),
]


@lru_cache(maxsize=1)
def _runtime_dataset() -> dict[str, list[dict[str, Any]]]:
    return runtime_dataset()


@lru_cache(maxsize=1)
def _evaluator_dataset() -> dict[str, list[dict[str, Any]]]:
    _, evaluator = build_dataset()
    return evaluator


def comparison_cases() -> list[ComparisonCase]:
    lots = [
        row
        for row in _runtime_dataset()["manufacturing_lots"]
        if row["tenant_id"] == PRIMARY_TENANT
    ]
    return [
        ComparisonCase(lot_id=row["lot_id"], label=f"Manufacturing lot {row['lot_id'][-3:]}")
        for row in sorted(lots, key=lambda item: item["lot_id"])
    ]


def _iso(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _decision(detail: dict[str, Any], evidence: list[EvidenceSummary]) -> tuple[DecisionSummary, FindingSummary]:
    as_of = _iso(_runtime_dataset()["dataset_snapshots"][0]["as_of_time"])
    hold_reasons: list[str] = []
    escalation_reasons: list[str] = []
    missing: list[str] = []
    stale: list[str] = []
    conflicts: list[str] = []
    conflict_ids: list[str] = []

    inspections = detail["inspections"]
    if not inspections:
        missing.append("final_inspection")
    elif any(row["result"] == "FAILED" or row["critical_defect_count"] > 0 for row in inspections):
        hold_reasons.append("Final inspection contains a critical failure.")

    certificates = detail["certificates"]
    if not certificates:
        missing.append("certificate_of_analysis")
    elif any(row["verification_status"] != "VERIFIED" for row in certificates):
        hold_reasons.append("The certificate of analysis is not verified.")

    calibrations = detail["calibrations"]
    if not calibrations:
        missing.append("equipment_calibration")
    elif any(row["calibration_status"] != "VALID" or _iso(row["valid_until"]) < as_of for row in calibrations):
        hold_reasons.append("Inspection equipment calibration is not current.")

    revisions = [
        row
        for row in detail["revisions"]
        if row["release_status"] == "RELEASED"
        and _iso(row["effective_from"]) <= as_of
        and (row["effective_to"] is None or _iso(row["effective_to"]) > as_of)
    ]
    if not revisions:
        missing.append("released_revision_alignment")
    elif len(revisions) > 1:
        conflicts.append("Multiple engineering revisions are simultaneously active and released.")
        conflict_ids.extend(row["source_record_id"] for row in revisions)
    elif detail["lot"]["observed_part_revision"] != revisions[0]["revision_code"]:
        hold_reasons.append("The observed part revision does not match the released revision.")

    supplier_events = sorted(detail["supplier_events"], key=lambda row: row["event_at"], reverse=True)
    fresh_events = [row for row in supplier_events if (as_of - _iso(row["event_at"])).days <= 90]
    if not supplier_events:
        missing.append("supplier_part_family_history")
    elif not fresh_events:
        stale.extend(row["source_record_id"] for row in supplier_events)
    elif len(fresh_events) >= 3 and all(row["outcome"] == "FAIL" for row in fresh_events[:3]):
        hold_reasons.append("The three most recent supplier quality events failed.")

    if any(row["status"] == "OPEN" for row in detail["deviations"]):
        escalation_reasons.append("An open connected deviation requires review.")

    conflict_notes = [
        row
        for row in detail["notes"]
        if any(term in row["body"].casefold() for term in ("split seal", "seal fracture"))
    ]
    if conflict_notes:
        conflicts.append("An authorized manufacturing note conflicts with the accepted inspection.")
        conflict_ids.extend(row["source_record_id"] for row in inspections)
        conflict_ids.extend(row["source_record_id"] for row in conflict_notes)

    if missing:
        escalation_reasons.append("Mandatory evidence is missing.")
    if stale:
        escalation_reasons.append("Mandatory supplier evidence is stale.")
    if conflicts:
        escalation_reasons.append("Conflicting authorized evidence requires review.")

    if hold_reasons:
        disposition = "HOLD"
        reasons = hold_reasons + escalation_reasons
    elif escalation_reasons:
        disposition = "ESCALATE"
        reasons = escalation_reasons
    else:
        disposition = "PASS"
        reasons = ["All mandatory evidence is present, current, authorized, and consistent."]

    actions = {
        "PASS": "Quality reviewer confirms or rejects release readiness.",
        "HOLD": "Quality reviewer maintains the hold and assigns remediation.",
        "ESCALATE": "Quality reviewer resolves the missing, stale, or conflicting evidence.",
    }
    decision = DecisionSummary(
        disposition=disposition,
        summary=" ".join(reasons),
        citations=[item.source_record_id for item in evidence],
        human_action=actions[disposition],
    )
    return decision, FindingSummary(
        missing=sorted(set(missing)),
        stale=sorted(set(stale)),
        conflicts=conflicts,
        conflict_source_ids=sorted(set(conflict_ids)),
    )


def _timeline(stage: str, tool_counts: list[tuple[str, int]]) -> list[ToolTraceItem]:
    return [
        ToolTraceItem(
            order=index,
            stage=stage,
            tool_name=name,
            status="SUCCEEDED" if count else "NO_MATCH",
            returned_count=count,
            elapsed_ms=2 + count,
        )
        for index, (name, count) in enumerate(tool_counts, start=1)
    ]


def _combine_usage(*items: NormalizedUsage) -> NormalizedUsage:
    complete = all(item.complete for item in items)
    if not complete:
        return NormalizedUsage(None, None, None, None, None, False)
    inputs = sum(item.input_tokens or 0 for item in items)
    outputs = sum(item.output_tokens or 0 for item in items)
    return NormalizedUsage(inputs, outputs, inputs + outputs, 0, 0, True, True)


def _unavailable_cost(reason: str = "Approved pricing is not configured for simulation models") -> CostEstimate:
    return CostEstimate(
        availability=MetricAvailability.UNAVAILABLE,
        pricing_catalog_version="unconfigured-2026-08-06",
        reason=reason,
    )


def _arm(
    request: ComparisonRequest,
    *,
    enhanced: bool,
) -> ComparisonArmResult:
    access = (
        ManufacturingContextCoreProvider().compile_case(
            request.lot_id,
            request.decision_profile_id,
        )
        if enhanced
        else FragmentedSourceToolPlane().collect_case(request.lot_id)
    )
    detail = access.detail
    evidence = access.evidence
    tool_counts = access.tool_counts
    decision, findings = _decision(detail, evidence)
    evidence_text = "|".join(item.source_record_id for item in evidence)
    tool_time = sum(2 + count for _, count in tool_counts)

    if enhanced:
        packet_text = f"DecisionPacket:{request.lot_id}:{evidence_text}:{findings.model_dump_json()}"
        compiler_usage = simulated_usage(request.task + evidence_text, packet_text)
        review_usage = simulated_usage(request.task + packet_text, decision.model_dump_json())
        usage = _combine_usage(compiler_usage, review_usage)
        compiler_ms = 12 + (compiler_usage.total_tokens or 0) // 40
        review_ms = 10 + (review_usage.total_tokens or 0) // 40
        stages = [
            StageMetric(
                stage="enhanced.hexacontext_compiler",
                label="HexaContext Compiler Agent",
                model_calls=1,
                tool_calls=len(tool_counts),
                input_tokens=compiler_usage.input_tokens,
                output_tokens=compiler_usage.output_tokens,
                total_tokens=compiler_usage.total_tokens,
                elapsed_ms=compiler_ms + tool_time,
            ),
            StageMetric(
                stage="enhanced.context_review",
                label="Context-Assisted Review Agent",
                model_calls=1,
                input_tokens=review_usage.input_tokens,
                output_tokens=review_usage.output_tokens,
                total_tokens=review_usage.total_tokens,
                elapsed_ms=review_ms,
            ),
        ]
        packet_status = (
            "INCOMPLETE"
            if findings.missing or findings.stale
            else "CONFLICTED"
            if findings.conflicts
            else "VALIDATED"
        )
        projection = access.projection_metadata or {}
        decision_packet = {
            "packet_status": packet_status,
            "subject_type": "manufacturing_lot",
            "subject_lot_id": request.lot_id,
            "context_core_id": projection.get("context_core_id"),
            "context_core_version": projection.get("context_core_version"),
            "persistence_model": projection.get("persistence_model"),
            "decision_profile_id": projection.get("decision_profile_id"),
            "decision_profile_version": projection.get("decision_profile_version"),
            "projection_strategy": projection.get("projection_strategy"),
            "core_snapshot_record_count": projection.get("core_snapshot_record_count", 0),
            "selected_evidence_count": projection.get("selected_evidence_count", len(evidence)),
            "excluded_evidence_count": projection.get("excluded_evidence_count", 0),
            "satisfied_requirement_keys": projection.get("satisfied_requirement_keys", []),
            "relationship_paths": projection.get("relationship_paths", []),
            "evidence_items": len(evidence),
            "evidence_classes": len({item.evidence_class for item in evidence}),
            "source_domains": sorted({item.source_domain for item in evidence}),
            "missing_classes": findings.missing,
            "stale_records": len(findings.stale),
            "conflicts": len(findings.conflicts),
            "access_contract": access.access_contract,
            "human_authority_retained": True,
        }
        label = "With HexaContext"
        stage_name = "enhanced.hexacontext_compiler"
        model_time = compiler_ms + review_ms
        model_calls = 2
    else:
        direct_usage = simulated_usage(request.task + evidence_text, decision.model_dump_json())
        usage = direct_usage
        direct_ms = 12 + (direct_usage.total_tokens or 0) // 40
        stages = [
            StageMetric(
                stage="baseline.direct_review",
                label="Direct Review Agent · retrieval",
                tool_calls=len(tool_counts),
                elapsed_ms=tool_time,
            ),
            StageMetric(
                stage="baseline.direct_review",
                label="Direct Review Agent · analysis",
                model_calls=1,
                input_tokens=direct_usage.input_tokens,
                output_tokens=direct_usage.output_tokens,
                total_tokens=direct_usage.total_tokens,
                elapsed_ms=direct_ms,
            ),
        ]
        decision_packet = None
        label = "Direct Review Agent"
        stage_name = "baseline.direct_review"
        model_time = direct_ms
        model_calls = 1

    # Exercise the estimator contract without presenting an invented simulation price.
    cost = estimate_model_cost(
        "simulation-hexacontext-v1" if enhanced else "simulation-manufacturing-v1",
        usage,
    )
    if cost.availability != MetricAvailability.AVAILABLE:
        cost = _unavailable_cost(cost.reason or "Approved pricing is not configured")

    return ComparisonArmResult(
        status=RunStatus.COMPLETED,
        label=label,
        decision=decision,
        evidence=evidence,
        findings=findings,
        tool_timeline=_timeline(stage_name, tool_counts),
        metrics=ArmMetrics(
            metric_source="SIMULATED_ESTIMATE",
            availability=MetricAvailability.AVAILABLE,
            model_calls=model_calls,
            tool_calls=len(tool_counts),
            returned_records=len(evidence),
            input_tokens=usage.input_tokens,
            output_tokens=usage.output_tokens,
            total_tokens=usage.total_tokens,
            foundry_request_ms=model_time,
            supabase_retrieval_ms=tool_time,
            end_to_end_ms=model_time + tool_time + 2,
            retries=0,
            stages=stages,
            estimated_model_cost=cost,
        ),
        decision_packet_summary=decision_packet,
        limitations=[
            "Local deterministic simulation; none of the three Foundry agents was invoked.",
            (
                "The Direct arm used the FragmentedSourceToolPlane preview; the assisted arm used "
                "the ManufacturingContextCoreProvider projection contract."
            ),
            "The provider contracts execute over the same generated immutable snapshot; remote Supabase RPC latency is not represented.",
            "Token and latency values validate the UI contract and are not provider telemetry.",
        ],
    )


def _evaluate_arm(
    arm: ComparisonArmResult,
    expectation: dict[str, Any],
    expected_rows: list[dict[str, Any]],
) -> ArmEvaluation:
    evidence_ids = {item.source_record_id for item in arm.evidence}
    citations = set(arm.decision.citations)
    required = {
        row["source_record_id"]
        for row in expected_rows
        if row["requirement"] == "REQUIRED"
    }
    forbidden = set(expectation["forbidden_record_ids"])
    expected_conflicts = {
        source_id
        for group in expectation["expected_conflict_groups"]
        for source_id in group["record_ids"]
    }
    found = len(required & evidence_ids)
    return ArmEvaluation(
        disposition_correct=arm.decision.disposition == expectation["expected_disposition"],
        critical_false_pass=(
            arm.decision.disposition == "PASS" and expectation["expected_disposition"] != "PASS"
        ),
        required_evidence_found=found,
        required_evidence_total=len(required),
        required_evidence_recall=round(found / len(required), 4) if required else 1.0,
        valid_citations=len(citations & evidence_ids),
        citation_count=len(citations),
        missing_evidence_detected=set(arm.findings.missing)
        == set(expectation["expected_missing_classes"]),
        stale_evidence_detected=set(arm.findings.stale)
        == set(expectation["expected_stale_record_ids"]),
        conflicts_detected=set(arm.findings.conflict_source_ids) == expected_conflicts,
        unauthorized_leakage=len((evidence_ids | citations) & forbidden),
        cross_tenant_leakage=len(
            {source_id for source_id in (evidence_ids | citations) & forbidden if "BETA" in source_id}
        ),
        schema_valid=True,
    )


def _evaluation(lot_id: str, baseline: ComparisonArmResult, enhanced: ComparisonArmResult) -> ComparisonEvaluation:
    evaluator = _evaluator_dataset()
    expectation = next(
        (row for row in evaluator["case_expectations"] if row["lot_id"] == lot_id),
        None,
    )
    if expectation is None:
        return ComparisonEvaluation(
            status=EvaluationStatus.NOT_SCORED,
            note="Not automatically scored — human review required",
        )
    expected_rows = [
        row for row in evaluator["expected_evidence"] if row["case_id"] == expectation["case_id"]
    ]
    return ComparisonEvaluation(
        status=EvaluationStatus.SCORED,
        baseline=_evaluate_arm(baseline, expectation, expected_rows),
        hexacontext=_evaluate_arm(enhanced, expectation, expected_rows),
        note="Scored after both results were produced against the private synthetic answer key.",
    )


def _decimal_delta(left: CostEstimate, right: CostEstimate) -> str | None:
    if not left.amount or not right.amount or left.currency != right.currency:
        return None
    from decimal import Decimal

    return format(Decimal(right.amount) - Decimal(left.amount), "f")


def run_comparison(request: ComparisonRequest, *, persist: bool = True) -> ComparisonResult:
    started = time.perf_counter()
    snapshot = _runtime_dataset()["dataset_snapshots"][0]
    profile = _runtime_dataset()["decision_profiles"][0]
    normalized_task = " ".join(request.task.split())
    request_hash = hashlib.sha256(normalized_task.encode("utf-8")).hexdigest()
    baseline = _arm(request, enhanced=False)
    enhanced = _arm(request, enhanced=True)
    evaluation = _evaluation(request.lot_id, baseline, enhanced)

    baseline_eval = evaluation.baseline
    enhanced_eval = evaluation.hexacontext
    result = ComparisonResult(
        comparison_run_id=str(uuid.uuid4()),
        status=RunStatus.COMPLETED,
        agent_roles=_AGENT_ROLES,
        controls=FrozenControls(
            normalized_task=normalized_task,
            request_hash=request_hash,
            lot_id=request.lot_id,
            actor_label="Synthetic quality reviewer",
            tenant_id=PRIMARY_TENANT,
            site_id=PRIMARY_SITE,
            snapshot_id=snapshot["snapshot_id"],
            dataset_version=snapshot["dataset_version"],
            record_manifest_hash=snapshot["record_manifest_hash"],
            as_of_time=snapshot["as_of_time"],
            decision_profile_id=profile["profile_id"],
            decision_profile_version=profile["profile_version"],
            context_core_id=CONTEXT_CORE_ID,
            context_core_version=CONTEXT_CORE_VERSION,
            tool_contract_version=TOOL_CONTRACT_VERSION,
            workflow_id=_WORKFLOW_ID,
            independent_variable=(
                "Context assembly: fragmented source reconciliation versus Decision Profile projection "
                "from the persistent Manufacturing Context Core."
            ),
            controlled_invariants=[
                "same synthetic case",
                "same immutable evidence universe",
                "same actor permissions",
                "same task and decision criteria",
                "same recommendation contract",
                "same qualified-human final authority",
            ],
            execution_mode="SIMULATED_LOCAL",
        ),
        baseline=baseline,
        hexacontext=enhanced,
        evaluation=evaluation,
        deltas=ComparisonDeltas(
            input_tokens=(enhanced.metrics.input_tokens or 0) - (baseline.metrics.input_tokens or 0),
            output_tokens=(enhanced.metrics.output_tokens or 0) - (baseline.metrics.output_tokens or 0),
            total_tokens=(enhanced.metrics.total_tokens or 0) - (baseline.metrics.total_tokens or 0),
            model_calls=enhanced.metrics.model_calls - baseline.metrics.model_calls,
            tool_calls=enhanced.metrics.tool_calls - baseline.metrics.tool_calls,
            end_to_end_ms=enhanced.metrics.end_to_end_ms - baseline.metrics.end_to_end_ms,
            required_evidence_found=(
                enhanced_eval.required_evidence_found - baseline_eval.required_evidence_found
                if enhanced_eval and baseline_eval
                else None
            ),
            valid_citations=(
                enhanced_eval.valid_citations - baseline_eval.valid_citations
                if enhanced_eval and baseline_eval
                else None
            ),
            estimated_model_cost=_decimal_delta(
                baseline.metrics.estimated_model_cost,
                enhanced.metrics.estimated_model_cost,
            ),
        ),
        comparison_elapsed_ms=max(
            1,
            round((time.perf_counter() - started) * 1000),
        ),
        limitations=[
            "Synthetic, Seagate-inspired benchmark with 15 designed cases; it does not describe or measure Seagate's internal workflow.",
            "This computer is showing a local deterministic comparison preview because Foundry is not configured.",
            "Tool traces execute against the generated local snapshot, not the remote Supabase Data API.",
            "Estimated model cost remains unavailable until an approved deployment-specific pricing catalog is configured.",
            "Supabase infrastructure cost is not allocated to individual tool calls.",
        ],
    )
    if persist:
        _RUNS[result.comparison_run_id] = result
    return result


def get_comparison(comparison_run_id: str) -> ComparisonResult:
    try:
        return _RUNS[comparison_run_id]
    except KeyError:
        raise KeyError(comparison_run_id) from None


def evaluation_summary() -> EvaluationSummary:
    results = [
        run_comparison(ComparisonRequest(lot_id=case.lot_id), persist=False)
        for case in comparison_cases()
    ]
    baseline_evals = [result.evaluation.baseline for result in results if result.evaluation.baseline]
    enhanced_evals = [result.evaluation.hexacontext for result in results if result.evaluation.hexacontext]

    def aggregate(arm_name: str, evaluations: list[ArmEvaluation]) -> ArmAggregate:
        arms = [getattr(result, arm_name) for result in results]
        return ArmAggregate(
            correct=sum(item.disposition_correct for item in evaluations),
            critical_false_passes=sum(item.critical_false_pass for item in evaluations),
            mean_required_evidence_recall=round(
                sum(item.required_evidence_recall for item in evaluations) / len(evaluations), 4
            ),
            valid_citations=sum(item.valid_citations for item in evaluations),
            unauthorized_leakage=sum(item.unauthorized_leakage for item in evaluations),
            total_tokens=sum(arm.metrics.total_tokens or 0 for arm in arms),
            total_model_calls=sum(arm.metrics.model_calls for arm in arms),
            total_tool_calls=sum(arm.metrics.tool_calls for arm in arms),
            median_end_to_end_ms=round(median(arm.metrics.end_to_end_ms for arm in arms)),
            estimated_model_cost=None,
        )

    baseline = aggregate("baseline", baseline_evals)
    enhanced = aggregate("hexacontext", enhanced_evals)
    return EvaluationSummary(
        dataset_version=results[0].controls.dataset_version,
        snapshot_id=results[0].controls.snapshot_id,
        execution_mode="SIMULATED_LOCAL",
        attempted_cases=len(results),
        paired_complete_cases=len(results),
        baseline=baseline,
        hexacontext=enhanced,
        deltas=ComparisonDeltas(
            input_tokens=sum(result.deltas.input_tokens or 0 for result in results),
            output_tokens=sum(result.deltas.output_tokens or 0 for result in results),
            total_tokens=enhanced.total_tokens - baseline.total_tokens,
            model_calls=enhanced.total_model_calls - baseline.total_model_calls,
            tool_calls=enhanced.total_tool_calls - baseline.total_tool_calls,
            end_to_end_ms=enhanced.median_end_to_end_ms - baseline.median_end_to_end_ms,
            required_evidence_found=sum(result.deltas.required_evidence_found or 0 for result in results),
            valid_citations=sum(result.deltas.valid_citations or 0 for result in results),
            estimated_model_cost=None,
        ),
        note=(
            "Local architecture/contract preview: the Direct arm reconciles fragmented source-domain results; "
            "the assisted arm compiles a minimum-sufficient projection from the shared Context Core. Both use "
            "the same immutable authorized facts and deterministic rules, so Foundry runs remain required for a "
            "model-performance claim."
        ),
    )
