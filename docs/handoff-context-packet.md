# HexaContext — Canonical Product, MVP, and Foundry Implementation Handoff

**Status date:** 2026-08-12
**Repository:** `https://github.com/pathagearty/hcontext`
**Current execution mode:** `SIMULATED_LOCAL`
**Target execution mode:** `FOUNDRY_LIVE`
**Data classification:** designed synthetic manufacturing data only

> **Read this first.** This document is the canonical handoff for a human or coding agent continuing HexaContext on another device. If an older repository document describes a two-agent design, calls the Decision Packet the shared context layer, or says both arms use the same tool plane, this document and the current code take precedence.

---

## 1. Executive summary

HexaContext is a proposed **governed enterprise context fabric and runtime context-synthesis layer** for AI agents.

Its purpose is to connect fragmented enterprise evidence once, preserve source identity, authority, relationships, temporal validity, authorization and policy, then compile the **minimum-sufficient context** needed by a particular agent decision.

The target pattern is:

```text
fragmented synthetic source systems
  -> persistent governed Manufacturing Context Core
     + reusable Decision Profile
  -> HexaContext Compiler
  -> minimum-sufficient, source-linked Decision Packet
  -> Context-Assisted Review Agent
  -> readiness recommendation
  -> qualified-human authority
```

The first MVP is a bounded, synthetic manufacturing demonstration. It asks whether evidence for a material-deviation or lot-disposition review is ready for a qualified human to assess.

The MVP compares that path with a direct baseline:

```text
same request + same immutable evidence universe + same controls

A. Direct Review
   -> fragmented source-domain tools
   -> Direct Review Agent reconciles evidence and recommends readiness

B. With HexaContext
   -> Manufacturing Context Core + Decision Profile
   -> HexaContext Compiler projects a Decision Packet
   -> Context-Assisted Review Agent recommends readiness from packet only
```

There are **exactly three experimental agent roles**:

1. `direct_review`
2. `hexacontext_compiler`
3. `context_assisted_review`

The qualified human is not a fourth agent. The human retains final material-disposition authority.

### Current reality

The browser application and comparison harness work locally, but the running comparison is a **deterministic simulation**, not a live Microsoft Foundry run. It validates the architecture, data contracts, provider separation, deterministic controls, packet lineage, UI and evaluation mechanics. It does not validate real model behavior, provider latency, billed cost or business lift.

### Intended next implementation

Wire the existing Foundry client/configuration and Supabase gateway foundations into a real three-agent orchestration loop while preserving the exact experiment boundaries and visible execution-mode disclosures.

---

## 2. Product definition

### 2.1 The problem

Enterprise agents often fail because their context is:

- incomplete;
- fragmented across systems;
- stale or temporally inapplicable;
- contradictory;
- noisy or excessive;
- weakly sourced;
- unauthorized for the requester;
- missing the relationships required to interpret a record.

A stronger model cannot recover evidence that was never retrieved, cannot safely repair incorrect source context, and should not be expected to enforce every hard policy from prose alone.

### 2.2 Product thesis

HexaContext should allow an enterprise to:

> **Connect once, govern once, update once, and compile different minimum-sufficient context for different agent decisions.**

The reusable product foundation is the **Context Core**, not a prompt and not a one-off packet.

### 2.3 Product components

#### Manufacturing Context Core

A persistent, governed domain context model that describes what the bounded enterprise environment knows.

It includes:

- canonical entities and IDs;
- source domains and systems;
- typed relationships;
- source record/version/content hash;
- provenance and authority;
- observed/effective time and validity windows;
- authorization scope;
- policies and deterministic controls;
- update events and affected subjects/profiles.

#### Decision Profile

A reusable, versioned contract describing what a particular decision requires.

It defines:

- required and conditional evidence classes;
- relationship paths;
- source-domain expectations;
- minimum/maximum counts;
- freshness requirements;
- authority requirements;
- deterministic policy rules;
- packet priority and output contract.

The Context Core describes **what is known**. The Decision Profile describes **what a decision needs**. They are separate compiler inputs.

#### HexaContext Compiler

A bounded context-selection role. It applies one Decision Profile to the authorized, current Context Core and emits a validated Decision Packet.

It may perform bounded reasoning for mapping, retrieval planning, ranking, conflict identification and explanation. Hard policy checks—such as calibration validity—should remain deterministic wherever mechanically testable.

