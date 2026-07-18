-- Dawa Clinician side of the cross-project Dawa platform integration.
--
-- Purpose:
--   * add stable public UUIDs without replacing legacy text primary keys
--   * harden/reuse the existing Dawa Mom patient mapping
--   * receive appointments transactionally with idempotency and slot locking
--   * create assigned-clinician notifications
--   * enforce clinician-owned appointment transitions and queue callbacks
--
-- Existing-data impact:
--   Additive columns/tables/functions/indexes. Existing doctor auth/clinic links
--   are backfilled only from valid UUID paths and unambiguous clinic-name
--   matches. Existing appointments/encounters and clinical records are retained.
--
-- RLS impact:
--   RLS remains enabled. The existing broad appointments and doctor policies
--   are narrowed in place; clinic writes are admin-guarded without dropping the
--   legacy read-compatible policy. Private integration tables have no Flutter
--   policies. Other broad legacy clinical-table policies require a separate,
--   regression-tested audit.
--
-- Backfill and rollback:
--   No cross-project backfill is run by this migration. For rollback, stop
--   workers/rotate secrets and keep additive mapping/audit rows for recovery.

begin;

create extension if not exists pgcrypto;

alter table public.clinic
  add column if not exists integration_id uuid not null default gen_random_uuid();

alter table public.doctor
  add column if not exists integration_id uuid not null default gen_random_uuid(),
  add column if not exists auth_user_id uuid,
  add column if not exists clinic_id text,
  add column if not exists professional_title text,
  add column if not exists profile_image_url text,
  add column if not exists is_active boolean not null default true,
  add column if not exists is_bookable boolean not null default true,
  add column if not exists slot_minutes integer not null default 30;

create unique index if not exists clinic_integration_id_uidx
  on public.clinic(integration_id);

create unique index if not exists doctor_integration_id_uidx
  on public.doctor(integration_id);

create index if not exists doctor_clinic_id_idx
  on public.doctor(clinic_id);

alter table public.mother
  add column if not exists email text,
  add column if not exists source_event_id uuid,
  add column if not exists source_updated_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'doctor_slot_minutes_check'
      and conrelid = 'public.doctor'::regclass
  ) then
    alter table public.doctor
      add constraint doctor_slot_minutes_check
      check (slot_minutes between 5 and 240);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'doctor_clinic_id_fkey'
      and conrelid = 'public.doctor'::regclass
  ) then
    alter table public.doctor
      add constraint doctor_clinic_id_fkey
      foreign key (clinic_id) references public.clinic(id)
      on delete set null not valid;
  end if;
end $$;

with doctor_auth_candidates as (
  select
    d.id as doctor_id,
    regexp_replace(d."user_Id", '^.*/', '')::uuid as auth_user_id
  from public.doctor d
  where d.auth_user_id is null
    and regexp_replace(coalesce(d."user_Id", ''), '^.*/', '')
        ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
), unambiguous_doctor_auth_candidates as (
  select min(c.doctor_id) as doctor_id, c.auth_user_id
  from doctor_auth_candidates c
  group by c.auth_user_id
  having count(*) = 1
)
update public.doctor d
set auth_user_id = candidate.auth_user_id
from unambiguous_doctor_auth_candidates candidate
where d.id = candidate.doctor_id
  and not exists (
    select 1
    from public.doctor already_linked
    where already_linked.auth_user_id = candidate.auth_user_id
  );

create unique index if not exists doctor_auth_user_id_uidx
  on public.doctor(auth_user_id)
  where auth_user_id is not null;

with unambiguous_clinic_matches as (
  select d.id as doctor_id, min(c.id) as clinic_id
  from public.doctor d
  join public.clinic c
    on lower(trim(c.name)) = lower(trim(d.clinic_name))
  where d.clinic_id is null
    and nullif(trim(d.clinic_name), '') is not null
  group by d.id
  having count(*) = 1
)
update public.doctor d
set clinic_id = matched.clinic_id
from unambiguous_clinic_matches matched
where d.id = matched.doctor_id;

-- The pre-existing `patients` compatibility view was created with `select *`.
-- PostgreSQL freezes that column list at view-creation time, so recreate it
-- after extending `mother` to expose the new patient sync fields safely.
do $$
begin
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'patients'
      and c.relkind = 'v'
  ) then
    execute 'create or replace view public.patients '
      || 'with (security_invoker = true) as select * from public.mother';
  end if;
end $$;

