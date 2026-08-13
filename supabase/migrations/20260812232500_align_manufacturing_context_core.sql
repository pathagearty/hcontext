-- Align the bounded manufacturing PoC with the approved HexaContext direction.
--
-- Existing normalized manufacturing tables remain the canonical fact layer. This
-- migration adds an inspectable registry for the persistent shared Context Core,
-- reusable Decision Profiles, case-specific Decision Packets, packet provenance,
-- update events, and the corrected three-role experiment. It intentionally does
-- not add a second copy of every manufacturing fact or require a graph database.

begin;

create table public.context_cores (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  core_id text not null,
  core_version text not null,
  core_name text not null,
  domain_name text not null,
  description text not null,
  status text not null check (status in ('ACTIVE', 'SUPERSEDED', 'DRAFT')),
  persistence_model text not null check (persistence_model = 'POSTGRES_CANONICAL_CONTEXT'),
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  as_of_time timestamptz not null,
  synthetic boolean not null check (synthetic),
  production_capability_mapping text not null,
  qualified_human_authority_statement text not null,
  required_scopes text[] not null default array['quality']::text[],
  created_at timestamptz not null default now(),
  check (cardinality(required_scopes) > 0),
  unique (tenant_id, core_id, core_version, snapshot_id),
  unique (id, tenant_id, snapshot_id),
  foreign key (tenant_id, snapshot_id)
    references public.organizations(tenant_id, snapshot_id)
);

create table public.context_source_domains (
  id uuid primary key default gen_random_uuid(),
  context_core_id uuid not null references public.context_cores(id) on delete cascade,
  tenant_id text not null,
  snapshot_id text not null,
  domain_key text not null,
  display_name text not null,
  purpose text not null,
  representative_systems jsonb not null check (jsonb_typeof(representative_systems) = 'array'),
  canonical_tables text[] not null,
  governance_statement text not null,
  required_scopes text[] not null default array['quality']::text[],
  created_at timestamptz not null default now(),
  check (cardinality(canonical_tables) > 0),
  check (cardinality(required_scopes) > 0),
  unique (context_core_id, domain_key),
  foreign key (context_core_id, tenant_id, snapshot_id)
    references public.context_cores(id, tenant_id, snapshot_id)
);

create table public.context_entity_types (
  id uuid primary key default gen_random_uuid(),
  context_core_id uuid not null references public.context_cores(id) on delete cascade,
  tenant_id text not null,
  snapshot_id text not null,
  entity_type_key text not null,
  display_name text not null,
  source_domain_key text not null,
  canonical_table text not null,
  canonical_id_column text not null,
  description text not null,
  provenance_fields text[] not null,
  temporal_fields text[] not null,
  authority_field text not null default 'authority',
  required_scopes text[] not null default array['quality']::text[],
  created_at timestamptz not null default now(),
  check (cardinality(provenance_fields) > 0),
  check (cardinality(temporal_fields) > 0),
  check (cardinality(required_scopes) > 0),
  unique (context_core_id, entity_type_key),
  foreign key (context_core_id, tenant_id, snapshot_id)
    references public.context_cores(id, tenant_id, snapshot_id),
  foreign key (context_core_id, source_domain_key)
    references public.context_source_domains(context_core_id, domain_key)
);

create table public.context_relationship_types (
  id uuid primary key default gen_random_uuid(),
  context_core_id uuid not null references public.context_cores(id) on delete cascade,
  tenant_id text not null,
  snapshot_id text not null,
  relationship_key text not null,
  display_name text not null,
  from_entity_type text not null,
  to_entity_type text not null,
  backing_table text not null,
  relationship_semantics text not null,
  temporal_semantics text not null,
  maximum_demo_hops smallint not null check (maximum_demo_hops between 1 and 8),
  required_scopes text[] not null default array['quality']::text[],
  created_at timestamptz not null default now(),
  check (cardinality(required_scopes) > 0),
  unique (context_core_id, relationship_key),
  foreign key (context_core_id, tenant_id, snapshot_id)
    references public.context_cores(id, tenant_id, snapshot_id),
  foreign key (context_core_id, from_entity_type)
    references public.context_entity_types(context_core_id, entity_type_key),
  foreign key (context_core_id, to_entity_type)
    references public.context_entity_types(context_core_id, entity_type_key)
);

create table public.context_policy_controls (
  id uuid primary key default gen_random_uuid(),
  context_core_id uuid not null references public.context_cores(id) on delete cascade,
  tenant_id text not null,
  snapshot_id text not null,
  policy_key text not null,
  policy_version text not null,
  control_type text not null check (
    control_type in ('AUTHORIZATION', 'TEMPORAL_VALIDITY', 'SOURCE_AUTHORITY', 'PACKET_READINESS', 'HUMAN_AUTHORITY')
  ),
  description text not null,
  deterministic boolean not null,
  enforcement_layer text not null check (enforcement_layer in ('DATABASE', 'COMPILER_VALIDATOR', 'WORKFLOW')),
  policy_config jsonb not null check (jsonb_typeof(policy_config) = 'object'),
  authority text not null,
  source_system text not null,
  required_scopes text[] not null default array['quality']::text[],
  created_at timestamptz not null default now(),
  check (cardinality(required_scopes) > 0),
  unique (context_core_id, policy_key, policy_version),
  foreign key (context_core_id, tenant_id, snapshot_id)
    references public.context_cores(id, tenant_id, snapshot_id)
);

alter table public.decision_profiles
  add column context_core_id text,
  add column context_core_version text,
  add column projection_strategy text not null default 'MINIMUM_SUFFICIENT'
    check (projection_strategy = 'MINIMUM_SUFFICIENT'),
  add column packet_output_contract text not null default 'DecisionPacket',
  add column qualified_human_authority_statement text not null default
    'The packet supports readiness review; a qualified human retains final disposition authority.',
  add check (
    (context_core_id is null and context_core_version is null)
    or (context_core_id is not null and context_core_version is not null)
  ),
  add constraint decision_profiles_id_tenant_snapshot_key
    unique (id, tenant_id, snapshot_id);

create table public.decision_profile_requirements (
  id uuid primary key default gen_random_uuid(),
  decision_profile_row_id uuid not null references public.decision_profiles(id) on delete cascade,
  tenant_id text not null,
  snapshot_id text not null,
  requirement_key text not null,
  evidence_class text not null,
  requirement_type text not null check (requirement_type in ('REQUIRED', 'CONDITIONAL', 'CROSS_CUTTING')),
  source_domain_key text not null,
  minimum_count smallint not null default 1 check (minimum_count between 0 and 100),
  maximum_count smallint not null default 20 check (maximum_count between 1 and 100),
  relationship_path jsonb not null check (jsonb_typeof(relationship_path) = 'array'),
  freshness_policy jsonb not null check (jsonb_typeof(freshness_policy) = 'object'),
  authority_policy jsonb not null check (jsonb_typeof(authority_policy) = 'object'),
  deterministic_policy_rules jsonb not null check (jsonb_typeof(deterministic_policy_rules) = 'array'),
  packet_priority smallint not null check (packet_priority between 1 and 100),
  required_scopes text[] not null default array['quality']::text[],
  created_at timestamptz not null default now(),
  check (minimum_count <= maximum_count),
  check (cardinality(required_scopes) > 0),
  unique (decision_profile_row_id, requirement_key),
  foreign key (decision_profile_row_id, tenant_id, snapshot_id)
    references public.decision_profiles(id, tenant_id, snapshot_id)
);

