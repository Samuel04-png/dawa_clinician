-- Follow-up fix for RISK_ALERT_DELIVERY_FAILED on Dawa Mom risk-alert events.
-- The 202609240001 RPC inserted mother.id (text 'dawa_mom_...') into
-- clinician_risk_alerts.patient_id (uuid), failing with SQLSTATE 42804.
-- Canonical UUID is p_source_mother_id (raw mother uuid); patient_source_id
-- keeps the text form. This replaces only the function body/grants; the
-- clinician_risk_alerts table and RLS from 202609240001 are unchanged.
begin;

create or replace function public.apply_dawa_mom_risk_alert(
  p_event_id uuid,
  p_event_type text,
  p_source_alert_id uuid,
  p_source_mother_id uuid,
  p_alert_type text,
  p_severity text,
  p_status text,
  p_title text,
  p_summary text,
  p_details text,
  p_recommendation text,
  p_vital_context jsonb,
  p_provenance text,
  p_detected_at timestamptz,
  p_acknowledged_at timestamptz,
  p_resolved_at timestamptz,
  p_dismissed_at timestamptz,
  p_source_created_at timestamptz,
  p_source_updated_at timestamptz,
  p_source_deleted_at timestamptz default null,
  p_source_record jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  previous_result jsonb;
  existing_row public.clinician_risk_alerts%rowtype;
  conflicting_row public.clinician_risk_alerts%rowtype;
  patient_row public.mother%rowtype;
  normalized_event text := lower(trim(coalesce(p_event_type, '')));
  normalized_severity text := lower(trim(coalesce(p_severity, '')));
  normalized_status text := lower(trim(coalesce(p_status, '')));
  is_archive boolean;
  effective_updated_at timestamptz;
  destination_id uuid;
  result_status text;
  action text;
  result_payload jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));
  perform pg_advisory_xact_lock(hashtextextended(
    'dawa-mom-risk-alert:' || p_source_alert_id::text,
    0
  ));

  -- Replay protection: a repeated event id returns the stored safe result and
  -- never writes a second time.
  select e.result into previous_result
  from public.integration_processed_events e
  where e.source = 'dawa_mom'
    and e.event_id = p_event_id;

  if previous_result is not null then
    return previous_result;
  end if;

  if normalized_event not in ('risk_alert.upsert', 'risk_alert.archived') then
    raise exception using
      errcode = '22023',
      message = 'Unsupported risk alert event type';
  end if;

  if p_source_alert_id is null or p_source_mother_id is null then
    raise exception using
      errcode = '22023',
      message = 'Risk alert and source mother identifiers are required';
  end if;

  is_archive := normalized_event = 'risk_alert.archived'
    or p_source_deleted_at is not null;

  if not is_archive then
    if normalized_severity is null or normalized_severity not in (
      'low', 'moderate', 'high', 'critical'
    ) then
      raise exception using
        errcode = '22023',
        message = 'Unsupported risk alert severity';
    end if;

    if normalized_status is null or normalized_status not in (
      'open', 'acknowledged', 'resolved', 'dismissed', 'archived'
    ) then
      raise exception using
        errcode = '22023',
        message = 'Unsupported risk alert status';
    end if;

    if length(trim(coalesce(p_title, ''))) < 3 then
      raise exception using
        errcode = '22023',
        message = 'Risk alert title is required';
    end if;
  end if;

  select * into patient_row
  from public.mother m
  where m.source_project = 'dawa_mom'
    and m.source_mother_id = p_source_mother_id::text
    and m.source_deleted_at is null
  limit 1;

  if patient_row.id is null then
    raise exception using
      errcode = 'P0002',
      message = 'Mapped patient was not found';
  end if;

  select * into existing_row
  from public.clinician_risk_alerts a
  where a.source_project = 'dawa_mom'
    and a.source_alert_id = p_source_alert_id::text
  for update;

  if existing_row.id is null then
    -- The source alert id is also the preferred mirror id. Refuse to take over an
    -- identifier that already belongs to a clinician-owned record instead of
    -- silently overwriting it.
    select * into conflicting_row
    from public.clinician_risk_alerts a
    where a.id = p_source_alert_id
    for update;

    if conflicting_row.id is not null then
      raise exception using
        errcode = '23505',
        message = 'Risk alert identifier is already used by a clinician record';
    end if;
  end if;

  effective_updated_at := coalesce(p_source_updated_at, now());

  if existing_row.id is not null
     and existing_row.source_updated_at is not null
     and p_source_updated_at is not null
     and p_source_updated_at <= existing_row.source_updated_at then
    -- Out-of-order or replayed snapshot: never overwrite a newer mirror row and
    -- never insert a duplicate one.
    destination_id := existing_row.id;
    result_status := existing_row.status;
    action := 'stale_noop';
  elsif is_archive then
    if existing_row.id is null then
      -- Deleting a source alert that never reached Dawa Clinician is a successful
      -- no-op, not an error.
      destination_id := null;
      result_status := null;
      action := 'missing';
    else
      update public.clinician_risk_alerts a
      set status = 'archived',
          source_deleted_at = coalesce(p_source_deleted_at, now()),
          source_updated_at = effective_updated_at,
          source_payload = coalesce(p_source_record, a.source_payload),
          synced_at = now()
      where a.id = existing_row.id
      returning a.id, a.status into destination_id, result_status;

      action := 'archived';
    end if;
  elsif existing_row.id is null then
    insert into public.clinician_risk_alerts (
      id,
      mother_id,
      source_project,
      source_alert_id,
      patient_id,
      patient_source_id,
      alert_type,
      severity,
      status,
      title,
      summary,
      details,
      recommendation,
      vital_context,
      provenance,
      detected_at,
      acknowledged_at,
      resolved_at,
      dismissed_at,
      status_updated_at,
      source_created_at,
      source_updated_at,
      source_payload,
      synced_at
    ) values (
      p_source_alert_id,
      p_source_mother_id,
      'dawa_mom',
      p_source_alert_id::text,
      p_source_mother_id,
      p_source_mother_id::text,
      coalesce(nullif(trim(p_alert_type), ''), 'maternal_risk'),
      normalized_severity,
      normalized_status,
      trim(p_title),
      nullif(trim(coalesce(p_summary, '')), ''),
      nullif(trim(coalesce(p_details, '')), ''),
      nullif(trim(coalesce(p_recommendation, '')), ''),
      coalesce(p_vital_context, '{}'::jsonb),
      coalesce(nullif(trim(p_provenance), ''), 'dawa_mom'),
      coalesce(p_detected_at, p_source_created_at, effective_updated_at),
      p_acknowledged_at,
      p_resolved_at,
      p_dismissed_at,
      effective_updated_at,
      p_source_created_at,
      effective_updated_at,
      coalesce(p_source_record, '{}'::jsonb),
      now()
    )
    returning id, status into destination_id, result_status;

    action := 'inserted';
  else
    update public.clinician_risk_alerts a
    set mother_id = p_source_mother_id,
        patient_id = p_source_mother_id,
        patient_source_id = p_source_mother_id::text,
        alert_type = coalesce(nullif(trim(p_alert_type), ''), a.alert_type),
        severity = normalized_severity,
        status = normalized_status,
        title = trim(p_title),
        summary = nullif(trim(coalesce(p_summary, '')), ''),
        details = nullif(trim(coalesce(p_details, '')), ''),
        recommendation = nullif(trim(coalesce(p_recommendation, '')), ''),
        vital_context = coalesce(p_vital_context, a.vital_context),
        provenance = coalesce(nullif(trim(p_provenance), ''), a.provenance),
        detected_at = coalesce(p_detected_at, a.detected_at),
        acknowledged_at = p_acknowledged_at,
        resolved_at = p_resolved_at,
        dismissed_at = p_dismissed_at,
        status_updated_at = effective_updated_at,
        source_created_at = coalesce(a.source_created_at, p_source_created_at),
        source_updated_at = effective_updated_at,
        source_deleted_at = null,
        source_payload = coalesce(p_source_record, a.source_payload),
        synced_at = now()
    where a.id = existing_row.id
    returning a.id, a.status into destination_id, result_status;

    action := 'updated';
  end if;

  result_payload := jsonb_build_object(
    'ok', true,
    'event_id', p_event_id,
    'alert_id', destination_id,
    'patient_id', p_source_mother_id,
    'action', action,
    'status', result_status,
    'received_at', now()
  );

  insert into public.integration_processed_events (
    source,
    event_id,
    event_type,
    aggregate_id,
    destination_id,
    result
  ) values (
    'dawa_mom',
    p_event_id,
    normalized_event,
    p_source_alert_id::text,
    destination_id::text,
    result_payload
  );

  return result_payload;
end;
$$;

revoke all on function public.apply_dawa_mom_risk_alert(
  uuid, text, uuid, uuid, text, text, text, text, text, text, text, jsonb, text,
  timestamptz, timestamptz, timestamptz, timestamptz, timestamptz, timestamptz,
  timestamptz, jsonb
) from public, anon, authenticated;
grant execute on function public.apply_dawa_mom_risk_alert(
  uuid, text, uuid, uuid, text, text, text, text, text, text, text, jsonb, text,
  timestamptz, timestamptz, timestamptz, timestamptz, timestamptz, timestamptz,
  timestamptz, jsonb
) to service_role;

comment on table public.clinician_risk_alerts is
  'Read-only mirror of Dawa Mom clinician_risk_alerts, kept current by the existing integration_processed_events receiver contract.';

comment on function public.apply_dawa_mom_risk_alert(
  uuid, text, uuid, uuid, text, text, text, text, text, text, text, jsonb, text,
  timestamptz, timestamptz, timestamptz, timestamptz, timestamptz, timestamptz,
  timestamptz, jsonb
) is
  'Idempotently applies trusted Dawa Mom risk-alert events, preserving the source alert id and never duplicating a mirrored alert.';

commit;
