# Sneha HexaContext Manufacturing PoC — Handoff Context Packet

## Document purpose

This is the primary orientation document for any engineer, AI coding agent, product reviewer or stakeholder taking over this repository. Read it before changing architecture, prompts, data contracts or demo claims.

It explains:

- what HexaContext is and is not;
- why manufacturing is the initial proving workflow;
- what the current local prototype actually does;
- what the next Foundry comparison must implement;
- why two agents are planned;
- what the stakeholder demo is intended to prove;
- how success should be evaluated;
- what remains uncertain or prohibited from being claimed.

## Executive summary

HexaContext is a proposed additive context, memory and governance layer for existing AI agents. It aims to provide the minimum sufficient, authorized, current and source-backed context required for a particular task so the downstream agent does not need to search blindly or ingest an ungoverned data dump.

The initial PoC uses one synthetic manufacturing workflow: **lot disposition readiness**. An existing Manufacturing Readiness Agent must inspect direct lot records, connected supplier/equipment/revision/deviation evidence and narrative notes before recommending a human-review state.

The controlling next experiment compares:

1. **Foundry Direct:** the Manufacturing Agent gathers its own context through raw read-only tools; and
2. **With HexaContext:** a smaller HexaContext Agent plans/gathers governed context first, then passes a validated ContextPacket to the same Manufacturing Agent.

The Manufacturing Agent is identical in both arms. This isolates the value of context acquisition as much as practical.

The current local application is a deterministic synthetic harness. It demonstrates scenario logic, authorization and retrieval-mode ablations, but it does **not** yet implement the two live Foundry agents or prove business lift.

## Portfolio boundary

Sneha's HexaContext is an independent PoC. Other intern PoCs—including Nandini's, Ramyasri's and Shorya/Clearway—must remain separate products, repositories, data strategies and value demonstrations.

HexaContext might later integrate with another solution as an optional value-add layer, but those PoCs are not applications built on this repository and must not become dependencies of this demo.

## Product thesis

### Problem

Enterprise agents often receive one of two poor context conditions:

1. **Under-contexting:** the active record lacks connected facts such as supplier history, equipment state, released revisions, deviations or narrative conflicts.
2. **Over-contexting:** the agent receives a broad, noisy prompt containing stale, irrelevant, duplicate or unauthorized data.

A capable model does not solve missing, wrong or unauthorized input by itself.

### Hypothesis

A task-specific context compiler can improve agent execution by:

- interpreting a Decision Profile;
- selecting the correct exact, relationship and document retrieval routes;
- enforcing actor scope and retrieval bounds;
- preserving source identity, authority, freshness and version;
- making missing evidence and conflicts explicit;
- producing a typed ContextPacket for a downstream agent.

### Proposed value

If validated, HexaContext could provide:

- higher critical-evidence coverage;
- fewer context-related false passes or unnecessary escalations;
- more consistent tool selection;
- lower context noise and token use;
- clearer citations and provenance;
- better missing/conflict/freshness handling;
- a reusable context contract across agents and workflows;
- a path to a smaller specialized context-planning model.

These are hypotheses, not established product results.

## Why manufacturing lot disposition readiness

Manufacturing provides a useful proving wedge because required evidence is distributed across multiple source and relationship types:

```text
lot
  -> direct inspection
  -> certificate of analysis
  -> part and released revision
  -> supplier and part-family history
  -> inspection equipment and calibration
  -> deviations/exceptions
  -> narrative/operator notes
```

The workflow provides clear failure modes:

- direct critical defect;
- connected supplier failures;
- expired equipment calibration;
- revision mismatch;
- open deviation;
- stale context;
- missing mandatory evidence;
- narrative conflict;
- unauthorized distractor.

It is bounded enough for a PoC while still testing why a context layer might matter.

Manufacturing is not necessarily the final market category. It is the initial experiment.

## Target users and stakeholders

### Primary workflow user

An authorized quality engineer, supplier-quality reviewer or lot-disposition coordinator reviewing whether evidence is ready for a human disposition decision.

### Technical user

An agent/application owner who needs a reliable, inspectable way to supply context to Foundry or another agent runtime.

### Potential buyer hypothesis

Manufacturing quality, digital operations, AI platform or enterprise architecture leadership. This has not been validated through buyer interviews.

### Required evaluator