-- Decision Packets are projections from a Context Core for one subject and task.
-- They do not own the shared context and never grant final disposition authority.
create table public.decision_packets (
  packet_id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  snapshot_id text not null,
  context_core_row_id uuid not null references public.context_cores(id) on delete restrict,
  decision_profile_row_id uuid not null references public.decision_profiles(id) on delete restrict,
  workflow_id text not null references public.demo_workflows(workflow_id) on delete restrict,
  subject_type text not null,
  subject_id text not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  packet_status text not null check (packet_status in ('VALIDATED', 'INCOMPLETE', 'CONFLICTED', 'FAILED')),
  execution_mode text not null check (execution_mode in ('SEEDED_REFERENCE', 'SIMULATED_LOCAL', 'FOUNDRY_LIVE')),
  compiler_role_key text not null check (compiler_role_key = 'hexacontext_compiler'),
  as_of_time timestamptz not null,
  compiled_at timestamptz not null,
  core_snapshot_record_count integer not null check (core_snapshot_record_count >= 0),
  selected_evidence_count integer not null check (selected_evidence_count >= 0),
  excluded_evidence_count integer not null check (excluded_evidence_count >= 0),
  missing_requirements jsonb not null check (jsonb_typeof(missing_requirements) = 'array'),
  conflicts jsonb not null check (jsonb_typeof(conflicts) = 'array'),
  policy_findings jsonb not null check (jsonb_typeof(policy_findings) = 'array'),
  packet_hash text not null check (packet_hash ~ '^[0-9a-f]{64}$'),
  is_reference_fixture boolean not null default false,
  qualified_human_authority_statement text not null,
  required_scopes text[] not null default array['quality']::text[],
  created_at timestamptz not null default now(),
  check (cardinality(required_scopes) > 0),
  unique (tenant_id, snapshot_id, packet_hash),
  unique (packet_id, tenant_id, snapshot_id),
  foreign key (context_core_row_id, tenant_id, snapshot_id)
    references public.context_cores(id, tenant_id, snapshot_id),
  foreign key (decision_profile_row_id, tenant_id, snapshot_id)
    references public.decision_profiles(id, tenant_id, snapshot_id)
);

create table public.decision_packet_evidence (
  id uuid primary key default gen_random_uuid(),
  packet_id uuid not null references public.decision_packets(packet_id) on delete cascade,
  requirement_row_id uuid references public.decision_profile_requirements(id) on delete restrict,
  tenant_id text not null,
  snapshot_id text not null,
  selection_order smallint not null check (selection_order between 1 and 500),
  evidence_class text not null,
  source_domain_key text not null,
  canonical_entity_type text not null,
  canonical_entity_id text not null,
  source_table text not null,
  source_system text not null,
  source_record_id text not null,
  source_version text not null,
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  authority text not null,
  observed_at timestamptz not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  relationship_path jsonb not null check (jsonb_typeof(relationship_path) = 'array'),
  selection_reason text not null,
  applied_policy_rules jsonb not null check (jsonb_typeof(applied_policy_rules) = 'array'),
  required_scopes text[] not null default array['quality']::text[],
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from),
  check (cardinality(required_scopes) > 0),
  unique (packet_id, selection_order),
  unique (packet_id, source_table, source_record_id),
  foreign key (packet_id, tenant_id, snapshot_id)
    references public.decision_packets(packet_id, tenant_id, snapshot_id)
);

create table public.context_update_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null,
  context_core_row_id uuid not null references public.context_cores(id) on delete restrict,
  tenant_id text not null,
  snapshot_id text not null,
  event_type text not null check (event_type in ('SOURCE_FACT_INGESTED', 'SOURCE_FACT_CORRECTED', 'RELATIONSHIP_CHANGED', 'POLICY_CHANGED')),
  source_domain_key text not null,
  canonical_entity_type text not null,
  canonical_entity_id text not null,
  source_system text not null,
  source_record_id text not null,
  previous_content_hash text check (previous_content_hash is null or previous_content_hash ~ '^[0-9a-f]{64}$'),
  new_content_hash text not null check (new_content_hash ~ '^[0-9a-f]{64}$'),
  observed_at timestamptz not null,
  effective_at timestamptz not null,
  affected_subjects jsonb not null check (jsonb_typeof(affected_subjects) = 'array'),
  affected_profile_ids text[] not null,
  recompile_required boolean not null,
  description text not null,
  synthetic boolean not null check (synthetic),
  required_scopes text[] not null default array['quality']::text[],
  created_at timestamptz not null default now(),
  check (cardinality(affected_profile_ids) > 0),
  check (cardinality(required_scopes) > 0),
  unique (tenant_id, snapshot_id, event_id),
  foreign key (context_core_row_id, tenant_id, snapshot_id)
    references public.context_cores(id, tenant_id, snapshot_id)
);

-- New runtime metadata remains read-only to authenticated identities. Writes are
-- reserved for the migration/seed path and trusted backend service role.
revoke all on public.context_cores,
  public.context_source_domains,
  public.context_entity_types,
  public.context_relationship_types,
  public.context_policy_controls,
  public.decision_profile_requirements,
  public.decision_packets,
  public.decision_packet_evidence,
  public.context_update_events
from public, anon, authenticated;

grant select on public.context_cores,
  public.context_source_domains,
  public.context_entity_types,
  public.context_relationship_types,
  public.context_policy_controls,
  public.decision_profile_requirements,
  public.decision_packets,
  public.decision_packet_evidence,
  public.context_update_events
to authenticated, service_role;

grant insert, update on public.decision_packets, public.decision_packet_evidence,
  public.context_update_events
to service_role;

-- Force tenant/scope RLS on every new runtime table.
do $migration$
declare
  table_name text;
