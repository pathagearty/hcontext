# Implementation Agent Prompt — Two-Arm Evaluation, Telemetry and UI

## How to use this file

Give this entire document to the implementation agent working in the HexaContext repository. It is both the task prompt and the acceptance contract.

Do not paste credentials, private endpoints, bearer tokens, database passwords or service-role keys into the agent conversation. Configure approved values through the repository's ignored environment file or the approved secret-management path on the Foundry-connected computer.

---

## Prompt begins

You are the implementation agent responsible for evolving Sneha's HexaContext manufacturing MVP from its legacy deterministic retrieval-mode UI into a verified side-by-side Foundry comparison with first-party evaluation and telemetry.

Work thoughtfully and incrementally. Inspect the current repository before editing. Preserve working behavior until the replacement path has been exercised and verified. Do not describe a plan and stop: implement the requested artifacts, run them, test them and report actual outputs. If live Foundry or Supabase configuration is unavailable on your computer, complete the provider-independent implementation with fakes/contract tests, mark live-only verification as blocked and never substitute mock results while labeling them live.

## Repository and read order

Repository:

```text
/Users/claw1/sneha-hexacontext-mvp
```

Read these before changing code:

1. [`cross-computer-implementation-handoff.md`](cross-computer-implementation-handoff.md)
2. [`../handoff-context-packet.md`](../handoff-context-packet.md)
3. [`../supabase-synthetic-dataset-v1.md`](../supabase-synthetic-dataset-v1.md)
4. [`orchestration-and-evaluation.md`](orchestration-and-evaluation.md)
5. [`manufacturing-agent.md`](manufacturing-agent.md)
6. [`hexacontext-agent.md`](hexacontext-agent.md)
7. [`tool-contracts.md`](tool-contracts.md)
8. [`setup-checklist.md`](setup-checklist.md)
9. `backend/foundry_client.py`
10. `backend/settings.py`
11. `backend/models.py`
12. `backend/app.py`
13. `frontend/index.html`
14. `frontend/app.js`
15. `frontend/styles.css`
16. all current tests

Then inspect:

```bash
git status --short
git diff --check
```

There may be active, uncommitted work from another computer. Do not overwrite unrelated changes, reset the repository, force checkout files, delete files or commit without explicit approval.

## Product objective

Implement a clear stakeholder-facing experiment that answers:

> For the same manufacturing request, actor, source snapshot, tool plane and Manufacturing Agent, does adding HexaContext improve evidence coverage, provenance, conflict/missing/freshness detection, authorization assurance or decision quality enough to justify its extra model calls, latency, cost and complexity?

The comparison is:

```text
Arm A — Foundry Direct
same request
  -> Manufacturing Readiness Agent
  -> approved read-only Supabase tools
  -> ManufacturingDecision

Arm B — With HexaContext, hydrate first
same request
  -> HexaContext Compiler Agent
  -> same approved read-only Supabase tools
  -> validated ContextPacket
  -> same Manufacturing Readiness Agent
  -> ManufacturingDecision
```

The Manufacturing Agent is the downstream business-task agent in both arms. HexaContext compiles context; it does not own the manufacturing disposition. An authorized human remains responsible for release, rejection, deviation and remediation decisions.

## Current verified repository state

Treat these as current implementation facts until your inspection proves otherwise:

- The primary UI is now the side-by-side comparison experience; the legacy deterministic APIs remain as a regression fallback.
- `POST /api/compile` compiles one deterministic `DecisionPacket`.
- `GET /api/evaluation` evaluates retrieval modes over the designed JSON fixtures.
- `GET /api/comparison-cases`, `POST /api/comparisons`, `GET /api/comparisons/{comparison_run_id}` and `GET /api/evaluations/summary` are implemented for a synchronous deterministic local preview.
- The two live Foundry architectures are not yet orchestrated end to end.
- The Supabase tool gateway and immutable snapshot substrate are implemented, but this computer does not have the approved user identity/Foundry configuration needed to exercise the live path.
- The local preview uses server-owned synthetic actor, snapshot and profile controls and gives both arms the same authorized evidence.
- The local preview is explicitly labeled `SIMULATED_LOCAL`; its token and latency values are simulated estimates, not provider-reported usage.
- The pricing catalog is intentionally empty until approved rates and billing type are supplied, so estimated model cost is `UNAVAILABLE` rather than invented.
- Comparison results are held in memory for this single-user MVP; durable multi-user history remains a later requirement if the experiment advances.
- `backend/foundry_client.py` already supports the saved-agent Responses endpoints, typed configuration, Entra authentication, bounded retries, strict JSON schema payloads and tool definitions.
- `FoundryCallMetadata` already captures:
  - agent and agent ID;
  - model and API version;
  - response and request IDs;
  - HTTP/response status;
  - `elapsed_ms`;
  - attempts and retries;
  - raw provider `usage` when present.