The compiler does not authorize a manufacturing disposition.

#### Decision Packet

A case-specific projection for one subject, task, actor, snapshot and as-of time.

It should include:

- Context Core and Decision Profile lineage;
- selected source-backed evidence;
- relationship paths;
- provenance, authority and temporal validity;
- missing requirements;
- conflicts and policy findings;
- packet status and hash;
- explicit human-authority statement.

A Decision Packet is not the persistent shared context layer and should not become an ungoverned cache.

#### Decision agent

The downstream task agent analyzes the packet and returns the same readiness-recommendation contract as the direct baseline.

#### Qualified human

A qualified reviewer retains release, rejection, deviation approval, remediation and shipment authority.

---

## 3. What this MVP is intended to prove

The MVP is not intended to prove that HexaContext is already a production platform. It is intended to validate a narrow architecture and product hypothesis.

### 3.1 Primary proof

Can a persistent governed context model plus a reusable Decision Profile produce inspectable, minimum-sufficient, source-linked context for an agent decision?

### 3.2 Comparison proof

When the two paths use the same case, evidence universe, task, rules, permissions and output contract, does the HexaContext path materially improve any of the following enough to justify its overhead?

- required-evidence recall;
- evidence precision/noise;
- missing/stale/conflict detection;
- citation validity;
- unauthorized leakage;
- tool-selection consistency;
- reviewer acceptance or review time;
- token use, latency and cost.

The experiment must allow the answer to be **no**. The direct baseline must not be handicapped.

### 3.3 Reuse proof

Can the same Context Core support more than one Decision Profile without reconstructing or retraining the context layer?

Seeded profiles include:

- `manufacturing_lot_disposition_v1` — primary proof;
- `calibration_impact_assessment_v1` — reuse proof.

### 3.4 Update-propagation proof

Can a source fact—such as a calibration validity change—be updated once and cause affected packets to be recompiled without model retraining?

The schema includes `context_update_events` for this purpose.

### 3.5 Human-boundary proof

Can the system clearly distinguish decision readiness from authority?

`PASS` means **ready for qualified review**. It never means autonomously approved, released or shipped.

---

## 4. Scope and claim boundaries

### 4.1 In scope

- synthetic manufacturing evidence;
- material-deviation / lot-disposition readiness;
- fragmented source-domain access;
- bounded PostgreSQL relationship traversal;
- governed Context Core semantics;
- reusable Decision Profiles;
- source-linked Decision Packets;
- deterministic policy gates;
- three-agent comparison;
- hidden synthetic scoring;
- traces, usage, tool, token, latency and cost-availability contracts;
- explicit human authority.

### 4.2 Out of scope for the current MVP

- autonomous lot release/rejection;
- production QMS replacement;
- live customer or Seagate data;
- claims about private Seagate processes;
- broad enterprise digital twins;
- continuous employee/desktop sensing;
- Workfabric parity;
- production compliance certification;
- production ROI claims;
- model fine-tuning as an initial requirement;
- a required graph database;
- write actions into source systems.

### 4.3 External positioning

The workflow is **synthetic and Seagate-inspired**. It does not claim knowledge of Seagate's private processes.

Safe description:

> HexaContext is a bounded manufacturing validation of a governed context-model and runtime-synthesis pattern. It is not a Workfabric clone, a production digital twin, or a proven autonomous decision system.

---

## 5. Experimental design

### 5.1 Frozen controls

Both arms must use the same:

- synthetic subject/case;
- immutable evidence universe and snapshot;
- actor, tenant, site and authorization scopes;
- task and decision criteria;
- recommendation/output contract;
- deterministic policy rules;
- hidden evaluator answer key;
- qualified-human final authority;
- comparable model and decoding configuration when live.

### 5.2 Independent variable

The independent variable is **context assembly**:

```text
fragmented source reconciliation
versus
Decision Profile projection from the persistent Manufacturing Context Core
```

The access paths are deliberately different. “Same underlying evidence” must not be confused with “same tool contract.”

### 5.3 Role contracts

| Role | Arm | Access | Output | Authority |
|---|---|---|---|---|
| `direct_review` | Direct | `FRAGMENTED_SOURCE_TOOLS` | `ReadinessRecommendation` | Recommendation only |
| `hexacontext_compiler` | With HexaContext | `CONTEXT_CORE_QUERY` | `DecisionPacket` | No disposition authority |
| `context_assisted_review` | With HexaContext | `DECISION_PACKET_ONLY` | `ReadinessRecommendation` | Recommendation only |