begin
  foreach table_name in array array[
    'context_cores',
    'context_source_domains',
    'context_entity_types',
    'context_relationship_types',
    'context_policy_controls',
    'decision_profile_requirements',
    'decision_packets',
    'decision_packet_evidence',
    'context_update_events'
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

create index context_cores_lookup_idx
  on public.context_cores (tenant_id, snapshot_id, core_id, core_version);
create index context_source_domains_core_idx
  on public.context_source_domains (tenant_id, snapshot_id, context_core_id, domain_key);
create index context_entity_types_core_idx
  on public.context_entity_types (tenant_id, snapshot_id, context_core_id, entity_type_key);
create index context_relationship_types_core_idx
  on public.context_relationship_types (tenant_id, snapshot_id, context_core_id, relationship_key);
create index context_policy_controls_core_idx
  on public.context_policy_controls (tenant_id, snapshot_id, context_core_id, control_type);
create index decision_profile_requirements_profile_idx
  on public.decision_profile_requirements (tenant_id, snapshot_id, decision_profile_row_id, packet_priority);
create index decision_packets_subject_idx
  on public.decision_packets (tenant_id, snapshot_id, subject_type, subject_id, compiled_at desc);
create index decision_packet_evidence_packet_idx
  on public.decision_packet_evidence (tenant_id, snapshot_id, packet_id, selection_order);
create index context_update_events_entity_idx
  on public.context_update_events (tenant_id, snapshot_id, canonical_entity_type, canonical_entity_id, effective_at desc);

-- Correct the stored experiment metadata without rewriting pushed history.
alter table public.demo_agent_roles
  drop constraint if exists demo_agent_roles_role_key_check;
alter table public.demo_agent_roles
  drop constraint if exists demo_agent_roles_tool_access_check;

update public.demo_agent_roles
set role_key = 'context_assisted_review'
where role_key = 'context_review';

update public.demo_agent_roles
set
  tool_access = case role_key
    when 'direct_review' then 'FRAGMENTED_SOURCE_TOOLS'
    when 'hexacontext_compiler' then 'CONTEXT_CORE_QUERY'
    else 'DECISION_PACKET_ONLY'
  end,
  responsibility = case role_key
    when 'direct_review' then
      'Gather and reconcile authorized evidence through fragmented source-domain tools, then recommend PASS, HOLD, or ESCALATE readiness.'
    when 'hexacontext_compiler' then
      'Apply a reusable Decision Profile to the persistent Manufacturing Context Core and compile a validated, source-linked Decision Packet without making final disposition.'
    else
      'Analyze the case-specific Decision Packet and recommend PASS, HOLD, or ESCALATE readiness without direct source access.'
  end,
  input_contract = case role_key
    when 'direct_review' then 'ContextRequest plus fragmented source-domain tools'
    when 'hexacontext_compiler' then 'ContextRequest plus Decision Profile plus Manufacturing Context Core query contract'
    else 'DecisionPacket only'
  end;

alter table public.demo_agent_roles
  add constraint demo_agent_roles_role_key_check check (
    role_key in ('direct_review', 'hexacontext_compiler', 'context_assisted_review')
  ),
  add constraint demo_agent_roles_tool_access_check check (
    tool_access in ('FRAGMENTED_SOURCE_TOOLS', 'CONTEXT_CORE_QUERY', 'DECISION_PACKET_ONLY')
  );

alter table public.demo_workflows
  add column context_core_id text,
  add column context_core_version text,
  add column independent_variable text not null default
    'Context assembly: fragmented source reconciliation versus Decision Profile projection from the shared Context Core.',
  add column controlled_invariants jsonb not null default '[]'::jsonb
    check (jsonb_typeof(controlled_invariants) = 'array');

update public.demo_workflows
set
  context_core_id = 'manufacturing_context_core',
  context_core_version = '1.0',
  description = 'Controlled comparison of direct fragmented-source reconciliation versus a Decision Profile projection from the persistent Manufacturing Context Core.',
  comparison_question = 'Does connected, governed, minimum-sufficient context improve decision support enough to justify compiler and packet overhead?',
  controlled_invariants = '[
    "same synthetic case",
    "same immutable evidence universe",
    "same actor permissions",
    "same task and decision criteria",
    "same recommendation contract",
    "same qualified-human final authority"
  ]'::jsonb,
  source_domains = '[
    {"domain_key":"MANUFACTURING_EXECUTION","label":"Manufacturing execution and genealogy","representative_systems":["MES"]},
    {"domain_key":"QUALITY_MANAGEMENT","label":"Inspections, deviations, and quality records","representative_systems":["QMS"]},
    {"domain_key":"ENGINEERING_LIFECYCLE","label":"Parts, revisions, specifications, and changes","representative_systems":["PLM"]},
    {"domain_key":"EQUIPMENT_CALIBRATION","label":"Equipment usage and calibration state","representative_systems":["CMMS","EQMS"]},
    {"domain_key":"SUPPLIER_QUALITY","label":"Supplier, certificate, and material evidence","representative_systems":["SUPPLIER_QMS","SUPPLIER_PORTAL"]},
    {"domain_key":"POLICY_REGISTRY","label":"Decision requirements and deterministic rules","representative_systems":["POLICY_REGISTRY"]}
  ]'::jsonb
where workflow_id = 'synthetic_material_deviation_readiness_v1';

