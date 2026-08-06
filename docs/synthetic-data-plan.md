# Synthetic Data Plan

## Objective

Create a safe, reproducible and evaluator-reviewable dataset that demonstrates whether HexaContext adds value over exact-record, relationship-only or narrative-search baselines for one manufacturing lot-disposition decision profile.

The data must make the **reason for every expected result explicit**. It should test retrieval, authorization, policy and failure behavior—not imitate a real client dataset.

## Data principles

1. **Designed before scaled:** start with hand-designed edge cases, then add generated variation only after the answer key is reviewed.
2. **No real records:** use fictitious entity IDs, materials, systems and timestamps.
3. **Separate truth:** expected dispositions and reasons stay in fixtures/evaluation, never in model prompts.
4. **Source realism without identity realism:** records resemble quality, supplier, PLM and calibration evidence but do not copy a customer's schemas or values.
5. **Unknown means unknown:** missing facts are not filled with plausible medical/quality inferences.
6. **Negative-path coverage:** stale, contradictory, unauthorized and unavailable evidence are first-class cases.
7. **Reproducibility:** `python3 data/generate.py` produces the same versioned dataset.

## Current v1 dataset

- Dataset ID: `hexacontext-manufacturing-demo-v1`
- Cases: `12`
- Data type: designed synthetic JSON
- Real company/client data: none
- Decision profile: `manufacturing_lot_disposition_v1`
- Expected states: `PASS`, `HOLD`, `ESCALATE`

### Entity model

```text
Lot
 ├─ contains_part → Part / released revision
 ├─ produced_by → Supplier / recent quality history
 ├─ inspected_with → Equipment / calibration
 ├─ governed_by → Lot disposition policy
 ├─ supported_by → Inspection + certificate records
 └─ linked_to → Deviation / narrative note
```

### Evidence fields

Every source includes:

- unique evidence and source-record IDs;
- source system and authority class;
- observed time and source version;
- access scope;
- retrieval scope (`direct`, `relationship`, `narrative`);
- human-readable summary;
- structured signals used by deterministic policy.

## Designed case matrix

| Case | Designed condition | Expected state | Primary proof |
|---|---|---:|---|
| `HX-LOT-1001` | Complete, current, consistent evidence | PASS | Positive path |
| `HX-LOT-1002` | Three connected supplier failures | HOLD | Graph relationship value |
| `HX-LOT-1003` | Critical defect in direct inspection | HOLD | Direct blocker |
| `HX-LOT-1004` | Expired connected equipment calibration | HOLD | Multi-entity evidence |
| `HX-LOT-1005` | Observed/released revision mismatch | HOLD | PLM relationship |
| `HX-LOT-1006` | Certificate cannot be verified | HOLD | Source verification |
| `HX-LOT-1007` | Final inspection failed | HOLD | Direct negative path |
| `HX-LOT-1008` | Open connected deviation | ESCALATE | Non-release escalation |
| `HX-LOT-1009` | Narrative conflicts with structured result | ESCALATE | Search + graph fusion |
| `HX-LOT-1010` | Supplier relationship evidence is stale | ESCALATE | Freshness behavior |
| `HX-LOT-1011` | Mandatory supplier history is absent | ESCALATE | Missing-data behavior |
| `HX-LOT-1012` | Passing authorized evidence plus restricted distractor | PASS | Authorization/no leakage |

## Retrieval-condition experiment

The same cases are compiled under four conditions:

1. **Exact:** direct lot evidence only.
2. **Graph:** exact plus bounded relationship evidence.
3. **Search:** exact plus narrative evidence.
4. **Hybrid:** exact, relationships and narrative evidence fused after authorization.

The API computes:

- fixture agreement;
- correct/total cases;
- critical false passes;
- over-escalations.

These metrics validate the harness and the designed query classes only. They are not estimates of production accuracy.

## Expansion plan after evaluator review

### Phase 1 — 12 designed cases (implemented)

Purpose: correctness, architecture comparison and negative paths.

### Phase 2 — 30–50 evaluator-approved cases

Add controlled variation across:

- part families and suppliers;
- multiple policy and source versions;
- temporal windows;
- one-to-many and many-to-one relationships;
- duplicate and conflicting records;
- missing/non-authoritative sources;
- access scopes and purpose-of-use;
- narrative paraphrases and irrelevant distractors.

Target distribution should be evaluator-owned rather than evenly randomized. Include enough difficult HOLD/ESCALATE cases to expose unsafe false passes.

### Phase 3 — Perturbation set

For each approved base case, generate controlled variants:

- change only the supplier relationship;
- expire only the calibration;
- remove one mandatory source;
- introduce one source-version conflict;
- add irrelevant narrative noise;
- move a record to an unauthorized scope;
- reorder evidence and rename non-key labels.

The expected result should change only when a decision-relevant fact changes.

### Phase 4 — Sandbox-shaped data

After source ownership and permission are confirmed, map the synthetic schema to one approved sandbox contract. Keep identifiers and content synthetic until data-policy approval exists.

## Answer-key governance

The golden set should be reviewed by:

1. a manufacturing quality/workflow evaluator;
2. the profile/policy owner;
3. a technical reviewer who confirms source and authorization paths.

Every answer-key revision should record:

- case ID and version;
- changed expected state/reason;
- evaluator and date;
- whether the rule, source mapping or fixture was wrong;
- regression cases affected.

## Quality checks

The generator/tests should enforce:

- unique entity/evidence IDs;
- declared synthetic status;
- no real company/client names;
- required metadata on every source;
- valid relationship endpoints;
- only allowed disposition labels;
- at least one positive, critical failure, missing, conflict, stale and unauthorized case;
- hybrid agreement with the reviewed answer key;
- restricted evidence exclusion before model use.

## Privacy and safety

Do not use:

- client or partner source schemas without approval;
- real supplier names, quality events or lot identifiers;
- employee notes or identities;
- credentials, endpoints or tenant IDs;
- copied production policies;
- claims that synthetic metrics predict manufacturing outcomes.

## Open data decisions

- Which actual decision profile and policy owner should replace the synthetic rule pack?
- Which source systems provide lot, inspection, supplier, PLM, equipment and deviation evidence?
- Which relationship queries cannot be served adequately from an approved relational platform?
- What source/freshness hierarchy should resolve conflicts?
- Which restricted scopes must the profile know exist without revealing their content?
