-- Deterministically hash every ordinary runtime source record in a snapshot.
-- Answer keys and run traces are intentionally excluded from this manifest.

create or replace function private_app.compute_runtime_snapshot_manifest(
  p_snapshot_id text
)
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  with records(table_name, tenant_id, source_system, source_record_id, content_hash) as (
    select 'organizations', tenant_id, source_system, source_record_id, content_hash
      from public.organizations where snapshot_id = p_snapshot_id
    union all select 'sites', tenant_id, source_system, source_record_id, content_hash
      from public.sites where snapshot_id = p_snapshot_id
    union all select 'suppliers', tenant_id, source_system, source_record_id, content_hash
      from public.suppliers where snapshot_id = p_snapshot_id
    union all select 'parts', tenant_id, source_system, source_record_id, content_hash
      from public.parts where snapshot_id = p_snapshot_id
    union all select 'equipment', tenant_id, source_system, source_record_id, content_hash
      from public.equipment where snapshot_id = p_snapshot_id
    union all select 'manufacturing_lots', tenant_id, source_system, source_record_id, content_hash
      from public.manufacturing_lots where snapshot_id = p_snapshot_id
    union all select 'inspections', tenant_id, source_system, source_record_id, content_hash
      from public.inspections where snapshot_id = p_snapshot_id
    union all select 'certificates_of_analysis', tenant_id, source_system, source_record_id, content_hash
      from public.certificates_of_analysis where snapshot_id = p_snapshot_id
    union all select 'calibration_records', tenant_id, source_system, source_record_id, content_hash
      from public.calibration_records where snapshot_id = p_snapshot_id
    union all select 'engineering_revisions', tenant_id, source_system, source_record_id, content_hash
      from public.engineering_revisions where snapshot_id = p_snapshot_id
    union all select 'supplier_quality_events', tenant_id, source_system, source_record_id, content_hash
      from public.supplier_quality_events where snapshot_id = p_snapshot_id
    union all select 'deviations', tenant_id, source_system, source_record_id, content_hash
      from public.deviations where snapshot_id = p_snapshot_id
    union all select 'manufacturing_notes', tenant_id, source_system, source_record_id, content_hash
      from public.manufacturing_notes where snapshot_id = p_snapshot_id
    union all select 'decision_profiles', tenant_id, source_system, source_record_id, content_hash
      from public.decision_profiles where snapshot_id = p_snapshot_id
    union all select 'work_orders', tenant_id, source_system, source_record_id, content_hash
      from public.work_orders where snapshot_id = p_snapshot_id
    union all select 'manufacturing_operations', tenant_id, source_system, source_record_id, content_hash
      from public.manufacturing_operations where snapshot_id = p_snapshot_id
    union all select 'equipment_usage', tenant_id, source_system, source_record_id, content_hash
      from public.equipment_usage where snapshot_id = p_snapshot_id
    union all select 'material_batches', tenant_id, source_system, source_record_id, content_hash
      from public.material_batches where snapshot_id = p_snapshot_id
    union all select 'material_certificates', tenant_id, source_system, source_record_id, content_hash
      from public.material_certificates where snapshot_id = p_snapshot_id
    union all select 'bills_of_material', tenant_id, source_system, source_record_id, content_hash
      from public.bills_of_material where snapshot_id = p_snapshot_id
    union all select 'component_lot_usage', tenant_id, source_system, source_record_id, content_hash
      from public.component_lot_usage where snapshot_id = p_snapshot_id
    union all select 'engineering_change_orders', tenant_id, source_system, source_record_id, content_hash
      from public.engineering_change_orders where snapshot_id = p_snapshot_id
  ), canonical as (
    select string_agg(
      concat_ws(':', table_name, tenant_id, source_system, source_record_id, content_hash),
      E'\n' order by table_name, tenant_id, source_system, source_record_id, content_hash
    ) as value
    from records
  )
  select encode(sha256(convert_to(coalesce(value, ''), 'UTF8')), 'hex')
  from canonical;
$$;

revoke all on function private_app.compute_runtime_snapshot_manifest(text)
  from public, anon, authenticated;
grant execute on function private_app.compute_runtime_snapshot_manifest(text)
  to service_role;
