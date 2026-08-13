-- RLS, grants, and indexes for the v2 context graph.

-- New runtime tables inherit no application privileges. Grant only SELECT and
-- enforce the same signed app_metadata tenant/scope policy used by v1.
grant select on table
  public.work_orders,
  public.manufacturing_operations,
  public.equipment_usage,
  public.material_batches,
  public.material_certificates,
  public.bills_of_material,
  public.component_lot_usage,
  public.engineering_change_orders
to authenticated, service_role;

do $migration$
declare
  table_name text;
begin
  foreach table_name in array array[
    'work_orders',
    'manufacturing_operations',
    'equipment_usage',
    'material_batches',
    'material_certificates',
    'bills_of_material',
    'component_lot_usage',
    'engineering_change_orders'
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

-- Access-path indexes lead with tenant and immutable snapshot because every
-- authorized query carries both predicates. Each foreign-key relationship used
-- by a tool has a matching index.
create index work_orders_lot_idx
  on public.work_orders (tenant_id, snapshot_id, lot_id, scheduled_start desc);
create index work_orders_site_fk_idx
  on public.work_orders (tenant_id, site_id, snapshot_id);

create index manufacturing_operations_work_order_idx
  on public.manufacturing_operations
  (tenant_id, snapshot_id, work_order_id, operation_sequence);
create index manufacturing_operations_site_fk_idx
  on public.manufacturing_operations (tenant_id, site_id, snapshot_id);

create index equipment_usage_operation_idx
  on public.equipment_usage (tenant_id, snapshot_id, operation_id, equipment_id);
create index equipment_usage_equipment_fk_idx
  on public.equipment_usage (tenant_id, equipment_id, snapshot_id);
create index equipment_usage_site_fk_idx
  on public.equipment_usage (tenant_id, site_id, snapshot_id);

create index material_batches_component_idx
  on public.material_batches
  (tenant_id, snapshot_id, component_part_id, received_at desc);
create index material_batches_supplier_fk_idx
  on public.material_batches (tenant_id, supplier_id, snapshot_id);
create index material_batches_site_fk_idx
  on public.material_batches (tenant_id, site_id, snapshot_id);

create index material_certificates_batch_idx
  on public.material_certificates (tenant_id, snapshot_id, material_batch_id);
create index material_certificates_site_fk_idx
  on public.material_certificates (tenant_id, site_id, snapshot_id);

create index bills_of_material_parent_active_idx
  on public.bills_of_material
  (tenant_id, snapshot_id, parent_part_id, parent_revision_code, line_number)
  where effective_to is null;
create index bills_of_material_component_fk_idx
  on public.bills_of_material (tenant_id, component_part_id, snapshot_id);
create index bills_of_material_site_fk_idx
  on public.bills_of_material (tenant_id, site_id, snapshot_id);

create index component_lot_usage_lot_idx
  on public.component_lot_usage
  (tenant_id, snapshot_id, lot_id, consumed_at desc);
create index component_lot_usage_bom_fk_idx
  on public.component_lot_usage (tenant_id, bom_item_id, snapshot_id);
create index component_lot_usage_batch_fk_idx
  on public.component_lot_usage (tenant_id, material_batch_id, snapshot_id);
create index component_lot_usage_site_fk_idx
  on public.component_lot_usage (tenant_id, site_id, snapshot_id);

create index engineering_change_orders_part_idx
  on public.engineering_change_orders
  (tenant_id, snapshot_id, part_id, implementation_effective_at desc);
create index engineering_change_orders_site_fk_idx
  on public.engineering_change_orders (tenant_id, site_id, snapshot_id);