alter table public.appointments
  add column if not exists source_project text not null default 'clinician',
  add column if not exists source_appointment_id uuid,
  add column if not exists source_event_id uuid,
  add column if not exists patient_record_id text,
  add column if not exists assigned_doctor_id text,
  add column if not exists clinic_record_id text,
  add column if not exists appointment_date date,
  add column if not exists start_time time without time zone,
  add column if not exists end_time time without time zone,
  add column if not exists appointment_type text,
  add column if not exists reason text,
  add column if not exists notes text,
  add column if not exists source_created_at timestamptz,
  add column if not exists source_updated_at timestamptz,
  add column if not exists received_at timestamptz,
  add column if not exists integration_status text not null default 'local',
  add column if not exists integration_synced_at timestamptz,
  add column if not exists integration_error_code text,
  add column if not exists patient_safe_status_message text;

create unique index if not exists appointments_source_mapping_uidx
  on public.appointments(source_project, source_appointment_id)
  where source_appointment_id is not null;

create unique index if not exists dawa_mom_appointment_active_slot_uidx
  on public.appointments(assigned_doctor_id, appointment_date, start_time)
  where source_project = 'dawa_mom'
    and status in ('pending', 'confirmed', 'rescheduled');

create index if not exists appointments_assigned_doctor_date_idx
  on public.appointments(assigned_doctor_id, appointment_date, start_time);

create index if not exists appointments_integration_status_idx
  on public.appointments(integration_status, updated_at)
  where source_project = 'dawa_mom' and integration_status <> 'synced';

create table if not exists public.integration_processed_events (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  event_id uuid not null,
  event_type text not null,
  aggregate_id text,
  destination_id text,
  result jsonb not null default '{}'::jsonb,
  processed_at timestamptz not null default now(),
  constraint integration_processed_events_source_event_unique
    unique (source, event_id),
  constraint integration_processed_events_result_object_check check (
    jsonb_typeof(result) = 'object'
  )
);

alter table public.integration_processed_events enable row level security;
revoke all on table public.integration_processed_events from anon, authenticated;

create table if not exists public.integration_outbox (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null default gen_random_uuid(),
  event_type text not null,
  aggregate_type text not null,
  aggregate_id text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  processing_started_at timestamptz,
  locked_by text,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint clinician_integration_outbox_event_unique unique (event_id),
  constraint clinician_integration_outbox_event_type_check check (
    event_type = 'appointment.status.changed'
  ),
  constraint clinician_integration_outbox_aggregate_type_check check (
    aggregate_type = 'appointment'
  ),
  constraint clinician_integration_outbox_status_check check (
    status in (
      'pending', 'processing', 'completed', 'retrying', 'failed',
      'permanently_failed'
    )
  ),
  constraint clinician_integration_outbox_attempt_check check (attempt_count >= 0),
  constraint clinician_integration_outbox_payload_object_check check (
    jsonb_typeof(payload) = 'object'
  )
);

create index if not exists clinician_integration_outbox_ready_idx
  on public.integration_outbox(status, next_attempt_at, created_at)
  where status in ('pending', 'retrying', 'processing');

create index if not exists clinician_integration_outbox_aggregate_idx
  on public.integration_outbox(aggregate_type, aggregate_id, created_at);

alter table public.integration_outbox enable row level security;
revoke all on table public.integration_outbox from anon, authenticated;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  clinician_id text not null,
  clinician_auth_user_id uuid not null,
  appointment_id text references public.appointments(id) on delete cascade,
  source_event_id uuid not null,
  type text not null,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notifications_source_event_unique
    unique (source_event_id, clinician_id, type),
  constraint notifications_read_at_check check (
    (is_read and read_at is not null) or (not is_read and read_at is null)
  )
);

create index if not exists notifications_clinician_unread_idx
  on public.notifications(clinician_auth_user_id, is_read, created_at desc);

alter table public.notifications enable row level security;

create or replace function public.current_clinician_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select d.id
  from public.doctor d
  where d.auth_user_id = auth.uid()
     or d."user_Id" = auth.uid()::text
     or d."user_Id" = 'user/' || auth.uid()::text
  order by case when d.auth_user_id = auth.uid() then 0 else 1 end
  limit 1;
$$;

create or replace function public.current_clinician_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public."user" u
    where (u.id = auth.uid()::text or u.uid = auth.uid()::text)
      and lower(coalesce(u.role, '')) = 'admin'
  );
$$;

revoke all on function public.current_clinician_id() from public;
revoke all on function public.current_clinician_is_admin() from public;
grant execute on function public.current_clinician_id() to authenticated;
grant execute on function public.current_clinician_is_admin() to authenticated;

