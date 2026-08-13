# HexaContext — Governed Context for Manufacturing Agents

HexaContext is a bounded proof of concept for a **persistent, governed enterprise context fabric and runtime context-synthesis layer**.

The product hypothesis is:

> Connect fragmented evidence once, govern and update it once, then compile the minimum-sufficient, authorized, current and source-linked context each agent decision needs.

## Read this first

**Canonical cross-device handoff:** [`docs/handoff-context-packet.md`](docs/handoff-context-packet.md)

It contains the complete product definition, MVP scope, current implementation, Supabase model, three-role experiment, Foundry migration plan, setup, claim boundaries, risks and next-agent checklist.

If an older document describes a two-agent design, treats a Decision Packet as the shared context layer, or says both arms use the same tool plane, the canonical handoff and current code take precedence.

## Current status

| Area | Status |
|---|---|
| Browser demo | Working locally |
| Comparison mode | `SIMULATED_LOCAL` |
| Foundry agents invoked by comparison | **No** |
| Remote Supabase invoked by comparison | **No** |
| Distinct local access paths | Yes |
| Persistent Context Core schema | Implemented in forward Supabase migration |
| Three-agent client/config foundation | Implemented and unit-tested |
| Live three-agent orchestration | Not implemented |
| Data | Designed synthetic manufacturing data only |
| Final authority | Qualified human |

The local MVP validates architecture, data and response contracts, provider separation, packet lineage, deterministic policy behavior, UI behavior and evaluation mechanics. It does **not** establish live model quality, provider latency, billed cost, production accuracy, compliance or ROI.

## Product architecture

```text
fragmented synthetic sources
  -> persistent governed Manufacturing Context Core
     + reusable Decision Profile
  -> HexaContext Compiler
  -> minimum-sufficient, source-linked Decision Packet
  -> Context-Assisted Review Agent
  -> PASS / HOLD / ESCALATE readiness recommendation
  -> qualified-human authority
```

### Important distinction

- **Context Core:** persistent reusable product foundation—what the bounded enterprise knows.
- **Decision Profile:** reusable task contract—what one decision needs.
- **Decision Packet:** case-specific projection—what one agent review receives.

A Decision Packet is not the shared Context Core.

## Controlled MVP comparison

The current experiment preserves exactly three roles:

| Role | Access contract | Output |
|---|---|---|
| `direct_review` | `FRAGMENTED_SOURCE_TOOLS` | `ReadinessRecommendation` |
| `hexacontext_compiler` | `CONTEXT_CORE_QUERY` | `DecisionPacket` |
| `context_assisted_review` | `DECISION_PACKET_ONLY` | `ReadinessRecommendation` |

```text
A. DIRECT REVIEW
Same request
  -> Direct Review Agent
  -> fragmented source-domain tools
  -> evidence reconciliation
  -> readiness recommendation
  -> qualified reviewer

B. WITH HEXACONTEXT
Same request
  -> Manufacturing Context Core + Decision Profile
  -> HexaContext Compiler
  -> validated Decision Packet
  -> Context-Assisted Review Agent (packet only)
  -> readiness recommendation
  -> qualified reviewer
```

Both paths use the same synthetic case, immutable evidence universe, actor permissions, task, rules, output contract, hidden evaluation and human-authority boundary. The independent variable is **context assembly**.

`PASS` means ready for qualified review. It never means autonomously approved, released or shipped.

## MVP scenario

The first workflow is synthetic, Seagate-inspired **manufacturing material-deviation / lot-disposition readiness**. It does not claim knowledge of private Seagate processes.

Evidence spans:

- manufacturing execution;
- quality management;
- engineering lifecycle;
- equipment and calibration;
- supplier quality;
- policy registry.

The MVP is intentionally multi-source and relationship-heavy. It tests missing, stale, conflicting, restricted and temporally invalid evidence as well as straightforward control cases.

## Quick start

Requirements: Python 3.11+. Node.js is used only for JavaScript syntax verification.

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

