# Architecture

> **Architecture status:** this file contains historical deterministic-harness and additive-service detail. The controlling architecture is now the three-role Context Core + Decision Profile model in [`handoff-context-packet.md`](handoff-context-packet.md). The current comparison remains `SIMULATED_LOCAL`; live Foundry orchestration is not yet implemented. Where this file conflicts with the canonical handoff, the handoff and current code take precedence.

## Architectural intent

HexaContext is an additive service called by an existing agent or workflow. It does not own the system of record, agent runtime, final business decision or enterprise identity plane.

```text
Existing agent / workflow
        |
        | ContextRequest(profile, entity, actor, task)
        v
+------------------------ HexaContext -------------------------+
|  1. Request validation and actor scope                       |
|  2. Decision-profile retrieval plan                          |
|       - exact identifiers                                    |
|       - bounded relationship traversal                       |
|       - document / narrative search                          |
|  3. Authorization before fusion or model invocation          |
|  4. Evidence normalization, provenance and freshness         |
|  5. Deterministic policy and failure handling                |
|  6. Optional bounded model explanation                       |
|  7. Typed DecisionPacket with sources, gaps and human action |
+--------------------------------------------------------------+
        |
        v
Authorized human review / existing workflow handoff
```

## Current runnable MVP

| Concern | Implementation |
|---|---|
| API | FastAPI |
| Contracts | Pydantic models |
| Local evidence | Versioned generated JSON |
| Exact retrieval | Entity-scoped deterministic lookup |
| Relationship retrieval | Bounded traversal over checked-in relationship edges |
| Narrative retrieval | Profile-scoped narrative source selection |
| Authorization | Evidence `access_scope` filter before policy/model use |
| Policy | Inspectable Python checks |
| Explanation | Deterministic mock, Azure Foundry adapter, AWS Bedrock adapter |
| UI | Responsive HTML/CSS/JavaScript served by the same API |
| Evaluation | Designed fixtures and separated expected dispositions |
| Testing | Python `unittest` engine and API suites |

The local graph and search routes are intentionally small simulations of the retrieval contract. They are not benchmarks of FalkorDB, PostgreSQL, embeddings or a production search engine.

## Request contract

```json
{
  "lot_id": "HX-LOT-1002",
  "profile_id": "manufacturing_lot_disposition_v1",
  "retrieval_mode": "hybrid",
  "provider": "mock",
  "actor_id": "demo-quality-reviewer",
  "actor_scopes": ["quality", "general"]
}
```

A production request should additionally carry tenant, trace, purpose-of-use, source-system authorization and policy-version context from the approved identity/runtime plane.

## DecisionPacket contract

The packet contains:

- deterministic `PASS`, `HOLD` or `ESCALATE` readiness;
- policy checks and source evidence IDs;
- missing-information and conflict lists;
- retrieval routes and authorization exclusions;
- model explanation source;
- required human action;
- limitations and trace/request ID.

The explanation provider never receives authority to change the disposition.

## Provider adapters

### Deterministic mock

Used for local development, evaluation and rehearsal. It creates a templated explanation from policy results. It is visibly labeled and does not pretend to be a live model.

### Azure Foundry

The adapter accepts a full approved Responses-compatible endpoint because project and deployment paths vary. Authentication is server-side through an API key or already-acquired bearer token environment variable. Before a stakeholder calls it "Foundry integrated," verify:

1. target project/deployment and exact endpoint contract;
2. approved authentication method and secret handling;
3. successful health/smoke call from the allowed network;
4. request/trace evidence;
5. malformed response and network failure behavior;
6. no fallback to mock output.

### AWS Bedrock

The adapter uses `boto3` and the Bedrock Converse API. It requires an approved model ID, AWS region and role/profile. Access is currently an explicit verification gate rather than a claimed integration.

## Production data direction

### PostgreSQL — canonical evidence and retrieval

PostgreSQL should be the primary record/evidence and audit store, not a generic "fallback":

- B-tree and composite indexes for tenant/entity/version/time lookup;
- native full-text search for document evidence;
- `pg_trgm` only where validated fuzzy identifier/name matching is useful;
- `pgvector` only where semantic retrieval improves an evaluator-approved query class;
- immutable source/version/provenance metadata;
- request, policy, reviewer and output audit records.

### FalkorDB — bounded relationship value

Use FalkorDB only for query classes that materially require multi-hop relationship traversal, such as:

```text
lot → part family → supplier → prior failures
lot → inspection → equipment → calibration
lot → work order → part revision → released policy
lot → deviation → CAPA → affected supplier/part/equipment
```

The profile should define traversal depth, allowed edge types, entity scopes and freshness. Do not expose unrestricted graph query generation to a model.

### Retrieval planner

A decision profile chooses the smallest route that can satisfy the task:

1. exact identifier lookup first;
2. native text search for controlled document retrieval;
3. vector retrieval only for semantic gaps;
4. bounded graph traversal only for relationship questions;
5. fuse, deduplicate and rank by authority/freshness;
6. abstain or escalate when required evidence is missing or contradictory.

### OPA/Rego

Move must-happen authorization and policy checks to OPA/Rego after the workflow rules are evaluator-approved. A policy call should receive structured facts and return structured allow/deny/hold/escalate reasons. Prompts should not be the only enforcement mechanism.

## Profile-specific model role

A future small profile model may help with:

- criterion/evidence normalization;
- controlled explanation style;
- query-plan suggestions subject to code validation;
- classification that is evaluated against a golden set.

It should not memorize current supplier status, policies, lot facts, identities or access grants. Those remain mutable, authorized evidence.

## Security and privacy boundary

- No credential is exposed to frontend JavaScript.
- Authorization filtering occurs before model invocation.
- Restricted evidence is not returned by the default detail API.
- Unknowns and conflicts escalate rather than being inferred away.
- The mock provider is explicit; provider failure returns an error without fixture substitution.
- Synthetic data contains no real company, supplier, employee, client or production records.

Production work still requires real identity, tenant isolation, least privilege, source authorization, secret management, logging/redaction, audit retention and threat testing.

## Failure behavior

| Failure | Required response |
|---|---|
| Unknown lot/profile | Typed `404` / validation error |
| Missing required evidence | `ESCALATE`, with exact missing fields |
| Critical failed policy | `HOLD`, with source-backed reasons |
| Conflicting authorized evidence | `ESCALATE`, no inference |
| Unauthorized evidence | Exclude before fusion/model; record count without leaking content |
| Provider not configured | `503`; no mock fallback |
| Provider network/response failure | `502`; no fabricated explanation |
| Invalid model response | Reject; deterministic packet remains authoritative |

## Deployment evolution

1. **Current:** local FastAPI + JSON + mock provider.
2. **Endpoint gate:** approved live Foundry or Bedrock explanation call with trace and failure test.
3. **Source adapter gate:** one approved synthetic or sandbox source-system contract.
4. **Persistence gate:** PostgreSQL evidence/audit implementation.
5. **Relationship gate:** add FalkorDB only if measured query value warrants it.
6. **Policy gate:** externalize approved rules to OPA/Rego.
7. **Integration gate:** expose the stable API first; add MCP only if an agent ecosystem requires tool discovery and the authorization model is preserved.
