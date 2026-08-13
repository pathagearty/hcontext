-- Narrow v2 context-graph RPCs.

-- All functions are SECURITY INVOKER. The caller cannot choose a tenant and
-- every requested relationship must be reachable from the server-bound lot.

create or replace function public.get_lot_work_orders(
  p_subject_lot_id text,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with matching as (
    select work_order.*
    from public.work_orders as work_order
    join public.manufacturing_lots as lot
      on lot.tenant_id = work_order.tenant_id
      and lot.snapshot_id = work_order.snapshot_id
      and lot.lot_id = work_order.lot_id
    where lot.lot_id = p_subject_lot_id
      and lot.snapshot_id = p_snapshot_id
    order by work_order.scheduled_start, work_order.source_record_id
    limit 10
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'work_order', 'Connected manufacturing work order',
        row.source_system, row.source_record_id, row.authority,
        row.observed_at, row.effective_from, row.effective_to,
        row.source_version, row.snapshot_id, 'relationship',
        jsonb_build_object(
          'work_order_id', row.work_order_id,
          'work_order_number', row.work_order_number,
          'lot_id', row.lot_id,
          'planned_quantity', row.planned_quantity,
          'priority', row.priority,
          'scheduled_start', row.scheduled_start,
          'scheduled_end', row.scheduled_end,
          'completed_at', row.completed_at,
          'status', row.status
        ), row.content_hash
      ) || jsonb_build_object(
        'relationship_path', array[p_subject_lot_id, row.work_order_id]
      ) order by row.scheduled_start, row.source_record_id
    ), '[]'::jsonb) as value
    from matching as row
  )
  select private_app.tool_envelope(
    'get_lot_work_orders', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'The server-bound subject lot is required.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.get_work_order_operations(
  p_subject_lot_id text,
  p_work_order_id text,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with connected as (
    select work_order.tenant_id, work_order.snapshot_id
    from public.work_orders as work_order
    where work_order.lot_id = p_subject_lot_id
      and work_order.work_order_id = p_work_order_id
      and work_order.snapshot_id = p_snapshot_id
  ), matching as (
    select operation.*
    from public.manufacturing_operations as operation
    join connected using (tenant_id, snapshot_id)
    where operation.work_order_id = p_work_order_id
    order by operation.operation_sequence, operation.source_record_id
    limit 20
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'manufacturing_operation', 'Connected manufacturing operation',
        row.source_system, row.source_record_id, row.authority,
        row.observed_at, row.effective_from, row.effective_to,
        row.source_version, row.snapshot_id, 'relationship',
        jsonb_strip_nulls(jsonb_build_object(
          'operation_id', row.operation_id,
          'work_order_id', row.work_order_id,
          'operation_sequence', row.operation_sequence,
          'operation_code', row.operation_code,
          'operation_name', row.operation_name,
          'specification_code', row.specification_code,
          'recorded_value', row.recorded_value,
          'lower_limit', row.lower_limit,
          'upper_limit', row.upper_limit,
          'unit', row.unit,
          'result', row.result,
          'started_at', row.started_at,
          'completed_at', row.completed_at,
          'operator_alias', row.operator_alias
        )), row.content_hash
      ) || jsonb_build_object(
        'relationship_path', array[p_subject_lot_id, p_work_order_id, row.operation_id]
      ) order by row.operation_sequence, row.source_record_id
    ), '[]'::jsonb) as value
    from matching as row
  )
  select private_app.tool_envelope(
    'get_work_order_operations', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or coalesce(p_work_order_id, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'A connected lot and exact work-order ID are required.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.get_operation_equipment_usage(
  p_subject_lot_id text,
  p_operation_id text,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with connected as (
    select operation.tenant_id, operation.snapshot_id, work_order.work_order_id
    from public.manufacturing_operations as operation
    join public.work_orders as work_order
      on work_order.tenant_id = operation.tenant_id
      and work_order.snapshot_id = operation.snapshot_id
      and work_order.work_order_id = operation.work_order_id
    where work_order.lot_id = p_subject_lot_id
      and operation.operation_id = p_operation_id
      and operation.snapshot_id = p_snapshot_id
  ), matching as (
    select usage.*, connected.work_order_id
    from public.equipment_usage as usage
    join connected using (tenant_id, snapshot_id)
    where usage.operation_id = p_operation_id
    order by usage.used_from, usage.source_record_id
    limit 10
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'equipment_usage', 'Equipment used for connected operation',
        row.source_system, row.source_record_id, row.authority,
        row.observed_at, row.effective_from, row.effective_to,
        row.source_version, row.snapshot_id, 'relationship',
        jsonb_build_object(
          'usage_id', row.usage_id,
          'operation_id', row.operation_id,
          'equipment_id', row.equipment_id,
          'usage_role', row.usage_role,
          'setup_verified', row.setup_verified,
          'used_from', row.used_from,
          'used_to', row.used_to
        ), row.content_hash
      ) || jsonb_build_object(
        'relationship_path', array[p_subject_lot_id, row.work_order_id, p_operation_id, row.equipment_id]
      ) order by row.used_from, row.source_record_id
    ), '[]'::jsonb) as value
    from matching as row
  )
  select private_app.tool_envelope(
    'get_operation_equipment_usage', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or coalesce(p_operation_id, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'A connected lot and exact operation ID are required.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.get_connected_equipment_calibration(
  p_subject_lot_id text,
  p_equipment_id text,
  p_as_of_time timestamptz,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with connected as (
    select distinct usage.tenant_id, usage.snapshot_id
    from public.work_orders as work_order
    join public.manufacturing_operations as operation
      on operation.tenant_id = work_order.tenant_id
      and operation.snapshot_id = work_order.snapshot_id
      and operation.work_order_id = work_order.work_order_id
    join public.equipment_usage as usage
      on usage.tenant_id = operation.tenant_id
      and usage.snapshot_id = operation.snapshot_id
      and usage.operation_id = operation.operation_id
    where work_order.lot_id = p_subject_lot_id
      and usage.equipment_id = p_equipment_id
      and work_order.snapshot_id = p_snapshot_id
  ), matching as (
    select calibration.*
    from public.calibration_records as calibration
    join connected using (tenant_id, snapshot_id)
    where calibration.equipment_id = p_equipment_id
      and calibration.calibrated_at <= p_as_of_time
      and calibration.effective_from <= p_as_of_time
      and (calibration.effective_to is null or calibration.effective_to > p_as_of_time)
    order by calibration.calibrated_at desc, calibration.source_record_id
    limit 5
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'process_equipment_calibration', 'Calibration for connected process equipment',
        row.source_system, row.source_record_id, row.authority,
        row.observed_at, row.effective_from, row.effective_to,
        row.source_version, row.snapshot_id, 'relationship',
        jsonb_build_object(
          'calibration_id', row.calibration_id,
          'equipment_id', row.equipment_id,
          'calibration_status', row.calibration_status,
          'calibrated_at', row.calibrated_at,
          'valid_until', row.valid_until,
          'standard_reference', row.standard_reference
        ), row.content_hash
      ) || jsonb_build_object(
        'relationship_path', array[p_subject_lot_id, 'operations', p_equipment_id, row.calibration_id]
      ) order by row.calibrated_at desc, row.source_record_id
    ), '[]'::jsonb) as value
    from matching as row
  )
  select private_app.tool_envelope(
    'get_connected_equipment_calibration', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or coalesce(p_equipment_id, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'A connected lot and exact process-equipment ID are required.'))
      when not private_app.snapshot_time_matches(p_snapshot_id, p_as_of_time)
        then jsonb_build_array(jsonb_build_object('code', 'SNAPSHOT_MISMATCH', 'message', 'The request time does not match the pinned snapshot.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.get_part_bom(
  p_subject_lot_id text,
  p_part_id text,
  p_as_of_time timestamptz,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with subject as (
    select tenant_id, snapshot_id, observed_part_revision
    from public.manufacturing_lots
    where lot_id = p_subject_lot_id
      and part_id = p_part_id
      and snapshot_id = p_snapshot_id
  ), matching as (
    select bom.*
    from public.bills_of_material as bom
    join subject using (tenant_id, snapshot_id)
    where bom.parent_part_id = p_part_id
      and bom.parent_revision_code = subject.observed_part_revision
      and bom.effective_from <= p_as_of_time
      and (bom.effective_to is null or bom.effective_to > p_as_of_time)
    order by bom.line_number, bom.source_record_id
    limit 20
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'bill_of_material', 'Effective bill-of-material component',
        row.source_system, row.source_record_id, row.authority,
        row.observed_at, row.effective_from, row.effective_to,
        row.source_version, row.snapshot_id, 'relationship',
        jsonb_build_object(
          'bom_item_id', row.bom_item_id,
          'parent_part_id', row.parent_part_id,
          'parent_revision_code', row.parent_revision_code,
          'component_part_id', row.component_part_id,
          'line_number', row.line_number,
          'quantity_per', row.quantity_per,
          'unit', row.unit,
          'is_critical_component', row.is_critical_component
        ), row.content_hash
      ) || jsonb_build_object(
        'relationship_path', array[p_subject_lot_id, p_part_id, row.bom_item_id, row.component_part_id]
      ) order by row.line_number, row.source_record_id
    ), '[]'::jsonb) as value
    from matching as row
  )
  select private_app.tool_envelope(
    'get_part_bom', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or coalesce(p_part_id, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'A connected lot and exact parent-part ID are required.'))
      when not private_app.snapshot_time_matches(p_snapshot_id, p_as_of_time)
        then jsonb_build_array(jsonb_build_object('code', 'SNAPSHOT_MISMATCH', 'message', 'The request time does not match the pinned snapshot.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.get_lot_component_usage(
  p_subject_lot_id text,
  p_bom_item_id text,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with connected as (
    select usage.*
    from public.component_lot_usage as usage
    join public.manufacturing_lots as lot
      on lot.tenant_id = usage.tenant_id
      and lot.snapshot_id = usage.snapshot_id
      and lot.lot_id = usage.lot_id
    join public.bills_of_material as bom
      on bom.tenant_id = usage.tenant_id
      and bom.snapshot_id = usage.snapshot_id
      and bom.bom_item_id = usage.bom_item_id
      and bom.parent_part_id = lot.part_id
    where lot.lot_id = p_subject_lot_id
      and usage.bom_item_id = p_bom_item_id
      and lot.snapshot_id = p_snapshot_id
    order by usage.consumed_at, usage.source_record_id
    limit 10
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'component_lot_usage', 'Material batch consumed by subject lot',
        row.source_system, row.source_record_id, row.authority,
        row.observed_at, row.effective_from, row.effective_to,
        row.source_version, row.snapshot_id, 'relationship',
        jsonb_build_object(
          'component_usage_id', row.component_usage_id,
          'lot_id', row.lot_id,
          'bom_item_id', row.bom_item_id,
          'material_batch_id', row.material_batch_id,
          'quantity_consumed', row.quantity_consumed,
          'consumed_at', row.consumed_at
        ), row.content_hash
      ) || jsonb_build_object(
        'relationship_path', array[p_subject_lot_id, p_bom_item_id, row.material_batch_id]
      ) order by row.consumed_at, row.source_record_id
    ), '[]'::jsonb) as value
    from connected as row
  )
  select private_app.tool_envelope(
    'get_lot_component_usage', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or coalesce(p_bom_item_id, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'A connected lot and exact BOM-item ID are required.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.get_material_batch_records(
  p_subject_lot_id text,
  p_material_batch_id text,
  p_as_of_time timestamptz,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with connected as (
    select usage.tenant_id, usage.snapshot_id
    from public.component_lot_usage as usage
    where usage.lot_id = p_subject_lot_id
      and usage.material_batch_id = p_material_batch_id
      and usage.snapshot_id = p_snapshot_id
  ), evidence as (
    select 1 as sort_order, batch.source_record_id as sort_id,
      private_app.evidence_item(
        'material_batch', 'Connected component material batch',
        batch.source_system, batch.source_record_id, batch.authority,
        batch.observed_at, batch.effective_from, batch.effective_to,
        batch.source_version, batch.snapshot_id, 'relationship',
        jsonb_build_object(
          'material_batch_id', batch.material_batch_id,
          'material_batch_number', batch.material_batch_number,
          'component_part_id', batch.component_part_id,
          'supplier_id', batch.supplier_id,
          'received_at', batch.received_at,
          'expires_at', batch.expires_at,
          'inventory_status', batch.inventory_status
        ), batch.content_hash
      ) || jsonb_build_object(
        'relationship_path', array[p_subject_lot_id, p_material_batch_id]
      ) as item
    from public.material_batches as batch
    join connected using (tenant_id, snapshot_id)
    where batch.material_batch_id = p_material_batch_id
      and batch.received_at <= p_as_of_time
    union all
    select 2, certificate.source_record_id,
      private_app.evidence_item(
        'material_certificate', 'Certificate for connected material batch',
        certificate.source_system, certificate.source_record_id, certificate.authority,
        certificate.observed_at, certificate.effective_from, certificate.effective_to,
        certificate.source_version, certificate.snapshot_id, 'relationship',
        jsonb_build_object(
          'material_certificate_id', certificate.material_certificate_id,
          'material_batch_id', certificate.material_batch_id,
          'certificate_number', certificate.certificate_number,
          'verification_status', certificate.verification_status,
          'specification_code', certificate.specification_code,
          'measured_value', certificate.measured_value,
          'lower_limit', certificate.lower_limit,
          'upper_limit', certificate.upper_limit,
          'unit', certificate.unit,
          'issued_at', certificate.issued_at,
          'verified_at', certificate.verified_at
        ), certificate.content_hash
      ) || jsonb_build_object(
        'relationship_path', array[p_subject_lot_id, p_material_batch_id, certificate.material_certificate_id]
      )
    from public.material_certificates as certificate
    join connected using (tenant_id, snapshot_id)
    where certificate.material_batch_id = p_material_batch_id
      and certificate.issued_at <= p_as_of_time
  ), items as (
    select coalesce(jsonb_agg(item order by sort_order, sort_id), '[]'::jsonb) as value
    from evidence
  )
  select private_app.tool_envelope(
    'get_material_batch_records', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or coalesce(p_material_batch_id, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'A connected lot and exact material-batch ID are required.'))
      when not private_app.snapshot_time_matches(p_snapshot_id, p_as_of_time)
        then jsonb_build_array(jsonb_build_object('code', 'SNAPSHOT_MISMATCH', 'message', 'The request time does not match the pinned snapshot.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.get_engineering_change_orders(
  p_subject_lot_id text,
  p_part_id text,
  p_as_of_time timestamptz,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with connected as (
    select tenant_id, snapshot_id
    from public.manufacturing_lots
    where lot_id = p_subject_lot_id
      and part_id = p_part_id
      and snapshot_id = p_snapshot_id
  ), matching as (
    select change_order.*
    from public.engineering_change_orders as change_order
    join connected using (tenant_id, snapshot_id)
    where change_order.part_id = p_part_id
      and change_order.effective_from <= p_as_of_time
    order by change_order.effective_from desc, change_order.source_record_id
    limit 10
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'engineering_change_order', 'Connected engineering change order',
        row.source_system, row.source_record_id, row.authority,
        row.observed_at, row.effective_from, row.effective_to,
        row.source_version, row.snapshot_id, 'relationship',
        jsonb_strip_nulls(jsonb_build_object(
          'change_order_id', row.change_order_id,
          'part_id', row.part_id,
          'from_revision_code', row.from_revision_code,
          'to_revision_code', row.to_revision_code,
          'change_type', row.change_type,
          'status', row.status,
          'reason', row.reason,
          'approved_at', row.approved_at,
          'implementation_effective_at', row.implementation_effective_at
        )), row.content_hash
      ) || jsonb_build_object(
        'relationship_path', array[p_subject_lot_id, p_part_id, row.change_order_id]
      ) order by row.effective_from desc, row.source_record_id
    ), '[]'::jsonb) as value
    from matching as row
  )
  select private_app.tool_envelope(
    'get_engineering_change_orders', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or coalesce(p_part_id, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'A connected lot and exact part ID are required.'))
      when not private_app.snapshot_time_matches(p_snapshot_id, p_as_of_time)
        then jsonb_build_array(jsonb_build_object('code', 'SNAPSHOT_MISMATCH', 'message', 'The request time does not match the pinned snapshot.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

revoke all on function public.get_lot_work_orders(text, text) from public, anon;
revoke all on function public.get_work_order_operations(text, text, text) from public, anon;
revoke all on function public.get_operation_equipment_usage(text, text, text) from public, anon;
revoke all on function public.get_connected_equipment_calibration(text, text, timestamptz, text) from public, anon;
revoke all on function public.get_part_bom(text, text, timestamptz, text) from public, anon;
revoke all on function public.get_lot_component_usage(text, text, text) from public, anon;
revoke all on function public.get_material_batch_records(text, text, timestamptz, text) from public, anon;
revoke all on function public.get_engineering_change_orders(text, text, timestamptz, text) from public, anon;

grant execute on function public.get_lot_work_orders(text, text) to authenticated, service_role;
grant execute on function public.get_work_order_operations(text, text, text) to authenticated, service_role;
grant execute on function public.get_operation_equipment_usage(text, text, text) to authenticated, service_role;
grant execute on function public.get_connected_equipment_calibration(text, text, timestamptz, text) to authenticated, service_role;
grant execute on function public.get_part_bom(text, text, timestamptz, text) to authenticated, service_role;
grant execute on function public.get_lot_component_usage(text, text, text) to authenticated, service_role;
grant execute on function public.get_material_batch_records(text, text, timestamptz, text) to authenticated, service_role;
grant execute on function public.get_engineering_change_orders(text, text, timestamptz, text) to authenticated, service_role;