-- Seed helper is retained so a later local seed can invoke the same idempotent
-- metadata load after its fixture snapshots exist. The forward migration invokes
-- it immediately for the already-seeded linked project.
create or replace function private_app.seed_manufacturing_context_core_metadata()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.context_cores (
    tenant_id, core_id, core_version, core_name, domain_name, description,
    status, persistence_model, snapshot_id, as_of_time, synthetic,
    production_capability_mapping, qualified_human_authority_statement,
    required_scopes
  )
  select
    organization.tenant_id,
    'manufacturing_context_core',
    case when snapshot.dataset_version like '1.%' then '1.0' else '2.0' end,
    'Manufacturing Context Core',
    'synthetic_manufacturing',
    'Persistent, reusable, governed manufacturing context assembled from canonical source-backed entities and typed relationships.',
    'ACTIVE',
    'POSTGRES_CANONICAL_CONTEXT',
    snapshot.snapshot_id,
    snapshot.as_of_time,
    true,
    'Represents the production context-fabric capability at bounded PoC scale; it does not claim a continuously synchronized enterprise digital twin.',
    'HexaContext supplies decision support. A qualified human retains final material-disposition authority.',
    array['quality']::text[]
  from public.dataset_snapshots as snapshot
  join public.organizations as organization using (snapshot_id)
  on conflict (tenant_id, core_id, core_version, snapshot_id) do update set
    description = excluded.description,
    production_capability_mapping = excluded.production_capability_mapping,
    qualified_human_authority_statement = excluded.qualified_human_authority_statement;

  insert into public.context_source_domains (
    context_core_id, tenant_id, snapshot_id, domain_key, display_name, purpose,
    representative_systems, canonical_tables, governance_statement, required_scopes
  )
  select core.id, core.tenant_id, core.snapshot_id, domain.domain_key,
    domain.display_name, domain.purpose, domain.representative_systems,
    domain.canonical_tables, domain.governance_statement, core.required_scopes
  from public.context_cores as core
  cross join (
    values
      ('MANUFACTURING_EXECUTION', 'Manufacturing execution', 'Lots, work orders, operations, equipment usage, genealogy, and signed operating notes.',
       '["MES","MANUFACTURING_LOG"]'::jsonb,
       array['manufacturing_lots','work_orders','manufacturing_operations','equipment_usage','component_lot_usage','manufacturing_notes']::text[],
       'Preserve lot genealogy, source version, observed time, effective time, and actor scope.'),
      ('QUALITY_MANAGEMENT', 'Quality management', 'Inspection results, deviations, and quality-review evidence.',
       '["QMS"]'::jsonb,
       array['inspections','deviations']::text[],
       'Quality records remain source-linked; missing or conflicting evidence cannot be inferred away.'),
      ('ENGINEERING_LIFECYCLE', 'Engineering lifecycle', 'Parts, released revisions, BOM structures, and engineering change orders.',
       '["PLM"]'::jsonb,
       array['parts','engineering_revisions','bills_of_material','engineering_change_orders']::text[],
       'Use the authoritative effective revision and surface simultaneous or ambiguous releases.'),
      ('EQUIPMENT_CALIBRATION', 'Equipment and calibration', 'Equipment masters, process usage, and time-valid calibration records.',
       '["CMMS","EQMS"]'::jsonb,
       array['equipment','equipment_usage','calibration_records']::text[],
       'Calibration validity is evaluated at the time of use or inspection, not only at query time.'),
      ('SUPPLIER_QUALITY', 'Supplier and material quality', 'Suppliers, certificates, material batches, and historical supplier quality.',
       '["SUPPLIER_QMS","SUPPLIER_PORTAL","ERP_INVENTORY"]'::jsonb,
       array['suppliers','supplier_quality_events','certificates_of_analysis','material_batches','material_certificates']::text[],
       'Retain certificate verification, material genealogy, freshness, and source authority.'),
      ('POLICY_REGISTRY', 'Policy registry', 'Versioned Decision Profiles, requirements, source precedence, and deterministic readiness rules.',
       '["POLICY_REGISTRY"]'::jsonb,
       array['decision_profiles','decision_profile_requirements','context_policy_controls']::text[],
       'Decision requirements are reviewed configuration and remain separate from changing enterprise facts.')
  ) as domain(domain_key, display_name, purpose, representative_systems, canonical_tables, governance_statement)
  on conflict (context_core_id, domain_key) do update set
    display_name = excluded.display_name,
    purpose = excluded.purpose,
    representative_systems = excluded.representative_systems,
    canonical_tables = excluded.canonical_tables,
    governance_statement = excluded.governance_statement;

  insert into public.context_entity_types (
    context_core_id, tenant_id, snapshot_id, entity_type_key, display_name,
    source_domain_key, canonical_table, canonical_id_column, description,
    provenance_fields, temporal_fields, required_scopes
  )
  select core.id, core.tenant_id, core.snapshot_id, entity.entity_type_key,
    entity.display_name, entity.source_domain_key, entity.canonical_table,
    entity.canonical_id_column, entity.description,
    array['source_system','source_record_id','source_version','content_hash']::text[],
    entity.temporal_fields, core.required_scopes
  from public.context_cores as core
  cross join (
    values
      ('manufacturing_lot','Manufacturing lot','MANUFACTURING_EXECUTION','manufacturing_lots','lot_id','Canonical lot and primary subject for the disposition-readiness profile.',array['observed_at','effective_from','effective_to','manufactured_at']::text[]),
      ('work_order','Work order','MANUFACTURING_EXECUTION','work_orders','work_order_id','Production order connected to one manufacturing lot.',array['observed_at','effective_from','effective_to','scheduled_start','scheduled_end']::text[]),
      ('manufacturing_operation','Manufacturing operation','MANUFACTURING_EXECUTION','manufacturing_operations','operation_id','Ordered controlled operation performed under a work order.',array['observed_at','effective_from','effective_to','started_at','completed_at']::text[]),
      ('inspection','Inspection','QUALITY_MANAGEMENT','inspections','inspection_id','Source-backed final or in-process quality inspection.',array['observed_at','effective_from','effective_to','completed_at']::text[]),
      ('deviation','Deviation','QUALITY_MANAGEMENT','deviations','deviation_id','Open or historical quality deviation connected to governed subjects.',array['observed_at','effective_from','effective_to','opened_at','closed_at']::text[]),
      ('part','Part','ENGINEERING_LIFECYCLE','parts','part_id','Canonical manufactured or component part.',array['observed_at','effective_from','effective_to']::text[]),
      ('engineering_revision','Engineering revision','ENGINEERING_LIFECYCLE','engineering_revisions','revision_id','Time-effective controlled engineering revision.',array['observed_at','effective_from','effective_to','released_at']::text[]),
      ('engineering_change','Engineering change order','ENGINEERING_LIFECYCLE','engineering_change_orders','change_order_id','Controlled change from one revision to another.',array['observed_at','effective_from','effective_to','implementation_effective_at']::text[]),
      ('equipment','Equipment','EQUIPMENT_CALIBRATION','equipment','equipment_id','Canonical production, measurement, or monitoring equipment.',array['observed_at','effective_from','effective_to']::text[]),
      ('calibration_record','Calibration record','EQUIPMENT_CALIBRATION','calibration_records','calibration_id','Calibration state with explicit validity at equipment-use time.',array['observed_at','effective_from','effective_to','calibrated_at','valid_until']::text[]),
      ('supplier','Supplier','SUPPLIER_QUALITY','suppliers','supplier_id','Approved, conditional, or inactive supplier master.',array['observed_at','effective_from','effective_to']::text[]),
      ('material_batch','Material batch','SUPPLIER_QUALITY','material_batches','material_batch_id','Lot-controlled component material consumed by manufacturing lots.',array['observed_at','effective_from','effective_to','received_at','expires_at']::text[]),
      ('material_certificate','Material certificate','SUPPLIER_QUALITY','material_certificates','material_certificate_id','Verified laboratory evidence for one material batch.',array['observed_at','effective_from','effective_to','issued_at','verified_at']::text[]),
      ('decision_profile','Decision Profile','POLICY_REGISTRY','decision_profiles','profile_id','Reusable, versioned requirements for one class of decision.',array['observed_at','effective_from','effective_to','active_from','active_to']::text[])
  ) as entity(entity_type_key, display_name, source_domain_key, canonical_table, canonical_id_column, description, temporal_fields)
  on conflict (context_core_id, entity_type_key) do update set
    display_name = excluded.display_name,
    source_domain_key = excluded.source_domain_key,
    canonical_table = excluded.canonical_table,
    canonical_id_column = excluded.canonical_id_column,
    description = excluded.description,
    temporal_fields = excluded.temporal_fields;

  insert into public.context_relationship_types (
    context_core_id, tenant_id, snapshot_id, relationship_key, display_name,
    from_entity_type, to_entity_type, backing_table, relationship_semantics,
    temporal_semantics, maximum_demo_hops, required_scopes
  )
  select core.id, core.tenant_id, core.snapshot_id, relationship.relationship_key,
    relationship.display_name, relationship.from_entity_type,
    relationship.to_entity_type, relationship.backing_table,
    relationship.relationship_semantics, relationship.temporal_semantics,
    relationship.maximum_demo_hops, core.required_scopes
  from public.context_cores as core
  cross join (
    values
      ('lot_has_work_order','Lot has work order','manufacturing_lot','work_order','work_orders','work_orders.lot_id identifies the subject lot.','Work-order schedule and effective window must include the relevant production period.',1::smallint),
      ('work_order_has_operation','Work order has operation','work_order','manufacturing_operation','manufacturing_operations','manufacturing_operations.work_order_id preserves ordered process genealogy.','Operation start/completion and effective windows are retained.',2::smallint),
      ('lot_has_inspection','Lot has inspection','manufacturing_lot','inspection','inspections','inspections.lot_id connects signed quality evidence to the lot.','Inspection completion and evidence effective time are retained.',1::smallint),
      ('operation_uses_equipment','Operation uses equipment','manufacturing_operation','equipment','equipment_usage','equipment_usage connects a controlled operation to exact equipment.','Calibration is evaluated at used_from/used_to, not only query time.',3::smallint),
      ('equipment_has_calibration','Equipment has calibration','equipment','calibration_record','calibration_records','calibration_records.equipment_id connects time-valid calibration evidence.','valid_until and effective windows must cover equipment-use time.',4::smallint),
      ('lot_has_part','Lot has part','manufacturing_lot','part','manufacturing_lots','manufacturing_lots.part_id identifies the produced part.','The observed revision is compared with the time-effective released revision.',1::smallint),
      ('part_has_revision','Part has revision','part','engineering_revision','engineering_revisions','engineering_revisions.part_id connects released design state.','Only revisions effective at manufacture/as-of time qualify.',2::smallint),
      ('part_has_change_order','Part has change order','part','engineering_change','engineering_change_orders','engineering_change_orders.part_id exposes controlled revision transitions.','Implementation effective time is compared with manufacture time.',2::smallint),
      ('lot_uses_material_batch','Lot uses material batch','manufacturing_lot','material_batch','component_lot_usage','Component usage and BOM edges connect a subject lot to consumed material.','The material batch must be released and unexpired at consumed_at.',4::smallint),
      ('material_batch_has_certificate','Material batch has certificate','material_batch','material_certificate','material_certificates','material_certificates.material_batch_id connects laboratory evidence.','Issued, verified, and freshness times are preserved.',5::smallint),
      ('lot_has_supplier','Lot has supplier','manufacturing_lot','supplier','manufacturing_lots','manufacturing_lots.supplier_id connects the direct supplier.','Supplier status and quality history are evaluated at the pinned time.',1::smallint),
      ('profile_projects_core','Decision Profile projects Context Core','decision_profile','manufacturing_lot','decision_profile_requirements','A profile specifies minimum-sufficient evidence and allowed relationship paths for a subject.','Profile and core versions are pinned for every compilation.',1::smallint)
  ) as relationship(relationship_key, display_name, from_entity_type, to_entity_type, backing_table, relationship_semantics, temporal_semantics, maximum_demo_hops)
  on conflict (context_core_id, relationship_key) do update set
    display_name = excluded.display_name,
    relationship_semantics = excluded.relationship_semantics,
    temporal_semantics = excluded.temporal_semantics,
    maximum_demo_hops = excluded.maximum_demo_hops;

  insert into public.context_policy_controls (
    context_core_id, tenant_id, snapshot_id, policy_key, policy_version,
    control_type, description, deterministic, enforcement_layer, policy_config,
    authority, source_system, required_scopes
  )
  select core.id, core.tenant_id, core.snapshot_id, policy.policy_key, '1.0',
    policy.control_type, policy.description, policy.deterministic,
    policy.enforcement_layer, policy.policy_config,
    'reviewed_synthetic_governance', 'POLICY_REGISTRY', core.required_scopes
  from public.context_cores as core
  cross join (
    values
      ('tenant_scope_authorization','AUTHORIZATION','Tenant and required scopes are enforced before evidence reaches a model.',true,'DATABASE','{"claims_source":"signed app_metadata","default_deny":true}'::jsonb),
      ('effective_time_validation','TEMPORAL_VALIDITY','Evidence must be valid at the decision-relevant time, including calibration at use time.',true,'COMPILER_VALIDATOR','{"use_effective_windows":true,"calibration_at_use_time":true}'::jsonb),
      ('source_authority_preservation','SOURCE_AUTHORITY','Every packet item retains source system, record, version, hash, and authority.',true,'COMPILER_VALIDATOR','{"require_source_record_id":true,"require_content_hash":true}'::jsonb),
      ('minimum_sufficient_packet','PACKET_READINESS','The compiler selects only evidence required or justified by the active Decision Profile.',true,'COMPILER_VALIDATOR','{"strategy":"MINIMUM_SUFFICIENT","missing_required":"INCOMPLETE","conflict":"CONFLICTED"}'::jsonb),
      ('qualified_human_final_authority','HUMAN_AUTHORITY','PASS means ready for qualified review and never authorizes release or shipment.',true,'WORKFLOW','{"agent_can_release":false,"qualified_human_required":true}'::jsonb)
  ) as policy(policy_key, control_type, description, deterministic, enforcement_layer, policy_config)
  on conflict (context_core_id, policy_key, policy_version) do update set
    description = excluded.description,
    policy_config = excluded.policy_config;

  update public.decision_profiles as profile
  set context_core_id = core.core_id,
      context_core_version = core.core_version,
      projection_strategy = 'MINIMUM_SUFFICIENT',
      packet_output_contract = 'DecisionPacket',
      qualified_human_authority_statement =
        'The Decision Packet supports readiness review; a qualified human retains final material-disposition authority.'
  from public.context_cores as core
  where core.tenant_id = profile.tenant_id
    and core.snapshot_id = profile.snapshot_id;

  -- Reuse proof: a second profile projects calibration impact from the same core.
  insert into public.decision_profiles (
    tenant_id, site_id, profile_id, profile_version, task_type,
    required_evidence_classes, freshness_rules, source_precedence, hold_rules,
    escalation_rules, retrieval_limits, active_from, active_to, snapshot_id,
    source_system, source_record_id, source_version, authority, observed_at,
    effective_from, effective_to, required_scopes, content_hash, created_at,
    context_core_id, context_core_version, projection_strategy,
    packet_output_contract, qualified_human_authority_statement
  )
  select source.tenant_id, source.site_id,
    'calibration_impact_assessment_v1', '1.0', 'calibration_impact_assessment',
    '{"record_required":["equipment_usage","equipment_calibration","affected_lot"],"query_required":["affected_operations"]}'::jsonb,
    '{"calibration_valid_at_use_time":true,"affected_lot_window_days":365}'::jsonb,
    '{"calibration":["approved_calibration_record"],"genealogy":["approved_manufacturing_record"]}'::jsonb,
    '["expired_or_suspended_calibration_at_use_time"]'::jsonb,
    '["missing_equipment_usage","missing_calibration_record","ambiguous_equipment_genealogy"]'::jsonb,
    '{"max_relationship_depth":4,"max_affected_lots":100}'::jsonb,
    source.active_from, null, source.snapshot_id,
    'POLICY_REGISTRY',
    'POLICY-CALIBRATION-IMPACT-1.0-' || source.tenant_id,
    '1.0', 'reviewed_synthetic_decision_profile', source.observed_at,
    source.effective_from, null, source.required_scopes,
    encode(sha256(convert_to(source.tenant_id || '|' || source.snapshot_id || '|calibration-impact-v1', 'UTF8')), 'hex'),
    source.created_at, source.context_core_id, source.context_core_version,
    'MINIMUM_SUFFICIENT', 'DecisionPacket',
    'The Decision Packet identifies potentially affected work for qualified quality and calibration review; it does not disposition material.'
  from public.decision_profiles as source
  where source.task_type = 'manufacturing_lot_disposition'
  on conflict (tenant_id, profile_id, profile_version, snapshot_id) do update set
    context_core_id = excluded.context_core_id,
    context_core_version = excluded.context_core_version,
    required_evidence_classes = excluded.required_evidence_classes,
    freshness_rules = excluded.freshness_rules,
    source_precedence = excluded.source_precedence,
    hold_rules = excluded.hold_rules,
    escalation_rules = excluded.escalation_rules,
    retrieval_limits = excluded.retrieval_limits,
    qualified_human_authority_statement = excluded.qualified_human_authority_statement;

  insert into public.decision_profile_requirements (
    decision_profile_row_id, tenant_id, snapshot_id, requirement_key,
    evidence_class, requirement_type, source_domain_key, minimum_count,
    maximum_count, relationship_path, freshness_policy, authority_policy,
    deterministic_policy_rules, packet_priority, required_scopes
  )
  select profile.id, profile.tenant_id, profile.snapshot_id,
    requirement.requirement_key, requirement.evidence_class,
    requirement.requirement_type, requirement.source_domain_key,
    requirement.minimum_count, requirement.maximum_count,
    requirement.relationship_path, requirement.freshness_policy,
    requirement.authority_policy, requirement.deterministic_policy_rules,
    requirement.packet_priority, profile.required_scopes
  from public.decision_profiles as profile
  cross join (
    values
      ('lot_identity','lot_record','REQUIRED','MANUFACTURING_EXECUTION',1::smallint,1::smallint,'["manufacturing_lot"]'::jsonb,'{"as_of":"pinned_snapshot"}'::jsonb,'{"accepted":["approved_manufacturing_record","MES lot genealogy"]}'::jsonb,'[]'::jsonb,1::smallint),
      ('final_inspection','final_inspection','REQUIRED','QUALITY_MANAGEMENT',1::smallint,5::smallint,'["manufacturing_lot","inspection"]'::jsonb,'{"valid_at":"inspection_completed_at"}'::jsonb,'{"accepted":["approved_quality_record","Electronic inspection record"]}'::jsonb,'["critical_defect_implies_hold"]'::jsonb,10::smallint),
      ('direct_certificate','certificate_of_analysis','REQUIRED','SUPPLIER_QUALITY',1::smallint,5::smallint,'["manufacturing_lot","certificate_of_analysis"]'::jsonb,'{"valid_at":"manufactured_at"}'::jsonb,'{"accepted":["verified_supplier_record","Verified supplier certificate"]}'::jsonb,'["invalid_certificate_implies_hold"]'::jsonb,20::smallint),
      ('inspection_calibration','equipment_calibration','REQUIRED','EQUIPMENT_CALIBRATION',1::smallint,5::smallint,'["manufacturing_lot","inspection","equipment","calibration_record"]'::jsonb,'{"valid_at":"inspection_completed_at"}'::jsonb,'{"accepted":["approved_calibration_record","Calibration management system"]}'::jsonb,'["expired_calibration_at_use_implies_hold"]'::jsonb,30::smallint),
      ('released_revision','released_revision_alignment','REQUIRED','ENGINEERING_LIFECYCLE',1::smallint,5::smallint,'["manufacturing_lot","part","engineering_revision"]'::jsonb,'{"valid_at":"manufactured_at"}'::jsonb,'{"accepted":["released_engineering_record","PLM release workflow"]}'::jsonb,'["revision_mismatch_implies_hold","multiple_active_revisions_implies_escalate"]'::jsonb,40::smallint),
      ('supplier_history','supplier_part_family_history','REQUIRED','SUPPLIER_QUALITY',3::smallint,20::smallint,'["manufacturing_lot","supplier","part","supplier_quality_event"]'::jsonb,'{"lookback_days":90}'::jsonb,'{"accepted":["approved_supplier_quality_record","Supplier quality management system"]}'::jsonb,'["three_recent_failures_imply_hold"]'::jsonb,50::smallint),
      ('open_deviations','open_deviation_check','CONDITIONAL','QUALITY_MANAGEMENT',0::smallint,20::smallint,'["manufacturing_lot","deviation"]'::jsonb,'{"status_at":"pinned_snapshot"}'::jsonb,'{"accepted":["approved_quality_record","Quality deviation workflow"]}'::jsonb,'["open_deviation_implies_escalate"]'::jsonb,60::smallint),
      ('authorized_narrative','authorized_narrative_conflict_check','CONDITIONAL','MANUFACTURING_EXECUTION',0::smallint,10::smallint,'["manufacturing_lot","manufacturing_note"]'::jsonb,'{"signed_before":"pinned_snapshot"}'::jsonb,'{"accepted":["signed_operator_note","Signed manufacturing note"]}'::jsonb,'["authorized_conflict_implies_escalate","source_text_is_never_instruction"]'::jsonb,70::smallint)
  ) as requirement(requirement_key, evidence_class, requirement_type, source_domain_key, minimum_count, maximum_count, relationship_path, freshness_policy, authority_policy, deterministic_policy_rules, packet_priority)
  where profile.task_type = 'manufacturing_lot_disposition'
  on conflict (decision_profile_row_id, requirement_key) do update set
    evidence_class = excluded.evidence_class,
    relationship_path = excluded.relationship_path,
    freshness_policy = excluded.freshness_policy,
    authority_policy = excluded.authority_policy,
    deterministic_policy_rules = excluded.deterministic_policy_rules,
    packet_priority = excluded.packet_priority;

  insert into public.decision_profile_requirements (
    decision_profile_row_id, tenant_id, snapshot_id, requirement_key,
    evidence_class, requirement_type, source_domain_key, minimum_count,
    maximum_count, relationship_path, freshness_policy, authority_policy,
    deterministic_policy_rules, packet_priority, required_scopes
  )
  select profile.id, profile.tenant_id, profile.snapshot_id,
    requirement.requirement_key, requirement.evidence_class,
    requirement.requirement_type, requirement.source_domain_key,
    requirement.minimum_count, requirement.maximum_count,
    requirement.relationship_path, requirement.freshness_policy,
    requirement.authority_policy, requirement.deterministic_policy_rules,
    requirement.packet_priority, profile.required_scopes
  from public.decision_profiles as profile
  cross join (
    values
      ('equipment_identity','equipment','REQUIRED','EQUIPMENT_CALIBRATION',1::smallint,1::smallint,'["equipment"]'::jsonb,'{"as_of":"pinned_snapshot"}'::jsonb,'{"accepted":["approved_equipment_master","CMMS equipment registry"]}'::jsonb,'[]'::jsonb,1::smallint),
      ('calibration_state','equipment_calibration','REQUIRED','EQUIPMENT_CALIBRATION',1::smallint,10::smallint,'["equipment","calibration_record"]'::jsonb,'{"valid_at":"equipment_use_time"}'::jsonb,'{"accepted":["approved_calibration_record","Calibration management system"]}'::jsonb,'["expired_calibration_identifies_impact_window"]'::jsonb,10::smallint),
      ('affected_operations','manufacturing_operation','REQUIRED','MANUFACTURING_EXECUTION',1::smallint,100::smallint,'["equipment","manufacturing_operation"]'::jsonb,'{"overlaps":"calibration_invalid_window"}'::jsonb,'{"accepted":["MES electronic traveler"]}'::jsonb,'[]'::jsonb,20::smallint),
      ('affected_lots','affected_lot','REQUIRED','MANUFACTURING_EXECUTION',1::smallint,100::smallint,'["equipment","manufacturing_operation","work_order","manufacturing_lot"]'::jsonb,'{"overlaps":"calibration_invalid_window"}'::jsonb,'{"accepted":["MES equipment genealogy","MES lot genealogy"]}'::jsonb,'["missing_genealogy_implies_escalate"]'::jsonb,30::smallint)
  ) as requirement(requirement_key, evidence_class, requirement_type, source_domain_key, minimum_count, maximum_count, relationship_path, freshness_policy, authority_policy, deterministic_policy_rules, packet_priority)
  where profile.task_type = 'calibration_impact_assessment'
  on conflict (decision_profile_row_id, requirement_key) do update set
    evidence_class = excluded.evidence_class,
    relationship_path = excluded.relationship_path,
    freshness_policy = excluded.freshness_policy,
    authority_policy = excluded.authority_policy,
    deterministic_policy_rules = excluded.deterministic_policy_rules,
    packet_priority = excluded.packet_priority;

  -- One explicitly labeled reference fixture proves that a packet is a projection
  -- with source lineage, not the Context Core itself. It is not a Foundry result.
  insert into public.decision_packets (
    packet_id, tenant_id, snapshot_id, context_core_row_id,
    decision_profile_row_id, workflow_id, subject_type, subject_id,
    request_hash, packet_status, execution_mode, compiler_role_key,
    as_of_time, compiled_at, core_snapshot_record_count,
    selected_evidence_count, excluded_evidence_count, missing_requirements,
    conflicts, policy_findings, packet_hash, is_reference_fixture,
    qualified_human_authority_statement, required_scopes
  )
  select
    '49f34a33-f2d5-4fa1-8a24-a40cf979d005'::uuid,
    core.tenant_id, core.snapshot_id, core.id, profile.id,
    'synthetic_material_deviation_readiness_v1',
    'manufacturing_lot', 'HX-V2-LOT-005',
    encode(sha256(convert_to('reference|HX-V2-LOT-005|manufacturing_lot_disposition_v1', 'UTF8')), 'hex'),
    'VALIDATED', 'SEEDED_REFERENCE', 'hexacontext_compiler',
    core.as_of_time, core.as_of_time,
    (
      select count(*)::integer from (
        select source_record_id from public.manufacturing_lots where tenant_id = core.tenant_id and snapshot_id = core.snapshot_id
        union all select source_record_id from public.inspections where tenant_id = core.tenant_id and snapshot_id = core.snapshot_id
        union all select source_record_id from public.certificates_of_analysis where tenant_id = core.tenant_id and snapshot_id = core.snapshot_id
        union all select source_record_id from public.calibration_records where tenant_id = core.tenant_id and snapshot_id = core.snapshot_id
        union all select source_record_id from public.engineering_revisions where tenant_id = core.tenant_id and snapshot_id = core.snapshot_id
        union all select source_record_id from public.supplier_quality_events where tenant_id = core.tenant_id and snapshot_id = core.snapshot_id
      ) records
    ),
    8, 0, '[]'::jsonb, '[]'::jsonb,
    '[{"rule":"expired_calibration_at_use_implies_hold","source_record_id":"EQMS-CAL-HX-V2-EQP-005"}]'::jsonb,
    encode(sha256(convert_to('reference-packet|HX-V2-LOT-005|8-items|v1', 'UTF8')), 'hex'),
    true,
    'This reference packet supports readiness review only; a qualified human retains final material-disposition authority.',
    array['quality']::text[]
  from public.context_cores as core
  join public.decision_profiles as profile
    on profile.tenant_id = core.tenant_id
    and profile.snapshot_id = core.snapshot_id
    and profile.context_core_id = core.core_id
    and profile.context_core_version = core.core_version
    and profile.profile_id = 'manufacturing_lot_disposition_v1'
    and profile.profile_version = '1.0'
  where core.tenant_id = 'HX-TENANT-ALPHA'
    and core.snapshot_id = 'hx-mfg-v1-snapshot-001'
  on conflict (packet_id) do update set
    selected_evidence_count = excluded.selected_evidence_count,
    policy_findings = excluded.policy_findings,
    qualified_human_authority_statement = excluded.qualified_human_authority_statement;

  insert into public.decision_packet_evidence (
    packet_id, requirement_row_id, tenant_id, snapshot_id, selection_order,
    evidence_class, source_domain_key, canonical_entity_type,
    canonical_entity_id, source_table, source_system, source_record_id,
    source_version, content_hash, authority, observed_at, effective_from,
    effective_to, relationship_path, selection_reason, applied_policy_rules,
    required_scopes
  )
  select packet.packet_id, requirement.id, packet.tenant_id, packet.snapshot_id,
    evidence.selection_order, evidence.evidence_class, evidence.source_domain_key,
    evidence.canonical_entity_type, evidence.canonical_entity_id,
    evidence.source_table, evidence.source_system, evidence.source_record_id,
    evidence.source_version, evidence.content_hash, evidence.authority,
    evidence.observed_at, evidence.effective_from, evidence.effective_to,
    evidence.relationship_path, evidence.selection_reason,
    evidence.applied_policy_rules, packet.required_scopes
  from public.decision_packets as packet
  join public.decision_profiles as profile on profile.id = packet.decision_profile_row_id
  join lateral (
    select 1::smallint as selection_order, 'lot_record'::text as evidence_class,
      'MANUFACTURING_EXECUTION'::text as source_domain_key,
      'manufacturing_lot'::text as canonical_entity_type, lot.lot_id as canonical_entity_id,
      'manufacturing_lots'::text as source_table, lot.source_system, lot.source_record_id,
      lot.source_version, lot.content_hash, lot.authority, lot.observed_at,
      lot.effective_from, lot.effective_to,
      jsonb_build_array(lot.lot_id) as relationship_path,
      'Required subject identity from the active Decision Profile.'::text as selection_reason,
      '[]'::jsonb as applied_policy_rules
    from public.manufacturing_lots as lot
    where lot.tenant_id = packet.tenant_id and lot.snapshot_id = packet.snapshot_id
      and lot.lot_id = packet.subject_id
    union all
    select 2, 'final_inspection', 'QUALITY_MANAGEMENT', 'inspection', inspection.inspection_id,
      'inspections', inspection.source_system, inspection.source_record_id,
      inspection.source_version, inspection.content_hash, inspection.authority,
      inspection.observed_at, inspection.effective_from, inspection.effective_to,
      jsonb_build_array(packet.subject_id, inspection.inspection_id),
      'Required signed inspection evidence.', '["critical_defect_implies_hold"]'::jsonb
    from public.inspections as inspection
    where inspection.tenant_id = packet.tenant_id and inspection.snapshot_id = packet.snapshot_id
      and inspection.lot_id = packet.subject_id
    union all
    select 3, 'certificate_of_analysis', 'SUPPLIER_QUALITY', 'material_certificate', certificate.certificate_id,
      'certificates_of_analysis', certificate.source_system, certificate.source_record_id,
      certificate.source_version, certificate.content_hash, certificate.authority,
      certificate.observed_at, certificate.effective_from, certificate.effective_to,
      jsonb_build_array(packet.subject_id, certificate.certificate_id),
      'Required supplier certificate evidence.', '["invalid_certificate_implies_hold"]'::jsonb
    from public.certificates_of_analysis as certificate
    where certificate.tenant_id = packet.tenant_id and certificate.snapshot_id = packet.snapshot_id
      and certificate.lot_id = packet.subject_id
    union all
    select 4, 'equipment_calibration', 'EQUIPMENT_CALIBRATION', 'calibration_record', calibration.calibration_id,
      'calibration_records', calibration.source_system, calibration.source_record_id,
      calibration.source_version, calibration.content_hash, calibration.authority,
      calibration.observed_at, calibration.effective_from, calibration.effective_to,
      jsonb_build_array(packet.subject_id, lot.inspection_equipment_id, calibration.calibration_id),
      'Calibration selected through the lot-to-inspection-equipment relationship.',
      '["expired_calibration_at_use_implies_hold"]'::jsonb
    from public.manufacturing_lots as lot
    join public.calibration_records as calibration
      on calibration.tenant_id = lot.tenant_id and calibration.snapshot_id = lot.snapshot_id
      and calibration.equipment_id = lot.inspection_equipment_id
    where lot.tenant_id = packet.tenant_id and lot.snapshot_id = packet.snapshot_id
      and lot.lot_id = packet.subject_id
    union all
    select 5, 'released_revision_alignment', 'ENGINEERING_LIFECYCLE', 'engineering_revision', revision.revision_id,
      'engineering_revisions', revision.source_system, revision.source_record_id,
      revision.source_version, revision.content_hash, revision.authority,
      revision.observed_at, revision.effective_from, revision.effective_to,
      jsonb_build_array(packet.subject_id, lot.part_id, revision.revision_id),
      'Released revision selected through the lot-to-part relationship.',
      '["revision_mismatch_implies_hold","multiple_active_revisions_implies_escalate"]'::jsonb
    from public.manufacturing_lots as lot
    join public.engineering_revisions as revision
      on revision.tenant_id = lot.tenant_id and revision.snapshot_id = lot.snapshot_id
      and revision.part_id = lot.part_id
    where lot.tenant_id = packet.tenant_id and lot.snapshot_id = packet.snapshot_id
      and lot.lot_id = packet.subject_id and revision.release_status = 'RELEASED'
    union all
    select (5 + row_number() over (order by event.event_at desc, event.source_record_id))::smallint,
      'supplier_part_family_history', 'SUPPLIER_QUALITY', 'supplier', event.quality_event_id,
      'supplier_quality_events', event.source_system, event.source_record_id,
      event.source_version, event.content_hash, event.authority,
      event.observed_at, event.effective_from, event.effective_to,
      jsonb_build_array(packet.subject_id, lot.supplier_id, lot.part_id, event.quality_event_id),
      'Recent supplier/part history required by the Decision Profile.',
      '["three_recent_failures_imply_hold"]'::jsonb
    from public.manufacturing_lots as lot
    join public.supplier_quality_events as event
      on event.tenant_id = lot.tenant_id and event.snapshot_id = lot.snapshot_id
      and event.supplier_id = lot.supplier_id and event.part_id = lot.part_id
    where lot.tenant_id = packet.tenant_id and lot.snapshot_id = packet.snapshot_id
      and lot.lot_id = packet.subject_id
  ) as evidence on true
  left join public.decision_profile_requirements as requirement
    on requirement.decision_profile_row_id = profile.id
    and requirement.evidence_class = evidence.evidence_class
  where packet.packet_id = '49f34a33-f2d5-4fa1-8a24-a40cf979d005'::uuid
  on conflict (packet_id, source_table, source_record_id) do update set
    relationship_path = excluded.relationship_path,
    selection_reason = excluded.selection_reason,
    applied_policy_rules = excluded.applied_policy_rules;

  insert into public.context_update_events (
    event_id, context_core_row_id, tenant_id, snapshot_id, event_type,
    source_domain_key, canonical_entity_type, canonical_entity_id,
    source_system, source_record_id, previous_content_hash,
    new_content_hash, observed_at, effective_at, affected_subjects,
    affected_profile_ids, recompile_required, description, synthetic,
    required_scopes
  )
  select 'hx-v1-calibration-005-ingested', core.id, calibration.tenant_id,
    calibration.snapshot_id, 'SOURCE_FACT_INGESTED', 'EQUIPMENT_CALIBRATION',
    'calibration_record', calibration.calibration_id, calibration.source_system,
    calibration.source_record_id, null, calibration.content_hash,
    calibration.observed_at, calibration.effective_from,
    jsonb_build_array(jsonb_build_object('subject_type','manufacturing_lot','subject_id',lot.lot_id)),
    array['manufacturing_lot_disposition_v1','calibration_impact_assessment_v1']::text[],
    true,
    'Synthetic expired-calibration fact demonstrates that changing governed context can trigger packet recompilation without model retraining or prompt rewriting.',
    true, calibration.required_scopes
  from public.calibration_records as calibration
  join public.manufacturing_lots as lot
    on lot.tenant_id = calibration.tenant_id and lot.snapshot_id = calibration.snapshot_id
    and lot.inspection_equipment_id = calibration.equipment_id
  join public.context_cores as core
    on core.tenant_id = calibration.tenant_id and core.snapshot_id = calibration.snapshot_id
  where calibration.tenant_id = 'HX-TENANT-ALPHA'
    and calibration.snapshot_id = 'hx-mfg-v1-snapshot-001'
    and lot.lot_id = 'HX-V2-LOT-005'
  on conflict (tenant_id, snapshot_id, event_id) do update set
    new_content_hash = excluded.new_content_hash,
    affected_subjects = excluded.affected_subjects,
    affected_profile_ids = excluded.affected_profile_ids,
    recompile_required = excluded.recompile_required,
    description = excluded.description;
