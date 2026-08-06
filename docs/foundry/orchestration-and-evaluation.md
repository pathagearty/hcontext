# Comparison Orchestration and Evaluation Plan

## Experiment question

For the same manufacturing task, actor permissions, source data and Manufacturing Agent, does adding HexaContext improve the completeness, relevance, authorization, provenance and efficiency of the context used to recommend a human-review state?

The first experiment is not “Which agent sounds better?” It is a controlled comparison of context acquisition architectures.

## Comparison arms

### Arm A — Foundry Direct baseline

```text
Request
  -> Manufacturing Readiness Agent
  -> raw read-only manufacturing tools
  -> ManufacturingDecision
  -> deterministic validation
```

The Manufacturing Agent must retrieve its own context.

### Arm B — HexaContext hydrate

```text
Same request
  -> HexaContext Compiler Agent (smaller model)
  -> same raw read-only tools
  -> validated ContextPacket
  -> same Manufacturing Readiness Agent, broad tools disabled
  -> ManufacturingDecision
  -> deterministic validation
```

### Arm C — HexaContext guide (evaluation-lab option)

```text
Same request
  -> HexaContext Compiler Agent
  -> RetrievalPlan
  -> deterministic plan validation/execution
  -> ContextPacket
  -> same Manufacturing Readiness Agent
  -> ManufacturingDecision
  -> deterministic validation
```

The stakeholder UI may show two columns—baseline and one selected HexaContext mode—while the Evaluation Lab can run all three.

## Fairness controls

Every comparison run must lock:

| Controlled variable | Requirement |
|---|---|
| User task | Byte-equivalent normalized request |
| Subject | Same lot/entity ID |
| Actor | Same authenticated identity and scopes |
| Data | Same immutable snapshot and as-of time |
| Manufacturing model | Same deployment/version |
| Manufacturing instructions | Same prompt hash/version |
| Decision Profile | Same ID/version |
| Tool plane | Same tool contract and underlying data |
| Output schema | Same ManufacturingDecision schema |
| Decoding | Same supported settings |
| Cache state | Disable or report/normalize warm-cache effects |
| Timeout/retry policy | Same policy where architecture allows |

The baseline must not be denied a tool simply because HexaContext knows to use it. HexaContext may add value by choosing tools more consistently or efficiently, not by having exclusive data access.

## Run isolation

- Generate a `comparison_run_id` before either arm begins.
- Create separate model runs/threads for each arm.
- Never share messages, retrieved context, tool results or model state between arms.
- Start arms concurrently only after the same snapshot is pinned.
- Do not require exact wall-clock simultaneity; snapshot equivalence is the meaningful control.
- Store the completion state of each arm independently so a failure in one is visible rather than replaced.

## Proposed API

### `POST /api/comparisons`

```json
{
  "task": "Assess manufacturing lot disposition readiness",
  "lot_id": "HX-LOT-1002",
  "decision_profile_id": "manufacturing_lot_disposition_v1",
  "hexacontext_mode": "hydrate",
  "actor_id": "demo-quality-reviewer"
}
```

Backend derives scopes, snapshot, model and prompt versions; clients cannot choose unauthorized scopes or hidden evaluation labels.

### Response

For a short MVP run, return the completed result. If Foundry/tool latency becomes material, use an asynchronous job:

```text
POST /api/comparisons          -> 202 + comparison_run_id
GET  /api/comparisons/{id}     -> per-arm status/results
GET  /api/comparisons/{id}/events -> optional SSE progress
```

### Comparison record

```json
{
  "comparison_run_id": "uuid",
  "request": {},
  "controls": {
    "snapshot_id": "snapshot-v1",
    "manufacturing_model": "deployment-name",
    "manufacturing_prompt_hash": "sha256",
    "hexacontext_model": "deployment-name",
    "hexacontext_prompt_hash": "sha256",
    "tool_contract_version": "1.0",
    "decision_profile_version": "1.0"
  },
  "baseline": {
    "status": "COMPLETED",
    "decision": {},
    "trace_summary": {},
    "metrics": {}
  },
  "hexacontext": {
    "status": "COMPLETED",
    "mode": "hydrate",
    "context_packet": {},
    "decision": {},
    "trace_summary": {},
    "metrics": {}
  },
  "evaluation": {}
}
```

Do not send hidden answer keys to the browser during a blind/ad hoc run. The Evaluation Lab can display metrics after outputs are locked.