A qualified manufacturing/quality reviewer who can approve the synthetic Decision Profile, scenario expectations and acceptable failure behavior.

## Product boundary

### HexaContext may

- receive a typed ContextRequest;
- interpret an approved Decision Profile;
- plan bounded retrieval;
- call approved read-only tools;
- filter unauthorized evidence;
- verify freshness/source metadata;
- identify missing evidence and conflicts;
- return a ContextPacket or RetrievalPlan;
- record an audit/retrieval trace.

### HexaContext may not

- release or reject manufacturing lots;
- approve deviations;
- contact suppliers;
- modify source systems;
- invent manufacturing policy;
- replace a quality-management system;
- determine legal/regulatory compliance;
- infer restricted evidence;
- silently hide tool/provider errors.

The downstream Manufacturing Agent may recommend `PASS`, `HOLD` or `ESCALATE`, but a human remains the final authority.

## Two-agent architecture

### Agent 1 — Manufacturing Readiness Agent

The business-task agent. It evaluates evidence against the active Decision Profile and returns a source-grounded workflow recommendation.

Detailed specification and exact prompt:

- [`foundry/manufacturing-agent.md`](foundry/manufacturing-agent.md)

### Agent 2 — HexaContext Compiler Agent

The value-add context agent. The first MVP uses a normal approved smaller model. It either gathers a ContextPacket or returns a RetrievalPlan.

Detailed specification, exact prompt and fine-tuning path:

- [`foundry/hexacontext-agent.md`](foundry/hexacontext-agent.md)

### Baseline architecture

```text
UI/backend
  -> Manufacturing Agent
      -> Decision Profile tool
      -> lot record tool
      -> supplier history tool
      -> calibration tool
      -> revision tool
      -> deviation tool
      -> note search tool
  -> ManufacturingDecision
  -> deterministic validation
  -> human reviewer
```

### HexaContext-enhanced architecture

```text
UI/backend
  -> HexaContext Agent (smaller model)
      -> same read-only tool plane
      -> ContextPacket
      -> deterministic packet validation
  -> same Manufacturing Agent
      -> ManufacturingDecision
      -> deterministic output/citation validation
  -> human reviewer
```

The same Manufacturing Agent model, prompt, schema and business rules are used in both paths.

## HexaContext operating modes

### Hydrate

HexaContext interprets the profile, chooses tools, retrieves evidence and returns the complete ContextPacket.

This is the recommended first live implementation because it directly demonstrates the value proposition.

### Guide

HexaContext returns a typed RetrievalPlan. Deterministic backend code validates and executes the plan, then assembles the ContextPacket.

Guide mode tests whether the main value lies in specialized retrieval planning rather than model-executed retrieval. It also provides a stronger deterministic safety boundary.

### Important terminology

“Gather all relevant context” does not mean retrieve everything. It means comprehensive coverage of required evidence classes within authorization, freshness, depth, count and context-size constraints.

## Foundry implementation posture

### Recommended first implementation

Use Git-defined ephemeral agents through the Microsoft Foundry project-scoped Responses API.

Reasons:

- prompts and tool definitions remain versioned with code;
- transfer to GitHub/work computer is straightforward;
- no hidden Playground drift;
- application code controls comparison, validation and traces;
- the same definitions can later be published as prompt or hosted agents.

Foundry setup package:

- [`foundry/README.md`](foundry/README.md)
- [`foundry/setup-checklist.md`](foundry/setup-checklist.md)
- [`foundry/tool-contracts.md`](foundry/tool-contracts.md)
- [`foundry/orchestration-and-evaluation.md`](foundry/orchestration-and-evaluation.md)

### Identity boundary

```text
browser
  -> application backend
  -> Foundry project endpoint and data tools
```

The browser never receives model, database or Foundry credentials. Local development should use an approved Entra developer identity; Azure deployment should prefer managed identity where supported and approved.

## What the current repository implements

### Working local components

- FastAPI backend;
- responsive no-build browser UI;
- typed request/DecisionPacket models;
- deterministic policy checks;
- synthetic exact/relationship/narrative evidence;
- exact, graph, search and hybrid route simulation;
- actor-scope filtering;
- restricted-evidence distractor;
- deterministic mock explanation provider;
- generic Azure Foundry and AWS Bedrock explanation adapters;
- 12-case generated synthetic dataset;
- unit/API tests;
- evaluation and demo documentation.

### Current local flow