-- Protect directory ownership while retaining authenticated clinic discovery
-- for clinician registration. Directory reads exposed cross-project still use
-- the service-only safe RPC below.
alter policy "authenticated users can manage doctors"
  on public.doctor
  to authenticated
  using (
    auth_user_id = auth.uid()
    or "user_Id" = auth.uid()::text
    or "user_Id" = 'user/' || auth.uid()::text
    or public.current_clinician_is_admin()
  )
  with check (
    auth_user_id = auth.uid()
    or "user_Id" = auth.uid()::text
    or "user_Id" = 'user/' || auth.uid()::text
    or public.current_clinician_is_admin()
  );

-- The broad legacy clinic policy is retained for compatibility rather than
-- dropped. This trigger narrows writes to admins while clinician registration
-- continues to read the clinic list.
create or replace function public.guard_clinic_directory_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.current_clinician_is_admin() then
    raise exception using
      errcode = '42501',
      message = 'Clinic directory rows are admin managed';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_clinic_directory_write on public.clinic;
create trigger guard_clinic_directory_write
  before insert or update or delete on public.clinic
  for each row execute function public.guard_clinic_directory_write();

create or replace function public.guard_doctor_directory_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.current_clinician_is_admin() then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception using
      errcode = '42501',
      message = 'Clinician directory rows are admin managed';
  elsif tg_op = 'INSERT' then
    if new."user_Id" is null
       or new."user_Id" not in (
         auth.uid()::text,
         'user/' || auth.uid()::text
       )
       or (
         new.auth_user_id is not null
         and new.auth_user_id <> auth.uid()
       ) then
      raise exception using
        errcode = '42501',
        message = 'Clinician identity fields are server managed';
    end if;
    new.integration_id := gen_random_uuid();
    new.auth_user_id := auth.uid();
    new.clinic_id := null;
    if nullif(trim(new.clinic_name), '') is not null then
      select min(c.id) into new.clinic_id
      from public.clinic c
      where lower(trim(c.name)) = lower(trim(new.clinic_name))
      having count(*) = 1;
    end if;
  elsif old.integration_id is distinct from new.integration_id
     or old.auth_user_id is distinct from new.auth_user_id
     or old."user_Id" is distinct from new."user_Id"
     or old.clinic_id is distinct from new.clinic_id
     or old.clinic_name is distinct from new.clinic_name
     or old.is_active is distinct from new.is_active then
    raise exception using
      errcode = '42501',
      message = 'Clinician identity fields are server managed';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_doctor_directory_identity on public.doctor;
create trigger guard_doctor_directory_identity
  before insert or update or delete on public.doctor
  for each row execute function public.guard_doctor_directory_identity();

-- Narrow the existing policy in place. The policy remains present and RLS is
-- never disabled.
alter policy "authenticated users can manage appointments"
  on public.appointments
  to authenticated
  using (
    assigned_doctor_id = public.current_clinician_id()
    or (
      source_project = 'clinician'
      and doctor_id in (
        public.current_clinician_id(),
        'doctor/' || public.current_clinician_id()
      )
    )
    or public.current_clinician_is_admin()
  )
  with check (
    assigned_doctor_id = public.current_clinician_id()
    or (
      source_project = 'clinician'
      and doctor_id in (
        public.current_clinician_id(),
        'doctor/' || public.current_clinician_id()
      )
    )
    or public.current_clinician_is_admin()
  );

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
  on public.notifications
  for select
  to authenticated
  using (clinician_auth_user_id = auth.uid());

drop policy if exists notifications_mark_own_read on public.notifications;
create policy notifications_mark_own_read
  on public.notifications
  for update
  to authenticated
  using (clinician_auth_user_id = auth.uid())
  with check (clinician_auth_user_id = auth.uid());

create or replace function public.guard_notification_client_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    if old.id is distinct from new.id
       or old.clinician_id is distinct from new.clinician_id
       or old.clinician_auth_user_id is distinct from new.clinician_auth_user_id
       or old.appointment_id is distinct from new.appointment_id
       or old.source_event_id is distinct from new.source_event_id
       or old.type is distinct from new.type
       or old.title is distinct from new.title
       or old.body is distinct from new.body
       or old.created_at is distinct from new.created_at then
      raise exception using errcode = '42501', message = 'Only notification read state may be changed';
    end if;

    if new.is_read then
      new.read_at := coalesce(new.read_at, now());
    else
      new.read_at := null;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists guard_notification_client_update on public.notifications;
create trigger guard_notification_client_update
  before update on public.notifications
  for each row execute function public.guard_notification_client_update();

drop trigger if exists set_notifications_updated_at on public.notifications;
create trigger set_notifications_updated_at
  before update on public.notifications
  for each row execute function public.set_updated_at();

