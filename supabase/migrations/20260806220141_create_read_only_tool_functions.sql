-- Narrow, read-only RPC functions used by the backend tool gateway. All are
-- SECURITY INVOKER: authenticated-table grants and RLS remain authoritative.

create or replace function private_app.tool_envelope(
  p_tool_name text,
  p_snapshot_id text,
  p_items jsonb,
  p_errors jsonb
)
returns jsonb
language sql
immutable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'ok', p_errors = '[]'::jsonb,
    'tool_name', p_tool_name,
    'tool_contract_version', '1.0',
    'data_snapshot_id', p_snapshot_id,
    'items', coalesce(p_items, '[]'::jsonb),
    'excluded_unauthorized_count', 0,
    'next_page_token', null,
    'warnings', '[]'::jsonb,
    'errors', coalesce(p_errors, '[]'::jsonb),
    'duration_ms', 0
  );
$$;

create or replace function private_app.evidence_item(
  p_evidence_class text,
  p_title text,
  p_source_system text,
  p_source_record_id text,
  p_authority text,
  p_observed_at timestamptz,
  p_effective_from timestamptz,
  p_effective_to timestamptz,
  p_source_version text,
  p_snapshot_id text,
  p_retrieval_route text,
  p_content jsonb,
  p_content_hash text
)
returns jsonb
language sql
immutable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'evidence_id', p_source_record_id,
    'evidence_class', p_evidence_class,
    'title', p_title,
    'source_system', p_source_system,
    'source_record_id', p_source_record_id,
    'authority', p_authority,
    'observed_at', p_observed_at,
    'effective_from', p_effective_from,
    'effective_to', p_effective_to,
    'source_version', p_source_version,
    'snapshot_id', p_snapshot_id,
    'retrieval_route', p_retrieval_route,
    'content', p_content,
    'content_hash', p_content_hash
  );
$$;

create or replace function private_app.snapshot_time_matches(
  p_snapshot_id text,
  p_as_of_time timestamptz
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.dataset_snapshots
    where snapshot_id = p_snapshot_id
      and as_of_time = p_as_of_time
  );
$$;

revoke all on function private_app.tool_envelope(text, text, jsonb, jsonb) from public, anon;
revoke all on function private_app.evidence_item(text, text, text, text, text, timestamptz, timestamptz, timestamptz, text, text, text, jsonb, text) from public, anon;
revoke all on function private_app.snapshot_time_matches(text, timestamptz) from public, anon;
grant execute on function private_app.tool_envelope(text, text, jsonb, jsonb) to authenticated, service_role;
grant execute on function private_app.evidence_item(text, text, text, text, text, timestamptz, timestamptz, timestamptz, text, text, text, jsonb, text) to authenticated, service_role;
grant execute on function private_app.snapshot_time_matches(text, timestamptz) to authenticated, service_role;

create or replace function public.get_decision_profile(
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
  with matching as (
    select private_app.evidence_item(
      'decision_profile',
      'Manufacturing lot disposition decision profile',
      profile.source_system,
      profile.source_record_id,
      profile.authority,
      profile.observed_at,
      profile.effective_from,
      profile.effective_to,
      profile.source_version,
      profile.snapshot_id,
      'exact',
      jsonb_build_object(
        'profile_id', profile.profile_id,
        'profile_version', profile.profile_version,
        'task_type', profile.task_type,
        'required_evidence_classes', profile.required_evidence_classes,
        'freshness_rules', profile.freshness_rules,
        'source_precedence', profile.source_precedence,
        'hold_rules', profile.hold_rules,
        'escalation_rules', profile.escalation_rules,
        'retrieval_limits', profile.retrieval_limits,
        'active_from', profile.active_from,
        'active_to', profile.active_to
      ),
      profile.content_hash
    ) as item
    from public.decision_profiles as profile
    where profile.profile_id = p_profile_id
      and profile.profile_version = p_profile_version
      and profile.snapshot_id = p_snapshot_id
  )
  select private_app.tool_envelope(
    'get_decision_profile',
    p_snapshot_id,
    coalesce((select jsonb_agg(item) from matching), '[]'::jsonb),
    case
      when coalesce(p_profile_id, '') = '' or coalesce(p_profile_version, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'Profile ID and version are required.'))
      when not exists (select 1 from matching)
        then jsonb_build_array(jsonb_build_object('code', 'PROFILE_VERSION_MISMATCH', 'message', 'No authorized profile matched the exact ID, version and snapshot.'))
      else '[]'::jsonb
    end
  );