```text
selected synthetic lot
  -> simulated retrieval scope
  -> authorization filter
  -> deterministic policy engine
  -> mock/optional provider explanation
  -> DecisionPacket
```

### What is not implemented

- live Manufacturing Foundry Agent;
- live HexaContext Foundry Agent;
- project-scoped Agent Framework/Responses API orchestration;
- shared OpenAPI/function tool plane;
- concurrent baseline/enhanced comparison API;
- immutable database snapshots;
- Supabase/PostgreSQL source tools;
- Azure AI Search or real full-text retrieval;
- FalkorDB/real graph traversal;
- Foundry tracing/evaluators;
- small-model comparison;
- fine-tuning;
- production identity/governance.

## Current synthetic scenarios

| Lot | Scenario | Expected state | Main capability tested |
|---|---|---:|---|
| `HX-LOT-1001` | Complete, current, consistent evidence | PASS | Complete relationship context avoids false escalation |
| `HX-LOT-1002` | Three connected supplier failures | HOLD | Supplier/part-family relationship retrieval |
| `HX-LOT-1003` | Critical direct defect | HOLD | Simple direct-evidence control |
| `HX-LOT-1004` | Expired calibration | HOLD | Lot → equipment → calibration |
| `HX-LOT-1005` | Revision mismatch | HOLD | Observed vs authoritative released revision |
| `HX-LOT-1006` | Certificate cannot be verified | HOLD | Direct certificate control |
| `HX-LOT-1007` | Final inspection failed | HOLD | Direct inspection control |
| `HX-LOT-1008` | Open connected deviation | ESCALATE | Bounded relationship/deviation context |
| `HX-LOT-1009` | Narrative conflicts with inspection | ESCALATE | Search plus structured/graph fusion |
| `HX-LOT-1010` | Connected evidence is stale | ESCALATE | Freshness/provenance |
| `HX-LOT-1011` | Required supplier history missing | ESCALATE | Missing is unknown, not pass |
| `HX-LOT-1012` | Restricted irrelevant distractor | PASS | Authorization exclusion |

## Current synthetic result

The local deterministic harness currently reports:

| Retrieval condition | Correct fixtures | Agreement | Critical false passes |
|---|---:|---:|---:|
| Exact only | 7/12 | 58.33% | 0 |
| Graph + exact | 11/12 | 91.67% | 1 |
| Search + exact | 7/12 | 58.33% | 0 |
| Hybrid | 12/12 | 100% | 0 |

These are designed fixture outcomes. They do not establish real-world model/retrieval accuracy. The graph condition's false PASS on the narrative-conflict case demonstrates why graph-only context is insufficient.

## Intended stakeholder demo

### What the audience should see

1. The same request, actor and data snapshot.
2. The same Manufacturing Agent in both arms.
3. Foundry Direct selecting its own tools.
4. HexaContext compiling a source-backed ContextPacket with a smaller model.
5. The Manufacturing Agent evaluating that packet.
6. Side-by-side evidence coverage, citations, tool calls and outputs.
7. Missing, stale, conflicting and unauthorized evidence behavior.
8. End-to-end latency, model/tool calls, context size and cost.
9. Execution traces and explicit limitations.

### Recommended case sequence

1. Direct critical defect—both paths should work.
2. Connected supplier failure—tests relationship context.
3. Calibration/revision dependency—tests authoritative connected records.
4. Narrative conflict—tests graph plus search.
5. Missing evidence—tests safe unknown behavior.
6. Restricted distractor—tests authorization.
7. Tool/source failure—tests fail-safe behavior.

### What makes the demo credible

- live Foundry calls;
- actual tool execution;
- hidden answer keys;
- same model and data controls;
- no silent mock fallback;
- complete source/tool traces;
- honest end-to-end latency/cost;
- visible cases where the baseline succeeds;
- visible limitations and human authority.

## Evaluation thesis

The PoC must evaluate context and process, not only final prose or disposition.

### Key metrics

- required evidence recall;
- evidence precision/noise;
- critical false PASS;
- missing/conflict/freshness detection;
- citation/claim validity;
- unauthorized leakage;
- tool selection and argument accuracy;
- schema validity;
- tool/model calls;
- context/token volume;
- end-to-end latency and accepted-result cost;
- reviewer acceptance and review time.

Detailed plan:

- [`foundry/orchestration-and-evaluation.md`](foundry/orchestration-and-evaluation.md)

### Important baseline

Include a deterministic profile planner ablation. If fixed code can generate the same ContextPacket as the smaller HexaContext model, the simpler implementation should win.

## Data strategy

### Initial phase

Use only synthetic, public or explicitly approved records. Do not use employer/client/customer/partner data without explicit approval.

### Preferred isolation

If Supabase is approved, create a dedicated Supabase project for this PoC rather than reusing Shorya's prior-authorization database.

Potential data responsibilities:

```text
PostgreSQL/Supabase
  canonical synthetic entities/records
  source authority/version/freshness metadata
  immutable snapshot membership
  comparison/evaluation run records

Document/search layer
  versioned synthetic operator/manufacturing notes

Optional graph projection
  bounded approved relationships
```

The data substrate is replaceable behind the shared tool contract.

### Hidden evaluation data

Expected dispositions, required evidence IDs/classes, expected conflicts and forbidden evidence stay in evaluation fixtures and never enter runtime prompts or tool results.

See [`synthetic-data-plan.md`](synthetic-data-plan.md).

## Small model and fine-tuning direction

### Initial MVP

Use an approved normal smaller Foundry model for the HexaContext Agent. Prompt and evaluate it before any tuning.

### Fine-tuning hypothesis

A future specialized model could learn stable context-compilation behavior:

- Decision Profile → evidence coverage targets;
- tool/route selection;
- bounded valid parameters;
- stop conditions;
- missing/stale/conflict labels;
- ContextPacket/RetrievalPlan schema.

It must not memorize current manufacturing records, source versions, credentials, mutable policy or restricted data.

### Training-data gate

Training begins only after:

- trace use/training rights are approved;
- data is sanitized and tenant-isolated;
- qualified reviewers label accepted plans/packets;
- deduplication and leakage-resistant splits exist;
- the prompted baseline is stable;
- held-out/adversarial evaluation is defined;
- a measurable optimization need remains.

Fine-tuning must beat the prompted smaller model on accepted-packet quality/cost/latency without degrading evidence recall, authorization, conflict preservation or generalization.

## Major risks and pushback

### 1. The baseline may already be sufficient

A well-instructed Foundry Agent with good tools may gather the required context reliably. If so, HexaContext must demonstrate a meaningful assurance, consistency, efficiency or portability advantage—not merely add another model call.

### 2. Deterministic planning may beat an agent

The manufacturing profile is small. A deterministic planner may select the tools more reliably and cheaply. This must be included as an ablation.

### 3. Two agents add latency and cost

The enhanced arm includes an extra model stage. Report full end-to-end latency/cost. Do not compare only the downstream Manufacturing call.

### 4. Synthetic fixtures can overfit the design

The current routes and signals were designed for the expected cases. Expand the dataset and separate raw evidence extraction from answer keys before making claims.

### 5. Graph complexity may not be justified

Relational queries may cover the bounded relationships. Add a graph only if an apples-to-apples evaluation shows measured lift.

### 6. Fine-tuning may not help

Prompting, schemas and deterministic validation may be enough. Fine-tuning is conditional on evidence.

### 7. Policy correctness is external

The PoC can test evidence assembly against synthetic rules. It cannot validate real manufacturing policy without an accountable subject-matter owner.

### 8. “Governance” can be overstated

Authorization filtering, provenance and traces support governance controls; they do not automatically establish regulatory compliance.

## Continuation criteria

Continue investing if the controlled live comparison shows a material, repeatable advantage in critical evidence coverage, reviewer workflow, assurance or accepted-result economics without unacceptable complexity.

Pause or simplify if:

- the direct Foundry Agent matches HexaContext;
- deterministic planning matches the HexaContext model;
- tool/data quality is the true bottleneck;
- the added stage materially harms latency/cost;
- qualified evaluators do not recognize workflow value;
- the team cannot secure realistic approved data or source ownership.

## Implementation phases

### Phase 0 — current local harness

Status: implemented and tested.

- synthetic data;
- deterministic policy;
- retrieval-mode simulation;
- UI and smoke evaluation.

### Phase 1 — source/tool substrate

- dedicated approved data project;
- raw synthetic records without runtime answer labels;
- immutable snapshots;
- shared read-only tools;
- contract/security tests.

### Phase 2 — Manufacturing Agent baseline

