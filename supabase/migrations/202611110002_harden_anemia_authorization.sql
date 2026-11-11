begin;

-- Screening authorization is deliberately independent of public.user.role and
-- self-editable doctor profiles. Existing patient/clinician rows are untouched.
create table public.anemia_clinician_memberships (
  user_id uuid not null references auth.users(id),
  clinic_id text not null references public.clinic(id),
  clinician_role text not null default 'clinician' check (clinician_role = 'clinician'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (user_id, clinic_id)
);
create table public.anemia_patient_access (
  patient_id text not null references public.mother(id),
  user_id uuid not null,
  clinic_id text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (patient_id, user_id),
  foreign key (user_id, clinic_id)
    references public.anemia_clinician_memberships(user_id, clinic_id)
);

alter table public.anemia_clinician_memberships enable row level security;
alter table public.anemia_patient_access enable row level security;
revoke all on public.anemia_clinician_memberships, public.anemia_patient_access from public, anon, authenticated;
grant select on public.anemia_clinician_memberships, public.anemia_patient_access to authenticated;
grant all on public.anemia_clinician_memberships, public.anemia_patient_access to service_role;
create policy anemia_membership_read_self on public.anemia_clinician_memberships
  for select to authenticated using (user_id = (select auth.uid()));
create policy anemia_access_read_self on public.anemia_patient_access
  for select to authenticated using (user_id = (select auth.uid()));

create function public.can_access_anemia_patient(p_patient_id text, p_clinic_id text default null)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null and exists (
    select 1 from public.anemia_patient_access a
    join public.anemia_clinician_memberships m
      on m.user_id = a.user_id and m.clinic_id = a.clinic_id
    where a.patient_id = p_patient_id and a.user_id = auth.uid()
      and a.is_active and m.is_active and m.clinician_role = 'clinician'
      and (p_clinic_id is null or a.clinic_id = p_clinic_id)
  );
$$;
revoke all on function public.can_access_anemia_patient(text,text) from public, anon;
grant execute on function public.can_access_anemia_patient(text,text) to authenticated;

-- Provision only from a trusted backend/service role or an administrator whose
-- role was assigned in auth app_metadata. Never trust user-editable user_metadata
-- or the legacy public.user.role column for screening authorization.
create function public.grant_anemia_patient_access(p_user_id uuid, p_clinic_id text, p_patient_id text)
returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and coalesce(auth.jwt()->'app_metadata'->>'role', '') <> 'admin' then
    raise exception using errcode = '42501', message = 'Screening access is managed by an authorized administrator';
  end if;
  insert into public.anemia_clinician_memberships(user_id, clinic_id)
    values(p_user_id, p_clinic_id)
    on conflict(user_id, clinic_id) do update set is_active = true;
  insert into public.anemia_patient_access(patient_id, user_id, clinic_id)
    values(p_patient_id, p_user_id, p_clinic_id)
    on conflict(patient_id, user_id) do update set clinic_id = excluded.clinic_id, is_active = true;
end;
$$;
revoke all on function public.grant_anemia_patient_access(uuid,text,text) from public, anon;
grant execute on function public.grant_anemia_patient_access(uuid,text,text) to authenticated, service_role;

-- No clinic is guessed for pre-existing examinations. Administrators must
-- explicitly reconcile legacy rows before granting access to them.
alter table public.anemia_screening_records add column clinic_id text references public.clinic(id);
create index anemia_access_user_clinic_idx on public.anemia_patient_access(user_id,clinic_id) where is_active;
create index anemia_records_owner_clinic_idx on public.anemia_screening_records(user_id,clinic_id,created_at desc);

drop policy "clinicians read own anemia records" on public.anemia_screening_records;
drop policy "clinicians insert own anemia records" on public.anemia_screening_records;
drop policy "clinicians update own anemia records" on public.anemia_screening_records;
create policy anemia_read_authorized on public.anemia_screening_records for select to authenticated
  using (user_id = (select auth.uid()) and clinic_id is not null
    and public.can_access_anemia_patient(patient_id, clinic_id));
create policy anemia_insert_authorized on public.anemia_screening_records for insert to authenticated
  with check (user_id = (select auth.uid()) and clinic_id is not null
    and public.can_access_anemia_patient(patient_id, clinic_id));
-- Reviewed examinations are immutable to ordinary clients. Retries use the
-- idempotent RPC below; neither UPDATE nor DELETE is required by Flutter.
revoke all on public.anemia_screening_records from public, anon, authenticated;
grant select, insert on public.anemia_screening_records to authenticated;
grant all on public.anemia_screening_records to service_role;

create function public.valid_anemia_result(p_result jsonb)
returns boolean language plpgsql immutable
set search_path = pg_catalog, public
as $$
declare
  labels text[] := array['No Anemia','Mild Anemia','Moderate Anemia','Severe Anemia'];
  idx integer;
  confidence numeric;
  total numeric := 0;
  probability numeric;
  label text;
begin
  if jsonb_typeof(p_result) <> 'object'
     or jsonb_typeof(p_result->'classification') <> 'string'
     or jsonb_typeof(p_result->'class_index') <> 'number'
     or jsonb_typeof(p_result->'confidence') <> 'number'
     or jsonb_typeof(p_result->'probabilities') <> 'object'
     or jsonb_typeof(p_result->'disclaimer') <> 'string'
     or nullif(trim(p_result->>'disclaimer'),'') is null then return false; end if;
  idx := (p_result->>'class_index')::integer;
  confidence := (p_result->>'confidence')::numeric;
  if idx < 0 or idx > 3 or p_result->>'classification' <> labels[idx+1]
     or confidence < 0 or confidence > 1
     or (select count(*) from jsonb_object_keys(p_result->'probabilities')) <> 4 then return false; end if;
  foreach label in array labels loop
    if jsonb_typeof(p_result->'probabilities'->label) <> 'number' then return false; end if;
    probability := (p_result->'probabilities'->>label)::numeric;
    if probability < 0 or probability > 1 or probability > confidence + 0.02 then return false; end if;
    total := total + probability;
  end loop;
  return abs(total-1) <= 0.02 and
    abs((p_result->'probabilities'->>(p_result->>'classification'))::numeric-confidence) <= 0.02;
exception when others then return false;
end;
$$;
revoke all on function public.valid_anemia_result(jsonb) from public, anon;
grant execute on function public.valid_anemia_result(jsonb) to authenticated, service_role;

create function public.guard_anemia_review()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.clinic_id is null or nullif(trim(new.examination_id),'') is null
     or nullif(trim(new.device_id),'') is null or new.model_id <> 'anemia'
     or new.review_status <> 'reviewed' or nullif(trim(new.review_notes),'') is null
     or not coalesce(public.valid_anemia_result(new.result),false) then
    raise exception using errcode = '23514', message = 'A valid, reviewed anemia screening with complete provenance is required';
  end if;
  return new;
end;
$$;
create trigger anemia_review_guard before insert or update on public.anemia_screening_records
  for each row execute function public.guard_anemia_review();

create function public.list_anemia_patients()
returns table(id text,name text,"dateOfBirth" timestamptz,phone_number text,clinic_id text)
language sql stable security definer set search_path = pg_catalog, public
as $$
  select p.id,p.name,p."dateOfBirth",p.phone_number,a.clinic_id
  from public.mother p
  join public.anemia_patient_access a on a.patient_id = p.id and a.user_id = auth.uid()
  where public.can_access_anemia_patient(p.id,a.clinic_id)
    and p.source_deleted_at is null
    and nullif(trim(p.name),'') is not null;
$$;
revoke all on function public.list_anemia_patients() from public, anon;
grant execute on function public.list_anemia_patients() to authenticated;

create function public.save_anemia_screening_review(
  p_patient_id text, p_examination_id text, p_device_id text, p_result jsonb,
  p_review_notes text, p_review_confirmed boolean
)
returns setof public.anemia_screening_records
language plpgsql security invoker set search_path = pg_catalog, public
as $$
declare
  selected_clinic text;
  saved public.anemia_screening_records%rowtype;
begin
  if auth.uid() is null or p_review_confirmed is distinct from true
     or nullif(trim(p_review_notes),'') is null then
    raise exception using errcode = '42501', message = 'Authenticated clinician review and nonempty review notes are required';
  end if;
  select a.clinic_id into selected_clinic from public.anemia_patient_access a
    where a.patient_id = p_patient_id and a.user_id = auth.uid()
      and public.can_access_anemia_patient(a.patient_id,a.clinic_id);
  if selected_clinic is null then
    raise exception using errcode = '42501', message = 'You are not authorized to screen this patient';
  end if;
  insert into public.anemia_screening_records(
    patient_id,user_id,clinic_id,examination_id,model_id,device_id,result,review_notes,review_status
  ) values(p_patient_id,auth.uid(),selected_clinic,p_examination_id,'anemia',p_device_id,p_result,trim(p_review_notes),'reviewed')
  on conflict(examination_id) do nothing;
  select * into saved from public.anemia_screening_records where examination_id = p_examination_id;
  if not found or saved.patient_id is distinct from p_patient_id
     or saved.user_id is distinct from auth.uid() or saved.clinic_id is distinct from selected_clinic
     or saved.model_id <> 'anemia' or saved.device_id is distinct from p_device_id
     or saved.result is distinct from p_result or saved.review_notes is distinct from trim(p_review_notes) then
    raise exception using errcode = '23505', message = 'The examination was already saved with different content or is unavailable';
  end if;
  return next saved;
end;
$$;
revoke all on function public.save_anemia_screening_review(text,text,text,jsonb,text,boolean) from public, anon;
grant execute on function public.save_anemia_screening_review(text,text,text,jsonb,text,boolean) to authenticated;
comment on table public.anemia_clinician_memberships is 'Server-approved clinician/clinic membership; no self-enrollment from editable profile roles.';
comment on table public.anemia_patient_access is 'Explicit clinician and clinic scope for anemia screening; does not change existing patient records.';
notify pgrst, 'reload schema';
commit;