create or replace function public.guard_dawa_mom_appointment_client_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null
     or coalesce(current_setting('dawa.integration_transition', true), '') = 'allowed' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.source_project = 'dawa_mom' then
      raise exception using
        errcode = '42501',
        message = 'Dawa Mom appointment rows are server managed';
    end if;
    return old;
  elsif tg_op = 'INSERT' then
    if new.source_project <> 'clinician'
       or new.source_appointment_id is not null
       or new.source_event_id is not null
       or new.source_created_at is not null
       or new.source_updated_at is not null
       or new.received_at is not null
       or new.integration_status <> 'local'
       or new.integration_synced_at is not null
       or new.integration_error_code is not null
       or new.patient_safe_status_message is not null then
      raise exception using
        errcode = '42501',
        message = 'Appointment integration fields are server managed';
    end if;
    return new;
  end if;

  if old.source_project is distinct from new.source_project
     or old.source_appointment_id is distinct from new.source_appointment_id
     or old.source_event_id is distinct from new.source_event_id
     or old.source_created_at is distinct from new.source_created_at
     or old.source_updated_at is distinct from new.source_updated_at
     or old.received_at is distinct from new.received_at
     or old.integration_status is distinct from new.integration_status
     or old.integration_synced_at is distinct from new.integration_synced_at
     or old.integration_error_code is distinct from new.integration_error_code
     or old.patient_safe_status_message is distinct from new.patient_safe_status_message
     or old.source_project = 'dawa_mom'
     or new.source_project = 'dawa_mom' then
    raise exception using
      errcode = '42501',
      message = 'Dawa Mom appointment source and status fields are server managed';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_dawa_mom_appointment_client_write on public.appointments;
create trigger guard_dawa_mom_appointment_client_write
  before insert or update or delete on public.appointments
  for each row execute function public.guard_dawa_mom_appointment_client_write();

