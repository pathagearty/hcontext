-- Hidden evaluation truth. This schema is intentionally absent from the Data API
-- exposed-schema list and inaccessible to anon/authenticated application actors.

create schema if not exists private_eval;

revoke all on schema private_eval from public, anon, authenticated;
alter default privileges in schema private_eval revoke all on tables from public, anon, authenticated;
alter default privileges in schema private_eval revoke all on sequences from public, anon, authenticated;
alter default privileges in schema private_eval revoke execute on functions from public, anon, authenticated;

create table private_eval.case_expectations (
  id uuid primary key default gen_random_uuid(),
  case_id text not null,
  lot_id text not null,
  tenant_id text not null,
  snapshot_id text not null,
  dataset_version text not null,
  expected_disposition text not null
    check (expected_disposition in ('PASS', 'HOLD', 'ESCALATE')),
  expected_status text not null default 'COMPLETED'
    check (expected_status in ('COMPLETED', 'FAILED')),
  primary_reason text not null,
  expected_missing_classes text[] not null default '{}'::text[],
  expected_stale_record_ids text[] not null default '{}'::text[],
  expected_conflict_groups jsonb not null default '[]'::jsonb,
  forbidden_record_ids text[] not null default '{}'::text[],
  review_status text not null check (review_status in ('DRAFT', 'REVIEWED', 'APPROVED')),
  evaluator_alias text not null,
  created_at timestamptz not null default now(),
  check (jsonb_typeof(expected_conflict_groups) = 'array'),
  unique (case_id, snapshot_id),
  foreign key (tenant_id, lot_id, snapshot_id)
    references public.manufacturing_lots(tenant_id, lot_id, snapshot_id)
);

create table private_eval.expected_evidence (
  id uuid primary key default gen_random_uuid(),
  case_id text not null,
  snapshot_id text not null,
  evidence_class text not null,
  source_record_id text not null,
  requirement text not null check (requirement in ('REQUIRED', 'SUPPORTING', 'FORBIDDEN')),
  created_at timestamptz not null default now(),
  unique (case_id, snapshot_id, evidence_class, source_record_id, requirement),
  foreign key (case_id, snapshot_id)
    references private_eval.case_expectations(case_id, snapshot_id)
    on delete cascade
);

alter table private_eval.case_expectations enable row level security;
alter table private_eval.case_expectations force row level security;
alter table private_eval.expected_evidence enable row level security;
alter table private_eval.expected_evidence force row level security;

revoke all on all tables in schema private_eval from public, anon, authenticated;
grant usage on schema private_eval to service_role;
grant select on all tables in schema private_eval to service_role;
