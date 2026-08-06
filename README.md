# HexaContext MVP — Foundry Manufacturing Context Comparison

A transferable proof of concept for evaluating HexaContext as a **thin, additive context and assurance layer for existing AI agents**.

> **Current status:** the primary UI now runs a deterministic, side-by-side 15-case comparison preview with hidden-answer evaluation and normalized token, tool, latency and cost-availability telemetry. It is deliberately labeled `SIMULATED_LOCAL`: this computer is not configured for the saved Foundry agents, so live model behavior and billed cost remain unverified. The saved-agent client and Supabase source/tool substrate are available for the later live integration.

## Start here

A new engineer or implementation agent should read these in order:

1. [`docs/foundry/cross-computer-implementation-handoff.md`](docs/foundry/cross-computer-implementation-handoff.md) — verified endpoint facts, implemented foundation and two-computer workflow.
2. [`docs/handoff-context-packet.md`](docs/handoff-context-packet.md) — full product, experiment and takeover context.
3. [`docs/supabase-synthetic-dataset-v1.md`](docs/supabase-synthetic-dataset-v1.md) — controlling 15-case Supabase schema, seed, RLS and hidden-evaluator specification.
4. [`docs/foundry/implementation-agent-prompt-evaluation-ui.md`](docs/foundry/implementation-agent-prompt-evaluation-ui.md) — execution-ready prompt for building comparison orchestration, evaluation, token/cost/latency telemetry and the stakeholder UI.
5. [`docs/foundry/README.md`](docs/foundry/README.md) — two-agent Foundry architecture and implementation decision.
6. [`docs/foundry/manufacturing-agent.md`](docs/foundry/manufacturing-agent.md) — complete Manufacturing Agent specification and prompt.
7. [`docs/foundry/hexacontext-agent.md`](docs/foundry/hexacontext-agent.md) — complete HexaContext Agent specification, prompt and future fine-tuning plan.
8. [`docs/foundry/tool-contracts.md`](docs/foundry/tool-contracts.md) — common read-only tool plane.
9. [`docs/foundry/orchestration-and-evaluation.md`](docs/foundry/orchestration-and-evaluation.md) — fair comparison and metrics.
10. [`docs/foundry/setup-checklist.md`](docs/foundry/setup-checklist.md) — Foundry/work-environment setup and Git transfer checklist.

## PoC context

Enterprise agents can fail because they receive too little context, too much noisy context, stale information, conflicting sources or information the requester is not authorized to use.

HexaContext's hypothesis is that an additive context compiler can provide the downstream agent with the **minimum sufficient, authorized, current and source-backed context** for a specific task.

The initial proving workflow is synthetic manufacturing lot-disposition readiness. The evidence can span:

```text
lot and inspection records
supplier + part-family history
equipment + calibration state
part + released engineering revision
open deviations
narrative/operator notes
source authority, freshness and authorization
```

HexaContext is not a quality-management system or final decision-maker. A human quality reviewer retains release, rejection and remediation authority.

## Target two-agent experiment

### Agent 1 — Manufacturing Readiness Agent

The stable business-task agent. It evaluates evidence and recommends a human-review state of `PASS`, `HOLD` or `ESCALATE`.

### Agent 2 — HexaContext Compiler Agent

A smaller, specialized context agent that either:

- **hydrates** a validated, source-backed `ContextPacket`; or
- **guides** retrieval by returning a typed `RetrievalPlan` for deterministic execution.

It does not determine manufacturing disposition.

### Controlled comparison

```text
FOUNDRY DIRECT BASELINE
Same request
  -> Manufacturing Agent
  -> raw read-only tools
  -> ManufacturingDecision

WITH HEXACONTEXT
Same request
  -> HexaContext Agent (smaller model)
  -> same raw read-only tools
  -> validated ContextPacket
  -> same Manufacturing Agent
  -> ManufacturingDecision
```

Both arms must use the same:

- user request and subject;
- authenticated actor and permissions;
- immutable data snapshot;
- Manufacturing Agent model, prompt and output schema;
- Decision Profile;
- underlying source data and read-only tools;
- decoding, timeout and retry settings where practical.

The direct baseline must not be deliberately handicapped. HexaContext must earn any measured improvement through more reliable context planning, selection, authorization, freshness, conflict handling or packaging.

## Initial Foundry implementation direction

For the first live MVP, use the **two existing saved per-agent Responses endpoints** because reachability and authentication have already been verified on the Foundry-connected computer. The backend client in [`backend/foundry_client.py`](backend/foundry_client.py) supports this path without copied bearer tokens.

