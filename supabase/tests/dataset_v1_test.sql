begin;

create or replace function pg_temp.assert_true(p_condition boolean, p_label text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'dataset_v1 assertion failed: %', p_label;
  end if;
end;
$$;
grant execute on function pg_temp.assert_true(boolean, text) to public;

select '1..1';
set local role service_role;

select pg_temp.assert_true(
  (select count(*) = 1 from public.dataset_snapshots),
  'one immutable snapshot is seeded'
);
select pg_temp.assert_true(
  (
    select sum(row_count) = 179
    from (
      select count(*) row_count from public.dataset_snapshots union all
      select count(*) from public.organizations union all
      select count(*) from public.sites union all
      select count(*) from public.suppliers union all
      select count(*) from public.parts union all
      select count(*) from public.equipment union all
      select count(*) from public.manufacturing_lots union all
      select count(*) from public.inspections union all
      select count(*) from public.certificates_of_analysis union all
      select count(*) from public.calibration_records union all
      select count(*) from public.engineering_revisions union all
      select count(*) from public.supplier_quality_events union all
      select count(*) from public.deviations union all
      select count(*) from public.manufacturing_notes union all
      select count(*) from public.decision_profiles
    ) counts
  ),
  'runtime seed has 179 normalized rows'
);
select pg_temp.assert_true(
  (select count(*) = 15 from public.manufacturing_lots where tenant_id = 'HX-TENANT-ALPHA'),
  'primary tenant has 15 lots'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.manufacturing_lots where tenant_id = 'HX-TENANT-BETA'),
  'shadow tenant has one collision lot'
);
select pg_temp.assert_true(
  (
    select count(*) = 0
    from information_schema.columns
    where table_schema = 'public'
      and column_name = any(array[
        'expected_disposition','expected_answer','ground_truth','scenario','case_type',
        'designed_condition','signals','critical_signal','retrieval_scope_needed',
        'should_find','answer_reason'
      ])
  ),
  'runtime has no prohibited answer-bearing columns'
);
select pg_temp.assert_true(
  not has_table_privilege('anon', 'public.manufacturing_lots', 'select')
    and not has_function_privilege('anon', 'public.get_lot_record(text,text)', 'execute'),
  'anon cannot select runtime tables or execute tools'
);
select pg_temp.assert_true(
  not has_schema_privilege('authenticated', 'private_eval', 'usage')
    and not has_table_privilege('authenticated', 'private_eval.case_expectations', 'select'),
  'authenticated cannot use or read evaluator truth'
);
select pg_temp.assert_true(
  (
    select count(*) = 15
    from pg_class as relation
    join pg_namespace as namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = any(array[
        'dataset_snapshots','organizations','sites','suppliers','parts','equipment',
        'manufacturing_lots','inspections','certificates_of_analysis','calibration_records',
        'engineering_revisions','supplier_quality_events','deviations','manufacturing_notes',
        'decision_profiles'
      ])
      and relation.relrowsecurity
      and relation.relforcerowsecurity
  ),
  'all 15 runtime tables have forced RLS'
);
select pg_temp.assert_true(
  (
    select count(*) = 7
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname = any(array[
        'get_decision_profile','get_lot_record','get_supplier_quality_history',
        'get_equipment_calibration','get_released_part_revision',
        'get_open_deviations','search_manufacturing_notes'
      ])
      and not function.prosecdef
  ),
  'all seven public tools are security invoker'
);
select pg_temp.assert_true(
  (select count(*) = 1 from pg_indexes where schemaname = 'public' and tablename = 'manufacturing_notes' and indexdef like '%USING gin (fts)%'),
  'manufacturing notes have an FTS GIN index'
);
select pg_temp.assert_true(
  (select record_manifest_hash = '4a69bc05efbb8e72d2f0e98d3417324f49c9be3c98ef42818c73efeff1a8a3d9' from public.dataset_snapshots where snapshot_id = 'hx-mfg-v1-snapshot-001'),
  'snapshot manifest is deterministic'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"app_metadata":{"tenant_id":"HX-TENANT-ALPHA","scopes":["quality","general"]},"user_metadata":{"tenant_id":"HX-TENANT-BETA","scopes":["restricted_hr"]}}';