## Orchestration pseudocode

```python
async def compare(request, authenticated_actor):
    controls = await freeze_controls(request, authenticated_actor)

    baseline_task = run_manufacturing_agent_direct(controls)
    hexacontext_task = compile_context(controls, mode=request.hexacontext_mode)

    baseline_result, compiled = await gather_isolated(
        baseline_task,
        hexacontext_task,
    )

    enhanced_result = None
    if compiled.valid:
        enhanced_result = await run_manufacturing_agent_with_context(
            controls,
            compiled.context_packet,
            tool_choice="none",
        )

    validated_baseline = validate_manufacturing_result(baseline_result, controls)
    validated_enhanced = validate_manufacturing_result(enhanced_result, controls)

    return persist_and_evaluate(
        controls,
        validated_baseline,
        compiled,
        validated_enhanced,
    )
```

Starting the enhanced Manufacturing Agent after the packet is compiled means end-to-end arm latency includes both model stages. Report this honestly. Do not compare only the second call's latency to the full baseline.

## What to measure

### Deterministic outcome metrics

| Metric | Definition |
|---|---|
| Disposition agreement | Recommended state matches hidden expected state |
| Critical false PASS | Agent recommends PASS when expected state is HOLD/ESCALATE for a safety-critical reason |
| Unnecessary HOLD/escalation | Agent recommends a more restrictive state without evidence support |
| Required evidence recall | Required answer-key evidence classes/items retrieved or supplied |
| Evidence precision | Included evidence items judged relevant to the profile/task |
| Citation validity | Cited IDs exist in the allowed tool/packet result |
| Claim support | Material claims are entailed by cited evidence |
| Missing-evidence detection | Mandatory absent classes are explicitly identified |
| Conflict detection | Designed contradictory sources are preserved and surfaced |
| Freshness detection | Stale evidence is correctly identified under profile rules |
| Unauthorized leakage | Any restricted data reaches model input/output or citation set |
| Schema validity | Output conforms to required schema without manual repair |

### Process and efficiency metrics

```text
tool calls requested
tool calls accepted/rejected by validator
tool selection precision/recall
tool argument validity
tool success rate
retrieved candidate count
included evidence count
duplicate evidence count
input/output tokens per model call
context characters/tokens
model-call count
tool-call count
context-compile latency
manufacturing-agent latency
end-to-end latency
provider-reported cost or estimated cost under an approved rate table
retry count
```

Foundry's current agent evaluators include concepts such as Task Adherence, Task Navigation Efficiency, Tool Call Accuracy, Tool Selection, Tool Input Accuracy and Tool Output Utilization. Use them where available, but retain deterministic domain evaluators as the release authority. Some agent evaluators are preview features and must not become an unreviewed production dependency.

### Human-review metrics

With qualified synthetic-case reviewers:

- disposition accepted/changed;
- evidence packet completeness rating;
- evidence relevance/noise rating;
- time to confirm the result;
- missing evidence noticed by reviewer but not system;
- explanation usefulness;
- confidence in provenance/audit trace.

The PoC should not claim business value from model-only scores without human workflow evidence.

## Ground truth design

Keep hidden from runtime:

```text
expected disposition
required evidence classes
critical evidence IDs
expected missing classes
expected conflicts
stale evidence IDs
forbidden/unauthorized evidence IDs
acceptable tool sequences or route families
```

The current 12 cases are a smoke/regression set. Before stronger claims, expand to a versioned evaluator-reviewed set with:

- straightforward direct cases;
- relationship-dependent cases;
- document/narrative conflicts;
- stale and version-conflict cases;
- missing evidence;
- authorization distractors;
- source/system failures;
- prompt injection in retrieved text;
- duplicate/near-duplicate evidence;
- ambiguous policy/profile inputs;
- unseen supplier/part/scenario families.

Split by scenario family/entity rather than random row split to reduce leakage.

## Proposed initial release gates

These are engineering hypotheses requiring qualified owner approval:

| Gate | Initial target |
|---|---:|
| Unauthorized evidence leakage | `0` |
| Critical false PASS on release set | `0` |
| Valid output schema after normal retry policy | `100%` |
| Citation IDs present in allowed evidence set | `100%` |
| False `COMPLETE` ContextPackets with missing mandatory evidence | `0` |
| Required evidence-class recall | `>= 95%` |
| Tool argument/schema validity | `>= 99%` |
| Explicit system/tool failure reporting | `100%` of injected failures |