Before a recorded comparison, the saved definitions' exact prompts, schemas, tools, model, agent ID and version must be reconciled with the definitions in this repository. Git-defined ephemeral agents remain a later option when reproducibility is preferred over using the already-proven endpoints.

The target environment must approve and supply:

```bash
FOUNDRY_PROJECT_ENDPOINT=
FOUNDRY_MANUFACTURING_AGENT_ID=
FOUNDRY_MANUFACTURING_AGENT_ENDPOINT=
FOUNDRY_HEXACONTEXT_AGENT_ID=
FOUNDRY_HEXACONTEXT_AGENT_ENDPOINT=
```

The verified saved endpoints currently require `api-version=2025-05-15-preview` and `model=gpt-5`. Keep both values configurable; do not substitute `gpt-5.6-luna` unless both saved agent definitions are deliberately recreated/versioned for that model.

The first HexaContext implementation uses a normal approved smaller model. Fine-tuning is a later, evidence-gated optimization after rights-cleared, sanitized and reviewer-labeled traces exist.

## Current runnable harness

The implemented local flow is:

```text
synthetic lot
  -> selectable exact / graph / search / hybrid route simulation
  -> authorization filtering
  -> deterministic policy evaluation
  -> mock or optional explanation provider
  -> traceable DecisionPacket
```

It currently includes:

- 12 reproducible synthetic manufacturing cases;
- FastAPI backend and responsive browser UI;
- exact, relationship and narrative retrieval simulations;
- authorization filtering before model invocation;
- deterministic `PASS` / `HOLD` / `ESCALATE` policy checks;
- a restricted-evidence distractor;
- evaluator answer keys isolated from runtime/public fixtures;
- a second, normalized 15-case Supabase dataset with one cross-tenant shadow lot;
- four clean-reset-tested Supabase migrations, RLS, native full-text search and an unexposed `private_eval` schema;
- 179 immutable runtime rows and 124 separately seeded evaluator rows in snapshot `hx-mfg-v1-snapshot-001`;
- seven narrow read-only PostgreSQL functions and a backend gateway that binds subject, snapshot, time and approved user JWT server-side;
- typed `.env.local` settings and a fakeable Entra-authenticated Foundry client;
- API-version-safe URL composition, bounded transient retries and redacted errors;
- mock, generic Azure Foundry and AWS Bedrock explanation adapters;
- unit/API tests and local verification;
- a primary side-by-side comparison UI and aggregate 15-case Evaluation Lab;
- a per-run walkthrough showing the Manufacturing-only work versus HexaContext compilation followed by the same Manufacturing decision agent;
- server-owned comparison controls and private post-result scoring;
- normalized usage, stage, tool, latency and cost-availability contracts;
- synchronous local comparison endpoints with retrievable in-memory run results;
- an evaluation lab for the legacy retrieval-mode ablations.

It does **not** yet include:

- the live Manufacturing Foundry Agent;
- the live HexaContext Foundry Agent;
- Foundry-facing OpenAPI/function-call execution over the implemented Supabase gateway;
- durable comparison-run persistence or multi-user run history;
- comparison-runtime wiring for the implemented PostgreSQL/FTS tools or any graph projection;
- Foundry tracing/evaluators;
- small-model comparison or fine-tuning.

The local preview gives both arms the same authorized evidence and therefore does not manufacture a HexaContext quality advantage. Its current result is equal designed-case quality with additional enhanced-path model/token/latency overhead. A live Foundry run is required before making a model-performance claim.

## Local quick start

Requirements: Python 3.11+.

```bash
cd /path/to/sneha-hexacontext-mvp
cp .env.example .env.local
python3 -m pip install -r requirements.txt   # only if dependencies are absent
python3 data/generate.py
python3 data/generate_supabase_v1.py
python3 -m uvicorn backend.app:app --host 127.0.0.1 --port 8010
```

