-- Runtime authorization is database-enforced. Tenant and scopes come only from
-- signed Auth app_metadata claims; callers cannot provide them as tool arguments.

create schema if not exists private_app;
revoke all on schema private_app from public, anon;

create or replace function private_app.request_tenant_id()
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select nullif(auth.jwt() -> 'app_metadata' ->> 'tenant_id', '');
$$;

create or replace function private_app.request_scopes()
returns text[]
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(
    array(
      select jsonb_array_elements_text(
        coalesce(auth.jwt() -> 'app_metadata' -> 'scopes', '[]'::jsonb)
      )
    ),
    '{}'::text[]
  );
$$;

revoke all on function private_app.request_tenant_id() from public, anon;
revoke all on function private_app.request_scopes() from public, anon;
grant usage on schema private_app to authenticated, service_role;
grant execute on function private_app.request_tenant_id() to authenticated, service_role;
grant execute on function private_app.request_scopes() to authenticated, service_role;

-- Remove Supabase's broad default grants. The runtime is read-only for
-- authenticated actors; no INSERT/UPDATE/DELETE policy or grant is created.
revoke all on all tables in schema public from public, anon, authenticated;
grant select on table
  public.dataset_snapshots,
  public.organizations,
  public.sites,
  public.suppliers,
  public.parts,
  public.equipment,
  public.manufacturing_lots,
  public.inspections,
  public.certificates_of_analysis,
  public.calibration_records,
  public.engineering_revisions,
  public.supplier_quality_events,
  public.deviations,
  public.manufacturing_notes,
  public.decision_profiles
to authenticated, service_role;

alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

alter table public.dataset_snapshots enable row level security;
alter table public.dataset_snapshots force row level security;

do $migration$
declare
  table_name text;
begin
  foreach table_name in array array[
    'organizations',
    'sites',
    'suppliers',
    'parts',
    'equipment',
    'manufacturing_lots',
    'inspections',
    'certificates_of_analysis',
    'calibration_records',
    'engineering_revisions',
    'supplier_quality_events',
    'deviations',
    'manufacturing_notes',
    'decision_profiles'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format(
      'create policy tenant_scope_read on public.%I for select to authenticated using (' ||
      'tenant_id = (select private_app.request_tenant_id()) and ' ||
      'required_scopes <@ (select private_app.request_scopes())' ||
      ')',
      table_name
    );
  end loop;
end
$migration$;

create policy tenant_snapshot_read
on public.dataset_snapshots
for select
to authenticated
using (
  exists (
    select 1
    from public.organizations as organization
    where organization.snapshot_id = dataset_snapshots.snapshot_id
      and organization.tenant_id = (select private_app.request_tenant_id())
      and organization.required_scopes <@ (select private_app.request_scopes())
  )
);

-- Tenant/snapshot predicates lead the indexes because they are present on every
-- authorized query. The remaining columns match the narrow tool access paths.
create index organizations_scope_idx
  on public.organizations (tenant_id, snapshot_id) include (required_scopes);
create index sites_scope_idx
  on public.sites (tenant_id, snapshot_id, site_id) include (required_scopes);
create index suppliers_scope_idx
  on public.suppliers (tenant_id, snapshot_id, supplier_id) include (required_scopes);
create index suppliers_site_fk_idx
  on public.suppliers (tenant_id, site_id, snapshot_id);
create index parts_scope_idx
  on public.parts (tenant_id, snapshot_id, part_id) include (required_scopes);
create index parts_site_fk_idx
  on public.parts (tenant_id, site_id, snapshot_id);
create index equipment_scope_idx
  on public.equipment (tenant_id, snapshot_id, equipment_id) include (required_scopes);
create index equipment_site_fk_idx
  on public.equipment (tenant_id, site_id, snapshot_id);

create index manufacturing_lots_lookup_idx
  on public.manufacturing_lots (tenant_id, snapshot_id, lot_number);
create index manufacturing_lots_part_fk_idx
  on public.manufacturing_lots (tenant_id, part_id, snapshot_id);
create index manufacturing_lots_supplier_fk_idx
  on public.manufacturing_lots (tenant_id, supplier_id, snapshot_id);
create index manufacturing_lots_equipment_fk_idx
  on public.manufacturing_lots (tenant_id, inspection_equipment_id, snapshot_id);
create index manufacturing_lots_site_fk_idx
  on public.manufacturing_lots (tenant_id, site_id, snapshot_id);

create index inspections_lot_idx
  on public.inspections (tenant_id, snapshot_id, lot_id, completed_at desc);
create index inspections_site_fk_idx
  on public.inspections (tenant_id, site_id, snapshot_id);
create index certificates_lot_idx
  on public.certificates_of_analysis (tenant_id, snapshot_id, lot_id, issued_at desc);
create index certificates_site_fk_idx
  on public.certificates_of_analysis (tenant_id, site_id, snapshot_id);
create index calibration_equipment_idx
  on public.calibration_records (tenant_id, snapshot_id, equipment_id, valid_until desc);
create index calibration_site_fk_idx
  on public.calibration_records (tenant_id, site_id, snapshot_id);
create index engineering_revisions_part_active_idx
  on public.engineering_revisions
  (tenant_id, snapshot_id, part_id, effective_from, effective_to)
  where release_status = 'RELEASED';
create index engineering_revisions_site_fk_idx
  on public.engineering_revisions (tenant_id, site_id, snapshot_id);
create index supplier_quality_history_idx
  on public.supplier_quality_events
  (tenant_id, snapshot_id, supplier_id, part_id, event_at desc, source_record_id);
create index supplier_quality_events_site_fk_idx
  on public.supplier_quality_events (tenant_id, site_id, snapshot_id);

create index deviations_lot_open_idx
  on public.deviations (tenant_id, snapshot_id, lot_id, opened_at desc)
  where status = 'OPEN';
create index deviations_part_open_idx
  on public.deviations (tenant_id, snapshot_id, part_id, opened_at desc)
  where status = 'OPEN';
create index deviations_supplier_open_idx
  on public.deviations (tenant_id, snapshot_id, supplier_id, opened_at desc)
  where status = 'OPEN';
create index deviations_equipment_open_idx
  on public.deviations (tenant_id, snapshot_id, equipment_id, opened_at desc)
  where status = 'OPEN';
create index deviations_site_fk_idx
  on public.deviations (tenant_id, site_id, snapshot_id);

create index manufacturing_notes_fts_idx
  on public.manufacturing_notes using gin (fts);
create index manufacturing_notes_lot_idx
  on public.manufacturing_notes (tenant_id, snapshot_id, lot_id, signed_at desc);
create index manufacturing_notes_part_idx
  on public.manufacturing_notes (tenant_id, snapshot_id, part_id, signed_at desc);
create index manufacturing_notes_equipment_idx
  on public.manufacturing_notes (tenant_id, snapshot_id, equipment_id, signed_at desc);
create index manufacturing_notes_site_fk_idx
  on public.manufacturing_notes (tenant_id, site_id, snapshot_id);
create index decision_profiles_lookup_idx
  on public.decision_profiles
  (tenant_id, snapshot_id, profile_id, profile_version, active_from, active_to);
create index decision_profiles_site_fk_idx
  on public.decision_profiles (tenant_id, site_id, snapshot_id);