create or replace function public.get_bookable_clinician_directory(
  p_clinic_integration_id uuid default null
)
returns table (
  id uuid,
  display_name text,
  professional_title text,
  speciality text,
  clinic_id uuid,
  clinic_name text,
  profile_image_url text,
  is_active boolean,
  is_bookable boolean,
  start_time text,
  end_time text,
  slot_minutes integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    d.integration_id,
    coalesce(nullif(trim(d.name), ''), 'Clinician'),
    d.professional_title,
    d.speciality,
    c.integration_id,
    c.name,
    d.profile_image_url,
    d.is_active,
    d.is_bookable,
    d.start_time,
    d.end_time,
    d.slot_minutes
  from public.doctor d
  join public.clinic c on c.id = d.clinic_id
  where d.is_active
    and d.is_bookable
    and d.auth_user_id is not null
    and (p_clinic_integration_id is null or c.integration_id = p_clinic_integration_id)
  order by d.name;
$$;

revoke all on function public.get_bookable_clinician_directory(uuid)
  from public, anon, authenticated;
grant execute on function public.get_bookable_clinician_directory(uuid)
  to service_role;

create or replace function public.receive_dawa_mom_appointment(
  p_event_id uuid,
  p_source_appointment_id uuid,
  p_source_mother_id uuid,
  p_patient_id text,
  p_clinician_integration_id uuid,
  p_clinic_integration_id uuid,
  p_appointment_date date,
  p_start_time time without time zone,
  p_end_time time without time zone,
  p_appointment_type text default 'maternal_health',
  p_reason text default null,
  p_notes text default null,
  p_source_created_at timestamptz default null,
  p_source_updated_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  previous_result jsonb;
  patient_row public.mother%rowtype;
  doctor_row public.doctor%rowtype;
  clinic_row public.clinic%rowtype;
  destination_appointment_id text;
  result_payload jsonb;
  notification_body text;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));
  perform set_config('dawa.integration_transition', 'allowed', true);

  select e.result into previous_result
  from public.integration_processed_events e
  where e.source = 'dawa_mom'
    and e.event_id = p_event_id;

  if previous_result is not null then
    return previous_result;
  end if;

  if p_end_time <= p_start_time then
    raise exception using errcode = '22023', message = 'Appointment end time must be after start time';
  end if;

  if (p_appointment_date + p_start_time) <= timezone('Africa/Lusaka', now()) then
    raise exception using errcode = '22023', message = 'Appointment time must be in the future';
  end if;

  select * into patient_row
  from public.mother m
  where m.source_project = 'dawa_mom'
    and m.source_mother_id = p_source_mother_id::text
    and m.source_deleted_at is null
  limit 1;

  if patient_row.id is null then
    raise exception using errcode = 'P0002', message = 'Mapped patient was not found';
  end if;

  if nullif(trim(p_patient_id), '') is not null and patient_row.id <> trim(p_patient_id) then
    raise exception using errcode = '23514', message = 'Patient mapping does not match';
  end if;

  select * into doctor_row
  from public.doctor d
  where d.integration_id = p_clinician_integration_id
    and d.is_active
    and d.is_bookable
  limit 1;

  if doctor_row.id is null or doctor_row.auth_user_id is null then
    raise exception using errcode = '23514', message = 'Selected clinician is not active and bookable';
  end if;

  select * into clinic_row
  from public.clinic c
  where c.integration_id = p_clinic_integration_id
  limit 1;

  if clinic_row.id is null or doctor_row.clinic_id is distinct from clinic_row.id then
    raise exception using errcode = '23514', message = 'Selected clinician is not assigned to the clinic';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    doctor_row.id || ':' || p_appointment_date::text || ':' || p_start_time::text,
    0
  ));

  if exists (
    select 1
    from public.appointments a
    where (
        a.assigned_doctor_id = doctor_row.id
        or (
          a.source_project = 'clinician'
          and a.doctor_id in (doctor_row.id, 'doctor/' || doctor_row.id)
        )
      )
      and coalesce(
        a.appointment_date,
        (a.date at time zone 'Africa/Lusaka')::date
      ) = p_appointment_date
      and left(coalesce(a.start_time::text, a.time, ''), 5) =
        to_char(p_start_time, 'HH24:MI')
      and lower(coalesce(a.status, 'pending')) in ('pending', 'confirmed', 'rescheduled', 'scheduled')
      and not (
        a.source_project = 'dawa_mom'
        and a.source_appointment_id = p_source_appointment_id
      )
  ) or exists (
    select 1
    from public.encounter e
    where e.doctor_id in (doctor_row.id, 'doctor/' || doctor_row.id)
      and (e.date at time zone 'Africa/Lusaka')::date = p_appointment_date
      and left(coalesce(e.time, ''), 5) = to_char(p_start_time, 'HH24:MI')
      and lower(coalesce(e.status, 'scheduled')) not in ('cancelled', 'canceled', 'declined')
  ) then
    raise exception using errcode = '23P01', message = 'Appointment time is no longer available';
  end if;

  destination_appointment_id := 'dawa_mom_' || replace(p_source_appointment_id::text, '-', '');

  insert into public.appointments (
    id,
    "mother_Id",
    mother_id,
    doctor_id,
    status,
    date,
    time,
    payload,
    source_project,
    source_appointment_id,
    source_event_id,
    patient_record_id,
    assigned_doctor_id,
    clinic_record_id,
    appointment_date,
    start_time,
    end_time,
    appointment_type,
    reason,
    notes,
    source_created_at,
    source_updated_at,
    received_at,
    integration_status
  ) values (
    destination_appointment_id,
    'mother/' || patient_row.id,
    patient_row.id,
    doctor_row.id,
    'pending',
    (p_appointment_date + p_start_time) at time zone 'Africa/Lusaka',
    to_char(p_start_time, 'HH24:MI'),
    jsonb_build_object('source', 'dawa_mom'),
    'dawa_mom',
    p_source_appointment_id,
    p_event_id,
    patient_row.id,
    doctor_row.id,
    clinic_row.id,
    p_appointment_date,
    p_start_time,
    p_end_time,
    coalesce(nullif(trim(p_appointment_type), ''), 'maternal_health'),
    left(nullif(trim(p_reason), ''), 1000),
    left(nullif(trim(p_notes), ''), 2000),
    p_source_created_at,
    p_source_updated_at,
    now(),
    'received'
  )
  on conflict (source_project, source_appointment_id)
    where source_appointment_id is not null
    do update set
      source_updated_at = excluded.source_updated_at,
      integration_status = 'received',
      integration_error_code = null
  returning id into destination_appointment_id;

  notification_body := left(
    coalesce(nullif(trim(patient_row.name), ''), 'A patient')
    || ' requested an appointment for '
    || to_char(p_appointment_date, 'DD Mon YYYY')
    || ' at '
    || to_char(p_start_time, 'HH24:MI')
    || '.',
    500
  );

  insert into public.notifications (
    clinician_id,
    clinician_auth_user_id,
    appointment_id,
    source_event_id,
    type,
    title,
    body
  ) values (
    doctor_row.id,
    doctor_row.auth_user_id,
    destination_appointment_id,
    p_event_id,
    'appointment_booked',
    'New appointment request',
    notification_body
  )
  on conflict (source_event_id, clinician_id, type) do nothing;

  result_payload := jsonb_build_object(
    'ok', true,
    'event_id', p_event_id,
    'external_appointment_id', destination_appointment_id,
    'patient_id', patient_row.id,
    'status', 'pending',
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
    'appointment.created',
    p_source_appointment_id::text,
    destination_appointment_id,
    result_payload
  );

  return result_payload;