Open [http://127.0.0.1:8010](http://127.0.0.1:8010).

Run verification:

```bash
python3 -m compileall -q backend data tests
node --check frontend/app.js
python3 -m unittest discover -s tests -v
```

On the Foundry-connected computer only, after populating `.env.local` and completing `az login`, run the content-suppressing connection check:

```bash
python3 -m scripts.foundry_smoke
```

Convenience targets:

```bash
make data
make test
make run
make verify
```

## Synthetic scenarios

The legacy local JSON harness has 12 cases and remains the regression fallback. The deployed Supabase snapshot has 15 primary cases plus one cross-tenant shadow lot and adds closed-deviation control, simultaneous released-revision conflict, tenant collision and prompt-injection evidence tests.

The legacy 12 cases test:

- complete/current evidence;
- direct critical defect;
- failed inspection;
- unverifiable certificate;
- connected supplier failures;
- expired calibration;
- released-revision mismatch;
- open deviation;
- narrative conflict;
- stale connected evidence;
- missing mandatory evidence;
- restricted irrelevant evidence.

See [`docs/handoff-context-packet.md`](docs/handoff-context-packet.md#current-synthetic-scenarios) and [`docs/synthetic-data-plan.md`](docs/synthetic-data-plan.md).

## Current fixture result

| Retrieval condition | Correct fixtures | Agreement | Critical false passes |
|---|---:|---:|---:|
| Exact only | 7/12 | 58.33% | 0 |
| Graph + exact | 11/12 | 91.67% | 1 |
| Search + exact | 7/12 | 58.33% | 0 |
| Hybrid | 12/12 | 100% | 0 |

These are **designed synthetic-fixture results**, not production accuracy. Graph-only retrieval misses the narrative-conflict case, which is why the hybrid hypothesis includes both relationship and document context.

## Current local provider configuration

The default `mock` provider is deterministic. It explains the fixed policy result and allows the demo to run without credentials.

### Legacy generic Azure explanation adapter

The current code accepts a full Responses-compatible endpoint and server-side authentication:

```bash
AZURE_FOUNDRY_RESPONSES_URL=
AZURE_FOUNDRY_MODEL=
AZURE_FOUNDRY_API_KEY=
# or
AZURE_FOUNDRY_BEARER_TOKEN=
```

This is not the planned two-agent implementation. The new saved-agent client uses the `FOUNDRY_*` settings and an approved Entra identity. A requested live provider must fail explicitly when unconfigured; it must not silently return mock output.

### AWS Bedrock explanation adapter

```bash
AWS_REGION=us-east-1
AWS_PROFILE=
AWS_BEDROCK_MODEL_ID=
```

The adapter is retained for portability but is unverified until approved access and a model deployment are available.

## Current API surface

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/health` | Dataset/provider status |
| `GET` | `/api/profile` | Current deterministic Decision Profile |
| `GET` | `/api/lots` | Synthetic case summaries |
| `GET` | `/api/lots/{lot_id}` | Authorized demo detail/relationships |
| `POST` | `/api/compile` | Compile the current deterministic DecisionPacket |
| `GET` | `/api/evaluation` | Recompute fixture metrics by retrieval condition |
| `GET` | `/api/comparison-cases` | Neutral labels and server-owned comparison controls |
| `POST` | `/api/comparisons` | Run one synchronous local two-arm comparison preview |
| `GET` | `/api/comparisons/{comparison_run_id}` | Retrieve a completed in-memory comparison |
| `GET` | `/api/evaluations/summary` | Aggregate all 15 controlled cases |

The proposed contracts are in [`docs/foundry/orchestration-and-evaluation.md`](docs/foundry/orchestration-and-evaluation.md).

## Repository structure

```text
backend/                         Current FastAPI harness, policy and provider adapters
backend/settings.py              Typed local/deployment settings and non-secret status
backend/foundry_client.py        Saved-agent Responses client with Entra authentication
backend/supabase_gateway.py      User-JWT-preserving, server-bound read-only tool gateway
backend/comparison_models.py     Typed comparison, telemetry and evaluator response contracts
backend/comparison_service.py    Minimal deterministic two-arm preview and hidden scoring
backend/telemetry.py             Foundry usage normalization
backend/pricing.py               Versioned estimated-variable-cost calculation
config/model_pricing.json        Non-secret pricing catalog; intentionally unconfigured locally
frontend/                        Current responsive no-build UI
data/generate.py                 Reproducible synthetic-case generator
data/generate_supabase_v1.py     Deterministic normalized Supabase v1 generator
data/supabase/v1/                Generated runtime/evaluator CSV artifacts
data/generated/                  Checked-in synthetic fixtures
supabase/migrations/             Runtime, private evaluator, RLS/index and RPC migrations
supabase/seed.sql                Runtime-only immutable snapshot seed
supabase/seed_evaluator.sql      Trusted evaluator-only seed; never exposed to Foundry
tests/                           Engine and API tests
docs/handoff-context-packet.md   Primary takeover/product context
docs/foundry/                    Two-agent Foundry implementation package
docs/business-review.md          Product/business review
docs/architecture.md             Current architecture background
docs/synthetic-data-plan.md      Safe fixture/evaluation strategy
docs/demo-script.md              Current local-harness demo
docs/verification.md             Executed local verification
QUESTIONS.md                      Open business and technical decisions
```

## Product and architecture principles

- HexaContext is an additive layer, not an autonomous business-decision owner.
- Current business facts stay in source systems, not model weights.
- Authorization is enforced before model invocation and outside prompts.
- Source IDs, versions, timestamps, authority and content hashes are preserved.
- Missing evidence is unknown, never a pass.
- Conflicts are surfaced, not silently resolved by a model.
- The same tool plane is available to both comparison architectures.
- PostgreSQL can support canonical records, exact lookup and full-text search.
- A graph or vector store is added only if controlled ablations show measured lift.
- Deterministic validators own schema, authorization, bounds and mechanically testable safety rules.
- No silent cloud-to-mock fallback in a claimed live run.
- Humans retain final action authority.

## Evaluation and continuation gate

Do not judge the agents only by final prose. Measure:

- required evidence recall and precision;
- critical false PASS;
- missing, stale and conflict detection;
- citation and claim support;
- unauthorized evidence leakage;
- tool selection and argument validity;
- schema validity;
- model/tool calls and context volume;
- end-to-end latency and accepted-result cost;
- qualified reviewer acceptance and review time.

Also compare the HexaContext Agent with a deterministic profile planner. If fixed code performs equally well, use the simpler design.

Continue only if HexaContext provides a material, repeatable advantage without unacceptable latency, cost, complexity or safety regressions.

## Security and data boundaries

- Initial data must be synthetic, public or explicitly approved.
- Never commit secrets, tokens, passwords, connection strings or private endpoints.
- Never place Foundry/database credentials in browser code or prompts.
- Use one dedicated approved data project for this PoC; do not reuse another intern's database.
- Use least-privilege read-only tools and server-bound actor permissions.
- Review trace/log retention before using non-synthetic data.
- Do not push to a public repository without reviewing organizational/work-data policy.

## GitHub/work-computer transfer

Before pushing:

```bash
git status --short
git diff --check
python3 -m unittest discover -s tests -v
```

Then:

1. Review the destination organization and repository visibility.
2. Confirm no secrets or restricted data are tracked.
3. Push the repository through the approved GitHub account/process.
4. Clone it on the work computer.
5. Re-read [`docs/foundry/cross-computer-implementation-handoff.md`](docs/foundry/cross-computer-implementation-handoff.md).
6. Follow [`docs/foundry/setup-checklist.md`](docs/foundry/setup-checklist.md).
7. Re-check current Microsoft Foundry documentation before implementation.

No remote, commit or push is performed automatically by this documentation package.

## Current status

- [x] Local deterministic vertical slice.
- [x] Reproducible 12-case synthetic dataset.
- [x] Current unit/API/browser verification.
- [x] Complete two-agent Foundry design and exact prompts.
- [x] Shared tool, schema, orchestration and evaluation contracts.
- [x] Detailed takeover context packet.
- [x] `.env.local` loading, validation and secret-safe health state.
- [x] Fakeable saved-agent Foundry HTTP/authentication client.
- [x] Evaluator-only answer-key boundary for local fixtures.
- [x] Dedicated Supabase runtime/private-evaluator substrate and immutable v1 snapshot.
- [x] RLS tenant/scope enforcement, full-text search and seven narrow read-only operations.
- [x] Backend gateway that preserves an approved user JWT and rejects secret-key evidence queries.
- [x] Side-by-side local comparison API/UI with honest simulated-mode labeling.
- [x] Normalized tokens, stages, tool calls, latency and explicit cost-unavailable state.
- [x] Private post-result scoring and aggregate 15-case Evaluation Lab.
- [ ] Provision/approve real demo Auth identities and test the gateway through the remote Data API with their JWTs.
- [ ] Connect the implemented gateway to the Foundry function-call loop.
- [ ] Live Manufacturing Foundry Agent.
- [ ] Live HexaContext Foundry Agent.
- [ ] Foundry tracing and hidden evaluation.
- [ ] Qualified manufacturing review.
- [ ] Conditional model fine-tuning.

## Claim boundary

Safe description:

> This repository contains a tested synthetic manufacturing context harness, a deployed RLS-protected Supabase evaluation substrate, and a clearly labeled local side-by-side preview of the contracts and metrics needed to compare a direct Foundry Manufacturing Agent against the same agent supplied by a HexaContext context compiler.

Not yet supported:

```text
production manufacturing accuracy
regulatory compliance
customer ROI or adoption
enterprise-scale cost reduction
graph-database superiority
fine-tuned smaller-model superiority
frontier-model replacement
cross-domain generalization
```
