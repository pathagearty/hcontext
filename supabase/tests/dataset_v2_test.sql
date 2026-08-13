begin;

create or replace function pg_temp.assert_true(p_condition boolean, p_label text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'dataset_v2 assertion failed: %', p_label;
  end if;
end;
$$;
grant execute on function pg_temp.assert_true(boolean, text) to public;

select '1..1';
set local role service_role;

select pg_temp.assert_true(
  (select count(*) = 1 from public.dataset_snapshots where snapshot_id = 'hx-mfg-v2-snapshot-001'),
  'the immutable v2 snapshot is seeded'
);
select pg_temp.assert_true(
  (select record_manifest_hash = private_app.compute_runtime_snapshot_manifest(snapshot_id)
    from public.dataset_snapshots where snapshot_id = 'hx-mfg-v2-snapshot-001'),
  'the v2 manifest hashes the complete runtime snapshot'
);
select pg_temp.assert_true(
  (select count(*) = 2000 from public.manufacturing_lots where snapshot_id = 'hx-mfg-v2-snapshot-001')
    and (select count(*) = 1200 from public.manufacturing_lots where tenant_id = 'tenant-alpha' and snapshot_id = 'hx-mfg-v2-snapshot-001'),
  'v2 contains two thousand background lots and twelve hundred Alpha lots'
);
select pg_temp.assert_true(
  (
    select sum(row_count) = 40295
    from (
      select count(*) row_count from public.dataset_snapshots where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.organizations where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.sites where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.suppliers where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.parts where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.equipment where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.manufacturing_lots where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.inspections where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.certificates_of_analysis where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.calibration_records where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.engineering_revisions where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.supplier_quality_events where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.deviations where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.manufacturing_notes where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.decision_profiles where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.work_orders where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.manufacturing_operations where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.equipment_usage where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.material_batches where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.material_certificates where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.bills_of_material where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.component_lot_usage where snapshot_id = 'hx-mfg-v2-snapshot-001' union all
      select count(*) from public.engineering_change_orders where snapshot_id = 'hx-mfg-v2-snapshot-001'
    ) counts
  ),
  'v2 runtime has 40,295 deterministic normalized rows'
);
select pg_temp.assert_true(
  (select count(*) = 50 from private_eval.case_expectations where snapshot_id = 'hx-mfg-v2-snapshot-001')
    and (select count(*) = 8 from private_eval.case_expectations where snapshot_id = 'hx-mfg-v2-snapshot-001' and expected_disposition = 'PASS')
    and (select count(*) = 16 from private_eval.case_expectations where snapshot_id = 'hx-mfg-v2-snapshot-001' and expected_disposition = 'HOLD')
    and (select count(*) = 26 from private_eval.case_expectations where snapshot_id = 'hx-mfg-v2-snapshot-001' and expected_disposition = 'ESCALATE'),
  'all 50 cases have approved private expected results'
);
select pg_temp.assert_true(
  (select count(*) = 8 from pg_class relation join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = any(array[
        'work_orders','manufacturing_operations','equipment_usage','material_batches',
        'material_certificates','bills_of_material','component_lot_usage','engineering_change_orders'
      ]) and relation.relrowsecurity and relation.relforcerowsecurity),
  'all eight v2 context tables have forced RLS'
);
select pg_temp.assert_true(
  (select count(*) = 8 from pg_proc function join pg_namespace namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname = any(array[
        'get_lot_work_orders','get_work_order_operations','get_operation_equipment_usage',
        'get_connected_equipment_calibration','get_part_bom','get_lot_component_usage',
        'get_material_batch_records','get_engineering_change_orders'
      ]) and not function.prosecdef),
  'all eight v2 runtime tools are security invoker'
);
select pg_temp.assert_true(
  not has_schema_privilege('authenticated', 'private_eval', 'usage')
    and not has_table_privilege('authenticated', 'private_eval.case_expectations', 'select')
    and not has_table_privilege('authenticated', 'private_eval.evaluation_runs', 'select')
    and not has_function_privilege('authenticated', 'public.get_private_case_evaluation(text,text)', 'execute'),
  'runtime actors cannot read answer keys, scores, run artifacts or private RPCs'
);
select pg_temp.assert_true(
  public.get_private_case_evaluation('lot-alpha-0017', 'hx-mfg-v2-snapshot-001')->>'expected_disposition' = 'HOLD'
    and jsonb_array_length(public.get_private_case_evaluation('lot-alpha-0017', 'hx-mfg-v2-snapshot-001')->'expected_evidence') > 6,
  'the service-role evaluator can retrieve the complete private rubric'
);
select public.store_private_evaluation_run(
  'dataset-v2-test-run', 'lot-alpha-0017', 'hx-mfg-v2-snapshot-001',
  'FOUNDRY_LIVE', repeat('a', 64),
  '2026-08-01T12:00:00Z', '2026-08-01T12:00:01Z',
  '{"baseline":"model-a","hexacontext":"model-a"}',
  '{"disposition":"PASS"}', '{"disposition":"HOLD"}',
  '[]', '[]', '{"baseline_correct":false,"hexacontext_correct":true}'
);
select pg_temp.assert_true(
  exists (
    select 1 from private_eval.evaluation_runs
    where comparison_run_id = 'dataset-v2-test-run'
      and review_status = 'DRAFT' and not approved_for_fine_tuning
  ),
  'trace artifacts enter the private ledger as draft and unapproved for fine-tuning'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"app_metadata":{"tenant_id":"tenant-alpha","scopes":["quality"]},"user_metadata":{"tenant_id":"tenant-beta","scopes":["quality","restricted_hr"]}}';

select pg_temp.assert_true(
  (select count(*) = 1200 from public.manufacturing_lots where snapshot_id = 'hx-mfg-v2-snapshot-001')
    and (select count(*) = 0 from public.manufacturing_lots where tenant_id = 'tenant-beta' and snapshot_id = 'hx-mfg-v2-snapshot-001'),
  'signed Alpha app_metadata sees only Alpha runtime rows'
);
select pg_temp.assert_true(
  (select count(*) = 0 from public.manufacturing_notes where snapshot_id = 'hx-mfg-v2-snapshot-001' and note_type = 'HR_NOTE'),
  'quality scope cannot read restricted HR distractors'
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_lot_work_orders('lot-alpha-0014', 'hx-mfg-v2-snapshot-001')->'items') = 1
    and jsonb_array_length(public.get_work_order_operations('lot-alpha-0014', 'wo-lot-alpha-0014', 'hx-mfg-v2-snapshot-001')->'items') = 3,
  'lot to work-order to operation traversal is bounded and complete'
);
select pg_temp.assert_true(
  public.get_operation_equipment_usage('lot-alpha-0014', 'op-lot-alpha-0014-10', 'hx-mfg-v2-snapshot-001')->'items'->0->'content'->>'equipment_id' = 'eq-alpha-064'
    and public.get_connected_equipment_calibration(
      'lot-alpha-0014','eq-alpha-064','2026-08-01T12:00:00Z','hx-mfg-v2-snapshot-001'
    )->'items'->0->'content'->>'calibration_status' = 'EXPIRED',
  'four-hop process-equipment calibration evidence is reachable'
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_part_bom(
    'lot-alpha-0017','part-alpha-017','2026-08-01T12:00:00Z','hx-mfg-v2-snapshot-001'
  )->'items') = 3
    and jsonb_array_length(public.get_lot_component_usage(
      'lot-alpha-0017','bom-part-alpha-017-a-1','hx-mfg-v2-snapshot-001'
    )->'items') = 1
    and public.get_material_batch_records(
      'lot-alpha-0017','mat-alpha-c077-b017','2026-08-01T12:00:00Z','hx-mfg-v2-snapshot-001'
    )->'items'->1->'content'->>'verification_status' = 'INVALID',
  'five-hop material genealogy reaches the invalid certificate'
);
select pg_temp.assert_true(
  (public.get_material_batch_records(
    'lot-alpha-0021','mat-alpha-c061-b021','2026-08-01T12:00:00Z','hx-mfg-v2-snapshot-001'
  )->>'ok')::boolean
    and jsonb_array_length(public.get_material_batch_records(
      'lot-alpha-0021','mat-alpha-c061-b021','2026-08-01T12:00:00Z','hx-mfg-v2-snapshot-001'
    )->'items') = 1
    and jsonb_array_length(public.get_lot_component_usage(
      'lot-alpha-0024','bom-part-alpha-024-a-1','hx-mfg-v2-snapshot-001'
    )->'items') = 0,
  'missing multi-hop records are successful zero/partial results, not source failures'
);
select pg_temp.assert_true(
  jsonb_array_length(public.get_engineering_change_orders(
    'lot-alpha-0026','part-alpha-026','2026-08-01T12:00:00Z','hx-mfg-v2-snapshot-001'
  )->'items') = 2
    and public.get_released_part_revision(
      'lot-alpha-0026','part-alpha-026','2026-08-01T12:00:00Z','hx-mfg-v2-snapshot-001'
    )->'items'->0->'content'->>'revision_code' = 'B',
  'temporal traversal exposes the implemented change and effective revision'
);
select pg_temp.assert_true(
  jsonb_array_length(public.search_manufacturing_notes(
    'lot-alpha-0048',array['lot-alpha-0048'],'fracture ignore policy',
    '2026-08-01T12:00:00Z',10,'hx-mfg-v2-snapshot-001'
  )->'items') = 1,
  'prompt injection remains untrusted source text while the real conflict is retrievable'
);
select pg_temp.assert_true(
  public.get_lot_record('lot-alpha-0050', 'hx-mfg-v2-snapshot-001')::text not like '%tenant-beta%'
    and (select count(*) = 1 from public.manufacturing_lots where lot_number = 'LOT-ALPHA-0050' and snapshot_id = 'hx-mfg-v2-snapshot-001'),
  'same-number cross-tenant shadow evidence cannot leak into Alpha'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"app_metadata":{"tenant_id":"tenant-beta","scopes":["quality"]}}';
select pg_temp.assert_true(
  (select count(*) = 1 from public.inspections where lot_id = 'lot-beta-0050'
    and result = 'FAILED' and critical_defect_count = 3
    and snapshot_id = 'hx-mfg-v2-snapshot-001'),
  'Beta can see its own failing same-number shadow record'
);

reset role;
select 'ok 1 - dataset v2 scale, hidden evaluator, RLS and multi-hop tools';
rollback;