end;
$$;

create or replace function public.cancel_dawa_mom_appointment(
  p_event_id uuid,
  p_source_appointment_id uuid,
  p_effective_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  previous_result jsonb;
  appointment_row public.appointments%rowtype;
  result_payload jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));
  perform set_config('dawa.integration_transition', 'allowed', true);

  select e.result into previous_result
  from public.integration_processed_events e
  where e.source = 'dawa_mom'
    and e.event_id = p_event_id;

  if previous_result is not null then
    return previous_result;
  end if;

  select * into appointment_row
  from public.appointments a
  where a.source_project = 'dawa_mom'
    and a.source_appointment_id = p_source_appointment_id
  for update;

  if appointment_row.id is null then
    raise exception using errcode = 'P0002', message = 'Appointment was not found';
  end if;

  if lower(coalesce(appointment_row.status, 'pending')) not in (
    'pending', 'confirmed', 'rescheduled', 'cancelled'
  ) then
    raise exception using errcode = '23514', message = 'Appointment can no longer be cancelled';
  end if;

  update public.appointments a
  set status = 'cancelled',
      integration_status = 'received',
      integration_synced_at = coalesce(p_effective_at, now()),
      integration_error_code = null
  where a.id = appointment_row.id
  returning * into appointment_row;

  result_payload := jsonb_build_object(
    'ok', true,
    'event_id', p_event_id,
    'external_appointment_id', appointment_row.id,
    'status', appointment_row.status
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
    'appointment.cancelled',
    p_source_appointment_id::text,
    appointment_row.id,
    result_payload
  );

  return result_payload;
end;
$$;