- Git-defined ephemeral Foundry Agent;
- direct tool use;
- strict schema and citation validation;
- traces and hidden evaluation.

### Phase 3 — HexaContext hydrate

- smaller Foundry model;
- ContextPacket generation;
- plan/packet validation;
- same downstream Manufacturing Agent.

### Phase 4 — comparison UI/evaluation

- `/api/comparisons`;
- side-by-side UI;
- source/tool traces;
- metrics and human review.

### Phase 5 — guide/ablation experiments

- RetrievalPlan mode;
- deterministic planner;
- graph/no-graph and search/no-search;
- model-size comparison.

### Phase 6 — conditional fine-tuning

Only after the data and continuation gates are met.

## Repository map

```text
README.md                         Top-level setup/status/index
QUESTIONS.md                      Open business and technical decisions
backend/                          Current local FastAPI harness
frontend/                         Current local stakeholder UI
data/                             Synthetic generator and generated fixtures
tests/                            Current unit/API tests
docs/business-review.md           Product/business assessment
docs/architecture.md              Current and target architecture background
docs/synthetic-data-plan.md       Synthetic/evaluation data strategy
docs/demo-script.md               Current local-harness walkthrough
docs/verification.md              Executed local verification
docs/handoff-context-packet.md    This controlling orientation packet
docs/foundry/                     Two-agent Foundry implementation package
```

## First actions for a takeover agent

1. Read this packet, the top-level README and every file in `docs/foundry/`.
2. Inspect current code/tests before editing.
3. Re-check current Microsoft Foundry docs and target-project capabilities.
4. Confirm model deployments, roles, region, quota and approved identity.
5. Confirm dedicated data-project decision and manufacturing evaluator.
6. Implement the shared tool contracts before the agents.
7. Implement the Manufacturing Agent direct baseline before HexaContext.
8. Lock a baseline evaluation set and thresholds.
9. Implement HexaContext hydrate and compare against the unchanged Manufacturing Agent.
10. Verify traces, authorization and failure behavior before modifying the UI claim narrative.

Do not start with fine-tuning, a graph database or production integrations.

## Open decisions

- Exact Foundry project/region and available model deployments.
- Manufacturing Agent model.
- Smaller HexaContext model candidates.
- Qualified manufacturing profile/evaluation owner.
- Dedicated Supabase/data project approval.
- Initial hydrate vs guide priority; current recommendation is hydrate first.
- Search substrate and whether a graph is needed.
- Context/token/tool budgets.
- GitHub destination and repository visibility.
- App hosting target and managed identity/RBAC.
- Data/log retention policy.
- Live demo date and acceptance threshold approval.

See also [`../QUESTIONS.md`](../QUESTIONS.md).

## Claim boundaries

### Safe current statement

> HexaContext is a proposed additive context and assurance layer. This repository contains a tested synthetic manufacturing harness and a detailed plan to compare a direct Foundry Manufacturing Agent with the same agent supplied by a smaller HexaContext context compiler.

### Not yet supported

- production manufacturing accuracy;
- customer adoption or willingness to pay;
- regulatory compliance;
- graph-database superiority;
- fine-tuned smaller-model superiority;
- frontier-model replacement;
- enterprise-scale latency/cost savings;
- cross-domain generalization.

## Sources

### Internal project documents

- [`business-review.md`](business-review.md)
- [`architecture.md`](architecture.md)
- [`synthetic-data-plan.md`](synthetic-data-plan.md)
- [`verification.md`](verification.md)
- [`foundry/README.md`](foundry/README.md)

### Official Microsoft planning references

- [Foundry Agent Service overview](https://learn.microsoft.com/en-us/azure/foundry/agents/overview)
- [Responses API and ephemeral agents](https://learn.microsoft.com/en-us/azure/foundry/agents/quickstarts/responses-api)
- [Structured inputs](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/structured-inputs)
- [Tool best practices](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/tool-best-practice)
- [Agent development lifecycle](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/development-lifecycle)
- [Agent evaluators](https://learn.microsoft.com/en-us/azure/foundry/concepts/evaluation-evaluators/agent-evaluators)

## Final orientation

The current prototype is useful, but it is not the final proof. The next meaningful milestone is a fair, live, traceable Foundry comparison in which the same Manufacturing Agent uses either self-gathered context or a validated HexaContext packet. Build the simplest version that can answer that question honestly.