The assisted reviewer must not silently retrieve additional source context.

### 5.4 Primary recommendation states

- `PASS` — evidence is ready for qualified review;
- `HOLD` — a deterministic or critical evidence condition blocks readiness;
- `ESCALATE` — missing, stale, conflicting or unresolved evidence requires qualified attention.

These states support human review. They are not source-system actions.

---

## 6. Synthetic manufacturing evidence universe

The current bounded universe models information from:

- `MANUFACTURING_EXECUTION`;
- `QUALITY_MANAGEMENT`;
- `ENGINEERING_LIFECYCLE`;
- `EQUIPMENT_CALIBRATION`;
- `SUPPLIER_QUALITY`;
- `POLICY_REGISTRY`.

Representative evidence includes:

```text
manufacturing lot
  -> work order / operation
  -> part and released revision
  -> inspection and certificate
  -> inspection equipment
  -> calibration record
  -> supplier and part-family history
  -> deviations / exceptions
  -> authorized manufacturing notes
  -> applicable policy and profile requirements
```

The scenario must remain genuinely multi-source and relationship-heavy. If one source record or one simple lookup can answer every case, the experiment does not justify a context fabric.

---

## 7. Current implementation status

### 7.1 Working now

#### Local application

- FastAPI backend;
- responsive no-build browser UI;
- 15-case side-by-side comparison preview;
- hidden synthetic post-result evaluator;
- aggregate Evaluation Lab;
- source evidence, citation and tool-timeline views;
- visible simulation limitations;
- exactly three role contracts.

#### Distinct simulated access paths

`backend/context_providers.py` implements:

- `FragmentedSourceToolPlane` for Direct Review;
- `ManufacturingContextCoreProvider` for compiler projection.

Both use the same generated immutable fixture snapshot, but they expose different access contracts. The old single `_collect_case()` path was removed.

The assisted reviewer receives the packet representation only.

#### Supabase/PostgreSQL foundation

The linked schema contains normalized synthetic manufacturing records and context-model metadata. Important migrations include:

- `20260807154128_create_context_graph_v2.sql`;
- `20260807154131_secure_and_index_context_graph_v2.sql`;
- `20260807154132_create_context_graph_tools_v2.sql`;
- `20260807155531_create_private_evaluation_api.sql`;
- `20260807161622_add_runtime_snapshot_manifest_verifier.sql`;
- `20260812165850_add_three_agent_material_deviation_demo.sql`;
- `20260812232500_align_manufacturing_context_core.sql`.

The final alignment migration adds:

- `context_cores`;
- `context_source_domains`;
- `context_entity_types`;
- `context_relationship_types`;
- `context_policy_controls`;
- `decision_profile_requirements`;
- `decision_packets`;
- `decision_packet_evidence`;
- `context_update_events`.

It extends `decision_profiles` with Context Core linkage, projection strategy, packet contract and human-authority language.

The normalized manufacturing tables remain the canonical fact layer. The Context Core registry adds semantics and governance; it does not duplicate every fact.

PostgreSQL is sufficient for this bounded graph proof. Add a dedicated graph database only if measured traversal complexity, latency or maintainability requires it.

#### Reference fixture

Supabase includes an explicitly labeled `SEEDED_REFERENCE` packet with packet-to-source evidence lineage. It is not a claimed Foundry result.

#### Foundry foundation

The repository already includes:

- typed three-agent configuration;
- distinct saved-agent IDs and per-agent Responses endpoints;
- Azure CLI / managed-identity authentication posture;
- direct `httpx` Foundry client;
- structured response schemas;
- bounded retry behavior;
- redacted errors and logs;
- usage normalization and cost-availability contracts;
- a content-suppressing Foundry smoke script;
- tests with fake transports.

#### Supabase gateway foundation

The backend gateway binds subject, snapshot, as-of time and approved actor token server-side. It is designed so agent-supplied arguments cannot widen tenant, subject or temporal scope. Private evaluator data uses a separate service-role-only path and is never an agent tool.

### 7.2 Current runtime behavior

The running comparison endpoint is:

```text
SIMULATED_LOCAL
```

