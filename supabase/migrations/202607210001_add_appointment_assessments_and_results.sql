-- Appointment-linked clinical assessments and patient-safe result summaries.
--
-- Existing encounter rows and legacy encounter screens are preserved. New
-- Dawa Mom appointment encounters are writable only through the assigned-
-- clinician RPCs below. Completion, summary creation, appointment transition,
-- audit, and outbox enqueue happen in one transaction.

begin;

alter table public.mother
  add column if not exists source_pregnancy_status text,
  add column if not exists source_pregnancy_lnmp date,
  add column if not exists source_pregnancy_estimated_due_date date,
  add column if not exists source_pregnancy_updated_at timestamptz,
  add column if not exists source_pregnancy_provenance text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'mother_source_pregnancy_status_check'
      and conrelid = 'public.mother'::regclass
  ) then
    alter table public.mother
      add constraint mother_source_pregnancy_status_check check (
        source_pregnancy_status is null or source_pregnancy_status in (
          'pregnant', 'not_pregnant', 'not_provided', 'prefer_not_to_say'
        )
      );
  end if;
end $$;

alter table public.encounter
  add column if not exists appointment_id text references public.appointments(id) on delete restrict,
  add column if not exists assessment_status text not null default 'not_started',
  add column if not exists assessment_payload jsonb not null default '{}'::jsonb,
  add column if not exists clinical_assessment text,
  add column if not exists recommendations text,
  add column if not exists treatment_plan text,
  add column if not exists follow_up_instructions text,
  add column if not exists referral_summary text,
  add column if not exists clinician_only_notes text,
  add column if not exists assessment_version integer not null default 0,
  add column if not exists started_at timestamptz,
  add column if not exists last_edited_at timestamptz,
  add column if not exists last_edited_by uuid,
  add column if not exists completed_at timestamptz,
  add column if not exists completed_by uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'encounter_assessment_status_check'
      and conrelid = 'public.encounter'::regclass
  ) then
    alter table public.encounter
      add constraint encounter_assessment_status_check check (
        assessment_status in (
          'not_started', 'in_progress', 'ready_for_review', 'completed'
        )
      );
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'encounter_assessment_payload_object_check'
      and conrelid = 'public.encounter'::regclass
  ) then
    alter table public.encounter
      add constraint encounter_assessment_payload_object_check check (
        jsonb_typeof(assessment_payload) = 'object'
      );
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'encounter_assessment_version_check'
      and conrelid = 'public.encounter'::regclass
  ) then
    alter table public.encounter
      add constraint encounter_assessment_version_check check (
        assessment_version >= 0
      );
  end if;
end $$;

create unique index if not exists encounter_appointment_id_uidx
  on public.encounter(appointment_id)
  where appointment_id is not null;

create index if not exists encounter_assigned_assessment_idx
  on public.encounter(doctor_id, assessment_status, last_edited_at desc)
  where appointment_id is not null;

create table if not exists public.patient_appointment_summaries (
  id uuid primary key default gen_random_uuid(),
  appointment_id text not null references public.appointments(id) on delete restrict,
  encounter_id text not null references public.encounter(id) on delete restrict,
  source_appointment_id uuid not null,
  version integer not null default 1,
  clinician_display_name text not null,
  clinic_name text not null,
  appointment_date date not null,
  completed_at timestamptz not null,
  overall_status text not null,
  maternal_summary jsonb not null default '{}'::jsonb,
  pregnancy_summary jsonb not null default '{}'::jsonb,
  key_findings text,
  recommendations text,
  follow_up_instructions text,
  referral_summary text,
  next_appointment_at timestamptz,
  urgent_care_instruction text,
  generated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint patient_appointment_summaries_appointment_unique unique (appointment_id),
  constraint patient_appointment_summaries_encounter_unique unique (encounter_id),
  constraint patient_appointment_summaries_version_check check (version > 0),
  constraint patient_appointment_summaries_status_check check (
    overall_status in ('routine', 'follow_up', 'needs_attention', 'urgent')
  ),
  constraint patient_appointment_summaries_maternal_object_check check (
    jsonb_typeof(maternal_summary) = 'object'
  ),
  constraint patient_appointment_summaries_pregnancy_object_check check (
    jsonb_typeof(pregnancy_summary) = 'object'
  )
);

