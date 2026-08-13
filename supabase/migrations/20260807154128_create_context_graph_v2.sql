-- HexaContext manufacturing context graph v2.
-- These normalized records create realistic multi-hop evidence paths while
-- preserving the immutable v1 snapshot. Runtime rows never contain answer keys.

create table public.work_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  site_id text not null,
  work_order_id text not null,
  work_order_number text not null,
  lot_id text not null,
  planned_quantity integer not null check (planned_quantity > 0),
  priority text not null check (priority in ('STANDARD', 'EXPEDITE', 'CRITICAL')),
  scheduled_start timestamptz not null,
  scheduled_end timestamptz not null,
  completed_at timestamptz,
  status text not null check (status in ('PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  source_system text not null,
  source_record_id text not null,
  source_version text not null,
  authority text not null,
  observed_at timestamptz not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  required_scopes text[] not null default array['quality']::text[],
  content_hash text not null,
  created_at timestamptz not null default now(),
  check (scheduled_end > scheduled_start),
  check (completed_at is null or completed_at >= scheduled_start),
  check (effective_to is null or effective_to > effective_from),
  check (cardinality(required_scopes) > 0),
  check (content_hash ~ '^[0-9a-f]{64}$'),
  unique (tenant_id, work_order_id, snapshot_id),
  unique (tenant_id, work_order_number, snapshot_id),
  unique (tenant_id, snapshot_id, source_system, source_record_id),
  foreign key (tenant_id, lot_id, snapshot_id)
    references public.manufacturing_lots(tenant_id, lot_id, snapshot_id),
  foreign key (tenant_id, site_id, snapshot_id)
    references public.sites(tenant_id, site_id, snapshot_id)
);

create table public.manufacturing_operations (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  site_id text not null,
  operation_id text not null,
  work_order_id text not null,
  operation_sequence integer not null check (operation_sequence > 0),
  operation_code text not null,
  operation_name text not null,
  specification_code text not null,
  recorded_value numeric(12,4),
  lower_limit numeric(12,4),
  upper_limit numeric(12,4),
  unit text,
  result text not null check (result in ('PASS', 'FAIL', 'NOT_MEASURED')),
  started_at timestamptz not null,
  completed_at timestamptz not null,
  operator_alias text not null,
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  source_system text not null,
  source_record_id text not null,
  source_version text not null,
  authority text not null,
  observed_at timestamptz not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  required_scopes text[] not null default array['quality']::text[],
  content_hash text not null,
  created_at timestamptz not null default now(),
  check (completed_at >= started_at),
  check (lower_limit is null or upper_limit is null or upper_limit >= lower_limit),
  check (effective_to is null or effective_to > effective_from),
  check (cardinality(required_scopes) > 0),
  check (content_hash ~ '^[0-9a-f]{64}$'),
  unique (tenant_id, operation_id, snapshot_id),
  unique (tenant_id, work_order_id, operation_sequence, snapshot_id),
  unique (tenant_id, snapshot_id, source_system, source_record_id),
  foreign key (tenant_id, work_order_id, snapshot_id)
    references public.work_orders(tenant_id, work_order_id, snapshot_id),
  foreign key (tenant_id, site_id, snapshot_id)
    references public.sites(tenant_id, site_id, snapshot_id)
);

create table public.equipment_usage (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  site_id text not null,
  usage_id text not null,
  operation_id text not null,
  equipment_id text not null,
  usage_role text not null check (usage_role in ('PROCESS', 'MEASUREMENT', 'MONITORING')),
  setup_verified boolean not null,
  used_from timestamptz not null,
  used_to timestamptz not null,
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  source_system text not null,
  source_record_id text not null,
  source_version text not null,
  authority text not null,
  observed_at timestamptz not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  required_scopes text[] not null default array['quality']::text[],
  content_hash text not null,
  created_at timestamptz not null default now(),
  check (used_to >= used_from),
  check (effective_to is null or effective_to > effective_from),
  check (cardinality(required_scopes) > 0),
  check (content_hash ~ '^[0-9a-f]{64}$'),
  unique (tenant_id, usage_id, snapshot_id),
  unique (tenant_id, operation_id, equipment_id, snapshot_id),
  unique (tenant_id, snapshot_id, source_system, source_record_id),
  foreign key (tenant_id, operation_id, snapshot_id)
    references public.manufacturing_operations(tenant_id, operation_id, snapshot_id),
  foreign key (tenant_id, equipment_id, snapshot_id)
    references public.equipment(tenant_id, equipment_id, snapshot_id),
  foreign key (tenant_id, site_id, snapshot_id)
    references public.sites(tenant_id, site_id, snapshot_id)
);

create table public.material_batches (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  site_id text not null,
  material_batch_id text not null,
  material_batch_number text not null,
  component_part_id text not null,
  supplier_id text not null,
  received_at timestamptz not null,
  expires_at timestamptz not null,
  inventory_status text not null check (inventory_status in ('RELEASED', 'QUARANTINED', 'EXPIRED', 'CONSUMED')),
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  source_system text not null,
  source_record_id text not null,
  source_version text not null,
  authority text not null,
  observed_at timestamptz not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  required_scopes text[] not null default array['quality']::text[],
  content_hash text not null,
  created_at timestamptz not null default now(),
  check (expires_at > received_at),
  check (effective_to is null or effective_to > effective_from),
  check (cardinality(required_scopes) > 0),
  check (content_hash ~ '^[0-9a-f]{64}$'),
  unique (tenant_id, material_batch_id, snapshot_id),
  unique (tenant_id, material_batch_number, snapshot_id),
  unique (tenant_id, snapshot_id, source_system, source_record_id),
  foreign key (tenant_id, component_part_id, snapshot_id)
    references public.parts(tenant_id, part_id, snapshot_id),
  foreign key (tenant_id, supplier_id, snapshot_id)
    references public.suppliers(tenant_id, supplier_id, snapshot_id),
  foreign key (tenant_id, site_id, snapshot_id)
    references public.sites(tenant_id, site_id, snapshot_id)
);

create table public.material_certificates (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  site_id text not null,
  material_certificate_id text not null,
  material_batch_id text not null,
  certificate_number text not null,
  verification_status text not null check (verification_status in ('VERIFIED', 'UNVERIFIED', 'INVALID')),
  specification_code text not null,
  measured_value numeric(12,4) not null,
  lower_limit numeric(12,4) not null,
  upper_limit numeric(12,4) not null,
  unit text not null,
  issued_at timestamptz not null,
  verified_at timestamptz,
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  source_system text not null,
  source_record_id text not null,
  source_version text not null,
  authority text not null,
  observed_at timestamptz not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  required_scopes text[] not null default array['quality']::text[],
  content_hash text not null,
  created_at timestamptz not null default now(),
  check (upper_limit >= lower_limit),
  check (effective_to is null or effective_to > effective_from),
  check (cardinality(required_scopes) > 0),
  check (content_hash ~ '^[0-9a-f]{64}$'),
  unique (tenant_id, material_certificate_id, snapshot_id),
  unique (tenant_id, material_batch_id, snapshot_id),
  unique (tenant_id, snapshot_id, source_system, source_record_id),
  foreign key (tenant_id, material_batch_id, snapshot_id)
    references public.material_batches(tenant_id, material_batch_id, snapshot_id),
  foreign key (tenant_id, site_id, snapshot_id)
    references public.sites(tenant_id, site_id, snapshot_id)
);

create table public.bills_of_material (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  site_id text not null,
  bom_item_id text not null,
  parent_part_id text not null,
  parent_revision_code text not null,
  component_part_id text not null,
  line_number integer not null check (line_number > 0),
  quantity_per numeric(12,4) not null check (quantity_per > 0),
  unit text not null,
  is_critical_component boolean not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  source_system text not null,
  source_record_id text not null,
  source_version text not null,
  authority text not null,
  observed_at timestamptz not null,
  required_scopes text[] not null default array['quality']::text[],
  content_hash text not null,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from),
  check (cardinality(required_scopes) > 0),
  check (content_hash ~ '^[0-9a-f]{64}$'),
  check (parent_part_id <> component_part_id),
  unique (tenant_id, bom_item_id, snapshot_id),
  unique (tenant_id, parent_part_id, parent_revision_code, line_number, snapshot_id),
  unique (tenant_id, snapshot_id, source_system, source_record_id),
  foreign key (tenant_id, parent_part_id, snapshot_id)
    references public.parts(tenant_id, part_id, snapshot_id),
  foreign key (tenant_id, component_part_id, snapshot_id)
    references public.parts(tenant_id, part_id, snapshot_id),
  foreign key (tenant_id, site_id, snapshot_id)
    references public.sites(tenant_id, site_id, snapshot_id)
);

