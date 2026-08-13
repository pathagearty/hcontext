# Supabase Context Benchmark v2

## Purpose

Snapshot `hx-mfg-v2-snapshot-001` is the primary live comparison dataset for
showing the value of HexaContext. It preserves the v1 snapshot as a small control
set and embeds 50 scored Alpha cases in an ordinary multi-tenant manufacturing
history. Runtime rows contain evidence conditions only; they never contain an
answer, scenario label or case marker.

The benchmark is intentionally relational rather than merely large. A correct
decision may require following these paths:

```text
lot -> work order -> operation -> equipment usage -> equipment -> calibration
lot -> part -> released BOM -> component usage -> material batch -> certificate
lot -> part -> engineering change order -> effective released revision
lot -> supplier/part pair -> recent quality events
lot/part/equipment -> deviation or authorized note
```

## Free Plan fit

The hosted project was measured after deployment on 2026-08-07:

- complete database: 58 MB;
- public schema: 44 MB;
- private evaluator schema: 448 kB;
- v2 runtime: 40,295 normalized rows;
- v2 evaluated cases: 50;
- deterministic runtime manifest: `633dad2342765165b17f9d665593c2968749be0771bd6e69318a08980c0ae2ab`;
- v1 remains present and immutable.

Supabase Free currently includes a 500 MB database per project, shared compute,
500 MB RAM, 5 GB egress and 1 GB file storage. This benchmark therefore uses
about 12% of the database allowance and does not require Storage, Vector,
Realtime or Edge Functions. Free projects may pause after a week of inactivity,
so wake and smoke-test the project before a demo.

Current limits must be rechecked against the official
[Supabase billing documentation](https://supabase.com/docs/guides/platform/billing-on-supabase)
and [pricing page](https://supabase.com/pricing) before a production or public
performance claim.

## Runtime scale

The deterministic SQL seed creates:

| Area | Rows |
|---|---:|
| Lots, work orders | 2,000 each |
| Operations, equipment usage | 6,000 each |
| Material batches, certificates | 3,600 / 3,596 |
| Component consumption genealogy | 3,998 |
| Manufacturing notes | 4,102 |
| Supplier quality history | 2,697 |
| Direct inspections and lot certificates | 1,999 each |
| BOM lines | 540 |
| Equipment and calibrations | 480 / 479 |
| Revisions and change orders | 185 / 186 |
| Deviations | 106 |

The three tenants contain 1,200 Alpha, 500 Beta and 300 Gamma lots. Shared
parts, suppliers, equipment and material batches create fan-out and distractors.
The 50 evaluated Alpha lots use dedicated early equipment/batch assignments so
controlled mutations do not unintentionally change another scored case.

## Evaluation design

Every one of the 50 cases has an approved private rubric containing:

- expected `PASS`, `HOLD` or `ESCALATE` disposition;
- primary reason;
- difficulty tier and minimum relationship depth;
- expected tool sequence and relationship paths;
- required/supporting/forbidden source-record IDs;
- expected missing evidence classes;
- expected stale records and conflict groups;
- forbidden restricted or cross-tenant records.

Distribution: 8 `PASS`, 16 `HOLD`, 26 `ESCALATE`. Hard conditions are
deliberately overrepresented because this is a safety/context benchmark, not an
estimate of factory prevalence.

Difficulty ladder:

| Tier | Cases | What it tests |
|---|---:|---|
| Control | 10 | Direct clean, defect, certificate, calibration, supplier, deviation and note conditions |
| Multi-hop | 15 | Failed operations, process calibration and critical material genealogy |
| Temporal | 10 | Effective revisions, pending changes, expired batches and stale certificates |
| Conflict/missing | 10 | Narrative/revision conflicts and absent mandatory records |
| Authorization | 5 | Restricted HR text, prompt injection and same-number cross-tenant shadows |

## Answer-key and trace boundary

The scoring plane is structurally separate from the evidence plane.

| Capability | Foundry agents / authenticated runtime | Trusted evaluator service role |
|---|---:|---:|
| Read public runtime tables through approved RPCs | Yes, under RLS | Not used for agent retrieval |
| Read `private_eval.case_expectations` | No | Yes |
| Execute `get_private_case_evaluation` | No | Yes |
| Store comparison outputs and traces | No | Yes |
| Approve a trace for fine-tuning | No | Human-reviewed admin workflow only |

`private_eval` is absent from the Data API exposed-schema list, has forced RLS,
and grants neither schema usage nor table access to `anon` or `authenticated`.
The public evaluator RPCs explicitly revoke execute from those roles and grant
it only to `service_role`.

The application has two intentionally different clients:

- `SupabaseToolGateway` uses the publishable key plus an approved user JWT and
  rejects the Supabase secret key as an evidence identity;
- `SupabaseEvaluatorStore` uses the secret key and can call only the two private
  evaluator RPCs. It must never be registered as a Foundry tool.

`GET /api/evaluator/cases/{lot_id}` is an operator-only post-run endpoint. It is
disabled unless `EVALUATOR_UI_TOKEN` is configured, requires the
`X-Evaluator-Token` header and returns `Cache-Control: no-store, private`. Normal
runtime and comparison endpoints continue to omit raw expected dispositions.

The private run ledger records both arm outputs, tool timelines, scores, model
versions and review state. New rows default to `DRAFT` and
`approved_for_fine_tuning = false`; a database constraint prevents fine-tuning
approval unless the row is already `APPROVED`. Before any training use, traces
must also be rights-cleared, sanitized, deduplicated and reviewed for prompt or
restricted-data leakage.

## Read-only v2 tools

The existing seven v1 operations remain valid. V2 adds:

1. `get_lot_work_orders`
2. `get_work_order_operations`
3. `get_operation_equipment_usage`
4. `get_connected_equipment_calibration`
5. `get_part_bom`
6. `get_lot_component_usage`
7. `get_material_batch_records`
8. `get_engineering_change_orders`

Every relationship argument must be connected to the server-bound subject lot.
Tenant and scopes never appear in tool arguments; PostgreSQL derives them from
signed Auth `app_metadata`. All operations use bounded result sets and the
existing versioned evidence envelope. A successful empty result remains
distinct from an unauthorized, failed, unavailable or unperformed query.

## Rebuild and verification

Normal local reset loads only runtime data:

```bash
supabase db reset --local
```

The private evaluator seed is deliberately separate:

```bash
docker exec -i supabase_db_sneha-hexacontext-mvp \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < supabase/seed_v2_evaluator.sql
```

Run database verification after loading both evaluator seeds:

```bash
supabase test db --local
supabase db lint --local --level warning
supabase db advisors --linked
```

The checked-in database tests verify v1 preservation, exact v2 scale, all 50
answer keys, forced RLS, private evaluator denial, tenant/scope isolation,
multi-hop happy paths, successful missing-record queries, temporal conflicts,
prompt injection and cross-tenant shadows.

## Remaining live-comparison work

The data and tool substrate is deployed. A defensible HexaContext comparison
still requires:

1. provision approved Supabase Auth identities with tenant/scopes in
   `raw_app_meta_data`;
2. exercise the remote Data API using those actual user JWTs;
3. register only the 15 runtime RPCs in both Foundry conditions;
4. hold model, prompt, profile, snapshot and budgets constant;
5. run Manufacturing-only, then HexaContext hydrate plus the unchanged
   Manufacturing Agent;
6. score only after both outputs are locked;
7. persist redacted traces in the private run ledger and review them before any
   fine-tuning use.
