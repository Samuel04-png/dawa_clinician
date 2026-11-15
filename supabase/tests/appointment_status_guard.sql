begin;
do $verify$
declare
  profile public.doctor%rowtype;
  fixture_patient text := 'TEST_PHASE4_PATIENT_' || gen_random_uuid()::text;
  fixture_booking text := 'TEST_PHASE4_BOOKING_' || gen_random_uuid()::text;
  fixture_decline text := 'TEST_PHASE4_DECLINE_' || gen_random_uuid()::text;
  current_version timestamptz;
  original_version timestamptz;
  current_status text;
  outcome jsonb;
begin
  perform set_config('request.jwt.claim.sub', '', true);
  select d.* into profile from public.doctor d
  join auth.users u on u.id = d.auth_user_id where d.is_active limit 1;
  if profile.id is null then raise exception 'An active clinician test context is required'; end if;
  insert into public.mother(id,name) values (fixture_patient,'Synthetic rollback verification');
  insert into public.appointments(id,source_project,source_appointment_id,patient_record_id,
    assigned_doctor_id,status,appointment_date,start_time,end_time,integration_status)
  values (fixture_booking,'dawa_mom',gen_random_uuid(),fixture_patient,
    profile.id,'pending','2030-11-20','15:37','16:07','synced'),
    (fixture_decline,'dawa_mom',gen_random_uuid(),fixture_patient,
    profile.id,'pending','2030-11-21','15:37','16:07','synced');
  perform set_config('request.jwt.claim.sub',profile.auth_user_id::text,true);
  execute 'set local role authenticated';
  select updated_at into original_version from public.appointments where id=fixture_booking;
  perform public.update_dawa_mom_appointment_if_current(fixture_booking,original_version,'pending','confirmed');
  begin
    perform public.update_dawa_mom_appointment_if_current(fixture_booking,original_version,'pending','declined');
    raise exception 'A stale pending action overwrote the confirmed booking';
  exception when serialization_failure then null;
  end;
  select updated_at into current_version from public.appointments where id=fixture_booking;
  outcome := public.update_dawa_mom_appointment_if_current(fixture_booking,current_version,'confirmed','confirmed');
  if not (outcome->>'deduplicated')::boolean then raise exception 'Identical confirmation did not deduplicate'; end if;
  perform public.update_dawa_mom_appointment_if_current(fixture_booking,current_version,'confirmed','rescheduled','2030-11-22','15:37','16:07');
  select updated_at,status into current_version,current_status from public.appointments where id=fixture_booking;
  if current_status <> 'rescheduled' then raise exception 'Reschedule did not persist in transaction'; end if;
  perform public.update_dawa_mom_appointment_if_current(fixture_booking,current_version,'rescheduled','cancelled');
  select updated_at,status into current_version,current_status from public.appointments where id=fixture_booking;
  if current_status <> 'cancelled' then raise exception 'Cancel did not persist in transaction'; end if;
  begin
    perform public.update_dawa_mom_appointment_if_current(fixture_booking,current_version,'cancelled','confirmed');
    raise exception 'A cancelled booking was restored';
  exception when check_violation then null;
  end;
  select updated_at into current_version from public.appointments where id=fixture_decline;
  perform public.update_dawa_mom_appointment_if_current(fixture_decline,current_version,'pending','declined');
  select status into current_status from public.appointments where id=fixture_decline;
  if current_status <> 'declined' then raise exception 'Decline did not persist in transaction'; end if;
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  begin
    perform public.update_dawa_mom_appointment_if_current(fixture_booking,current_version,'cancelled','confirmed');
    raise exception 'An unrelated identity accessed the booking';
  exception when insufficient_privilege then null;
  end;
end
$verify$;
rollback;
select
  'Confirm, deduplication, stale rejection, reschedule, cancel, decline and unrelated-identity checks passed in rolled-back synthetic transaction' as result,
  (select count(*) from public.mother where id like 'TEST_PHASE4_PATIENT_%') as committed_fixture_patients,
  (select count(*) from public.appointments where id like 'TEST_PHASE4_%') as committed_fixture_appointments,
  (select count(*) from public.integration_outbox where aggregate_id like 'TEST_PHASE4_%') as committed_fixture_outbox_events;