create index if not exists patient_appointment_summaries_source_idx
  on public.patient_appointment_summaries(source_appointment_id, generated_at desc);

alter table public.patient_appointment_summaries enable row level security;
revoke all on table public.patient_appointment_summaries from anon;
revoke insert, update, delete on table public.patient_appointment_summaries from authenticated;

drop policy if exists patient_summaries_select_assigned on public.patient_appointment_summaries;
create policy patient_summaries_select_assigned
  on public.patient_appointment_summaries
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.appointments a
      where a.id = appointment_id
        and (
          a.assigned_doctor_id = public.current_clinician_id()
          or public.current_clinician_is_admin()
        )
    )
  );

create table if not exists public.clinical_assessment_audit (
  id uuid primary key default gen_random_uuid(),
  appointment_id text not null references public.appointments(id) on delete restrict,
  encounter_id text not null references public.encounter(id) on delete restrict,
  clinician_id text not null,
  actor_user_id uuid,
  action text not null,
  assessment_version integer not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint clinical_assessment_audit_action_check check (
    action in ('draft_saved', 'completed')
  ),
  constraint clinical_assessment_audit_version_check check (assessment_version > 0),
  constraint clinical_assessment_audit_metadata_object_check check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index if not exists clinical_assessment_audit_appointment_idx
  on public.clinical_assessment_audit(appointment_id, created_at desc);

alter table public.clinical_assessment_audit enable row level security;
revoke all on table public.clinical_assessment_audit from anon, authenticated;

alter table public.integration_outbox
  drop constraint if exists clinician_integration_outbox_event_type_check;

alter table public.integration_outbox
  add constraint clinician_integration_outbox_event_type_check check (
    event_type in (
      'appointment.status.changed',
      'appointment.results_available'
    )
  );

-- Preserve the broad legacy encounter access only for legacy rows. New
-- appointment-linked encounters are visible to their assigned clinician/admin.
alter policy "authenticated users can manage encounters"
  on public.encounter
  to authenticated
  using (
    appointment_id is null
    or exists (
      select 1
      from public.appointments a
      where a.id = appointment_id
        and (
          a.assigned_doctor_id = public.current_clinician_id()
          or public.current_clinician_is_admin()
        )
    )
  )
  with check (
    appointment_id is null
    or exists (
      select 1
      from public.appointments a
      where a.id = appointment_id
        and (
          a.assigned_doctor_id = public.current_clinician_id()
          or public.current_clinician_is_admin()
        )
    )
  );

create or replace function public.guard_appointment_assessment_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_appointment_id text := coalesce(new.appointment_id, old.appointment_id);
begin
  if target_appointment_id is not null
     and auth.uid() is not null
     and coalesce(current_setting('dawa.assessment_write', true), '') <> 'allowed' then
    raise exception using
      errcode = '42501',
      message = 'Appointment assessments must be changed through the assessment workflow';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_appointment_assessment_write on public.encounter;
create trigger guard_appointment_assessment_write
  before insert or update or delete on public.encounter
  for each row execute function public.guard_appointment_assessment_write();

create or replace function public.guard_assessed_appointment_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.source_project = 'dawa_mom'
     and lower(coalesce(old.status, '')) <> 'completed'
     and lower(coalesce(new.status, '')) = 'completed'
     and coalesce(current_setting('dawa.assessment_completion', true), '') <> 'allowed' then
    raise exception using
      errcode = '23514',
      message = 'Complete the clinical assessment before closing this appointment';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_assessed_appointment_completion on public.appointments;
create trigger guard_assessed_appointment_completion
  before update of status on public.appointments
  for each row execute function public.guard_assessed_appointment_completion();

create or replace function public.dawa_mom_assessment_validation_errors(
  p_assessment jsonb
)
returns text[]
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  errors text[] := array[]::text[];
  measurement_state text;
  measurement_key text;
  measurement_value text;
  interpretation text;
begin
  if p_assessment is null or jsonb_typeof(p_assessment) <> 'object' then
    return array['Assessment data is invalid.'];
  end if;

  measurement_state := p_assessment #>> '{maternal,blood_pressure,state}';
  if measurement_state is null or measurement_state not in (
    'measured', 'not_measured', 'unable_to_obtain', 'not_applicable'
  ) then
    errors := array_append(
      errors,
      'Enter the patient''s blood pressure or mark it as not measured.'
    );
  elsif measurement_state = 'measured'
        and nullif(trim(p_assessment #>> '{maternal,blood_pressure,value}'), '') is null then
    errors := array_append(errors, 'Enter the patient''s blood pressure.');
  elsif measurement_state = 'measured'
        and (
          p_assessment #>> '{maternal,blood_pressure,interpretation}' is null
          or p_assessment #>> '{maternal,blood_pressure,interpretation}' not in (
            'normal', 'low', 'high', 'needs_attention', 'critical', 'recorded'
          )
        ) then
    errors := array_append(errors, 'Confirm the blood pressure interpretation.');
  end if;

  foreach measurement_key in array array[
    'heart_rate', 'hemoglobin'
  ] loop
    measurement_state := p_assessment #>> array['maternal', measurement_key, 'state'];
    if measurement_state is not null and measurement_state not in (
      'measured', 'not_measured', 'unable_to_obtain', 'not_applicable'
    ) then
      errors := array_append(errors, 'A maternal measurement state is invalid.');
    end if;
    if measurement_state = 'measured' then
      measurement_value := p_assessment #>> array['maternal', measurement_key, 'value'];
      interpretation := p_assessment #>> array['maternal', measurement_key, 'interpretation'];
      if nullif(trim(measurement_value), '') is null then
        errors := array_append(errors, 'A measured maternal value is missing.');
      end if;
      if interpretation is null or interpretation not in (
        'normal', 'low', 'high', 'needs_attention', 'critical', 'recorded'
      ) then
        errors := array_append(errors, 'Confirm the interpretation for each measured maternal value.');
      end if;
    end if;
  end loop;

  foreach measurement_key in array array[
    'fetal_heartbeat', 'heartbeat_quality', 'fetal_position',
    'estimated_baby_size'
  ] loop
    measurement_state := p_assessment #>> array['pregnancy', measurement_key, 'state'];
    if measurement_state is not null and measurement_state not in (
      'measured', 'recorded', 'not_measured', 'unable_to_obtain', 'not_applicable'
    ) then
      errors := array_append(errors, 'A pregnancy or baby measurement state is invalid.');
    end if;
    if measurement_state in ('measured', 'recorded') then
      measurement_value := p_assessment #>> array['pregnancy', measurement_key, 'value'];
      if nullif(trim(measurement_value), '') is null then
        errors := array_append(errors, 'A recorded pregnancy or baby value is missing.');
      end if;
      if measurement_key in ('fetal_heartbeat', 'heartbeat_quality') then
        interpretation := p_assessment #>> array['pregnancy', measurement_key, 'interpretation'];
        if interpretation is null or interpretation not in (
          'normal', 'low', 'high', 'needs_attention', 'critical', 'recorded'
        ) then
          errors := array_append(errors, 'Confirm the interpretation for the recorded baby finding.');
        end if;
      end if;
    end if;
  end loop;

  if nullif(trim(p_assessment ->> 'clinical_assessment'), '') is null then
    errors := array_append(
      errors,
      'Record the clinical assessment before completing the appointment.'
    );
  end if;

  if nullif(trim(p_assessment ->> 'recommendations'), '') is null
     and nullif(trim(p_assessment ->> 'follow_up'), '') is null then
    errors := array_append(
      errors,
      'Add at least one recommendation or follow-up instruction.'
    );
  end if;

  if p_assessment #>> '{patient_summary,overall_status}' is null
     or p_assessment #>> '{patient_summary,overall_status}' not in (
       'routine', 'follow_up', 'needs_attention', 'urgent'
     ) then
    errors := array_append(errors, 'Select the patient-facing overall result.');
  end if;

  return errors;
end;
$$;

create or replace function public.save_dawa_mom_appointment_assessment_draft(
  p_appointment_id text,
  p_assessment jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  appointment_row public.appointments%rowtype;
  encounter_row public.encounter%rowtype;
  clinician_id text;
  encounter_id text;
  heart_rate_value text;
  hemoglobin_value text;
  fetal_heartbeat_value text;
  baby_size_value text;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Authentication is required';
  end if;
  if p_assessment is null or jsonb_typeof(p_assessment) <> 'object' then
    raise exception using errcode = '22023', message = 'Assessment data must be an object';
  end if;

  clinician_id := public.current_clinician_id();
  if clinician_id is null then
    raise exception using errcode = '42501', message = 'Clinician profile is not linked';
  end if;

  select * into appointment_row
  from public.appointments a
  where a.id = p_appointment_id
    and a.source_project = 'dawa_mom'
  for update;

  if appointment_row.id is null then
    raise exception using errcode = 'P0002', message = 'Appointment was not found';
  end if;
  if appointment_row.assigned_doctor_id <> clinician_id
     and not public.current_clinician_is_admin() then
    raise exception using errcode = '42501', message = 'Appointment is assigned to another clinician';
  end if;
  if lower(coalesce(appointment_row.status, '')) not in ('confirmed', 'rescheduled') then
    raise exception using errcode = '23514', message = 'Only an active confirmed appointment can be assessed';
  end if;

  encounter_id := appointment_row.id || '_encounter';
  heart_rate_value := p_assessment #>> '{maternal,heart_rate,value}';
  hemoglobin_value := p_assessment #>> '{maternal,hemoglobin,value}';
  fetal_heartbeat_value := p_assessment #>> '{pregnancy,fetal_heartbeat,value}';
  baby_size_value := p_assessment #>> '{pregnancy,estimated_baby_size,value}';

  perform set_config('dawa.assessment_write', 'allowed', true);

  insert into public.encounter (
    id,
    bp,
    pulse,
    next_visit,
    comment,
    mother_id,
    heart_beat,
    heart_beat_quality,
    womb_position,
    estimated_baby_size,
    hemocheck,
    clinic_id,
    doctor_id,
    status,
    is_instant,
    date,
    time,
    appointment_id,
    assessment_status,
    assessment_payload,
    clinical_assessment,
    recommendations,
    treatment_plan,
    follow_up_instructions,
    referral_summary,
    clinician_only_notes,
    assessment_version,
    started_at,
    last_edited_at,
    last_edited_by
  ) values (
    encounter_id,
    case
      when p_assessment #>> '{maternal,blood_pressure,state}' = 'measured'
        then nullif(trim(p_assessment #>> '{maternal,blood_pressure,value}'), '')
      else null
    end,
    case when heart_rate_value ~ '^[0-9]{1,6}$' then heart_rate_value::integer else null end,
    case
      when coalesce(p_assessment ->> 'next_visit', '') ~
        '^\d{4}-\d{2}-\d{2}([T ][0-9:.+-]+Z?)?$'
        then (p_assessment ->> 'next_visit')::timestamptz
      else null
    end,
    left(nullif(trim(p_assessment ->> 'observations'), ''), 8000),
    'mother/' || appointment_row.patient_record_id,
    case when fetal_heartbeat_value ~ '^[0-9]{1,6}$' then fetal_heartbeat_value::integer else null end,
    left(nullif(trim(p_assessment #>> '{pregnancy,heartbeat_quality,value}'), ''), 200),
    left(nullif(trim(p_assessment #>> '{pregnancy,fetal_position,value}'), ''), 200),
    case when baby_size_value ~ '^[0-9]{1,7}$' then baby_size_value::integer else null end,
    case when hemoglobin_value ~ '^[0-9]{1,6}$' then hemoglobin_value::integer else null end,
    case when appointment_row.clinic_record_id is null then null
      else 'clinic/' || appointment_row.clinic_record_id end,
    'doctor/' || clinician_id,
    'in_progress',
    false,
    (appointment_row.appointment_date + appointment_row.start_time)
      at time zone 'Africa/Lusaka',
    to_char(appointment_row.start_time, 'HH24:MI'),
    appointment_row.id,
    'in_progress',
    p_assessment,
    left(nullif(trim(p_assessment ->> 'clinical_assessment'), ''), 12000),
    left(nullif(trim(p_assessment ->> 'recommendations'), ''), 8000),
    left(nullif(trim(p_assessment ->> 'treatment'), ''), 8000),
    left(nullif(trim(p_assessment ->> 'follow_up'), ''), 8000),
    left(nullif(trim(p_assessment ->> 'referral'), ''), 8000),
    left(nullif(trim(p_assessment ->> 'clinician_only_notes'), ''), 12000),
    1,
    now(),
    now(),
    auth.uid()
  )
  on conflict (appointment_id) where appointment_id is not null
  do update set
    bp = excluded.bp,
    pulse = excluded.pulse,
    next_visit = excluded.next_visit,
    comment = excluded.comment,
    heart_beat = excluded.heart_beat,
    heart_beat_quality = excluded.heart_beat_quality,
    womb_position = excluded.womb_position,
    estimated_baby_size = excluded.estimated_baby_size,
    hemocheck = excluded.hemocheck,
    status = 'in_progress',
    assessment_status = 'in_progress',
    assessment_payload = excluded.assessment_payload,
    clinical_assessment = excluded.clinical_assessment,
    recommendations = excluded.recommendations,
    treatment_plan = excluded.treatment_plan,
    follow_up_instructions = excluded.follow_up_instructions,
    referral_summary = excluded.referral_summary,
    clinician_only_notes = excluded.clinician_only_notes,
    assessment_version = public.encounter.assessment_version + 1,
    started_at = coalesce(public.encounter.started_at, excluded.started_at),
    last_edited_at = excluded.last_edited_at,
    last_edited_by = excluded.last_edited_by,
    updated_at = now()
  returning * into encounter_row;

  insert into public.clinical_assessment_audit (
    appointment_id,
    encounter_id,
    clinician_id,
    actor_user_id,
    action,
    assessment_version,
    metadata
  ) values (
    appointment_row.id,
    encounter_row.id,
    clinician_id,
    auth.uid(),
    'draft_saved',
    encounter_row.assessment_version,
    jsonb_build_object('assessment_status', encounter_row.assessment_status)
  );

  return jsonb_build_object(
    'ok', true,
    'appointment_id', appointment_row.id,
    'encounter_id', encounter_row.id,
    'assessment_status', encounter_row.assessment_status,
    'assessment_version', encounter_row.assessment_version,
    'last_edited_at', encounter_row.last_edited_at,
    'validation_errors', public.dawa_mom_assessment_validation_errors(p_assessment)
  );
end;
$$;

create or replace function public.complete_dawa_mom_appointment_with_assessment(
  p_appointment_id text,
  p_assessment jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  appointment_row public.appointments%rowtype;
  encounter_row public.encounter%rowtype;
  summary_row public.patient_appointment_summaries%rowtype;
  clinician_id text;
  clinician_name text;
  clinic_display_name text;
  validation_errors text[];
  result_event_id uuid := gen_random_uuid();
  maternal_summary jsonb;
  pregnancy_summary jsonb;
  completion_time timestamptz := now();
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Authentication is required';
  end if;

  clinician_id := public.current_clinician_id();
  if clinician_id is null then
    raise exception using errcode = '42501', message = 'Clinician profile is not linked';
  end if;

  select * into appointment_row
  from public.appointments a
  where a.id = p_appointment_id
    and a.source_project = 'dawa_mom'
  for update;

  if appointment_row.id is null then
    raise exception using errcode = 'P0002', message = 'Appointment was not found';
  end if;
  if appointment_row.assigned_doctor_id <> clinician_id
     and not public.current_clinician_is_admin() then
    raise exception using errcode = '42501', message = 'Appointment is assigned to another clinician';
  end if;

  if lower(coalesce(appointment_row.status, '')) = 'completed' then
    select * into summary_row
    from public.patient_appointment_summaries s
    where s.appointment_id = appointment_row.id;
    if summary_row.id is not null then
      return jsonb_build_object(
        'ok', true,
        'deduplicated', true,
        'appointment_id', appointment_row.id,
        'encounter_id', summary_row.encounter_id,
        'summary_id', summary_row.id,
        'status', appointment_row.status
      );
    end if;
  end if;

  if lower(coalesce(appointment_row.status, '')) not in ('confirmed', 'rescheduled') then
    raise exception using errcode = '23514', message = 'Only an active confirmed appointment can be completed';
  end if;

  validation_errors := public.dawa_mom_assessment_validation_errors(p_assessment);
  if coalesce(array_length(validation_errors, 1), 0) > 0 then
    raise exception using
      errcode = '22023',
      message = 'Resolve the missing required information before completing the appointment.',
      detail = array_to_string(validation_errors, E'\n');
  end if;

  perform public.save_dawa_mom_appointment_assessment_draft(
    appointment_row.id,
    p_assessment
  );

  select * into encounter_row
  from public.encounter e
  where e.appointment_id = appointment_row.id
  for update;

  if encounter_row.id is null
     or encounter_row.mother_id <> ('mother/' || appointment_row.patient_record_id) then
    raise exception using errcode = '23514', message = 'Encounter patient does not match the appointment';
  end if;

  select coalesce(nullif(trim(d.name), ''), 'Your clinician')
    into clinician_name
  from public.doctor d
  where d.id = appointment_row.assigned_doctor_id;

  select coalesce(nullif(trim(c.name), ''), 'Your clinic')
    into clinic_display_name
  from public.clinic c
  where c.id = appointment_row.clinic_record_id;

  clinician_name := coalesce(clinician_name, 'Your clinician');
  clinic_display_name := coalesce(clinic_display_name, 'Your clinic');

  maternal_summary := jsonb_build_object(
    'heart_rate', jsonb_strip_nulls(jsonb_build_object(
      'state', p_assessment #>> '{maternal,heart_rate,state}',
      'value', case when p_assessment #>> '{maternal,heart_rate,state}' = 'measured'
        then p_assessment #>> '{maternal,heart_rate,value}' else null end,
      'unit', 'bpm',
      'interpretation', p_assessment #>> '{maternal,heart_rate,interpretation}'
    )),
    'blood_pressure', jsonb_strip_nulls(jsonb_build_object(
      'state', p_assessment #>> '{maternal,blood_pressure,state}',
      'value', case when p_assessment #>> '{maternal,blood_pressure,state}' = 'measured'
        then p_assessment #>> '{maternal,blood_pressure,value}' else null end,
      'unit', 'mmHg',
      'interpretation', p_assessment #>> '{maternal,blood_pressure,interpretation}'
    )),
    'hemoglobin', jsonb_strip_nulls(jsonb_build_object(
      'state', p_assessment #>> '{maternal,hemoglobin,state}',
      'value', case when p_assessment #>> '{maternal,hemoglobin,state}' = 'measured'
        then p_assessment #>> '{maternal,hemoglobin,value}' else null end,
      'unit', 'g/dL',
      'interpretation', p_assessment #>> '{maternal,hemoglobin,interpretation}'
    ))
  );

  pregnancy_summary := jsonb_build_object(
    'pregnancy_status', jsonb_strip_nulls(jsonb_build_object(
      'state', 'recorded',
      'value', p_assessment #>> '{pregnancy,status}',
      'source', p_assessment #>> '{pregnancy,status_source}'
    )),
    'fetal_heartbeat', jsonb_strip_nulls(jsonb_build_object(
      'state', p_assessment #>> '{pregnancy,fetal_heartbeat,state}',
      'value', case when p_assessment #>> '{pregnancy,fetal_heartbeat,state}' = 'measured'
        then p_assessment #>> '{pregnancy,fetal_heartbeat,value}' else null end,
      'unit', 'bpm',
      'interpretation', p_assessment #>> '{pregnancy,fetal_heartbeat,interpretation}'
    )),
    'heartbeat_quality', jsonb_strip_nulls(jsonb_build_object(
      'state', p_assessment #>> '{pregnancy,heartbeat_quality,state}',
      'value', case when p_assessment #>> '{pregnancy,heartbeat_quality,state}' in ('measured', 'recorded')
        then p_assessment #>> '{pregnancy,heartbeat_quality,value}' else null end,
      'interpretation', p_assessment #>> '{pregnancy,heartbeat_quality,interpretation}'
    )),
    'fetal_position', jsonb_strip_nulls(jsonb_build_object(
      'state', p_assessment #>> '{pregnancy,fetal_position,state}',
      'value', case when p_assessment #>> '{pregnancy,fetal_position,state}' in ('measured', 'recorded')
        then p_assessment #>> '{pregnancy,fetal_position,value}' else null end
    )),
    'estimated_baby_size', jsonb_strip_nulls(jsonb_build_object(
      'state', p_assessment #>> '{pregnancy,estimated_baby_size,state}',
      'value', case when p_assessment #>> '{pregnancy,estimated_baby_size,state}' in ('measured', 'recorded')
        then p_assessment #>> '{pregnancy,estimated_baby_size,value}' else null end,
      'unit', 'cm'
    ))
  );

  perform set_config('dawa.assessment_write', 'allowed', true);
  update public.encounter e
  set status = 'completed',
      assessment_status = 'completed',
      assessment_version = e.assessment_version + 1,
      completed_at = completion_time,
      completed_by = auth.uid(),
      performed_by = 'doctor/' || clinician_id,
      date_performed = completion_time,
      last_edited_at = completion_time,
      last_edited_by = auth.uid(),
      updated_at = completion_time
  where e.id = encounter_row.id
  returning * into encounter_row;

  insert into public.patient_appointment_summaries (
    appointment_id,
    encounter_id,
    source_appointment_id,
    clinician_display_name,
    clinic_name,
    appointment_date,
    completed_at,
    overall_status,
    maternal_summary,
    pregnancy_summary,
    key_findings,
    recommendations,
    follow_up_instructions,
    referral_summary,
    next_appointment_at,
    urgent_care_instruction
  ) values (
    appointment_row.id,
    encounter_row.id,
    appointment_row.source_appointment_id,
    clinician_name,
    clinic_display_name,
    appointment_row.appointment_date,
    completion_time,
    p_assessment #>> '{patient_summary,overall_status}',
    maternal_summary,
    pregnancy_summary,
    left(nullif(trim(p_assessment #>> '{patient_summary,key_findings}'), ''), 4000),
    left(trim(p_assessment ->> 'recommendations'), 8000),
    left(nullif(trim(p_assessment ->> 'follow_up'), ''), 8000),
    left(nullif(trim(p_assessment ->> 'referral'), ''), 8000),
    encounter_row.next_visit,
    left(nullif(trim(p_assessment #>> '{patient_summary,urgent_care_instruction}'), ''), 4000)
  )
  returning * into summary_row;

  perform set_config('dawa.assessment_completion', 'allowed', true);
  perform set_config('dawa.integration_transition', 'allowed', true);
  update public.appointments a
  set status = 'completed',
      patient_safe_status_message = 'Your appointment is complete and your care summary is available.',
      integration_status = 'pending',
      integration_error_code = null
  where a.id = appointment_row.id
  returning * into appointment_row;

  insert into public.integration_outbox (
    event_id,
    event_type,
    aggregate_type,
    aggregate_id,
    payload
  ) values (
    result_event_id,
    'appointment.results_available',
    'appointment',
    appointment_row.id,
    jsonb_strip_nulls(jsonb_build_object(
      'event_id', result_event_id,
      'event_type', 'appointment.results_available',
      'source', 'dawa_clinician',
      'source_appointment_id', appointment_row.source_appointment_id,
      'external_appointment_id', appointment_row.id,
      'status', 'completed',
      'effective_at', completion_time,
      'patient_safe_message', appointment_row.patient_safe_status_message,
      'summary', jsonb_build_object(
        'id', summary_row.id,
        'version', summary_row.version,
        'encounter_id', summary_row.encounter_id,
        'clinician_display_name', summary_row.clinician_display_name,
        'clinic_name', summary_row.clinic_name,
        'appointment_date', summary_row.appointment_date,
        'completed_at', summary_row.completed_at,
        'overall_status', summary_row.overall_status,
        'maternal_health', summary_row.maternal_summary,
        'pregnancy_health', summary_row.pregnancy_summary,
        'key_findings', summary_row.key_findings,
        'recommendations', summary_row.recommendations,
        'follow_up_instructions', summary_row.follow_up_instructions,
        'referral_summary', summary_row.referral_summary,
        'next_appointment_at', summary_row.next_appointment_at,
        'urgent_care_instruction', summary_row.urgent_care_instruction,
        'generated_at', summary_row.generated_at
      )
    ))
  );

  insert into public.clinical_assessment_audit (
    appointment_id,
    encounter_id,
    clinician_id,
    actor_user_id,
    action,
    assessment_version,
    metadata
  ) values (
    appointment_row.id,
    encounter_row.id,
    clinician_id,
    auth.uid(),
    'completed',
    encounter_row.assessment_version,
    jsonb_build_object(
      'summary_id', summary_row.id,
      'result_event_id', result_event_id,
      'overall_status', summary_row.overall_status
    )
  );

  return jsonb_build_object(
    'ok', true,
    'event_id', result_event_id,
    'appointment_id', appointment_row.id,
    'encounter_id', encounter_row.id,
    'summary_id', summary_row.id,
    'status', appointment_row.status,
    'integration_status', appointment_row.integration_status
  );
end;
$$;

revoke all on function public.dawa_mom_assessment_validation_errors(jsonb)
  from public, anon, authenticated;
revoke all on function public.save_dawa_mom_appointment_assessment_draft(text, jsonb)
  from public, anon;
revoke all on function public.complete_dawa_mom_appointment_with_assessment(text, jsonb)
  from public, anon;
grant execute on function public.save_dawa_mom_appointment_assessment_draft(text, jsonb)
  to authenticated;
grant execute on function public.complete_dawa_mom_appointment_with_assessment(text, jsonb)
  to authenticated;

comment on table public.patient_appointment_summaries is
  'Server-filtered patient-visible summaries. Clinician-only assessment text is never placed here.';
comment on function public.complete_dawa_mom_appointment_with_assessment(text, jsonb) is
  'Atomically validates and completes an assigned assessment, creates its safe summary, and enqueues Dawa Mom delivery.';

commit;