It does **not** invoke:

- the three live Foundry agents;
- a live Foundry tool/function-call loop;
- remote Supabase during each comparison arm.

Its token and latency numbers are simulation estimates used to validate contracts and UI behavior. They are not provider telemetry or billing data.

### 7.3 Verified local state as of this handoff

The latest completed Python verification before this document reported:

```text
Ran 62 tests
OK
```

The local browser and API smoke test confirmed:

- health endpoint returns `ok`;
- exactly three current role keys;
- Direct and HexaContext tool timelines differ;
- packet output identifies Context Core/profile lineage;
- the UI visibly labels `SIMULATED_LOCAL`.

A new device must rerun verification; do not rely on this historical result as evidence of its environment.

### 7.4 Not implemented yet

- live three-agent comparison orchestration;
- Foundry function-call loop connected to the Supabase access contracts;
- live Context Core projection through the remote Data API inside comparison runs;
- durable comparison-run storage for the UI;
- live provider tracing/evaluators;
- authenticated end-user workflow suitable for deployment;
- qualified manufacturing review of the synthetic profile and answer key;
- production observability, load, security and failure testing;
- model-performance or ROI evidence.

---

## 8. Local setup and review

### 8.1 Prerequisites

- Python 3.11+;
- Node.js only for JavaScript syntax verification;
- Supabase CLI only for local/linked database work;
- Azure CLI only for live Foundry authentication.

### 8.2 Start the deterministic MVP

```bash
git clone https://github.com/pathagearty/hcontext.git
cd hcontext
git checkout codex/add-comparison-supabase-foundry-foundation

python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
cp .env.example .env.local

.venv/bin/python data/generate.py
.venv/bin/python data/generate_supabase_v1.py
.venv/bin/python -m uvicorn backend.app:app --host 127.0.0.1 --port 8010
```

Open:

```text
http://127.0.0.1:8010
```

The default must remain visibly labeled `SIMULATED_LOCAL`.

### 8.3 Review sequence

1. Read the architecture strip.
2. Select a neutral manufacturing lot.
3. Run the comparison.
4. Inspect “What each path did.”
5. Compare tool timelines.
6. Expand evidence/citations and inspect relationship paths and selection reasons.
7. Inspect the Decision Packet's Core/profile lineage and selected/excluded counts.
8. Review the hidden evaluator results.
9. Review all 15 cases in the Evaluation Lab.
10. Read “Method & limits” before interpreting results.

### 8.4 Local verification

```bash
.venv/bin/python -m compileall -q backend data tests
node --check frontend/app.js
.venv/bin/python -m unittest discover -s tests -v
```

Convenience targets may also be available:

```bash
make data
make test
make run
make verify
```

---

## 9. Turning the simulation into a live Foundry implementation

This is an orchestration and tool-integration project—not a rewrite of the product or UI.

### Phase 0 — freeze and reconcile contracts

Before live wiring:

1. Preserve exactly the three current role keys.
2. Freeze/version:
   - Context Request;
   - Decision Packet;
   - Readiness Recommendation;
   - Decision Profile;
   - tool contracts;
   - policy version;
   - dataset snapshot;
   - evaluator answer key.
3. Reconcile saved Foundry definitions with Git:
   - prompt/instructions;
   - agent ID and endpoint;
   - model;
   - tools;
   - response schema;
   - version/hash.
4. Do not mix saved-agent and ephemeral-agent routes inside one experimental condition.
5. Obtain qualified manufacturing/quality review of the synthetic rules and hidden expectations.

### Phase 1 — implement a live execution mode boundary

Add an explicit execution-mode dispatcher rather than replacing the local path:

```text
SIMULATED_LOCAL
FOUNDRY_LIVE
```

Requirements:

- the caller chooses or the deployment config fixes the mode explicitly;
- live mode fails closed if Foundry or Supabase is incomplete;
- no silent mock fallback;
- API and UI return the actual mode;
- every persisted run records mode, model, agent, prompt, tool, profile, policy and snapshot versions.

Recommended code boundary:

```text
ComparisonOrchestrator
  -> SimulatedComparisonRunner
  -> FoundryComparisonRunner
```

Keep response models stable so the UI can render either mode without inventing data.

### Phase 2 — wire the Direct Review Agent

Implement:

```text
ContextRequest
  -> direct_review saved Foundry endpoint
  -> fragmented read-only source tools
  -> iterative tool/function-call loop
  -> ReadinessRecommendation
```

Requirements:

- expose only approved source-domain operations;
- bind actor, tenant, subject, snapshot and as-of time in the backend;
- reject service-role keys as query identity;
- treat source content as untrusted data;
- enforce tool limits and timeouts;
- capture every tool call, arguments hash, result count, status and elapsed time;
- validate recommendation schema and citations deterministically.

The direct baseline must be competent and must not receive intentionally poorer source data.

### Phase 3 — wire the HexaContext Compiler

Implement:

```text
ContextRequest + Decision Profile
  -> hexacontext_compiler saved Foundry endpoint
  -> Context Core query/path tools
  -> deterministic packet validator
  -> DecisionPacket
```

The compiler's tools should expose governed context semantics, not masquerade as the same fragmented source tools used by Direct Review.

Minimum tool capabilities:

- read Context Core manifest/version;
- read Decision Profile requirements;
- retrieve bounded subject projection/relationship paths;
- resolve provenance, authority and temporal validity;
- identify affected/missing/conflicting evidence;
- validate packet limits and authorization.

Hard controls stay outside model discretion:

- tenant and actor authorization;
- snapshot and as-of binding;
- source-record integrity/hash checks;
- calibration validity and similar mechanical policy checks;
- packet schema/size/count limits;
- no hidden evaluator access.

Start with a normal approved model. Fine-tuning is an evidence-gated later optimization, not the definition of HexaContext.

### Phase 4 — wire the Context-Assisted Review Agent

Implement:

```text
validated DecisionPacket
  -> context_assisted_review saved Foundry endpoint
  -> ReadinessRecommendation
```

Requirements:

- packet-only input;
- no fragmented-source or Context Core retrieval tools;
- same business task and output contract as Direct Review;
- preferably the same underlying model/version and comparable decoding configuration;
- deterministic citation and recommendation validation;
- visible packet-validation failures.

Do not reuse one saved agent with materially different hidden definitions and call it a controlled comparison. Keep the three versioned roles explicit.

### Phase 5 — orchestrate paired runs

For each case:

1. Create one immutable comparison envelope.
2. Run Direct and assisted paths independently.
3. Prevent either path from reading expected answers.
4. Lock both results.
5. Score only after both results exist.
6. Count full assisted-path consumption:
   - compiler model calls/tokens/cost/latency;
   - compiler tool calls/retrieval;
   - packet validation;
   - assisted-review model calls/tokens/cost/latency.
7. Persist traces with an explicit `FOUNDRY_LIVE` label.
8. Display failures rather than substituting simulated output.

Parallel execution is optional. Experimental integrity matters more than concurrency.

### Phase 6 — validate Supabase identity and access end to end

Before claiming live integration:

- provision an approved Supabase Auth demo identity or approved JWT exchange;
- exercise RLS using the same authenticated role/claims that runtime will use;
- verify cross-tenant, cross-subject, cross-snapshot and cross-time attempts fail;
- verify private evaluator tables/RPCs are unavailable to all three agents;
- verify Context Core and profile records respect required scopes;
- verify update events recompile affected packets only;
- retain secret/service credentials on the backend only.

### Phase 7 — add live observability and evaluation

Capture separately for every stage:

- agent/model identity and version;
- prompt/schema/tool-contract hash;
- provider response ID;
- input/output/total tokens;
- retries and continuation calls;
- tool calls and returned records;
- Supabase retrieval latency;
- Foundry request latency;
- end-to-end accepted-result latency;
- estimated variable model cost and pricing-catalog version;
- unavailable telemetry as unavailable—not zero;
- evaluator metrics and human-review notes.

Azure billing data, when approved, remains the billing source of truth. Application estimates must be labeled estimates.

### Phase 8 — acceptance gate for the live MVP

Do not call the Foundry MVP complete until:

- [ ] all three agent definitions are reconciled with Git;
- [ ] Direct uses fragmented-source tools;
- [ ] Compiler uses Context Core + Decision Profile tools;
- [ ] Assisted Review receives packet only;
- [ ] no live failure silently falls back to mock;
- [ ] hidden evaluator data is inaccessible to agents;
- [ ] RLS is verified with runtime identity;
- [ ] all provider/tool continuations are counted;
- [ ] packet lineage resolves to source records;
- [ ] deterministic policy gates are tested;
- [ ] all 15 control cases run in paired live mode;
- [ ] at least the targeted v2 subset runs under the same frozen contract;
- [ ] qualified reviewer signs off on workflow/rules/answers;
- [ ] UI labels live versus simulated results correctly;
- [ ] limitations remain visible;
- [ ] no production-quality, compliance or ROI claim is made from synthetic results.

