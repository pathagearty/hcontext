# Business and Product Review

> **Document status:** this review established the bounded additive-layer direction. The controlling next experiment is now the direct-versus-HexaContext two-agent Foundry comparison described in [`handoff-context-packet.md`](handoff-context-packet.md) and [`foundry/orchestration-and-evaluation.md`](foundry/orchestration-and-evaluation.md).

## Executive verdict

Proceed with a **bounded MVP**, but position HexaContext as a reusable decision-profile and governed context layer—not a generic memory platform, model router, graph product or autonomous learning system.

The strongest initial proof is not that HexaContext can assemble a graph. It is that, for one consequential workflow, it can deliver a more complete and traceable evidence packet than the active record or search alone, while preserving authorization and human accountability.

## One-sentence concept

HexaContext gives an existing AI agent the minimum relevant, authorized and source-backed context for a specific decision, applies deterministic policy and returns an auditable packet for human review.

## Initial proving workflow

**Synthetic manufacturing lot-disposition readiness** was selected because it naturally requires:

- exact lot, inspection and certificate records;
- connected supplier, part, revision, equipment and deviation relationships;
- narrative notes that can conflict with structured fields;
- deterministic hold and escalation rules;
- authorization and provenance;
- a clear human decision boundary.

This is a proving domain, not a claim that manufacturing is the final commercial vertical.

## Problem hypothesis

An agent operating on the current record can miss context held in adjacent systems and relationships. Sending every possible record to a large model is expensive, difficult to govern and can reduce signal quality. Search alone can find documents but may not reliably reconstruct multi-step relationships; graph traversal alone may miss narrative contradictions.

HexaContext's hypothesis is that a decision-specific profile can combine those evidence forms and return only the authorized packet needed for the task.

## User, buyer and beneficiary hypotheses

| Role | MVP hypothesis | Validation status |
|---|---|---|
| Primary user | Manufacturing quality engineer or lot-disposition reviewer | Plausible; needs direct operator validation |
| Integrating user | Owner of an existing agent/workflow product | Central to additive-layer positioning; named owner still needed |
| Workflow owner | Quality operations / manufacturing operations | Plausible; exact organization and approval chain open |
| Buyer | Digital manufacturing, quality transformation or AI platform leader | Hypothesis only |
| Beneficiary | Quality reviewers, plant operations, supplier quality and audit teams | Plausible, not economically quantified |

## MVP value proposition

The demo should show five things:

1. **More complete evidence:** relationship retrieval finds context missed by an active-record baseline.
2. **Less irrelevant context:** only profile-permitted, authorized evidence enters the packet.
3. **Deterministic control:** mandatory rules are inspectable and testable outside the model.
4. **Traceability:** every check links to source evidence and retrieval routes.
5. **Human control:** the system recommends readiness; an authorized reviewer owns final action.

## UX rationale

The UI is intentionally organized around proof rather than feature volume:

- **Lot inbox:** makes designed edge cases visible and easy to rehearse.
- **Relationship map:** shows why graph context exists without implying a universal enterprise graph.
- **Source candidates:** lets the audience inspect the evidence before seeing the result.
- **DecisionPacket:** separates deterministic disposition, model explanation and human action.
- **Retrieval selector:** turns architecture alternatives into an observable experiment.
- **Evaluation lab:** computes exact/search/graph/hybrid fixture agreement and safety errors live.
- **Validity panel:** prevents synthetic results from being presented as production claims.

## What the MVP can validly demonstrate

- one typed request-to-packet contract;
- designed synthetic behavior across positive, negative, missing, conflicting, stale and unauthorized cases;
- retrieval-condition differences;
- deterministic policy enforcement;
- source and authorization traces;
- absence of hidden live-provider fallback;
- endpoint portability at the adapter level.

## What it cannot validate yet

- accuracy on an actual manufacturing workflow;
- production integration, identity or data rights;
- customer willingness to pay;
- operating cost or time savings;
- better economics from a smaller model;
- the need for FalkorDB rather than a relational or managed graph capability;
- superiority to Workfabric, an internal platform or an incumbent context substrate;
- autonomous profile learning or fine-tuning value.

## Primary risks and pushback

### 1. Platform-scope risk

A broad "context layer for every agent" is too large for an intern MVP and overlaps a crowded infrastructure category. Keep the deliverable to one decision profile and one integration contract.

### 2. Substrate duplication risk

The active direction assumes a wider context substrate or Workfabric may already exist. The PoC must prove an additive profile compiler/assurance seam rather than rebuild identity, connectors, memory or enterprise graph infrastructure.

### 3. Graph-for-graph's-sake risk

FalkorDB is justified only if evaluator-approved relationship cases outperform relational/search baselines enough to justify operating complexity.

### 4. Model-weight confusion

Current supplier state, policies, lot facts and relationship evidence should not be fine-tuned into a small model. A future profile model may learn bounded extraction or explanation behavior, but mutable business facts remain retrieved evidence.

### 5. Synthetic-proof risk

A perfect hybrid result on designed fixtures proves only that the contract and harness behave as designed. It does not prove field accuracy. The evaluator must review both the cases and the answer key.

### 6. Governance theater risk

Policy names, provenance and human-review labels are not sufficient. A production path needs real identity, source authorization, immutable audit and enforced tool boundaries.

## Go / extend / merge / stop gates

### Go to stakeholder demo when

- the local UI and API run end to end;
- all synthetic fixtures pass;
- at least one false-pass/over-escalation comparison is visible;
- the restricted evidence case proves exclusion;
- model-provider failure does not fall back to fabricated analysis;
- architecture and limitations are visible in the demo.

### Extend after demo only when

- a manufacturing evaluator approves the rules and cases;
- one real source-system seam and owner are named;
- Workfabric/internal overlap is reviewed;
- a live Foundry or Bedrock call is traced;
- the profile demonstrates value over an accepted baseline.

### Merge rather than expand when

- an approved platform already provides identity, storage, graph, retrieval or memory;
- HexaContext's value is primarily the decision-profile contract, policy pack and evaluation harness.

### Stop or pivot when

- no owner will integrate it;
- relationship context does not improve evaluator-approved cases;
- authorization cannot be enforced before retrieval/model invocation;
- the build becomes a generic context fabric instead of a decision-focused additive layer.

## Source basis used for this review

Internal source-of-truth material:

- `/Users/claw1/hexaware_context/raw-notes/source-documents/2026-08-05--sneha-hexacontext-poc-brief-refined.docx`
- `/Users/claw1/hexaware_context/context-packets/2026-08-05--sneha-hexacontext-refined-poc-brief-product-technical-and-positioning-review.md`
- `/Users/claw1/hexaware_context/context-packets/2026-08-05--sneha-hexacontext-shared-context-substrate-and-profile-compiler-direction-decision.md`
- `/Users/claw1/hexaware_context/context-packets/2026-08-04--sneha-hexacontext-profile-slm-and-hybrid-evidence-graph-architecture-decision.md`
- `/Users/claw1/harness_architecture_best_practices/best_practices.md`

Those packets also document the public technology/market landscape reviewed for the concept, including contextual-memory, graph/RAG, policy and managed-agent approaches. This repo does not reproduce unverified vendor performance claims.