- Existing redaction intentionally removes prompts, evidence, tool output and credentials from log summaries. Preserve that boundary.
- Existing deterministic and Foundry-client tests must continue to pass.
- A previously successful saved-agent HTTP call proves connectivity only. It does not prove the comparison, tools, structured decision, evaluation or UI.

Do not claim that a feature is live merely because this prompt specifies it.

### Deliberate MVP scope

Keep the next implementation step as small as possible. The local preview exists to validate whether the side-by-side UI, hidden scoring and cost/latency accounting make the experiment understandable. Do not add queues, streaming, durable comparison tables, a graph database, per-query Supabase cost allocation or a generalized evaluation platform unless live use demonstrates a concrete need.

The next meaningful increment is the live Foundry tool loop on the approved computer. Replace simulated usage with provider-reported usage summed across every call, measure backend stage latency, and preserve the current honest result presentation. A negative or neutral HexaContext result is valid experimental output.

## Required outcome

Deliver a working comparison experience with:

1. one controlled comparison request;
2. isolated direct and HexaContext arms;
3. normalized per-call and per-arm telemetry;
4. Supabase tool-call telemetry;
5. hidden deterministic evaluation for the versioned synthetic benchmark;
6. immediate estimated model cost where defensible;
7. clear distinction between estimated cost and actual billed cost;
8. side-by-side result and trace UI;
9. aggregate Evaluation Lab for completed benchmark runs;
10. tests and actual verification output.

## Non-negotiable experiment controls

Every comparison must pin and persist:

```text
normalized request text/hash
lot/entity ID
authenticated actor ID and derived scopes
tenant and site from trusted identity
snapshot ID and as-of time
Decision Profile ID/version/hash
Manufacturing Agent ID/model/prompt version
HexaContext Agent ID/model/prompt version
shared tool-contract version
output-schema versions
timeout and retry policy
pricing-catalog version or explicit unavailable state
```

The browser must not select or submit trusted scopes, tenant IDs, answer keys, model identifiers or hidden expected outcomes. Derive them server-side.

Both arms must use:

- the same normalized task;
- the same lot/entity;
- the same actor permissions;
- the same Supabase snapshot;
- the same Decision Profile;
- the same Manufacturing Agent deployment and instructions;
- the same underlying read-only tools and source data;
- the same ManufacturingDecision schema;
- comparable timeout/retry limits.

Do not weaken the direct baseline. HexaContext must earn any improvement through planning, bounded retrieval, validation and packaging—not exclusive data access.

## Architecture to implement

```text
Browser
  -> POST /api/comparisons
      -> freeze controls and create comparison_run_id
      -> Arm A: run Manufacturing Agent direct
           -> validated read-only tool loop
           -> ManufacturingDecision validation
      -> Arm B: run HexaContext hydrate
           -> validated read-only tool loop
           -> ContextPacket validation
           -> run same Manufacturing Agent over ContextPacket
           -> ManufacturingDecision validation
      -> lock both terminal arm results
      -> run private evaluator if the subject belongs to a benchmark dataset
      -> persist comparison, stages, model calls, tool calls and evaluation
  -> render side-by-side result
```

Keep arm state isolated. Do not share messages, previous response IDs, tool results or model state between arms.

Start both arms only after controls and snapshot are frozen. The HexaContext arm's end-to-end latency begins before its compiler call and ends after its downstream Manufacturing result is validated.

## Implementation phases

Follow this order. Do not redesign the UI first and then invent data contracts around it.

### Phase 1 — typed comparison and telemetry contracts

Add typed models for at least:

```text
ComparisonRequest
FrozenComparisonControls
ComparisonRun
ComparisonArmResult
ComparisonStatus
ManufacturingDecision
ContextPacket reference/summary
ModelCallMetrics
ToolCallMetrics
ArmMetrics
EvaluationResult
MetricAvailability
CostEstimate
```

