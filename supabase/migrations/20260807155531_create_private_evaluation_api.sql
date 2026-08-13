-- Trusted scoring plane. Runtime agents have no schema usage and cannot execute
-- either RPC; only the server-side service_role evaluator may read/write here.

create table private_eval.evaluation_runs (
  id uuid primary key default gen_random_uuid(),
  comparison_run_id text not null,
  case_id text not null,
  snapshot_id text not null,
  execution_mode text not null check (execution_mode in ('SIMULATED_LOCAL', 'FOUNDRY_LIVE')),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  started_at timestamptz not null,
  completed_at timestamptz not null,
  model_versions jsonb not null default '{}'::jsonb,
  baseline_result jsonb not null,
  hexacontext_result jsonb not null,
  baseline_trace jsonb not null,
  hexacontext_trace jsonb not null,
  scores jsonb not null,
  review_status text not null default 'DRAFT'
    check (review_status in ('DRAFT', 'REVIEWED', 'APPROVED', 'REJECTED')),
  approved_for_fine_tuning boolean not null default false,
  reviewed_by_alias text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (completed_at >= started_at),
  check (jsonb_typeof(model_versions) = 'object'),
  check (jsonb_typeof(baseline_result) = 'object'),
  check (jsonb_typeof(hexacontext_result) = 'object'),
  check (jsonb_typeof(baseline_trace) = 'array'),
  check (jsonb_typeof(hexacontext_trace) = 'array'),
  check (jsonb_typeof(scores) = 'object'),
  check (not approved_for_fine_tuning or review_status = 'APPROVED'),
  unique (comparison_run_id),
  foreign key (case_id, snapshot_id)
    references private_eval.case_expectations(case_id, snapshot_id)
);

alter table private_eval.evaluation_runs enable row level security;
alter table private_eval.evaluation_runs force row level security;

revoke all on table private_eval.evaluation_runs from public, anon, authenticated;
grant select, insert, update on table private_eval.evaluation_runs to service_role;

create index evaluation_runs_case_idx
  on private_eval.evaluation_runs (snapshot_id, case_id, completed_at desc);
create index evaluation_runs_review_queue_idx
  on private_eval.evaluation_runs (review_status, completed_at desc)
  where review_status in ('DRAFT', 'REVIEWED');
create index evaluation_runs_fine_tuning_idx
  on private_eval.evaluation_runs (completed_at desc)
  where approved_for_fine_tuning;

create or replace function public.get_private_case_evaluation(
  p_lot_id text,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(
    (
      select jsonb_build_object(
        'case_id', expectation.case_id,
        'lot_id', expectation.lot_id,
        'snapshot_id', expectation.snapshot_id,
        'dataset_version', expectation.dataset_version,
        'expected_disposition', expectation.expected_disposition,
        'expected_status', expectation.expected_status,
        'primary_reason', expectation.primary_reason,
        'difficulty_tier', expectation.difficulty_tier,
        'minimum_hops', expectation.minimum_hops,
        'expected_tool_sequence', expectation.expected_tool_sequence,
        'expected_missing_classes', expectation.expected_missing_classes,
        'expected_stale_record_ids', expectation.expected_stale_record_ids,
        'expected_conflict_groups', expectation.expected_conflict_groups,
        'forbidden_record_ids', expectation.forbidden_record_ids,
        'expected_relationship_paths', expectation.expected_relationship_paths,
        'review_status', expectation.review_status,
        'expected_evidence', coalesce((
          select jsonb_agg(jsonb_build_object(
            'evidence_class', evidence.evidence_class,
            'source_record_id', evidence.source_record_id,
            'requirement', evidence.requirement,
            'retrieval_hop', evidence.retrieval_hop,
            'relationship_path', evidence.relationship_path
          ) order by evidence.requirement, evidence.retrieval_hop, evidence.evidence_class, evidence.source_record_id)
          from private_eval.expected_evidence as evidence
          where evidence.case_id = expectation.case_id
            and evidence.snapshot_id = expectation.snapshot_id
        ), '[]'::jsonb)
      )
      from private_eval.case_expectations as expectation
      where expectation.lot_id = p_lot_id
        and expectation.snapshot_id = p_snapshot_id
    ),
    '{}'::jsonb
  );
$$;

create or replace function public.store_private_evaluation_run(
  p_comparison_run_id text,
  p_lot_id text,
  p_snapshot_id text,
  p_execution_mode text,
  p_request_hash text,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_model_versions jsonb,
  p_baseline_result jsonb,
  p_hexacontext_result jsonb,
  p_baseline_trace jsonb,
  p_hexacontext_trace jsonb,
  p_scores jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_case_id text;
  v_id uuid;
begin
  select expectation.case_id into v_case_id
  from private_eval.case_expectations as expectation
  where expectation.lot_id = p_lot_id
    and expectation.snapshot_id = p_snapshot_id;

  if v_case_id is null then
    raise exception using
      errcode = '22023',
      message = 'No approved private evaluation case matched the lot and snapshot.';
  end if;

  insert into private_eval.evaluation_runs (
    comparison_run_id, case_id, snapshot_id, execution_mode, request_hash,
    started_at, completed_at, model_versions, baseline_result,
    hexacontext_result, baseline_trace, hexacontext_trace, scores
  ) values (
    p_comparison_run_id, v_case_id, p_snapshot_id, p_execution_mode,
    p_request_hash, p_started_at, p_completed_at,
    coalesce(p_model_versions, '{}'::jsonb), p_baseline_result,
    p_hexacontext_result, p_baseline_trace, p_hexacontext_trace, p_scores
  )
  returning id into v_id;

  return jsonb_build_object(
    'evaluation_run_id', v_id,
    'comparison_run_id', p_comparison_run_id,
    'case_id', v_case_id,
    'snapshot_id', p_snapshot_id,
    'review_status', 'DRAFT',
    'approved_for_fine_tuning', false
  );
end;
$$;

revoke all on function public.get_private_case_evaluation(text, text)
  from public, anon, authenticated;
revoke all on function public.store_private_evaluation_run(
  text, text, text, text, text, timestamptz, timestamptz,
  jsonb, jsonb, jsonb, jsonb, jsonb, jsonb
) from public, anon, authenticated;

grant execute on function public.get_private_case_evaluation(text, text)
  to service_role;
grant execute on function public.store_private_evaluation_run(
  text, text, text, text, text, timestamptz, timestamptz,
  jsonb, jsonb, jsonb, jsonb, jsonb, jsonb
) to service_role;
