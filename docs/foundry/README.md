# Microsoft Foundry Agent Package

## Purpose

This directory is the implementation specification for the two-agent version of the Sneha HexaContext manufacturing PoC. It is intended to travel with the repository to GitHub and then to the approved work environment.

The target comparison is:

```text
BASELINE
User request
  -> Manufacturing Readiness Agent
  -> read-only manufacturing data tools
  -> ManufacturingDecision

HEXACONTEXT-ENHANCED
Same user request, actor and data snapshot
  -> HexaContext Compiler Agent
  -> read-only context tools
  -> ContextPacket
  -> same Manufacturing Readiness Agent
  -> ManufacturingDecision
```

The Manufacturing Agent is the business-task agent. The HexaContext Agent is an additive context compiler. HexaContext is not the final manufacturing decision-maker.

## Initial Foundry implementation decision

Use **Git-versioned ephemeral agents** in the application backend for the first MVP:

- define the model, instructions, tools and schemas in code/files in this repository;
- call the Foundry project-scoped Responses API from the backend;
- authenticate locally with an approved developer identity and in Azure with managed identity where supported;
- keep secrets out of prompts, browser code and Git;
- capture every prompt/model/tool-contract version with each run.

This is preferable for the first comparison because the two agent definitions remain reviewable and versioned with the application instead of drifting as untracked Playground configuration. After the behavior passes evaluation, the same definitions may be saved/published as versioned prompt or hosted agents with stable endpoints.

Microsoft currently documents the project endpoint pattern as:

```text
{FOUNDRY_PROJECT_ENDPOINT}/openai/v1/responses
```

and documents Agent Framework's Foundry provider as the recommended Python path for a Git-defined ephemeral agent. Confirm the current SDK/API details in the target project before implementation because Foundry evolves quickly.

## Agent inventory

| Agent | Initial model | Responsibility | May decide manufacturing disposition? |
|---|---|---|---|
| `manufacturing-readiness-agent-v1` | Approved Foundry model; identical in both comparison arms | Retrieve/inspect evidence in baseline mode or assess a supplied ContextPacket in enhanced mode; produce a grounded workflow recommendation | May recommend `PASS`, `HOLD` or `ESCALATE`; may not release/reject a lot |
| `hexacontext-compiler-agent-v1` | Approved smaller Foundry model | Plan and/or gather the minimum sufficient, authorized, current, source-backed context; return a ContextPacket or RetrievalPlan | No |

Do not choose exact model names from this document alone. Model availability, structured-output/tool support, quotas, region, content filtering and organizational approval must be checked in the target Foundry project.

## Required files

- [`manufacturing-agent.md`](manufacturing-agent.md) — full role, instructions, schemas and test cases.
- [`hexacontext-agent.md`](hexacontext-agent.md) — context compiler modes, instructions, schemas and future fine-tuning plan.
- [`tool-contracts.md`](tool-contracts.md) — common read-only tool API and security contract.
- [`orchestration-and-evaluation.md`](orchestration-and-evaluation.md) — fair comparison, tracing, metrics and acceptance gates.
- [`setup-checklist.md`](setup-checklist.md) — Foundry project, model, identity, connections, tracing and deployment setup.

The broader product/handoff context is in [`../handoff-context-packet.md`](../handoff-context-packet.md).

## Runtime inputs

Both comparison arms must receive the same immutable envelope:

```json
{
  "comparison_run_id": "uuid",
  "request_id": "uuid",
  "task": "Assess manufacturing lot disposition readiness",
  "lot_id": "HX-LOT-1002",
  "actor": {
    "actor_id": "demo-quality-reviewer",
    "scopes": ["quality", "general"]
  },
  "decision_profile_id": "manufacturing_lot_disposition_v1",
  "data_snapshot_id": "snapshot-or-version",
  "as_of_time": "ISO-8601 timestamp",
  "context_mode": "baseline_direct | hydrate | guide"
}
```

Foundry structured inputs can supply runtime values such as actor scope, profile ID and context mode without creating a new agent version for every request. Authorization must still be enforced by the backend/tools; a prompt variable is not an authorization control.

## Context modes

### Baseline direct

The Manufacturing Agent receives the task envelope and can call the raw read-only data tools. It decides what to retrieve. HexaContext is not called.

### Hydrate

The HexaContext Agent receives a `ContextRequest`, plans retrieval, calls approved tools and returns a complete `ContextPacket`. The Manufacturing Agent receives that packet and should not perform broad retrieval unless the packet reports an allowed fallback condition.

### Guide

The HexaContext Agent returns a typed `RetrievalPlan` describing sources, filters, graph paths, search queries, freshness requirements, limits and stop conditions. Deterministic backend code validates and executes the plan, then assembles a `ContextPacket` for the Manufacturing Agent.

**Recommended first implementation:** build `hydrate` first, retain `guide` as the second experiment. Guide mode adds a cleaner safety boundary because deterministic code can validate the plan before any retrieval is executed.

## Shared non-negotiable boundaries

1. Same Manufacturing Agent model, prompt version, output schema and temperature/decoding settings in both arms.
2. Same user request, actor permissions and immutable data snapshot.
3. Same underlying source systems and read-only tool implementations.
4. Baseline is not deliberately handicapped; it receives access to the raw data tools a competent implementation would use.
5. Hidden answer keys never enter agent prompts or tool responses.
6. Source content and tool output are untrusted input; instructions embedded in data are ignored.
7. No browser-held Foundry or database credentials.
8. No silent fallback from Foundry to mock mode in a claimed live run.
9. Humans retain release, rejection and remediation authority.
10. Fine-tuning is not part of the initial MVP acceptance gate.

## Prompt and configuration versioning

Record these fields on every run:

```text
agent_definition_id
agent_definition_version
system_prompt_sha256
model_deployment_name
model_version_if_available
tool_contract_version
decision_profile_version
data_snapshot_id
policy_version
context_mode
comparison_run_id
```

Playground changes are exploratory only. Before a configuration is used for a recorded comparison, export/copy it into Git, review the diff and assign a new version.

## Official Microsoft references

These are current planning references; the target implementation agent must re-check them before coding:

- [Foundry Agent Service overview](https://learn.microsoft.com/en-us/azure/foundry/agents/overview)
- [Responses API quickstart and ephemeral agent pattern](https://learn.microsoft.com/en-us/azure/foundry/agents/quickstarts/responses-api)
- [Structured runtime inputs](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/structured-inputs)
- [Tool best practices](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/tool-best-practice)
- [Agent development lifecycle](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/development-lifecycle)
- [Agent evaluators](https://learn.microsoft.com/en-us/azure/foundry/concepts/evaluation-evaluators/agent-evaluators)

## Status

This directory is a **target implementation specification**. The current app still runs the deterministic local harness in `backend/` and has not yet executed either Foundry agent.