end;
$$;

revoke all on function private_app.seed_manufacturing_context_core_metadata() from public, anon, authenticated;
grant execute on function private_app.seed_manufacturing_context_core_metadata() to service_role;

select private_app.seed_manufacturing_context_core_metadata();

-- Compiler-only metadata/query contracts. Direct Review does not receive these
-- operations; it retains the fragmented source-domain tools.
create or replace function public.get_context_core_manifest(
  p_core_id text,
  p_core_version text,
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
        'core_id', core.core_id,
        'core_version', core.core_version,
        'core_name', core.core_name,
        'domain_name', core.domain_name,
        'description', core.description,
        'status', core.status,
        'persistence_model', core.persistence_model,
        'snapshot_id', core.snapshot_id,
        'as_of_time', core.as_of_time,
        'synthetic', core.synthetic,
        'production_capability_mapping', core.production_capability_mapping,
        'qualified_human_authority_statement', core.qualified_human_authority_statement,
        'source_domains', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'domain_key', domain.domain_key,
            'display_name', domain.display_name,
            'purpose', domain.purpose,
            'representative_systems', domain.representative_systems,
            'canonical_tables', domain.canonical_tables,
            'governance_statement', domain.governance_statement
          ) order by domain.domain_key), '[]'::jsonb)
          from public.context_source_domains as domain
          where domain.context_core_id = core.id
        ),
        'entity_types', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'entity_type_key', entity.entity_type_key,
            'display_name', entity.display_name,
            'source_domain_key', entity.source_domain_key,
            'canonical_table', entity.canonical_table,
            'canonical_id_column', entity.canonical_id_column,
            'provenance_fields', entity.provenance_fields,
            'temporal_fields', entity.temporal_fields,
            'authority_field', entity.authority_field
          ) order by entity.entity_type_key), '[]'::jsonb)
          from public.context_entity_types as entity
          where entity.context_core_id = core.id
        ),
        'relationship_types', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'relationship_key', relationship.relationship_key,
            'from_entity_type', relationship.from_entity_type,
            'to_entity_type', relationship.to_entity_type,
            'backing_table', relationship.backing_table,
            'relationship_semantics', relationship.relationship_semantics,
            'temporal_semantics', relationship.temporal_semantics,
            'maximum_demo_hops', relationship.maximum_demo_hops
          ) order by relationship.relationship_key), '[]'::jsonb)
          from public.context_relationship_types as relationship
          where relationship.context_core_id = core.id
        ),
        'policy_controls', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'policy_key', policy.policy_key,
            'policy_version', policy.policy_version,
            'control_type', policy.control_type,
            'description', policy.description,
            'deterministic', policy.deterministic,
            'enforcement_layer', policy.enforcement_layer,
            'policy_config', policy.policy_config,
            'authority', policy.authority
          ) order by policy.policy_key), '[]'::jsonb)
          from public.context_policy_controls as policy
          where policy.context_core_id = core.id
        )
      )
      from public.context_cores as core
      where core.core_id = p_core_id
        and core.core_version = p_core_version
        and core.snapshot_id = p_snapshot_id
      limit 1
    ),
    jsonb_build_object(
      'core_id', p_core_id,
      'core_version', p_core_version,
      'snapshot_id', p_snapshot_id,
      'error', jsonb_build_object('code','NOT_FOUND','message','No authorized matching Context Core version exists.')
    )
  );
