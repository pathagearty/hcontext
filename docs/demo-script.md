# Stakeholder Demo Script

> **Demo status:** this script covers the implemented deterministic local harness. The target live stakeholder demo is the two-column Foundry Direct vs With HexaContext comparison in [`foundry/orchestration-and-evaluation.md`](foundry/orchestration-and-evaluation.md). Retain this script as the reliable regression/fallback walkthrough.

Target length: **8–10 minutes**. Use the local mock provider first. A live Foundry/Bedrock call is a separate integration proof and should never replace the reliable product walkthrough.

## 1. Frame the problem — 45 seconds

> Existing agents often see the active record but miss connected supplier, equipment, revision and narrative context. Sending every possible record to a frontier model is costly and hard to govern. HexaContext compiles the minimum authorized evidence for one decision profile, applies deterministic rules and returns a traceable packet for human review.

Point to the **MVP thesis** and **decision boundary** cards.

## 2. Positive path — 90 seconds

1. Select `HX-LOT-1001`.
2. Leave retrieval on **Hybrid** and provider on **Deterministic mock**.
3. Show the lot, supplier, part, equipment and policy relationship map.
4. Click **Compile governed packet**.
5. Point out:
   - deterministic `PASS` readiness;
   - exact retrieval routes;
   - all policy checks;
   - source-backed evidence count;
   - required human confirmation;
   - model is explanation-only.

Say explicitly: `PASS` means ready for authorized review, not autonomous lot release.

## 3. Graph-value case — 90 seconds

1. Select `HX-LOT-1002`.
2. Compile with **Exact only**.
3. Show that the active-record condition lacks connected supplier/calibration/revision context and escalates because evidence is incomplete.
4. Switch to **Hybrid** and recompile.
5. Show the source-backed `HOLD` based on three connected supplier failures.

Message: the graph is useful because a specific relationship changes a consequential result—not because a graph looks impressive.

## 4. Hybrid-value case — 90 seconds

1. Select `HX-LOT-1009`.
2. Compile with **Graph + exact**.
3. Then compile with **Hybrid**.
4. Show that the narrative operator note conflicts with structured inspection and triggers `ESCALATE` only when narrative evidence is included.

Message: neither graph nor search is universally superior; the decision profile chooses and fuses the minimum routes.

## 5. Authorization case — 60 seconds

1. Select `HX-LOT-1012`.
2. Compile with **Hybrid**.
3. Point to `Excluded: 1` in the packet trace.
4. Confirm that no restricted content appears in the source list, packet or model input.

Message: authorization occurs before evidence fusion and model invocation.

## 6. Evaluation lab — 90 seconds

Scroll to **Evaluation lab**.

Explain:

- the same 12 designed cases run under exact, graph, search and hybrid conditions;
- agreement, false passes and over-escalations are calculated live by the backend;
- the expected answer key is separate from model prompts;
- 100% hybrid fixture agreement validates the current designed harness only—not production quality performance.

## 7. Architecture and validity — 60 seconds

Show the five-stage architecture:

1. typed decision request;
2. bounded hybrid context;
3. deterministic policy;
4. optional model explanation;
5. human action.

Then show **Measured in this MVP**, **Not yet claimed**, and **Next validation gate**.

## 8. Close with the decision ask — 30 seconds

> The next question is not whether we should build a universal context platform. It is whether a qualified workflow owner agrees that this decision profile and its relationship evidence are valuable enough to test against one approved source-system seam. If yes, we extend; if the substrate already exists, we integrate or merge rather than duplicate it.

## Optional live-provider proof

Only after the local walkthrough succeeds:

1. verify the endpoint/provider shows **Configured · untested**;
2. select the approved live provider;
3. run one positive and one HOLD/ESCALATE case;
4. capture provider request/trace evidence server-side;
5. repeat an invalid-network or invalid-endpoint test;
6. show the explicit error and absence of mock fallback.

Do not call the provider integrated if credentials, network, endpoint contract or trace evidence are still pending.

## Anticipated questions

### Why not just use RAG?

Exact/search retrieval is one route. The demo tests when bounded relationships and deterministic policy add value beyond document similarity.

### Why a graph database?

It is not yet assumed. The MVP proves relationship query classes first. FalkorDB should be adopted only if those classes outperform a simpler approved relational/managed approach enough to justify it.

### Why a small model?

A smaller profile model is a future optimization hypothesis for bounded explanation or normalization. The MVP does not require fine-tuning and does not put current business facts into weights.

### Is this a new agent platform?

No. HexaContext returns a typed packet to an existing agent/workflow and relies on existing identity, runtime and system-of-record ownership.

### Are the metrics real?

They are real executions against designed synthetic fixtures. They are not production accuracy, ROI or customer-validation claims.
