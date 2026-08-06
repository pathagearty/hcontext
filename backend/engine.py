from __future__ import annotations

import uuid

from .data_store import get_lot
from .models import DecisionPacket, DecisionRequest, Disposition
from .policy import evaluate_policy
from .providers import ExplanationRequest, get_provider
from .retrieval import retrieve_evidence


async def compile_decision(request: DecisionRequest) -> DecisionPacket:
    lot = get_lot(request.lot_id)
    evidence, trace = retrieve_evidence(lot, request.retrieval_mode, request.actor_scopes)
    policy = evaluate_policy(evidence)

    provider = get_provider(request.provider)
    explanation_request = ExplanationRequest(
        disposition=policy.disposition.value,
        lot_id=request.lot_id,
        checks=[check.model_dump() for check in policy.checks],
        missing_information=policy.missing_information,
        conflicts=policy.conflicts,
        evidence_summaries=[f"{item.evidence_id}: {item.summary}" for item in evidence],
    )
    summary = await provider.explain(explanation_request)

    human_action = {
        Disposition.PASS: "Authorized quality reviewer confirms or rejects release readiness.",
        Disposition.HOLD: "Authorized quality reviewer maintains the hold and assigns remediation.",
        Disposition.ESCALATE: "Authorized quality reviewer obtains missing evidence or resolves conflicts.",
    }[policy.disposition]

    return DecisionPacket(
        request_id=str(uuid.uuid4()),
        lot_id=request.lot_id,
        profile_id=request.profile_id,
        disposition=policy.disposition,
        summary=summary,
        explanation_source=provider.name,
        policy_checks=policy.checks,
        evidence=evidence,
        missing_information=policy.missing_information,
        conflicts=policy.conflicts,
        retrieval_trace=trace,
        context_characters=sum(len(item.summary) for item in evidence),
        human_action=human_action,
        limitations=[
            "Synthetic data only; this is not a production quality decision system.",
            "The model explains a deterministic result and cannot release, reject, or modify a lot.",
            "Identity, source connectors, Postgres/FalkorDB persistence, and OPA deployment are adapter boundaries for a later controlled environment.",
        ],
    )