Open [http://127.0.0.1:8010](http://127.0.0.1:8010).

The banner must say **Local comparison preview** / `SIMULATED_LOCAL` unless live Foundry orchestration has actually been implemented and invoked.

## Verify

```bash
.venv/bin/python -m compileall -q backend data scripts tests
node --check frontend/app.js
.venv/bin/python -m unittest discover -s tests -v
```

Or, with the desired Python environment active:

```bash
make verify
```

For local Supabase SQL regression tests:

```bash
supabase start
supabase db reset
supabase test db --local
```

`supabase db reset` is destructive to the local Supabase instance. Linked pushes require separate review and approval.

## What is implemented

### Application and harness

- FastAPI backend and responsive no-build UI;
- side-by-side 15-case deterministic comparison;
- hidden synthetic post-result scoring;
- aggregate Evaluation Lab;
- evidence/citation and tool-timeline inspection;
- stage-level model/tool/token/latency/cost-availability contracts;
- explicit simulation and human-authority disclosures.

### Distinct context paths

[`backend/context_providers.py`](backend/context_providers.py) implements:

- `FragmentedSourceToolPlane` for Direct Review;
- `ManufacturingContextCoreProvider` for compiler projection.

These use the same immutable fixture universe but different access contracts. The assisted reviewer receives the packet representation only.

### Supabase foundation

The repository contains normalized synthetic manufacturing data, forced RLS/tooling foundations, a private evaluator boundary, multi-hop relationship support and a forward migration for:

- Context Core registry;
- source domains;
- entity and relationship types;
- policy controls;
- reusable Decision Profile requirements;
- Decision Packets and packet evidence lineage;
- context update events;
- exactly three experiment roles.

Primary alignment migration:

[`supabase/migrations/20260812232500_align_manufacturing_context_core.sql`](supabase/migrations/20260812232500_align_manufacturing_context_core.sql)

PostgreSQL supplies bounded graph semantics for this MVP; a separate graph database is not currently required.

### Foundry foundation

The repository includes:

- three distinct saved-agent configuration slots;
- Entra authentication posture for Azure CLI or managed identity;
- per-agent Responses client;
- structured output schemas;
- bounded retries and redacted errors;
- usage normalization;
- content-suppressing smoke checks;
- Supabase source gateway with server-bound subject/snapshot/time/identity controls.

This is a foundation, not a working live comparison.

## From simulation to Foundry

The next build should add an explicit runner boundary:

```text
ComparisonOrchestrator
  -> SimulatedComparisonRunner
  -> FoundryComparisonRunner
```

Then wire:

```text
Direct Review Agent
  -> fragmented Supabase source tools
  -> ReadinessRecommendation
```

and:

```text
HexaContext Compiler
  -> Context Core + Decision Profile tools
  -> deterministic packet validation
  -> DecisionPacket
  -> Context-Assisted Review Agent (packet only)
  -> ReadinessRecommendation
```

Non-negotiable requirements:

- no silent live-to-mock fallback;
- hidden evaluator data never becomes an agent tool;
- runtime identity/RLS is exercised end to end;
- actor/tenant/subject/snapshot/time are backend-bound;
- all compiler plus assisted-reviewer usage is counted;
- saved Foundry prompts/tools/schemas are reconciled with Git;
- live and simulated runs are visibly distinct;
- qualified human retains final authority.

See the complete phased plan and acceptance checklist in [`docs/handoff-context-packet.md`](docs/handoff-context-packet.md#9-turning-the-simulation-into-a-live-foundry-implementation).

## Foundry configuration

Copy `.env.example` to `.env.local`; never commit `.env.local`, credentials or tokens.

The current configuration expects:

```text
FOUNDRY_ENABLED=true
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
```

The environment prefix `CONTEXT_REVIEW` is retained for compatibility; the canonical role key is `context_assisted_review`.

After approved configuration and `az login`, endpoint reachability can be checked with:

```bash
.venv/bin/python -m scripts.foundry_smoke
```

A successful smoke check proves reachability only—not tool execution or comparison validity.

## Repository map

```text
backend/app.py                 FastAPI routes and execution-mode disclosure
backend/context_providers.py   Distinct current simulation access paths
backend/comparison_service.py  Paired local comparison and hidden scoring
backend/comparison_models.py   Typed comparison and telemetry contracts
backend/foundry_client.py      Three-agent saved-endpoint client foundation
backend/supabase_gateway.py    Server-bound read-only source gateway
frontend/                      Stakeholder comparison UI
data/                          Deterministic synthetic fixture generators
supabase/migrations/           Forward schema, RLS and tool migrations
supabase/tests/                SQL regression tests
tests/                         Python unit/API/security tests
docs/handoff-context-packet.md Canonical product/build handoff
docs/foundry/                  Detailed Foundry and historical design material
```

## Claim boundaries

Do not claim that the current MVP:

- is live Foundry execution;
- proves model-performance lift;
- reflects private Seagate processes;
- is production-ready;
- authorizes material disposition;
- is a full digital twin;
- reproduces Workfabric;
- requires a graph database;
- has validated production ROI or compliance.

Safe description:

> HexaContext is a bounded synthetic manufacturing MVP that demonstrates a governed Context Core, reusable Decision Profiles and case-specific source-linked Decision Packets, and provides the harness and platform foundations needed for a controlled three-agent Microsoft Foundry evaluation.

## License and data

No license has been asserted in this README. Confirm repository licensing before third-party reuse.

All included demonstration data is designed synthetic data. Do not add employer, client, customer, partner or private manufacturing data without explicit approval and an appropriate governance review.