---

## 10. Foundry configuration

Copy `.env.example` to `.env.local`. Never commit `.env.local`, tokens, keys or connection strings.

The existing server configuration expects three distinct saved-agent definitions:

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

The environment-variable prefix `CONTEXT_REVIEW` is retained in current configuration for compatibility, but its canonical product/role key is `context_assisted_review`.

Local authentication should use an approved Azure CLI identity. Azure-hosted deployment should prefer an approved managed identity. Do not copy bearer tokens between devices.

On the Foundry-connected device, after configuration and `az login`:

```bash
.venv/bin/python -m scripts.foundry_smoke
```

This proves endpoint reachability only. It does not prove tool execution, schema compliance, paired comparison validity or decision quality.

---

## 11. Supabase setup and safety

### 11.1 Local database

Use the repository's Supabase configuration and migrations. A clean reset is destructive to the **local** Supabase instance and should only be run intentionally:

```bash
supabase start
supabase db reset
supabase test db
```

Confirm seed ordering loads the v2 snapshot and then calls the idempotent Context Core metadata seed function.

### 11.2 Linked project

Before any linked operation:

```bash
supabase migration list --linked
supabase db push --linked --dry-run
```

Only push reviewed forward migrations. Do not rewrite already-applied history.

### 11.3 Security rules

- browser receives no database secret;
- service role is evaluator/backend-only;
- agents never receive evaluator tools;
- authorization is enforced in database/gateway, not trusted to prompt text;
- subject/snapshot/time are bound server-side;
- source content is untrusted;
- cross-tenant and restricted distractors must remain inaccessible;
- synthetic-only data remains the default.

---

## 12. Evaluation and interpretation

### 12.1 Core metrics

- correct recommendation;
- critical false `PASS`;
- required-evidence recall;
- evidence precision/noise;
- valid citations;
- missing/stale/conflict detection;
- unauthorized and cross-tenant leakage;
- tool-call success and argument accuracy;
- packet/schema validity;
- model/tool calls;
- tokens;
- end-to-end latency;
- estimated cost availability;
- reviewer acceptance and review time.

### 12.2 Full assisted-path accounting

Never compare Direct Review only against the assisted reviewer call. The HexaContext arm includes:

```text
compiler retrieval + compiler model + packet validation + assisted reviewer model
```

All continuations, retries and failed attempts required to obtain the accepted result must be counted according to the frozen evaluation policy.

### 12.3 Current simulated result

The local deterministic comparison is intentionally conservative. Both arms see the same authorized facts and deterministic rules, so it generally reports equal designed-case quality with additional compiler/model overhead.

That is useful for contract validation, but it does not prove HexaContext improves model performance. A live Foundry comparison is required.

### 12.4 Decision rule

If a deterministic profile compiler performs as well as an LLM compiler at lower cost and risk, the deterministic implementation should win for that workflow. HexaContext's product value is governed reusable context—not requiring a model everywhere.

---

## 13. Repository map and source of truth

### Read in this order

1. `docs/handoff-context-packet.md` — this canonical product/current-state/next-build handoff.
2. `README.md` — concise setup, architecture and repository entry point.
3. `backend/context_providers.py` — current simulated access-path separation.
4. `backend/comparison_service.py` — current paired deterministic orchestration and hidden scoring.
5. `backend/comparison_models.py` — response and telemetry contracts.
6. `supabase/migrations/20260812232500_align_manufacturing_context_core.sql` — current Context Core/Profile/Packet schema direction.
7. `backend/supabase_gateway.py` — server-bound source-tool security.
8. `backend/foundry_client.py` and `backend/settings.py` — live Foundry client/config foundation.
9. `docs/foundry/tool-contracts.md` — tool security and contract detail; reconcile stale terminology against this handoff.
10. `docs/verification.md` — verification history and commands.

### Important directories

