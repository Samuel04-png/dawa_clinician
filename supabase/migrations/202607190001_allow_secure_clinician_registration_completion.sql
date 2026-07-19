begin;

-- Clinicians may choose a valid clinic while their own profile is still
-- incomplete. Once all registration fields are present, directory identity
-- fields remain immutable to non-admin users.
create or replace function public.guard_doctor_directory_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_clinic_name text;
  profile_was_complete boolean;
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

    if new.clinic_id is not null then
      select c.name into selected_clinic_name
      from public.clinic c
      where c.id = new.clinic_id;

      if selected_clinic_name is null then
        raise exception using
          errcode = '23514',
          message = 'Select a valid clinic from the directory';
      end if;
      new.clinic_name := selected_clinic_name;
    else
      new.clinic_id := null;
      if nullif(trim(new.clinic_name), '') is not null then
        select min(c.id), min(c.name)
        into new.clinic_id, selected_clinic_name
        from public.clinic c
        where lower(trim(c.name)) = lower(trim(new.clinic_name))
        having count(*) = 1;
        if selected_clinic_name is not null then
          new.clinic_name := selected_clinic_name;
        end if;
      end if;
    end if;
  else
    if old.integration_id is distinct from new.integration_id
       or old.auth_user_id is distinct from new.auth_user_id
       or old."user_Id" is distinct from new."user_Id"
       or old.is_active is distinct from new.is_active then
      raise exception using
        errcode = '42501',
        message = 'Clinician identity fields are server managed';
    end if;

    if old.clinic_id is distinct from new.clinic_id
       or old.clinic_name is distinct from new.clinic_name then
      profile_was_complete :=
        nullif(trim(old.name), '') is not null
        and nullif(trim(old.phone_number), '') is not null
        and nullif(trim(old.speciality), '') is not null
        and old.clinic_id is not null
        and nullif(trim(old.clinic_name), '') is not null
        and nullif(trim(old.start_time), '') is not null
        and nullif(trim(old.end_time), '') is not null;

      if profile_was_complete then
        raise exception using
          errcode = '42501',
          message = 'Clinician identity fields are server managed';
      end if;

      select c.name into selected_clinic_name
      from public.clinic c
      where c.id = new.clinic_id;

      if selected_clinic_name is null then
        raise exception using
          errcode = '23514',
          message = 'Select a valid clinic from the directory';
      end if;
      new.clinic_name := selected_clinic_name;
    end if;
  end if;

  return new;
end;
$$;

comment on function public.guard_doctor_directory_identity() is
  'Protects clinician directory identity while allowing a clinician to select one valid clinic during incomplete-profile registration.';

commit;