Suggested statuses:

```text
QUEUED
RUNNING
COMPLETED
FAILED
PARTIAL
NOT_SCORED
```

Do not expose raw hidden evaluator rows through runtime models.

### Phase 2 — normalize Foundry usage and model-call telemetry

Build a normalization layer over `FoundryCallMetadata` rather than changing every caller to interpret provider dictionaries.

Normalize, when returned:

```text
input_tokens
output_tokens
total_tokens
cached_input_tokens, if reported
reasoning/output-detail tokens, if reported
model call elapsed_ms
attempts
retry_count
response_id
request_id
agent_id
model
API version
status
```

Rules:

- Preserve the raw provider usage only in an approved server-side field if needed for debugging.
- Never expose arbitrary unvalidated provider payloads directly to the browser.
- Treat missing usage as unavailable, not zero.
- Validate token fields as nonnegative integers.
- Prefer provider-reported `total_tokens`.
- If total is absent but input and output are present, derive a total once and mark it derived.
- Do not double-count cached or reasoning-detail tokens when they are already included in provider totals.
- Aggregate every model call in a tool loop, not only the final response.
- Record failed attempts/retries and whether provider usage was available.
- Continue preserving response IDs for Foundry/Application Insights correlation.

The current client already measures elapsed time with a monotonic clock. Reuse that behavior and test it.

### Phase 3 — model-cost estimator

Implement an explicit estimator, not a hardcoded UI number.

Use a versioned, non-secret pricing catalog or configuration such as:

```text
config/model_pricing.json
```

Each entry should contain enough metadata to avoid ambiguity:

```text
pricing_catalog_version
effective_date
provider
billing_type
model/deployment match
currency
input token unit/rate
output token unit/rate
optional cached-input rate
source/reference URL
reviewed_at
```

Requirements:

- Use decimal-safe arithmetic.
- Persist unrounded component estimates; round only for display.
- Return separate input, output, cached and total estimates where supported.
- Label the result `ESTIMATED`, never `ACTUAL`.
- Return `UNAVAILABLE` with a reason when:
  - pricing is not configured;
  - the deployment/model cannot be matched;
  - token usage is missing;
  - billing is capacity/provisioned and a per-run token price is not defensible.
- Do not invent a price.
- Do not scrape pricing during a request.
- Do not hardcode a price silently in JavaScript.
- Include the pricing-catalog version in each result.
- Keep Azure Cost Management as the post-consumption billing source of truth.

For the HexaContext arm, the displayed total must include:

```text
HexaContext compiler model calls
+
HexaContext tool-loop continuation calls
+
Manufacturing Agent model calls
+
Manufacturing tool-loop continuation calls, if any
```

Do not present Supabase's fixed/project infrastructure cost as an invented per-query charge. Display Supabase tool count, records and latency separately.

### Phase 4 — tool telemetry

Wrap every approved Supabase tool operation with server-side telemetry.

Capture:

```text
tool_call_id
comparison_run_id
arm
stage
approved tool name
sanitized argument summary or argument hash
started/completed timestamps
elapsed_ms
status
attempts/retries
candidate_count
returned_count
excluded_unauthorized_count, only if disclosure policy permits
source/snapshot version
typed error category
```

Do not log:

- database credentials;
- service-role keys;
- bearer tokens;
- unrestricted tool arguments containing sensitive values;
- full evidence bodies by default;
- hidden evaluator labels;
- chain-of-thought;
- unrestricted SQL.

Tool error categories should distinguish:

```text
NO_MATCH
MISSING_BUSINESS_EVIDENCE
UNAUTHORIZED
SOURCE_UNAVAILABLE
TIMEOUT
RATE_LIMITED
INVALID_ARGUMENT
CONTRACT_VIOLATION
INTERNAL_ERROR
```

A successful zero-result bounded query is not a source failure.

### Phase 5 — persistence boundary

Implement a repository interface so comparison orchestration is not tightly coupled to Supabase:

```text
ComparisonStore
  create_run
  update_arm_status
  save_model_call
  save_tool_call
  save_arm_result
  lock_results
  save_evaluation
  get_run
  get_summary
```

Preferred live implementation: Supabase/PostgreSQL server-side persistence.

Preferred tests: in-memory or temporary fake store with the same contract.

Suggested private/backend-owned tables or equivalent:

```text
comparison_runs
comparison_arms
model_calls
tool_calls
evaluation_results
pricing_catalog_versions, if pricing is stored in DB
```

Security requirements:

- browser has no direct write access;
- hidden evaluator data remains in `private_eval` and is not joined into runtime views before results are locked;
- private run records are not exposed through broad table APIs;
- tenant/actor authorization applies when reading past runs;
- restricted source content is not copied unnecessarily into telemetry rows;
- use hashes and source IDs rather than duplicating evidence text where possible.

If Supabase is not configured locally, implement and test the interface/fake store. Do not silently persist a live run only in memory while claiming durable Supabase storage.

### Phase 6 — comparison orchestration

Implement an orchestrator with explicit stages:

```text
freeze_controls
baseline.manufacturing
baseline.validation
enhanced.hexacontext
enhanced.packet_validation
enhanced.manufacturing
enhanced.validation
evaluation
persistence/finalization
```

Rules:

- Generate `comparison_run_id` before either arm starts.
- Pin the same data snapshot before starting either arm.
- Use separate Foundry response/thread state.
- Validate every tool request against its allowlist and schema.
- Validate ContextPacket before sending it downstream.
- In hydrate mode, disable broad downstream retrieval unless the controlling architecture explicitly permits a bounded repair path.
- Validate both ManufacturingDecision outputs against the same strict schema.
- Preserve a failure in either arm. Never replace it with a mock result.
- Do not automatically fall back from HexaContext to direct without reporting it.
- Cap retries and record them.
- Include all stage time in arm end-to-end latency.
- If one arm fails, return a `PARTIAL` comparison with the successful arm visible and the failed arm's typed error.
- Store terminal status even if evaluation cannot run.

The formal benchmark may alternate/randomize arm order to reduce order/load bias. The interactive demo may run isolated stages concurrently after snapshot pinning, but it must disclose whether shared capacity could affect latency.

### Phase 7 — hidden evaluator

For one of the 15 controlled Supabase cases, run deterministic evaluation only after both arm outputs are locked.

The evaluator may read:

```text
private_eval.case_expectations
private_eval.expected_evidence
```

Neither runtime agent, runtime tool nor browser request may read these tables.

Produce at least:

```text
evaluation_status: SCORED | NOT_SCORED | EVALUATION_FAILED
disposition_correct
critical_false_pass
required_evidence_recall
evidence_precision, if the answer key supports relevance labels
citation_validity
claim_support, only if implemented with a reviewed deterministic/model evaluator
missing_evidence_detected
stale_evidence_detected
conflicts_detected
unauthorized_leakage
cross_tenant_leakage
schema_valid
```

Important rules:

- Use source IDs/citation sets captured during the run.
- A citation is valid only if it resolves to evidence authorized and returned in that arm.
- Restricted evidence counts as leakage if its ID, content or material fact reaches model input/output where unauthorized.
- Never use an agent's self-reported confidence as correctness.
- Do not reveal expected answers before results are terminal.
- For free-form/non-benchmark requests, return `NOT_SCORED` and display `Human review required`.
- If evaluator data is unavailable, report `EVALUATION_FAILED`; do not fabricate scores.

Keep Foundry preview evaluators optional. Deterministic domain/safety checks remain the release authority for this MVP.

### Phase 8 — APIs

Implement or adapt:

#### `POST /api/comparisons`

Model-visible/user-supplied input should be narrow:

```json
{
  "task": "Assess manufacturing lot disposition readiness",
  "lot_id": "HX-V2-LOT-004",
  "decision_profile_id": "manufacturing_lot_disposition_v1",
  "hexacontext_mode": "hydrate"
}
```

The backend derives actor, scopes, tenant, models, prompts, snapshot and pricing catalog.

For short runs, a synchronous completed response is acceptable. If actual latency makes this unreliable, use:

```text
POST /api/comparisons                 -> 202 + comparison_run_id
GET  /api/comparisons/{id}            -> status/result
GET  /api/comparisons/{id}/events     -> optional SSE progress
```

#### `GET /api/comparisons/{id}`

Return:

- frozen controls safe for the actor;
- each arm's status;
- final decision;
- evidence/citations safe for display;
- missing/stale/conflict findings;
- model/tool trace summary;
- normalized metrics;
- evaluation after locking;
- explicit limitations.