create table public.component_lot_usage (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  site_id text not null,
  component_usage_id text not null,
  lot_id text not null,
  bom_item_id text not null,
  material_batch_id text not null,
  quantity_consumed numeric(12,4) not null check (quantity_consumed > 0),
  consumed_at timestamptz not null,
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  source_system text not null,
  source_record_id text not null,
  source_version text not null,
  authority text not null,
  observed_at timestamptz not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  required_scopes text[] not null default array['quality']::text[],
  content_hash text not null,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from),
  check (cardinality(required_scopes) > 0),
  check (content_hash ~ '^[0-9a-f]{64}$'),
  unique (tenant_id, component_usage_id, snapshot_id),
  unique (tenant_id, lot_id, bom_item_id, snapshot_id),
  unique (tenant_id, snapshot_id, source_system, source_record_id),
  foreign key (tenant_id, lot_id, snapshot_id)
    references public.manufacturing_lots(tenant_id, lot_id, snapshot_id),
  foreign key (tenant_id, bom_item_id, snapshot_id)
    references public.bills_of_material(tenant_id, bom_item_id, snapshot_id),
  foreign key (tenant_id, material_batch_id, snapshot_id)
    references public.material_batches(tenant_id, material_batch_id, snapshot_id),
  foreign key (tenant_id, site_id, snapshot_id)
    references public.sites(tenant_id, site_id, snapshot_id)
);