create or replace function public.update_dawa_mom_appointment_status(
  p_appointment_id text,
  p_status text,
  p_appointment_date date default null,
  p_start_time time without time zone default null,
  p_end_time time without time zone default null,
  p_patient_safe_message text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  appointment_row public.appointments%rowtype;
  doctor_id text;
  normalized_status text := lower(trim(coalesce(p_status, '')));
  status_event_id uuid := gen_random_uuid();
  result_payload jsonb;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Authentication is required';
  end if;

  doctor_id := public.current_clinician_id();
  if doctor_id is null then
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

  if appointment_row.assigned_doctor_id <> doctor_id
     and not public.current_clinician_is_admin() then
    raise exception using errcode = '42501', message = 'Appointment is assigned to another clinician';
  end if;

  if normalized_status not in (
    'confirmed', 'declined', 'rescheduled', 'completed', 'cancelled'
  ) then
    raise exception using errcode = '22023', message = 'Unsupported appointment status';
  end if;

  if appointment_row.status = normalized_status
     and (
       normalized_status <> 'rescheduled'
       or (
         appointment_row.appointment_date is not distinct from p_appointment_date
         and appointment_row.start_time is not distinct from p_start_time
         and appointment_row.end_time is not distinct from p_end_time
       )
     ) then
    return jsonb_build_object(
      'ok', true,
      'deduplicated', true,
      'event_id', null,
      'external_appointment_id', appointment_row.id,
      'source_appointment_id', appointment_row.source_appointment_id,
      'status', appointment_row.status,
      'appointment_date', appointment_row.appointment_date,
      'start_time', appointment_row.start_time,
      'end_time', appointment_row.end_time,
      'integration_status', appointment_row.integration_status
    );
  end if;

  if appointment_row.status <> normalized_status and not (
    (appointment_row.status = 'pending' and normalized_status in ('confirmed', 'declined', 'rescheduled', 'cancelled'))
    or (appointment_row.status = 'confirmed' and normalized_status in ('rescheduled', 'completed', 'cancelled'))
    or (appointment_row.status = 'rescheduled' and normalized_status in ('confirmed', 'completed', 'cancelled'))
  ) then
    raise exception using errcode = '23514', message = 'Invalid appointment status transition';
  end if;

  if normalized_status = 'rescheduled' then
    if p_appointment_date is null or p_start_time is null or p_end_time is null then
      raise exception using errcode = '22023', message = 'Rescheduled appointments require a date and time range';
    end if;

    if p_end_time <= p_start_time
       or (p_appointment_date + p_start_time) <= timezone('Africa/Lusaka', now()) then
      raise exception using errcode = '22023', message = 'Rescheduled appointment time is invalid';
    end if;

    perform pg_advisory_xact_lock(hashtextextended(
      appointment_row.assigned_doctor_id || ':' || p_appointment_date::text || ':' || p_start_time::text,
      0
    ));

    if exists (
      select 1
      from public.appointments a
      where a.id <> appointment_row.id
        and (
          a.assigned_doctor_id = appointment_row.assigned_doctor_id
          or (
            a.source_project = 'clinician'
            and a.doctor_id in (
              appointment_row.assigned_doctor_id,
              'doctor/' || appointment_row.assigned_doctor_id
            )
          )
        )
        and coalesce(
          a.appointment_date,
          (a.date at time zone 'Africa/Lusaka')::date
        ) = p_appointment_date
        and left(coalesce(a.start_time::text, a.time, ''), 5) =
          to_char(p_start_time, 'HH24:MI')
        and lower(coalesce(a.status, 'pending')) in ('pending', 'confirmed', 'rescheduled', 'scheduled')
    ) or exists (
      select 1
      from public.encounter e
      where e.doctor_id in (
        appointment_row.assigned_doctor_id,
        'doctor/' || appointment_row.assigned_doctor_id
      )
        and (e.date at time zone 'Africa/Lusaka')::date = p_appointment_date
        and left(coalesce(e.time, ''), 5) = to_char(p_start_time, 'HH24:MI')
        and lower(coalesce(e.status, 'scheduled')) not in ('cancelled', 'canceled', 'declined')
    ) then
      raise exception using errcode = '23P01', message = 'Appointment time is no longer available';
    end if;
  end if;

  perform set_config('dawa.integration_transition', 'allowed', true);

  update public.appointments a
  set status = normalized_status,
      appointment_date = case when normalized_status = 'rescheduled' then p_appointment_date else a.appointment_date end,
      start_time = case when normalized_status = 'rescheduled' then p_start_time else a.start_time end,
      end_time = case when normalized_status = 'rescheduled' then p_end_time else a.end_time end,
      date = case
        when normalized_status = 'rescheduled'
          then (p_appointment_date + p_start_time) at time zone 'Africa/Lusaka'
        else a.date
      end,
      time = case when normalized_status = 'rescheduled' then to_char(p_start_time, 'HH24:MI') else a.time end,
      -- Do not relay arbitrary clinician-entered text across projects. The
      -- callback contains a fixed, non-clinical message for each status.
      patient_safe_status_message = case normalized_status
        when 'confirmed' then 'Your appointment has been confirmed.'
        when 'declined' then 'This appointment could not be confirmed. Please choose another time.'
        when 'rescheduled' then 'The clinic proposed a new appointment time.'
        when 'completed' then 'Your appointment is marked complete.'
        when 'cancelled' then 'This appointment was cancelled by the clinic.'
        else null
      end,
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
    status_event_id,
    'appointment.status.changed',
    'appointment',
    appointment_row.id,
    jsonb_strip_nulls(jsonb_build_object(
      'event_id', status_event_id,
      'source', 'dawa_clinician',
      'source_appointment_id', appointment_row.source_appointment_id,
      'external_appointment_id', appointment_row.id,
      'status', appointment_row.status,
      'appointment_date', appointment_row.appointment_date,
      'start_time', appointment_row.start_time,
      'end_time', appointment_row.end_time,
      'effective_at', now(),
      'patient_safe_message', appointment_row.patient_safe_status_message
    ))
  );

  result_payload := jsonb_build_object(
    'ok', true,
    'event_id', status_event_id,
    'external_appointment_id', appointment_row.id,
    'source_appointment_id', appointment_row.source_appointment_id,
    'status', appointment_row.status,
    'appointment_date', appointment_row.appointment_date,
    'start_time', appointment_row.start_time,
    'end_time', appointment_row.end_time,
    'integration_status', appointment_row.integration_status
  );

  return result_payload;
end;
$$;

create or replace function public.claim_dawa_mom_status_events(
  p_limit integer,
  p_worker_id text
)
returns setof public.integration_outbox
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_worker_id is null or length(trim(p_worker_id)) < 8 then
    raise exception 'A valid worker id is required';
  end if;

  return query
  with candidates as (
    select o.id
    from public.integration_outbox o
    where (
      (
        o.status in ('pending', 'retrying')
        and o.next_attempt_at <= now()
      ) or (
        o.status = 'processing'
        and o.processing_started_at < now() - interval '10 minutes'
      )
    )
      and not exists (
        select 1
        from public.integration_outbox earlier
        where earlier.aggregate_type = o.aggregate_type
          and earlier.aggregate_id = o.aggregate_id
          and (earlier.created_at, earlier.id) < (o.created_at, o.id)
          and earlier.status <> 'completed'
      )
    order by o.next_attempt_at, o.created_at
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 10), 50))
  )
  update public.integration_outbox o
  set status = 'processing',
      attempt_count = o.attempt_count + 1,
      processing_started_at = now(),
      locked_by = trim(p_worker_id),
      updated_at = now()
  from candidates c
  where o.id = c.id
  returning o.*;