$$;

create or replace function public.get_lot_record(
  p_lot_id text,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with subject as (
    select *
    from public.manufacturing_lots
    where lot_id = p_lot_id
      and snapshot_id = p_snapshot_id
  ), evidence as (
    select 1 as sort_order, lot.source_record_id as sort_id,
      private_app.evidence_item(
        'lot_record', 'Manufacturing lot record', lot.source_system,
        lot.source_record_id, lot.authority, lot.observed_at, lot.effective_from,
        lot.effective_to, lot.source_version, lot.snapshot_id, 'direct',
        jsonb_build_object(
          'lot_id', lot.lot_id, 'lot_number', lot.lot_number,
          'part_id', lot.part_id, 'supplier_id', lot.supplier_id,
          'inspection_equipment_id', lot.inspection_equipment_id,
          'observed_part_revision', lot.observed_part_revision,
          'quantity', lot.quantity, 'manufactured_at', lot.manufactured_at,
          'status', lot.status
        ), lot.content_hash
      ) as item
    from subject as lot
    union all
    select 2, inspection.source_record_id,
      private_app.evidence_item(
        'final_inspection', 'Final inspection record', inspection.source_system,
        inspection.source_record_id, inspection.authority, inspection.observed_at,
        inspection.effective_from, inspection.effective_to, inspection.source_version,
        inspection.snapshot_id, 'direct',
        jsonb_build_object(
          'inspection_id', inspection.inspection_id, 'lot_id', inspection.lot_id,
          'inspection_type', inspection.inspection_type, 'result', inspection.result,
          'critical_defect_count', inspection.critical_defect_count,
          'major_defect_count', inspection.major_defect_count,
          'minor_defect_count', inspection.minor_defect_count,
          'inspector_alias', inspection.inspector_alias,
          'completed_at', inspection.completed_at
        ), inspection.content_hash
      )
    from public.inspections as inspection
    join subject as lot on lot.lot_id = inspection.lot_id
      and lot.tenant_id = inspection.tenant_id and lot.snapshot_id = inspection.snapshot_id
    union all
    select 3, certificate.source_record_id,
      private_app.evidence_item(
        'certificate_of_analysis', 'Certificate of analysis', certificate.source_system,
        certificate.source_record_id, certificate.authority, certificate.observed_at,
        certificate.effective_from, certificate.effective_to, certificate.source_version,
        certificate.snapshot_id, 'direct',
        jsonb_build_object(
          'certificate_id', certificate.certificate_id, 'lot_id', certificate.lot_id,
          'certificate_number', certificate.certificate_number,
          'verification_status', certificate.verification_status,
          'issuer_name', certificate.issuer_name, 'issued_at', certificate.issued_at,
          'verified_at', certificate.verified_at
        ), certificate.content_hash
      )
    from public.certificates_of_analysis as certificate
    join subject as lot on lot.lot_id = certificate.lot_id
      and lot.tenant_id = certificate.tenant_id and lot.snapshot_id = certificate.snapshot_id
  ), items as (
    select coalesce(jsonb_agg(item order by sort_order, sort_id), '[]'::jsonb) as value
    from evidence
  )
  select private_app.tool_envelope(
    'get_lot_record', p_snapshot_id, items.value,
    case when coalesce(p_lot_id, '') = ''
      then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'Exact lot ID is required.'))
      else '[]'::jsonb end
  )
  from items;
$$;

