from __future__ import annotations

from .models import EvidenceItem, RetrievalMode, RetrievalTrace

_SCOPE_BY_MODE = {
    RetrievalMode.EXACT: {"direct"},
    RetrievalMode.GRAPH: {"direct", "relationship"},
    RetrievalMode.SEARCH: {"direct", "narrative"},
    RetrievalMode.HYBRID: {"direct", "relationship", "narrative"},
}

_ROUTES_BY_MODE = {
    RetrievalMode.EXACT: ["exact_identifier_lookup"],
    RetrievalMode.GRAPH: ["exact_identifier_lookup", "bounded_relationship_traversal"],
    RetrievalMode.SEARCH: ["exact_identifier_lookup", "document_search"],
    RetrievalMode.HYBRID: [
        "exact_identifier_lookup",
        "bounded_relationship_traversal",
        "document_search",
        "authorized_evidence_fusion",
    ],
}


def retrieve_evidence(
    lot: dict,
    mode: RetrievalMode,
    actor_scopes: list[str],
) -> tuple[list[EvidenceItem], RetrievalTrace]:
    allowed_retrieval_scopes = _SCOPE_BY_MODE[mode]
    candidates = [
        EvidenceItem.model_validate(item)
        for item in lot["evidence"]
        if item["retrieval_scope"] in allowed_retrieval_scopes
    ]
    authorized = [item for item in candidates if item.access_scope in actor_scopes]
    excluded = len(candidates) - len(authorized)
    authorized.sort(key=lambda item: (item.retrieval_scope, item.evidence_id))
    trace = RetrievalTrace(
        mode=mode,
        routes=_ROUTES_BY_MODE[mode],
        candidate_count=len(candidates),
        authorized_count=len(authorized),
        excluded_unauthorized_count=excluded,
        scopes_used=sorted(set(actor_scopes)),
    )
    return authorized, trace