$$;

create or replace function public.get_decision_profile_requirements(
  p_profile_id text,
  p_profile_version text,
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
        'profile_id', profile.profile_id,
        'profile_version', profile.profile_version,
        'task_type', profile.task_type,
        'context_core_id', profile.context_core_id,
        'context_core_version', profile.context_core_version,
        'projection_strategy', profile.projection_strategy,
        'packet_output_contract', profile.packet_output_contract,
        'qualified_human_authority_statement', profile.qualified_human_authority_statement,
        'requirements', coalesce(jsonb_agg(jsonb_build_object(
          'requirement_key', requirement.requirement_key,
          'evidence_class', requirement.evidence_class,
          'requirement_type', requirement.requirement_type,
          'source_domain_key', requirement.source_domain_key,
          'minimum_count', requirement.minimum_count,
          'maximum_count', requirement.maximum_count,
          'relationship_path', requirement.relationship_path,
          'freshness_policy', requirement.freshness_policy,
          'authority_policy', requirement.authority_policy,
          'deterministic_policy_rules', requirement.deterministic_policy_rules,
          'packet_priority', requirement.packet_priority
        ) order by requirement.packet_priority), '[]'::jsonb)
      )
      from public.decision_profiles as profile
      left join public.decision_profile_requirements as requirement
        on requirement.decision_profile_row_id = profile.id
      where profile.profile_id = p_profile_id
        and profile.profile_version = p_profile_version
        and profile.snapshot_id = p_snapshot_id
      group by profile.id
      limit 1
    ),
    jsonb_build_object(
      'profile_id', p_profile_id,
      'profile_version', p_profile_version,
      'snapshot_id', p_snapshot_id,
      'error', jsonb_build_object('code','NOT_FOUND','message','No authorized matching Decision Profile version exists.')
    )
  );
$$;

revoke all on function public.get_context_core_manifest(text, text, text) from public, anon;
revoke all on function public.get_decision_profile_requirements(text, text, text) from public, anon;
grant execute on function public.get_context_core_manifest(text, text, text) to authenticated, service_role;
grant execute on function public.get_decision_profile_requirements(text, text, text) to authenticated, service_role;

comment on table public.context_cores is
  'Versioned registry for the persistent reusable Manufacturing Context Core; canonical fact instances remain in normalized source-backed tables.';
comment on table public.decision_profiles is
  'Reusable decision requirements that project from a versioned Context Core; profiles are not enterprise facts or final decisions.';
comment on table public.decision_packets is
  'Case-specific, minimum-sufficient projections compiled from a Context Core plus Decision Profile; never the shared core itself.';
comment on table public.decision_packet_evidence is
  'Source-level provenance and relationship lineage for evidence selected into one Decision Packet.';
comment on table public.context_update_events is
  'Governed context changes that identify affected subjects/profiles and whether packet recompilation is required.';
comment on table public.demo_agent_roles is
  'Exactly three experimental roles: direct_review, hexacontext_compiler, and context_assisted_review. Qualified humans are not agents.';

commit;