```text
backend/                 FastAPI app, deterministic harness, providers, gateways and clients
frontend/                No-build comparison UI
data/                    Deterministic fixture generators and generated fixtures
supabase/migrations/     Forward schema/RLS/RPC migrations
supabase/tests/          SQL regression tests
supabase/seed*.sql       Runtime and private evaluator seeds
tests/                   Python unit/API/security tests
docs/foundry/            Foundry implementation details and historical design material
```

### Historical documents

Some Foundry documents were originally written for a two-agent design in which one Manufacturing Agent was reused in two modes. That design was superseded by the explicit three-role experiment. Use older documents for detailed prompts, tools or Microsoft references only after reconciling them with this handoff.

---

## 14. Known risks and open decisions

### Blocking for a credible live evaluation

- qualified manufacturing/quality evaluator has not been recorded in this repository;
- saved Foundry definitions must be reconciled against Git;
- runtime Supabase identity/RLS path must be exercised end to end;
- live orchestration and function-call loops remain unimplemented;
- exact live model availability/configuration must be confirmed;
- a recorded evaluation deadline and acceptance owner must be set.

### Product questions

- Is the initial formal workflow name “Material Deviation Decision-Readiness” or “Manufacturing Lot Disposition Readiness”? Use one externally after stakeholder confirmation.
- Is Workfabric only architectural inspiration, a future integration/partner possibility, or a competitive analogue?
- Is the second Decision Profile part of the primary demo or a secondary proof?
- Which feedback loops update Core facts, Profile requirements and compiler behavior, and who approves each?
- What evidence of review-time reduction or decision-quality lift is required to proceed beyond the PoC?

### Technical risks

- simulation contracts may diverge from live agent behavior;
- saved agent definitions may drift from Git;
- source tools may accidentally give one arm broader context;
- hidden evaluator leakage could invalidate results;
- missing provider telemetry may be incorrectly treated as zero;
- Context Core metadata may drift from normalized source tables;
- packet caching could become stale or unauthorized;
- broad “digital twin” language may overstate maturity.

---

## 15. Rules for the next implementation agent

1. Do not collapse the Context Core into the Decision Packet.
2. Do not give the compiler the same fragmented-source contract and merely rename it.
3. Do not add a fourth agent for the human reviewer.
4. Do not treat `PASS` as release authorization.
5. Do not silently fall back from live Foundry to simulation.
6. Do not expose Supabase secrets or evaluator data to agents or the browser.
7. Do not use private employer/client/manufacturing data without explicit approval.
8. Do not rewrite applied migrations; add forward migrations.
9. Do not add a graph database without measured need.
10. Do not fine-tune changing enterprise facts into model weights.
11. Do not claim production accuracy, ROI, compliance, Seagate process knowledge or Workfabric parity.
12. Keep facts, simulation estimates, live telemetry and human judgments visibly distinct.
13. Run and report real tests; never invent successful outputs.
14. Preserve the direct baseline as a competent comparison.
15. Keep the current UI response contract stable unless a versioned migration is justified.

---

## 16. Immediate next-action checklist

For the next agent/device:

- [ ] clone and check out the tracked feature branch;
- [ ] read this handoff and `README.md`;
- [ ] inspect Git status before changing files;
- [ ] create `.env.local` locally; never commit it;
- [ ] regenerate fixtures and run all Python/JavaScript tests;
- [ ] run the local UI and confirm `SIMULATED_LOCAL` disclosure;
- [ ] validate a clean local Supabase reset and SQL tests;
- [ ] reconcile Foundry saved definitions with Git;
- [ ] implement explicit `FoundryComparisonRunner` orchestration;
- [ ] connect Direct Review to fragmented-source tools;
- [ ] connect Compiler to Context Core + Decision Profile tools;
- [ ] enforce packet-only assisted review;
- [ ] persist versioned live traces/results;
- [ ] run paired live cases without evaluator leakage;
- [ ] obtain qualified-human review;
- [ ] report findings without overstating synthetic evidence.

---

## 17. One-sentence handoff

> HexaContext is currently a working, synthetic, deterministic MVP that demonstrates a persistent governed Manufacturing Context Core plus reusable Decision Profiles compiling source-linked Decision Packets for a three-role controlled comparison; the next build is to connect those existing contracts and security foundations to three live Microsoft Foundry agents and Supabase-backed tool loops without changing the human-authority boundary or overstating what the PoC proves.