Do not declare HexaContext successful merely because its final-disposition agreement is higher on 12 designed fixtures. Continue only if it provides a meaningful advantage in one or more of:

- critical evidence coverage;
- conflict/missing/freshness detection;
- authorization assurance;
- reduced unnecessary context/tool use;
- reviewer acceptance/time;
- accepted-result cost;

without unacceptable latency, complexity or safety regressions.

## Ablation matrix

Run these controlled conditions as data matures:

| Condition | Purpose |
|---|---|
| Direct Manufacturing Agent | Primary baseline |
| HexaContext hydrate + Manufacturing Agent | Full context-layer hypothesis |
| HexaContext guide + deterministic executor + Manufacturing Agent | Planning-only hypothesis |
| Deterministic profile planner without HexaContext model | Tests whether an LLM is needed in the context layer |
| Exact/relational retrieval only | Tests graph/search necessity |
| No graph traversal | Measures graph-specific lift |
| No narrative search | Measures document-conflict lift |
| Larger vs smaller HexaContext model | Tests model-size/cost tradeoff |
| Prompted vs later fine-tuned HexaContext model | Tests tuning lift |

The deterministic profile planner is an important baseline. If it matches the HexaContext model, use the simpler planner.

## Failure handling

- If one arm fails, display `FAILED`; never substitute mock output in a live comparison.
- Retry only on predefined transient categories and record every retry.
- Do not retry invalid schema indefinitely; cap attempts.
- Distinguish provider failure, tool failure, missing business evidence and authorization exclusion.
- Preserve partial traces even when a run fails.
- A failed HexaContext packet must not automatically trigger an unreported direct-agent run.

## Observability

Enable Foundry tracing/Application Insights or approved equivalent. Correlate spans with `comparison_run_id` and include:

```text
orchestrator
  baseline.manufacturing_agent
    tool calls
    output validation
  enhanced.hexacontext_agent
    plan
    tool calls
    packet validation
  enhanced.manufacturing_agent
    output validation
  evaluation
```

Record model/tool/prompt/profile/snapshot versions. Redact credentials and restricted content. Do not log hidden chain-of-thought. A concise model-provided rationale and tool trace are sufficient.

Tracing is evidence about execution, not proof of quality; evaluation remains separate.

## UI specification

### Request area

- user task;
- lot/entity;
- actor/role label;
- pinned snapshot/profile;
- HexaContext mode selector (`hydrate` or `guide`);
- `Run comparison` button.

### Side-by-side results

**Foundry Direct** and **With HexaContext** should each show:

- recommended disposition;
- evidence rationale;
- evidence classes covered;
- missing/stale/conflicting evidence;
- citations/source list;
- tool timeline;
- tokens/context size/model calls;
- end-to-end latency;
- errors/retries.

### Comparison strip

- evidence recall/precision on benchmark cases;
- citations valid;
- conflicts/missing detected;
- unauthorized leakage;
- context volume;
- tool/model calls;
- latency/cost;
- reviewer result if recorded.

Do not visually imply that the enhanced result is correct merely because it appears in the “value-add” column.

## Stakeholder demo sequence

1. Explain that the Manufacturing Agent is identical in both arms.
2. Run a direct critical-defect case where both should work.
3. Run a supplier-history/calibration/revision case to test relationship context.
4. Run a narrative conflict to test search plus graph coverage.
5. Run a missing-evidence case to show unknown is not pass.
6. Run a restricted distractor to show authorization exclusion.
7. Expand traces and source citations.
8. Show the Evaluation Lab and limitations.
9. State explicitly what is live versus synthetic/simulated.

## Claim discipline

Allowed after a successful controlled run:

> On this evaluator-reviewed synthetic dataset and configuration, the HexaContext path changed measured evidence coverage, tool use and decision quality relative to the same direct Foundry Manufacturing Agent.

Not allowed without broader evidence:

```text
production accuracy
manufacturing compliance
customer ROI
universal context improvement
fine-tuned model superiority
frontier-model replacement
cost reduction at enterprise scale
```

## Current implementation gap

The repository currently supports local exact/graph/search/hybrid simulation with a deterministic policy and mock explanation. It does not yet implement `/api/comparisons`, live Foundry ephemeral agents, shared external tools, immutable data snapshots or Foundry traces. This plan is the controlling target for the next build.