-- User-authorized provisioning for every existing active clinician account.
-- Run with a trusted database administrator. Does not alter RLS or grant access
-- to auth-only/patient accounts without an active clinician profile.
begin;

do $$
begin
  if (select count(*) from public.clinic) <> 1 then
    raise exception 'Multiple or missing clinics: explicitly map unlinked clinicians before provisioning';
  end if;
  if not exists(select 1 from public.doctor where is_active and auth_user_id is not null) then
    raise exception 'No active clinician accounts found';
  end if;
end;
$$;

insert into public.anemia_clinician_memberships(user_id, clinic_id, is_active)
select distinct d.auth_user_id,
  coalesce(d.clinic_id, (select id from public.clinic)), true
from public.doctor d join auth.users u on u.id = d.auth_user_id
where d.is_active
on conflict(user_id, clinic_id) do update set is_active = true;

insert into public.anemia_patient_access(patient_id, user_id, clinic_id, is_active)
select p.id, d.auth_user_id,
  coalesce(d.clinic_id, (select id from public.clinic)), true
from public.doctor d join auth.users u on u.id = d.auth_user_id
cross join public.mother p
where d.is_active and p.source_deleted_at is null
on conflict(patient_id, user_id) do update
  set clinic_id = excluded.clinic_id, is_active = true;

-- Check the actual patient-list RPC for every account before committing.
do $$
declare clinician record; actual integer; expected integer;
begin
  select count(*) into expected from public.mother
    where source_deleted_at is null and nullif(trim(name),'') is not null;
  for clinician in select distinct auth_user_id from public.doctor
    where is_active and auth_user_id is not null loop
    perform set_config('request.jwt.claims', jsonb_build_object(
      'sub', clinician.auth_user_id, 'role', 'authenticated')::text, true);
    select count(*) into actual from public.list_anemia_patients();
    if actual <> expected then
      raise exception 'Anemia patient-list verification failed: expected %, received %', expected, actual;
    end if;
  end loop;
end;
$$;
commit;

select count(distinct a.user_id) as enabled_clinician_accounts,
 count(distinct a.patient_id) as assigned_patients,
 count(*) as patient_assignments
from public.anemia_patient_access a
join public.anemia_clinician_memberships m using(user_id, clinic_id)
where a.is_active and m.is_active;