create or replace function public.get_supplier_quality_history(
  p_subject_lot_id text,
  p_supplier_id text,
  p_part_id text,
  p_as_of_time timestamptz,
  p_lookback_days integer,
  p_limit integer,
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
      and supplier_id = p_supplier_id
      and part_id = p_part_id
      and snapshot_id = p_snapshot_id
  ), matching as (
    select event.*
    from public.supplier_quality_events as event
    join connected using (tenant_id, snapshot_id)
    where event.supplier_id = p_supplier_id
      and event.part_id = p_part_id
      and event.event_at <= p_as_of_time
      and event.event_at >= p_as_of_time - make_interval(days => p_lookback_days)
    order by event.event_at desc, event.source_record_id
    limit least(p_limit, 20)
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'supplier_part_family_history', 'Connected supplier quality event',
        event.source_system, event.source_record_id, event.authority,
        event.observed_at, event.effective_from, event.effective_to,
        event.source_version, event.snapshot_id, 'relationship',
        jsonb_strip_nulls(jsonb_build_object(
          'quality_event_id', event.quality_event_id, 'supplier_id', event.supplier_id,
          'part_id', event.part_id, 'related_lot_number', event.related_lot_number,
          'outcome', event.outcome, 'failure_category', event.failure_category,
          'event_at', event.event_at
        )), event.content_hash
      ) order by event.event_at desc, event.source_record_id
    ), '[]'::jsonb) as value
    from matching as event
  )
  select private_app.tool_envelope(
    'get_supplier_quality_history', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or coalesce(p_supplier_id, '') = '' or coalesce(p_part_id, '') = ''
        or p_lookback_days not between 1 and 365 or p_limit not between 1 and 20
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'Connected IDs, a 1-365 day lookback and a 1-20 limit are required.'))
      when not private_app.snapshot_time_matches(p_snapshot_id, p_as_of_time)
        then jsonb_build_array(jsonb_build_object('code', 'SNAPSHOT_MISMATCH', 'message', 'The request time does not match the pinned snapshot.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.get_equipment_calibration(
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
    select tenant_id, snapshot_id
    from public.manufacturing_lots
    where lot_id = p_subject_lot_id
      and inspection_equipment_id = p_equipment_id
      and snapshot_id = p_snapshot_id
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
        'equipment_calibration', 'Connected equipment calibration',
        calibration.source_system, calibration.source_record_id, calibration.authority,
        calibration.observed_at, calibration.effective_from, calibration.effective_to,
        calibration.source_version, calibration.snapshot_id, 'relationship',
        jsonb_build_object(
          'calibration_id', calibration.calibration_id,
          'equipment_id', calibration.equipment_id,
          'calibration_status', calibration.calibration_status,
          'calibrated_at', calibration.calibrated_at,
          'valid_until', calibration.valid_until,
          'standard_reference', calibration.standard_reference
        ), calibration.content_hash
      ) order by calibration.calibrated_at desc, calibration.source_record_id
    ), '[]'::jsonb) as value
    from matching as calibration
  )
  select private_app.tool_envelope(
    'get_equipment_calibration', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or coalesce(p_equipment_id, '') = ''
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'A connected lot and exact equipment ID are required.'))
      when not private_app.snapshot_time_matches(p_snapshot_id, p_as_of_time)
        then jsonb_build_array(jsonb_build_object('code', 'SNAPSHOT_MISMATCH', 'message', 'The request time does not match the pinned snapshot.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.get_released_part_revision(
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
    where lot_id = p_subject_lot_id and part_id = p_part_id and snapshot_id = p_snapshot_id
  ), matching as (
    select revision.*
    from public.engineering_revisions as revision
    join connected using (tenant_id, snapshot_id)
    where revision.part_id = p_part_id
      and revision.release_status = 'RELEASED'
      and revision.effective_from <= p_as_of_time
      and (revision.effective_to is null or revision.effective_to > p_as_of_time)
    order by revision.effective_from desc, revision.revision_code, revision.source_record_id
    limit 10
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'released_revision_alignment', 'Active released engineering revision',
        revision.source_system, revision.source_record_id, revision.authority,
        revision.observed_at, revision.effective_from, revision.effective_to,
        revision.source_version, revision.snapshot_id, 'relationship',
        jsonb_build_object(
          'revision_id', revision.revision_id, 'part_id', revision.part_id,
          'revision_code', revision.revision_code,
          'release_status', revision.release_status,
          'released_at', revision.released_at
        ), revision.content_hash
      ) order by revision.effective_from desc, revision.revision_code, revision.source_record_id
    ), '[]'::jsonb) as value
    from matching as revision
  )
  select private_app.tool_envelope(
    'get_released_part_revision', p_snapshot_id, items.value,
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

create or replace function public.get_open_deviations(
  p_lot_id text,
  p_related_subject_types text[],
  p_as_of_time timestamptz,
  p_max_relationship_depth integer,
  p_limit integer,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with subject as (
    select * from public.manufacturing_lots
    where lot_id = p_lot_id and snapshot_id = p_snapshot_id
  ), matching as (
    select deviation.*,
      case
        when deviation.lot_id = subject.lot_id then array['lot', deviation.lot_id]
        when deviation.part_id = subject.part_id then array['lot', subject.lot_id, 'part', deviation.part_id]
        when deviation.supplier_id = subject.supplier_id then array['lot', subject.lot_id, 'supplier', deviation.supplier_id]
        when deviation.equipment_id = subject.inspection_equipment_id then array['lot', subject.lot_id, 'equipment', deviation.equipment_id]
      end as relationship_path
    from public.deviations as deviation
    join subject on subject.tenant_id = deviation.tenant_id
      and subject.snapshot_id = deviation.snapshot_id
    where deviation.status in ('OPEN', 'APPROVED')
      and deviation.opened_at <= p_as_of_time
      and (
        deviation.lot_id = subject.lot_id
        or (
          p_max_relationship_depth >= 1
          and (
            ('part' = any(p_related_subject_types) and deviation.part_id = subject.part_id)
            or ('supplier' = any(p_related_subject_types) and deviation.supplier_id = subject.supplier_id)
            or ('equipment' = any(p_related_subject_types) and deviation.equipment_id = subject.inspection_equipment_id)
          )
        )
      )
    order by deviation.opened_at desc, deviation.source_record_id
    limit least(p_limit, 20)
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'open_deviation_check', 'Connected open or unresolved deviation',
        deviation.source_system, deviation.source_record_id, deviation.authority,
        deviation.observed_at, deviation.effective_from, deviation.effective_to,
        deviation.source_version, deviation.snapshot_id, 'relationship',
        jsonb_strip_nulls(jsonb_build_object(
          'deviation_id', deviation.deviation_id, 'lot_id', deviation.lot_id,
          'part_id', deviation.part_id, 'supplier_id', deviation.supplier_id,
          'equipment_id', deviation.equipment_id, 'status', deviation.status,
          'severity', deviation.severity, 'opened_at', deviation.opened_at,
          'closed_at', deviation.closed_at, 'description', deviation.description
        )), deviation.content_hash
      ) || jsonb_build_object('relationship_path', deviation.relationship_path)
      order by deviation.opened_at desc, deviation.source_record_id
    ), '[]'::jsonb) as value
    from matching as deviation
  )
  select private_app.tool_envelope(
    'get_open_deviations', p_snapshot_id, items.value,
    case
      when coalesce(p_lot_id, '') = '' or p_max_relationship_depth not between 0 and 2
        or p_limit not between 1 and 20
        or p_related_subject_types is null
        or not (p_related_subject_types <@ array['part', 'supplier', 'equipment']::text[])
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'Use an exact lot, approved relationship types, depth 0-2 and limit 1-20.'))
      when not private_app.snapshot_time_matches(p_snapshot_id, p_as_of_time)
        then jsonb_build_array(jsonb_build_object('code', 'SNAPSHOT_MISMATCH', 'message', 'The request time does not match the pinned snapshot.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

create or replace function public.search_manufacturing_notes(
  p_subject_lot_id text,
  p_subject_ids text[],
  p_query text,
  p_as_of_time timestamptz,
  p_limit integer,
  p_snapshot_id text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with subject as (
    select * from public.manufacturing_lots
    where lot_id = p_subject_lot_id and snapshot_id = p_snapshot_id
  ), matching as (
    select note.*,
      ts_rank_cd(
        note.fts,
        websearch_to_tsquery(
          'english'::regconfig,
          regexp_replace(trim(p_query), '[^[:alnum:]_]+', ' OR ', 'g')
        )
      ) as retrieval_score
    from public.manufacturing_notes as note
    join subject on subject.tenant_id = note.tenant_id and subject.snapshot_id = note.snapshot_id
    where note.signed_at <= p_as_of_time
      and note.fts @@ websearch_to_tsquery(
        'english'::regconfig,
        regexp_replace(trim(p_query), '[^[:alnum:]_]+', ' OR ', 'g')
      )
      and (
        (note.lot_id = subject.lot_id and note.lot_id = any(p_subject_ids))
        or (note.part_id = subject.part_id and note.part_id = any(p_subject_ids))
        or (note.equipment_id = subject.inspection_equipment_id and note.equipment_id = any(p_subject_ids))
      )
    order by retrieval_score desc, note.signed_at desc, note.source_record_id
    limit least(p_limit, 10)
  ), items as (
    select coalesce(jsonb_agg(
      private_app.evidence_item(
        'authorized_narrative_conflict_check', 'Authorized manufacturing note',
        note.source_system, note.source_record_id, note.authority,
        note.observed_at, note.effective_from, note.effective_to,
        note.source_version, note.snapshot_id, 'full_text',
        jsonb_strip_nulls(jsonb_build_object(
          'note_id', note.note_id, 'lot_id', note.lot_id, 'part_id', note.part_id,
          'equipment_id', note.equipment_id, 'note_type', note.note_type,
          'body', note.body, 'signed_by_alias', note.signed_by_alias,
          'signed_at', note.signed_at
        )), note.content_hash
      ) || jsonb_build_object(
        'retrieval_score', note.retrieval_score,
        'source_text_is_untrusted', true
      ) order by note.retrieval_score desc, note.signed_at desc, note.source_record_id
    ), '[]'::jsonb) as value
    from matching as note
  )
  select private_app.tool_envelope(
    'search_manufacturing_notes', p_snapshot_id, items.value,
    case
      when coalesce(p_subject_lot_id, '') = '' or p_subject_ids is null or cardinality(p_subject_ids) < 1
        or length(trim(coalesce(p_query, ''))) not between 2 and 200
        or p_limit not between 1 and 10
        then jsonb_build_array(jsonb_build_object('code', 'INVALID_ARGUMENT', 'message', 'Bounded subjects, a 2-200 character query and limit 1-10 are required.'))
      when not private_app.snapshot_time_matches(p_snapshot_id, p_as_of_time)
        then jsonb_build_array(jsonb_build_object('code', 'SNAPSHOT_MISMATCH', 'message', 'The request time does not match the pinned snapshot.'))
      else '[]'::jsonb
    end
  )
  from items;
$$;

revoke all on function public.get_decision_profile(text, text, text) from public, anon;
revoke all on function public.get_lot_record(text, text) from public, anon;
revoke all on function public.get_supplier_quality_history(text, text, text, timestamptz, integer, integer, text) from public, anon;
revoke all on function public.get_equipment_calibration(text, text, timestamptz, text) from public, anon;
revoke all on function public.get_released_part_revision(text, text, timestamptz, text) from public, anon;
revoke all on function public.get_open_deviations(text, text[], timestamptz, integer, integer, text) from public, anon;
revoke all on function public.search_manufacturing_notes(text, text[], text, timestamptz, integer, text) from public, anon;

grant execute on function public.get_decision_profile(text, text, text) to authenticated, service_role;
grant execute on function public.get_lot_record(text, text) to authenticated, service_role;
grant execute on function public.get_supplier_quality_history(text, text, text, timestamptz, integer, integer, text) to authenticated, service_role;
grant execute on function public.get_equipment_calibration(text, text, timestamptz, text) to authenticated, service_role;
grant execute on function public.get_released_part_revision(text, text, timestamptz, text) to authenticated, service_role;
grant execute on function public.get_open_deviations(text, text[], timestamptz, integer, integer, text) to authenticated, service_role;
grant execute on function public.search_manufacturing_notes(text, text[], text, timestamptz, integer, text) to authenticated, service_role;
