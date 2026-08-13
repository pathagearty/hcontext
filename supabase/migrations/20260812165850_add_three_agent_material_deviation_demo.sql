-- Record the approved synthetic material-deviation workflow and three distinct
-- Foundry agent roles. These tables contain architecture metadata only: no agent
-- credentials, prompts, customer data, or private evaluator answers.

create table public.demo_workflows (
  workflow_id text primary key,
  workflow_version text not null,
  workflow_name text not null,
  workflow_type text not null,
  description text not null,
  synthetic boolean not null check (synthetic),
  seagate_inspired boolean not null,
  internal_workflow_validated boolean not null default false,
  human_authority_statement text not null,
  comparison_question text not null,
  decision_profile_id text not null,
  decision_profile_version text not null,
  snapshot_id text not null references public.dataset_snapshots(snapshot_id),
  source_domains jsonb not null check (jsonb_typeof(source_domains) = 'array'),
  created_at timestamptz not null default now(),
  unique (workflow_id, workflow_version)
);

create table public.demo_agent_roles (
  workflow_id text not null references public.demo_workflows(workflow_id) on delete restrict,
  role_key text not null check (
    role_key in ('direct_review', 'hexacontext_compiler', 'context_review')
  ),
  display_order smallint not null check (display_order between 1 and 3),
  display_name text not null,
  comparison_arm text not null check (comparison_arm in ('DIRECT', 'WITH_HEXACONTEXT')),
  responsibility text not null,
  input_contract text not null,
  tool_access text not null check (
    tool_access in ('BOUNDED_SOURCE_TOOLS', 'DECISION_PACKET_ONLY')
  ),
  output_contract text not null,
  makes_final_decision boolean not null default false check (not makes_final_decision),
  created_at timestamptz not null default now(),
  primary key (workflow_id, role_key),
  unique (workflow_id, display_order)
);

alter table public.demo_workflows enable row level security;
alter table public.demo_workflows force row level security;
alter table public.demo_agent_roles enable row level security;
alter table public.demo_agent_roles force row level security;

revoke all on public.demo_workflows, public.demo_agent_roles from public, anon, authenticated;
grant select on public.demo_workflows, public.demo_agent_roles to authenticated, service_role;

create policy authenticated_demo_workflow_read
on public.demo_workflows for select to authenticated
using (true);

create policy authenticated_demo_agent_roles_read
on public.demo_agent_roles for select to authenticated
using (true);

insert into public.demo_workflows (
  workflow_id,
  workflow_version,
  workflow_name,
  workflow_type,
  description,
  synthetic,
  seagate_inspired,
  internal_workflow_validated,
  human_authority_statement,
  comparison_question,
  decision_profile_id,
  decision_profile_version,
  snapshot_id,
  source_domains
) values (
  'synthetic_material_deviation_readiness_v1',
  '1.0',
  'Synthetic Material-Deviation Decision Readiness',
  'DECISION_READINESS_COMPARISON',
  'Controlled comparison of direct source gathering versus a governed Decision Packet across three synthetic factory information domains.',
  true,
  true,
  false,
  'The agents recommend PASS, HOLD, or ESCALATE readiness; a qualified human retains final disposition authority.',
  'Does separating context compilation from analysis improve evidence coverage and reviewer usability enough to justify the added model call and latency?',
  'manufacturing_lot_disposition_v1',
  '1.0',
  'hx-mfg-v1-snapshot-001',
  '[
    {"domain_key":"FACTORY_INSPECTION_AI","label":"Inspection and production evidence","representative_systems":["MES","QMS"]},
    {"domain_key":"PROCESS_EQUIPMENT_AI","label":"Process, equipment, and calibration evidence","representative_systems":["EQMS","MANUFACTURING_LOG"]},
    {"domain_key":"QUALITY_ENGINEERING_AI","label":"Quality, supplier, policy, and engineering evidence","representative_systems":["PLM","SUPPLIER_QUALITY_HUB","SUPPLIER_PORTAL","POLICY_REGISTRY"]}
  ]'::jsonb
);

insert into public.demo_agent_roles (
  workflow_id,
  role_key,
  display_order,
  display_name,
  comparison_arm,
  responsibility,
  input_contract,
  tool_access,
  output_contract,
  makes_final_decision
) values
(
  'synthetic_material_deviation_readiness_v1',
  'direct_review',
  1,
  'Direct Review Agent',
  'DIRECT',
  'Gather authorized source evidence and recommend PASS, HOLD, or ESCALATE readiness.',
  'ContextRequest plus bounded source tools',
  'BOUNDED_SOURCE_TOOLS',
  'ReadinessRecommendation',
  false
),
(
  'synthetic_material_deviation_readiness_v1',
  'hexacontext_compiler',
  2,
  'HexaContext Compiler Agent',
  'WITH_HEXACONTEXT',
  'Gather, authorize, normalize, and validate evidence without making the final disposition.',
  'ContextRequest plus the same bounded source tools',
  'BOUNDED_SOURCE_TOOLS',
  'DecisionPacket',
  false
),
(
  'synthetic_material_deviation_readiness_v1',
  'context_review',
  3,
  'Context-Assisted Review Agent',
  'WITH_HEXACONTEXT',
  'Analyze the DecisionPacket and recommend PASS, HOLD, or ESCALATE readiness.',
  'DecisionPacket only',
  'DECISION_PACKET_ONLY',
  'ReadinessRecommendation',
  false
);

comment on table public.demo_workflows is
  'Public synthetic demo architecture metadata; not a representation of Seagate internal workflow.';
comment on table public.demo_agent_roles is
  'Three Foundry saved-agent roles used by the controlled HexaContext comparison.';
