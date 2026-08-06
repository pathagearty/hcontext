from __future__ import annotations

from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field


class RunStatus(str, Enum):
    COMPLETED = "COMPLETED"
    PARTIAL = "PARTIAL"
    FAILED = "FAILED"


class EvaluationStatus(str, Enum):
    SCORED = "SCORED"
    NOT_SCORED = "NOT_SCORED"
    EVALUATION_FAILED = "EVALUATION_FAILED"


class MetricAvailability(str, Enum):
    AVAILABLE = "AVAILABLE"
    PARTIAL = "PARTIAL"
    UNAVAILABLE = "UNAVAILABLE"


class ComparisonRequest(BaseModel):
    task: str = Field(default="Assess manufacturing lot disposition readiness", max_length=300)
    lot_id: str = Field(pattern=r"^HX-V2-LOT-[0-9]{3}$")
    decision_profile_id: str = Field(default="manufacturing_lot_disposition_v1", max_length=100)
    hexacontext_mode: Literal["hydrate"] = "hydrate"


class FrozenControls(BaseModel):
    normalized_task: str
    request_hash: str
    lot_id: str
    actor_label: str
    tenant_id: str
    site_id: str
    snapshot_id: str
    dataset_version: str
    record_manifest_hash: str
    as_of_time: str
    decision_profile_id: str
    decision_profile_version: str
    tool_contract_version: str
    execution_mode: Literal["SIMULATED_LOCAL", "FOUNDRY_LIVE"]


class EvidenceSummary(BaseModel):
    evidence_class: str
    source_record_id: str
    title: str
    authority: str
    observed_at: str


class FindingSummary(BaseModel):
    missing: list[str] = Field(default_factory=list)
    stale: list[str] = Field(default_factory=list)
    conflicts: list[str] = Field(default_factory=list)
    conflict_source_ids: list[str] = Field(default_factory=list)


class DecisionSummary(BaseModel):
    disposition: Literal["PASS", "HOLD", "ESCALATE"]
    summary: str
    citations: list[str]
    human_action: str


class StageMetric(BaseModel):
    stage: str
    label: str
    model_calls: int = 0
    tool_calls: int = 0
    input_tokens: int | None = None
    output_tokens: int | None = None
    total_tokens: int | None = None
    elapsed_ms: int


class CostEstimate(BaseModel):
    availability: MetricAvailability
    label: str = "Estimated variable model cost"
    currency: str | None = None
    amount: str | None = None
    pricing_catalog_version: str | None = None
    reason: str | None = None


class ArmMetrics(BaseModel):
    metric_source: Literal["PROVIDER_REPORTED", "SIMULATED_ESTIMATE"]
    availability: MetricAvailability
    model_calls: int
    tool_calls: int
    returned_records: int
    input_tokens: int | None
    output_tokens: int | None
    total_tokens: int | None
    foundry_request_ms: int
    supabase_retrieval_ms: int
    end_to_end_ms: int
    retries: int
    stages: list[StageMetric]
    estimated_model_cost: CostEstimate


class ToolTraceItem(BaseModel):
    order: int
    stage: str
    tool_name: str
    status: Literal["SUCCEEDED", "NO_MATCH", "FAILED"]
    returned_count: int
    elapsed_ms: int


class ComparisonArmResult(BaseModel):
    status: RunStatus
    label: str
    decision: DecisionSummary
    evidence: list[EvidenceSummary]
    findings: FindingSummary
    tool_timeline: list[ToolTraceItem]
    metrics: ArmMetrics
    context_packet_summary: dict | None = None
    limitations: list[str] = Field(default_factory=list)


class ArmEvaluation(BaseModel):
    disposition_correct: bool
    critical_false_pass: bool
    required_evidence_found: int
    required_evidence_total: int
    required_evidence_recall: float
    valid_citations: int
    citation_count: int
    missing_evidence_detected: bool
    stale_evidence_detected: bool
    conflicts_detected: bool
    unauthorized_leakage: int
    cross_tenant_leakage: int
    schema_valid: bool


class ComparisonEvaluation(BaseModel):
    status: EvaluationStatus
    baseline: ArmEvaluation | None = None
    hexacontext: ArmEvaluation | None = None
    note: str


class ComparisonDeltas(BaseModel):
    input_tokens: int | None
    output_tokens: int | None
    total_tokens: int | None
    model_calls: int
    tool_calls: int
    end_to_end_ms: int
    required_evidence_found: int | None
    valid_citations: int | None
    estimated_model_cost: str | None


class ComparisonResult(BaseModel):
    comparison_run_id: str
    status: RunStatus
    synthetic: bool = True
    controls: FrozenControls
    baseline: ComparisonArmResult
    hexacontext: ComparisonArmResult
    evaluation: ComparisonEvaluation
    deltas: ComparisonDeltas
    comparison_elapsed_ms: int
    limitations: list[str]


class ComparisonCase(BaseModel):
    lot_id: str
    label: str


class ArmAggregate(BaseModel):
    correct: int
    critical_false_passes: int
    mean_required_evidence_recall: float
    valid_citations: int
    unauthorized_leakage: int
    total_tokens: int
    total_model_calls: int
    total_tool_calls: int
    median_end_to_end_ms: int
    estimated_model_cost: str | None


class EvaluationSummary(BaseModel):
    dataset_version: str
    snapshot_id: str
    execution_mode: str
    attempted_cases: int
    paired_complete_cases: int
    baseline: ArmAggregate
    hexacontext: ArmAggregate
    deltas: ComparisonDeltas
    note: str