Do not return secrets, raw private evaluator rows, raw provider payloads or restricted evidence.

#### Aggregate Evaluation Lab endpoint

Implement a bounded endpoint such as:

```text
GET /api/evaluations/summary?dataset_version=1.0.0
```

Return aggregate metrics only for completed, version-compatible runs. Do not mix different model/prompt/profile/snapshot/pricing versions without grouping or warning.

Keep the existing deterministic harness endpoints during transition, but label them legacy/regression. Do not let the new stakeholder UI accidentally call the legacy mock evaluator while presenting results as Foundry.

### Phase 9 — stakeholder UI

Redesign the primary UI around `Run comparison`. Preserve the old harness in a clearly separate regression route/page or feature flag until the live path is verified.

#### Request header

Show:

```text
synthetic-data badge
live/mock status per component
lot/entity selector without hidden scenario labels
actor/role label
pinned snapshot
Decision Profile/version
HexaContext mode, hydrate first
Run comparison button
```

The current UI exposes designed scenario names before the run. The new blind comparison UI must use neutral lot/entity labels. Scenario/answer-key labels may appear only in an explicitly authorized Evaluation Lab after results are locked.

#### Side-by-side columns

Use equal visual weight:

```text
Foundry Direct
With HexaContext
```

Do not visually imply that HexaContext is correct by default.

Each column should show:

- arm status;
- disposition;
- concise rationale;
- evidence classes covered;
- citations/source records;
- missing evidence;
- stale evidence;
- conflicts;
- tool timeline;
- model-call count;
- tool-call count;
- input/output/total tokens;
- Supabase retrieval latency;
- model latency;
- end-to-end arm latency;
- retries;
- estimated model cost or explicit unavailable state;
- typed error/limitation if incomplete.

#### Comparison strip

Show immediately scannable differences:

```text
disposition correctness, benchmark only
critical false PASS
required evidence recall
valid citations
conflicts/missing/stale evidence found
unauthorized leakage
tool calls
model calls
total tokens
end-to-end latency
estimated model cost
```

Do not use green/red solely to favor the HexaContext side. Use neutral comparison language and highlight safety failures consistently in either arm.

#### Expandable technical details

Provide tabs or accordions:

```text
Evidence
Tool timeline
Evaluation
Technical metrics
Limitations
```

Default view should remain executive-readable. Do not dump raw JSON, full prompts or raw provider traces into the primary stakeholder view.

#### Cost labels

Display one of:

```text
Estimated model cost
Cost unavailable — pricing not configured
Cost unavailable — provider usage missing
Cost unavailable — provisioned/capacity billing
```

Add a tooltip/note:

> Azure Cost Management remains the source of truth for actual post-consumption charges; portal billing data is delayed and is not an instant per-run value.

#### Free-form requests

When no private answer key exists, display:

```text
Not automatically scored — human review required
```

Never show a fake correctness percentage.

#### Aggregate Evaluation Lab

For the 15-case benchmark, show version-filtered summaries:

- case/run count;
- disposition agreement;
- critical false passes;
- evidence recall;
- citation validity;
- missing/conflict/freshness detection;
- authorization/cross-tenant failures;
- token totals/distribution;
- latency distribution;
- estimated model cost;
- failures/retries;
- model/prompt/profile/snapshot versions;
- explicit synthetic/limited-sample warning.

Do not claim production accuracy from 15 designed cases.

### Phase 10 — Foundry portal and tracing

The application UI is the primary per-run comparison. The Foundry portal is not required to see the demo result.

Use Foundry/Application Insights where approved for:

```text
aggregate monitoring
production traces
success/error rates
operational alerts
model-deployment metrics
actual Azure Cost Management reconciliation
```

Correlate traces with safe metadata:

```text
comparison_run_id
arm
stage
response_id
request_id
snapshot/profile/prompt/tool-contract versions
```

Do not send prompts, evidence bodies, hidden evaluator labels, credentials or chain-of-thought merely to improve observability.

If Application Insights is not connected or the user lacks RBAC, keep application telemetry working and label portal trace linkage unavailable.

## Suggested normalized response shape

Adapt to existing models rather than copying blindly, but preserve equivalent semantics:

```json
{
  "comparison_run_id": "uuid",
  "status": "COMPLETED",
  "synthetic": true,
  "controls": {
    "lot_id": "HX-V2-LOT-004",
    "snapshot_id": "hx-mfg-v1-snapshot-001",
    "as_of_time": "2026-08-01T12:00:00Z",
    "decision_profile_version": "1.0.0",
    "manufacturing_agent_version": "version",
    "hexacontext_agent_version": "version",
    "tool_contract_version": "1.0.0",
    "pricing_catalog_version": "UNAVAILABLE"
  },
  "baseline": {
    "status": "COMPLETED",
    "decision": {
      "disposition": "HOLD",
      "summary": "...",
      "citations": []
    },
    "findings": {
      "missing": [],
      "stale": [],
      "conflicts": []
    },
    "metrics": {
      "model_calls": 0,
      "tool_calls": 0,
      "input_tokens": null,
      "output_tokens": null,
      "total_tokens": null,
      "model_elapsed_ms": 0,
      "tool_elapsed_ms": 0,
      "end_to_end_elapsed_ms": 0,
      "estimated_model_cost": {
        "status": "UNAVAILABLE",
        "currency": null,
        "amount": null,
        "reason": "Pricing catalog not configured"
      }
    }
  },
  "hexacontext": {
    "status": "COMPLETED",
    "mode": "hydrate",
    "context_packet_summary": {},
    "decision": {},
    "findings": {},
    "metrics": {}
  },
  "evaluation": {
    "status": "SCORED",
    "baseline": {},
    "hexacontext": {}
  },
  "limitations": []
}
```

Do not use zeros in a live response to represent unavailable token/cost data. The zeros above are structural examples only; production code should use nullable fields plus explicit availability.

## Test requirements

Add unit, API, repository and UI-adjacent tests covering at least:

### Foundry usage normalization

- normal input/output/total token response;
- multiple model calls aggregate correctly;
- missing usage remains unavailable;
- malformed/negative usage is rejected or safely marked unavailable;
- cached/reasoning details do not double-count totals;
- failed calls/retries appear in telemetry;
- redaction remains intact.

### Cost estimation

- model/deployment matches the correct versioned rate;
- input and output components are calculated with decimal-safe arithmetic;
- missing price produces `UNAVAILABLE`;
- missing tokens produces `UNAVAILABLE`;
- provisioned/capacity billing does not claim per-run actual cost;
- enhanced total includes both agents/all calls;
- display rounding does not mutate persisted precision.

### Latency

- model elapsed time comes from backend monotonic timing;
- tool latency is captured per call;
- direct arm end-to-end includes retrieval and validation;
- HexaContext arm includes compiler, retrieval, packet validation and downstream Manufacturing call;
- retries and wait time are included in end-to-end time;
- evaluator time is tracked separately from arm latency.

### Fair comparison

- byte-equivalent normalized task for both arms;
- same lot, actor, scopes, tenant, snapshot, profile and Manufacturing Agent;
- independent response/thread state;
- same underlying tool implementation;
- no exclusive HexaContext-only source access;
- hidden labels never enter model input/tool output.

### Evaluation

- expected disposition is read only after outputs lock;
- citation must resolve to authorized returned evidence;
- restricted record causes leakage failure if exposed;
- cross-tenant record causes leakage failure if exposed;
- missing, stale and conflict cases score correctly;
- free-form request returns `NOT_SCORED`;
- unavailable evaluator returns explicit failure rather than synthetic scores.

### Failure handling

- one arm failing yields visible partial comparison;
- no silent live-to-mock fallback;
- no indefinite schema retry;
- provider, tool, authorization and missing-business-evidence errors remain distinct;
- partial telemetry survives failure.

### API/security

- browser cannot choose actor scopes or tenant;
- browser cannot access evaluator tables/expected values;
- no secrets or raw provider payloads in response;
- past comparison reads are actor/tenant authorized;
- arbitrary SQL tool is unavailable;
- runtime lot list omits pre-run scenario/answer labels.

### UI

- both arms render with equal visual hierarchy;
- unavailable tokens/cost display as unavailable, not zero;
- enhanced totals include both stages;
- failure/partial/not-scored states render clearly;
- source citations and tool timeline are escaped before rendering;
- restricted text cannot enter the DOM;
- desktop/laptop layout has no overlap or clipping at the supported widths. Mobile optimization is not an MVP requirement.

## Acceptance gates

Do not report completion until you have actual evidence for each applicable gate:

- [ ] Existing tests still pass.
- [ ] New comparison/telemetry/evaluator tests pass.
- [ ] `git diff --check` passes.
- [ ] Python compilation passes.
- [ ] JavaScript syntax check passes.
- [ ] A clean local API smoke test succeeds.
- [ ] One fake-provider comparison exercises both arms deterministically.
- [ ] A live Foundry comparison succeeds on the Foundry-connected computer, or is explicitly reported as blocked/unverified.
- [ ] Supabase persistence/RLS/tool tests succeed, or the Supabase live boundary is explicitly reported as blocked/unverified.
- [ ] UI is browser-tested with a completed, partial, failed and not-scored result.
- [ ] UI clearly labels synthetic data and estimated/unavailable cost.
- [ ] No answer key appears in pre-run runtime endpoints/browser payloads.
- [ ] No unauthorized/cross-tenant record appears in model input/output or UI.
- [ ] No credential or private endpoint appears in Git, logs, screenshots or responses.
- [ ] Verification documentation states exactly what ran and what did not.

Run at minimum:

```bash
python -m compileall -q backend data tests
node --check frontend/app.js
python -m unittest discover -s tests -v
git diff --check
```

Use the repository virtual environment/interpreter documented by the project. If the current suite uses a different test runner, run that as well.

Start the application, call the health and comparison endpoints, and visually inspect the UI. Do not substitute plausible example output for a real response.

## Deliverables

Exact filenames may change after inspecting the architecture, but the finished repository should contain equivalents of:

```text
backend/comparison_models.py or extensions to backend/models.py
backend/comparison_orchestrator.py
backend/telemetry.py
backend/pricing.py
backend/evaluator.py
backend/comparison_store.py
backend/supabase_tools.py or the approved gateway adapter
backend/app.py comparison routes

supabase/migrations/* comparison/evaluation/tool schema
supabase/tests/* RLS and retrieval tests

frontend/index.html
frontend/styles.css
frontend/app.js

tests/test_comparison_orchestrator.py
tests/test_telemetry.py
tests/test_pricing.py
tests/test_evaluator.py
tests/test_comparison_api.py

updated docs/verification.md
updated docs/demo-script.md
updated handoff/current-status documentation
```

Do not create redundant layers merely to match these filenames. Prefer clear boundaries and minimal dependencies.

## Decisions and blockers you must not invent

If unavailable, expose these as configuration questions/blockers:

```text
approved Supabase project and migration/authentication path
actual Supabase schema/RLS state
approved Foundry connectivity on the current computer
Foundry/Application Insights connection and RBAC
model deployment billing type
approved model pricing source/rates/effective date
whether comparisons should execute synchronously or as jobs
approved retention period for comparison traces
qualified reviewer approval of synthetic expected outcomes
```

Implement typed unavailable states and provider-independent tests while waiting. Do not insert guessed values.

## Security and policy boundaries

- Use synthetic data only until explicit approval says otherwise.
- Do not use real employer, client, customer, supplier or employee records.
- Do not put secrets in source, Markdown, prompts, browser code or logs.
- Do not expose a Supabase service-role key to Foundry or the browser.
- Do not give Foundry arbitrary SQL access.
- Do not log chain-of-thought.
- Do not store full prompts/evidence by default without approved retention and access controls.
- Do not turn prompt instructions into authorization controls; enforce authorization in the backend/database.
- Do not claim compliance, production accuracy or customer ROI from the 15 synthetic cases.
- Do not commit, push, deploy, create paid resources or modify unrelated projects without Patrick's explicit approval.

## Final response format

When finished, report:

1. **Implemented** — exact files and behavior.
2. **Verified locally** — commands and real results.
3. **Verified live** — exact Foundry/Supabase operations that succeeded, without exposing private endpoints or secrets.
4. **Not verified or blocked** — explicit gaps and reasons.
5. **Metrics shown** — which are provider-reported, backend-measured, derived or estimated.
6. **Security checks** — evaluator isolation, RLS/tool boundaries, secret scan and leakage tests.
7. **UI evidence** — routes tested and visual states inspected.
8. **Remaining decisions** — only unresolved user/work-environment choices.
9. **Git status** — do not commit or push unless explicitly approved.

Do not say “complete” if the UI contains hardcoded sample metrics, if only mocks ran, if Supabase persistence was not exercised, or if the live Foundry tool loop did not execute. State partial completion honestly.

## Prompt ends
