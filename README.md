# HexaContext MVP — Foundry Manufacturing Context Comparison

A transferable proof of concept for evaluating HexaContext as a **thin, additive context and assurance layer for existing AI agents**.

> **Current status:** the repository contains a working, tested local synthetic harness. The planned two-agent Microsoft Foundry comparison is fully specified in Markdown but is **not yet implemented or live**.

## Start here

A new engineer or implementation agent should read these in order:

1. [`docs/handoff-context-packet.md`](docs/handoff-context-packet.md) — full product, experiment and takeover context.
2. [`docs/foundry/README.md`](docs/foundry/README.md) — two-agent Foundry architecture and implementation decision.
3. [`docs/foundry/manufacturing-agent.md`](docs/foundry/manufacturing-agent.md) — complete Manufacturing Agent specification and prompt.
4. [`docs/foundry/hexacontext-agent.md`](docs/foundry/hexacontext-agent.md) — complete HexaContext Agent specification, prompt and future fine-tuning plan.
5. [`docs/foundry/tool-contracts.md`](docs/foundry/tool-contracts.md) — common read-only tool plane.
6. [`docs/foundry/orchestration-and-evaluation.md`](docs/foundry/orchestration-and-evaluation.md) — fair comparison and metrics.
7. [`docs/foundry/setup-checklist.md`](docs/foundry/setup-checklist.md) — Foundry/work-environment setup and Git transfer checklist.

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
FOUNDY DIRECT BASELINE
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

For the first live MVP, use **Git-defined ephemeral agents** called from the backend through the Microsoft Foundry project-scoped Responses API.

This keeps prompts, schemas and tool definitions in the repository instead of allowing untracked Playground drift. Stable prompt/hosted agents can be published later after the comparison passes evaluation.

The target environment must approve and supply:

```bash
FOUNDRY_PROJECT_ENDPOINT=
FOUNDRY_MANUFACTURING_MODEL=
FOUNDRY_HEXACONTEXT_MODEL=
```

Do not guess model names, regions or deployment IDs. Confirm availability, structured-output/tool support, quotas, content filters and organizational approval in the target Foundry project.

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
- mock, generic Azure Foundry and AWS Bedrock explanation adapters;
- unit/API tests and local verification;
- an evaluation lab for retrieval-mode ablations.

It does **not** yet include:

- the live Manufacturing Foundry Agent;
- the live HexaContext Foundry Agent;
- shared external OpenAPI/function tools;
- `/api/comparisons` orchestration;
- real PostgreSQL/search/graph retrieval;
- Foundry tracing/evaluators;
- small-model comparison or fine-tuning.

## Local quick start

Requirements: Python 3.11+.

```bash
cd /path/to/sneha-hexacontext-mvp
python3 -m pip install -r requirements.txt   # only if dependencies are absent
python3 data/generate.py
python3 -m uvicorn backend.app:app --host 127.0.0.1 --port 8010
```

Open [http://127.0.0.1:8010](http://127.0.0.1:8010).

Run verification:

```bash
python3 -m compileall -q backend data tests
node --check frontend/app.js
python3 -m unittest discover -s tests -v
```

Convenience targets:

```bash
make data
make test
make run
make verify
```

## Synthetic scenarios

The 12 cases test:

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

This is not the planned two-agent implementation. The target architecture uses `FOUNDRY_PROJECT_ENDPOINT` and approved Entra identity through the current Foundry SDK path. A requested live provider must fail explicitly when unconfigured; it must not silently return mock output.

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

Target addition:

```text
POST /api/comparisons
GET  /api/comparisons/{comparison_run_id}
```

The proposed contracts are in [`docs/foundry/orchestration-and-evaluation.md`](docs/foundry/orchestration-and-evaluation.md).

## Repository structure

```text
backend/                         Current FastAPI harness, policy and provider adapters
frontend/                        Current responsive no-build UI
data/generate.py                 Reproducible synthetic-case generator
data/generated/                  Checked-in synthetic fixtures
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
5. Re-read [`docs/handoff-context-packet.md`](docs/handoff-context-packet.md).
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
- [ ] Dedicated approved data/tool substrate.
- [ ] Live Manufacturing Foundry Agent.
- [ ] Live HexaContext Foundry Agent.
- [ ] Side-by-side comparison API/UI.
- [ ] Foundry tracing and hidden evaluation.
- [ ] Qualified manufacturing review.
- [ ] Conditional model fine-tuning.

## Claim boundary

Safe description:

> This repository contains a tested synthetic manufacturing context harness and a complete plan for comparing a direct Foundry Manufacturing Agent against the same agent supplied by a smaller HexaContext context compiler.

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