create table public.engineering_change_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  site_id text not null,
  change_order_id text not null,
  part_id text not null,
  from_revision_code text not null,
  to_revision_code text not null,
  change_type text not null check (change_type in ('DESIGN', 'PROCESS', 'MATERIAL', 'DOCUMENTATION')),
  status text not null check (status in ('DRAFT', 'APPROVED', 'IMPLEMENTED', 'CANCELLED')),
  reason text not null,
  approved_at timestamptz,
  implementation_effective_at timestamptz,
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  source_system text not null,
  source_record_id text not null,
  source_version text not null,
  authority text not null,
  observed_at timestamptz not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  required_scopes text[] not null default array['quality']::text[],
  content_hash text not null,
  created_at timestamptz not null default now(),
  check (from_revision_code <> to_revision_code),
  check (effective_to is null or effective_to > effective_from),
  check (cardinality(required_scopes) > 0),
  check (content_hash ~ '^[0-9a-f]{64}$'),
  unique (tenant_id, change_order_id, snapshot_id),
  unique (tenant_id, snapshot_id, source_system, source_record_id),
  foreign key (tenant_id, part_id, snapshot_id)
    references public.parts(tenant_id, part_id, snapshot_id),
  foreign key (tenant_id, site_id, snapshot_id)
    references public.sites(tenant_id, site_id, snapshot_id)
);

-- Evaluation metadata describes difficulty and required traversal without ever
-- entering an API-exposed schema.
alter table private_eval.case_expectations
  add column difficulty_tier text not null default 'CONTROL'
    check (difficulty_tier in ('CONTROL', 'MULTI_HOP', 'TEMPORAL', 'CONFLICT', 'AUTHORIZATION')),
  add column minimum_hops smallint not null default 0 check (minimum_hops between 0 and 8),
  add column expected_tool_sequence text[] not null default '{}'::text[],
  add column counterfactual_group_id text,
  add column expected_relationship_paths jsonb not null default '[]'::jsonb
    check (jsonb_typeof(expected_relationship_paths) = 'array');

alter table private_eval.expected_evidence
  add column retrieval_hop smallint not null default 0 check (retrieval_hop between 0 and 8),
  add column relationship_path text[] not null default '{}'::text[];
