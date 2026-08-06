from __future__ import annotations

from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field


class Disposition(str, Enum):
    PASS = "PASS"
    HOLD = "HOLD"
    ESCALATE = "ESCALATE"


class RetrievalMode(str, Enum):
    EXACT = "exact"
    GRAPH = "graph"
    SEARCH = "search"
    HYBRID = "hybrid"


class EvidenceItem(BaseModel):
    evidence_id: str
    title: str
    evidence_type: str
    source_system: str
    source_record_id: str
    authority: str
    observed_at: str
    source_version: str
    access_scope: str = "quality"
    retrieval_scope: Literal["direct", "relationship", "narrative"]
    summary: str
    signals: dict[str, Any] = Field(default_factory=dict)


class LotSummary(BaseModel):
    lot_id: str
    part_id: str
    part_revision: str
    supplier_id: str
    material: str
    quantity: int
    manufactured_at: str
    scenario: str
    expected_disposition: Disposition


class DecisionRequest(BaseModel):
    lot_id: str
    profile_id: str = "manufacturing_lot_disposition_v1"
    retrieval_mode: RetrievalMode = RetrievalMode.HYBRID
    provider: Literal["mock", "azure_foundry", "aws_bedrock"] = "mock"
    actor_id: str = "demo-quality-reviewer"
    actor_scopes: list[str] = Field(default_factory=lambda: ["quality", "general"])


class PolicyCheck(BaseModel):
    check_id: str
    label: str
    status: Literal["pass", "fail", "unknown"]
    severity: Literal["info", "warning", "critical"]
    reason: str
    evidence_ids: list[str] = Field(default_factory=list)


class RetrievalTrace(BaseModel):
    mode: RetrievalMode
    routes: list[str]
    candidate_count: int
    authorized_count: int
    excluded_unauthorized_count: int
    scopes_used: list[str]


class DecisionPacket(BaseModel):
    request_id: str
    lot_id: str
    profile_id: str
    disposition: Disposition
    summary: str
    explanation_source: str
    policy_checks: list[PolicyCheck]
    evidence: list[EvidenceItem]
    missing_information: list[str]
    conflicts: list[str]
    retrieval_trace: RetrievalTrace
    context_characters: int
    human_action: str
    limitations: list[str]


class EvaluationRow(BaseModel):
    mode: RetrievalMode
    correct: int
    total: int
    accuracy: float
    critical_false_passes: int
    over_escalations: int


class EvaluationReport(BaseModel):
    dataset_id: str
    rows: list[EvaluationRow]
    note: str