select pg_temp.assert_true(
  (select count(*) = 15 from public.manufacturing_lots)
    and (select count(*) = 2 from public.manufacturing_notes),
  'alpha app_metadata sees 15 lots and two authorized notes'
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_lot_record('HX-V2-LOT-014', 'hx-mfg-v1-snapshot-001')->'items') = 3
    and public.get_lot_record('HX-V2-LOT-014', 'hx-mfg-v1-snapshot-001')::text not like '%BETA%',
  'alpha case 14 direct lookup has no beta leakage'
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_supplier_quality_history(
    'HX-V2-LOT-011','HX-V2-SUP-011','HX-V2-PART-011',
    '2026-08-01T12:00:00Z',90,20,'hx-mfg-v1-snapshot-001'
  )->'items') = 0
    and (public.get_supplier_quality_history(
      'HX-V2-LOT-011','HX-V2-SUP-011','HX-V2-PART-011',
      '2026-08-01T12:00:00Z',90,20,'hx-mfg-v1-snapshot-001'
    )->>'ok')::boolean,
  'missing supplier history is a successful zero result'
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_supplier_quality_history(
    'HX-V2-LOT-012','HX-V2-SUP-012','HX-V2-PART-012',
    '2026-08-01T12:00:00Z',90,20,'hx-mfg-v1-snapshot-001'
  )->'items') = 0,
  'stale supplier history falls outside the pinned window'
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_open_deviations(
    'HX-V2-LOT-007',array['part','supplier','equipment'],
    '2026-08-01T12:00:00Z',2,20,'hx-mfg-v1-snapshot-001'
  )->'items') = 1
    and jsonb_array_length(public.get_open_deviations(
      'HX-V2-LOT-008',array['part','supplier','equipment'],
      '2026-08-01T12:00:00Z',2,20,'hx-mfg-v1-snapshot-001'
    )->'items') = 0,
  'open and closed deviation checks remain distinct'
);
select pg_temp.assert_true(
  jsonb_array_length(public.search_manufacturing_notes(
    'HX-V2-LOT-009',array['HX-V2-LOT-009','HX-V2-PART-009','HX-V2-EQP-009'],
    'inspection damage defect deviation exception seal',
    '2026-08-01T12:00:00Z',10,'hx-mfg-v1-snapshot-001'
  )->'items') = 1
    and jsonb_array_length(public.search_manufacturing_notes(
      'HX-V2-LOT-015',array['HX-V2-LOT-015','HX-V2-PART-015','HX-V2-EQP-015'],
      'inspection damage defect deviation exception fracture',
      '2026-08-01T12:00:00Z',10,'hx-mfg-v1-snapshot-001'
    )->'items') = 1,
  'authorized conflict and prompt-injection notes are searchable as evidence'
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_released_part_revision(
    'HX-V2-LOT-010','HX-V2-PART-010','2026-08-01T12:00:00Z','hx-mfg-v1-snapshot-001'
  )->'items') = 2,
  'case 10 preserves both active released revisions'
);
select pg_temp.assert_true(
  (select count(*) = 0 from public.manufacturing_notes where note_id = 'HX-V2-NOTE-013'),
  'case 13 restricted note is invisible to quality/general'
);
select pg_temp.assert_true(
  public.get_equipment_calibration(
    'HX-V2-LOT-001','HX-V2-EQP-001','2026-08-02T12:00:00Z','hx-mfg-v1-snapshot-001'
  )->'errors'->0->>'code' = 'SNAPSHOT_MISMATCH',
  'mismatched time is an explicit error rather than missing evidence'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"app_metadata":{"tenant_id":"HX-TENANT-ALPHA","scopes":["quality","general","restricted_hr"]}}';
select pg_temp.assert_true(
  (select count(*) = 3 from public.manufacturing_notes),
  'restricted scope reveals the third alpha note'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"app_metadata":{"tenant_id":"HX-TENANT-BETA","scopes":["quality","general"]}}';
select pg_temp.assert_true(
  (select count(*) = 1 from public.manufacturing_lots)
    and (select count(*) = 1 from public.inspections where result = 'FAILED' and critical_defect_count = 2),
  'beta sees only its failing shadow lot'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"app_metadata":{"tenant_id":"HX-TENANT-ALPHA","scopes":["quality"]}}';
select pg_temp.assert_true(
  (select count(*) = 0 from public.manufacturing_notes),
  'quality-only scope cannot read general or restricted notes'
);

reset role;
select 'ok 1 - dataset v1 structural, RLS, search and tool assertions';
rollback;
