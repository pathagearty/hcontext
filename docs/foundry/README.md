# Microsoft Foundry Implementation Package

## Purpose and authority

This directory contains detailed Foundry implementation material for the HexaContext manufacturing MVP.

**Read [`../handoff-context-packet.md`](../handoff-context-packet.md) first.** It is the canonical product, current-state and next-build handoff. Some files here originated during an earlier two-agent design and remain useful for prompt, schema, tool and Microsoft-reference detail, but must be reconciled with the current three-role architecture before implementation.

## Current target

```text
SAME CONTROLLED CONDITIONS
case + immutable evidence universe + actor/permissions + task/rules + output contract

DIRECT ARM
ContextRequest
  -> Direct Review Agent (`direct_review`)
  -> fragmented source-domain tools
  -> ReadinessRecommendation

WITH HEXACONTEXT
ContextRequest + Decision Profile
  -> HexaContext Compiler (`hexacontext_compiler`)
  -> governed Manufacturing Context Core query/path tools
  -> deterministically validated DecisionPacket
  -> Context-Assisted Review Agent (`context_assisted_review`)
  -> ReadinessRecommendation

BOTH
  -> qualified-human authority
```

There are exactly three experimental roles. The human reviewer is outside the agent count.

## Product distinction

- **Manufacturing Context Core:** persistent governed context foundation.
- **Decision Profile:** reusable task/evidence contract.
- **Decision Packet:** case-specific source-linked projection.
- **Compiler:** bounded context-selection role.
- **Review agents:** business-task analysis roles.

Do not call the packet the shared Context Core. Do not give Direct Review and the compiler identical tool contracts and present that as an architecture comparison.

## Current execution status

The repository currently runs the comparison in:

```text
SIMULATED_LOCAL
```

Working foundations include:

- typed three-agent settings;
- three distinct saved-agent IDs/endpoints/models;
- Azure CLI / managed-identity authentication posture;
- direct Responses client with structured outputs;
- bounded retries and redacted errors;
- usage normalization;
- Supabase source gateway with server-bound actor/subject/snapshot/time;
- private evaluator separation;
- local comparison/UI/evaluation contracts.

Not yet working:

- live three-agent orchestration;
- iterative Foundry tool/function-call execution;
- remote Supabase Context Core projection within comparison runs;
- paired live result persistence and scoring;
- live provider telemetry in the UI.

A successful endpoint smoke check proves reachability only.

## Immediate implementation decision

Use three distinct, approved saved per-agent Responses endpoints for the first live MVP, provided their saved definitions are reconciled with Git before recorded evaluation.

Current role/config mapping:

| Canonical role | Environment prefix | Access contract |
|---|---|---|
| `direct_review` | `FOUNDRY_DIRECT_REVIEW_*` | `FRAGMENTED_SOURCE_TOOLS` |
| `hexacontext_compiler` | `FOUNDRY_HEXACONTEXT_COMPILER_*` | `CONTEXT_CORE_QUERY` |
| `context_assisted_review` | `FOUNDRY_CONTEXT_REVIEW_*` | `DECISION_PACKET_ONLY` |

`FOUNDRY_CONTEXT_REVIEW_*` is retained as the current environment-variable prefix for compatibility. The canonical role key and product name are `context_assisted_review` / Context-Assisted Review Agent.

The existing client expects per-agent `/responses` endpoints, configurable API version and model. Repository history records successful endpoint reachability from a separate Foundry-connected computer, but that is not evidence that the current definitions, tools or orchestration are complete.

Do not choose or change exact models from historical prose alone. Confirm current project availability, tool/structured-output support, quota, region and organizational approval.

## Controlled comparison rules

1. Same synthetic case and immutable evidence universe.
2. Same actor, tenant, site, snapshot, as-of time and authorization.
3. Same readiness task, policy criteria and output contract.
4. Same qualified-human authority boundary.
5. Direct Review receives a competent fragmented-source tool surface.
6. Compiler receives governed Context Core + Decision Profile query/path tools.
7. Assisted Review receives Decision Packet only.
8. Hidden answers never enter prompts or tool responses.
9. Source content is untrusted data; embedded instructions are ignored.
10. No browser-held Foundry or Supabase secret.
11. No silent fallback from live mode to mock/simulation.
12. Count compiler plus assisted-review usage for the HexaContext arm.
13. Fine-tuning is not an initial acceptance requirement.

## Required live flow

### Direct arm

```text
ContextRequest
  -> direct_review endpoint
  -> iterative fragmented-source tool loop
  -> deterministic schema/citation validation
  -> ReadinessRecommendation
```

### HexaContext arm

```text
ContextRequest + Decision Profile
  -> hexacontext_compiler endpoint
  -> iterative Context Core query/path loop
  -> deterministic authorization/freshness/policy/packet validation
  -> DecisionPacket
  -> context_assisted_review endpoint (packet only)
  -> deterministic schema/citation validation
  -> ReadinessRecommendation
```

### Scoring

Only after both results are locked:

```text
paired results
  -> private evaluator boundary
  -> quality/safety metrics
  -> optional qualified-human assessment
```

## Runtime envelope

Both arms should derive from one server-owned immutable envelope:

```json
{
  "comparison_run_id": "uuid",
  "request_id": "uuid",
  "workflow_id": "synthetic_material_deviation_readiness_v1",
  "task": "Assess material-deviation disposition readiness",
  "subject_type": "manufacturing_lot",
  "subject_id": "HX-V2-LOT-009",
  "actor": {
    "actor_id": "demo-quality-reviewer",
    "tenant_id": "tenant-alpha",
    "site_id": "site-alpha",
    "scopes": ["quality", "general"]
  },
  "context_core_id": "manufacturing_context_core",
  "context_core_version": "1.0",
  "decision_profile_id": "manufacturing_lot_disposition_v1",
  "decision_profile_version": "1.0",
  "data_snapshot_id": "hx-mfg-v1-snapshot-001",
  "as_of_time": "2026-08-01T12:00:00Z",
  "execution_mode": "FOUNDRY_LIVE"
}
```

Prompt values are not authorization controls. Backend/database enforcement remains mandatory.

## Files in this package

- [`cross-computer-implementation-handoff.md`](cross-computer-implementation-handoff.md) — historical endpoint and two-computer operating details; reconcile status against the canonical handoff.
- [`setup-checklist.md`](setup-checklist.md) — project/environment checklist; use with the canonical three-role acceptance gate.
- [`tool-contracts.md`](tool-contracts.md) — detailed source tool and security contracts; split Direct and Context Core surfaces where older language treats them as common.
- [`orchestration-and-evaluation.md`](orchestration-and-evaluation.md) — evaluation detail; preserve paired controls and full-path accounting.
- [`manufacturing-agent.md`](manufacturing-agent.md) — historical business-agent specification; adapt into explicit Direct and Context-Assisted saved definitions with the same task/output contract but different input/tool boundaries.
- [`hexacontext-agent.md`](hexacontext-agent.md) — compiler detail; update source access to the Context Core + Decision Profile contract.
- [`implementation-agent-prompt-evaluation-ui.md`](implementation-agent-prompt-evaluation-ui.md) — historical implementation prompt; the current UI/harness has advanced beyond portions of it.

## Configuration

Copy `.env.example` to `.env.local` and populate only on the approved device:

```text
FOUNDRY_ENABLED=true
FOUNDRY_API_VERSION=2025-05-15-preview
FOUNDRY_PROJECT_ENDPOINT=

FOUNDRY_DIRECT_REVIEW_AGENT_ID=
FOUNDRY_DIRECT_REVIEW_AGENT_ENDPOINT=
FOUNDRY_DIRECT_REVIEW_MODEL=

FOUNDRY_HEXACONTEXT_COMPILER_AGENT_ID=
FOUNDRY_HEXACONTEXT_COMPILER_AGENT_ENDPOINT=
FOUNDRY_HEXACONTEXT_COMPILER_MODEL=

FOUNDRY_CONTEXT_REVIEW_AGENT_ID=
FOUNDRY_CONTEXT_REVIEW_AGENT_ENDPOINT=
FOUNDRY_CONTEXT_REVIEW_MODEL=

FOUNDRY_AUTH_MODE=auto
```

Never commit `.env.local`, bearer tokens, API keys, database secrets or connection strings.

Local authentication should use an approved Azure CLI identity. Azure deployment should prefer approved managed identity.

## Smoke test

After configuration and `az login`:

```bash
.venv/bin/python -m scripts.foundry_smoke
```

Expected value: verifies configuration/authentication/endpoint reachability while suppressing response content.

It does **not** verify:

- tools are correct;
- function calls execute;
- schemas match;
- the three roles are experimentally equivalent where required;
- Supabase RLS works with runtime identity;
- decisions are correct;
- costs/latency are acceptable.

## Live-mode acceptance gate

- [ ] three saved definitions reconciled with version-controlled prompts/tools/schemas;
- [ ] explicit `FOUNDRY_LIVE` runner separate from simulation;
- [ ] Direct fragmented-source loop works;
- [ ] Compiler Context Core/Profile loop works;
- [ ] packet validator works;
- [ ] assisted reviewer has packet-only access;
- [ ] Supabase runtime identity and RLS are verified end to end;
- [ ] evaluator plane is inaccessible to agents;
- [ ] no silent fallback;
- [ ] full stage usage/latency/cost availability captured;
- [ ] paired outputs scored only after both complete;
- [ ] limitations and human authority remain visible;
- [ ] qualified manufacturing/quality evaluator approves profile and answer key.

## Current official planning references

Re-check Microsoft documentation before implementing because platform APIs evolve:

- [Foundry Agent Service overview](https://learn.microsoft.com/en-us/azure/foundry/agents/overview)
- [Responses API and agent quickstarts](https://learn.microsoft.com/en-us/azure/foundry/agents/quickstarts/responses-api)
- [Structured runtime inputs](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/structured-inputs)
- [Tool best practices](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/tool-best-practice)
- [Agent development lifecycle](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/development-lifecycle)
- [Agent evaluators](https://learn.microsoft.com/en-us/azure/foundry/concepts/evaluation-evaluators/agent-evaluators)

## One-line implementation objective

> Add a fail-closed `FOUNDRY_LIVE` comparison runner that uses fragmented-source tools for Direct Review, governed Context Core + Decision Profile tools for the compiler, packet-only input for Context-Assisted Review, and private post-result scoring—without changing the synthetic-data, paired-control or qualified-human boundaries.