end;
$$;

create or replace function public.complete_dawa_mom_status_event(
  p_job_id uuid,
  p_worker_id text,
  p_success boolean,
  p_error_code text default null,
  p_retry_at timestamptz default null,
  p_permanent boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event public.integration_outbox%rowtype;
  safe_error_code text := left(nullif(trim(p_error_code), ''), 120);
begin
  perform set_config('dawa.integration_transition', 'allowed', true);

  update public.integration_outbox o
  set status = case
        when p_success then 'completed'
        when p_permanent then 'permanently_failed'
        else 'retrying'
      end,
      last_error_code = case when p_success then null else safe_error_code end,
      next_attempt_at = case
        when p_success or p_permanent then o.next_attempt_at
        else coalesce(p_retry_at, now() + interval '15 minutes')
      end,
      processing_started_at = null,
      locked_by = null,
      processed_at = case when p_success or p_permanent then now() else null end,
      updated_at = now()
  where o.id = p_job_id
    and o.status = 'processing'
    and o.locked_by = trim(p_worker_id)
  returning o.* into target_event;

  if target_event.id is null then
    raise exception 'Integration event is not claimed by this worker';
  end if;

  update public.appointments a
  set integration_status = case
        when p_success then 'synced'
        when p_permanent then 'failed'
        else 'retrying'
      end,
      integration_synced_at = case when p_success then now() else a.integration_synced_at end,
      integration_error_code = case when p_success then null else safe_error_code end
  where a.id = target_event.aggregate_id;
end;
$$;

revoke all on function public.receive_dawa_mom_appointment(
  uuid, uuid, uuid, text, uuid, uuid, date, time without time zone,
  time without time zone, text, text, text, timestamptz, timestamptz
) from public, anon, authenticated;
revoke all on function public.cancel_dawa_mom_appointment(uuid, uuid, timestamptz)
  from public, anon, authenticated;
revoke all on function public.claim_dawa_mom_status_events(integer, text)
  from public, anon, authenticated;
revoke all on function public.complete_dawa_mom_status_event(
  uuid, text, boolean, text, timestamptz, boolean
) from public, anon, authenticated;

grant execute on function public.receive_dawa_mom_appointment(
  uuid, uuid, uuid, text, uuid, uuid, date, time without time zone,
  time without time zone, text, text, text, timestamptz, timestamptz
) to service_role;
grant execute on function public.cancel_dawa_mom_appointment(uuid, uuid, timestamptz)
  to service_role;
grant execute on function public.claim_dawa_mom_status_events(integer, text)
  to service_role;
grant execute on function public.complete_dawa_mom_status_event(
  uuid, text, boolean, text, timestamptz, boolean
) to service_role;

revoke all on function public.update_dawa_mom_appointment_status(
  text, text, date, time without time zone, time without time zone, text
) from public, anon;
grant execute on function public.update_dawa_mom_appointment_status(
  text, text, date, time without time zone, time without time zone, text
) to authenticated;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;

  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'appointments'
  ) then
    alter publication supabase_realtime add table public.appointments;
  end if;
end $$;

comment on column public.doctor.integration_id is
  'Stable booking-safe UUID exposed to Dawa Mom instead of the legacy text primary key.';
comment on column public.clinic.integration_id is
  'Stable booking-safe UUID exposed to Dawa Mom instead of the legacy text primary key.';
comment on table public.integration_processed_events is
  'Private receiver idempotency ledger. Replayed events return the stored safe result.';
comment on table public.integration_outbox is
  'Private durable queue for appointment status callbacks to Dawa Mom.';
comment on table public.notifications is
  'Recipient-scoped clinician notifications. Clients may only read/mark their own rows.';
comment on function public.receive_dawa_mom_appointment(
  uuid, uuid, uuid, text, uuid, uuid, date, time without time zone,
  time without time zone, text, text, text, timestamptz, timestamptz
) is 'Transactional idempotent appointment receiver with mapped-patient, assignment, and slot validation.';

notify pgrst, 'reload schema';

commit;
