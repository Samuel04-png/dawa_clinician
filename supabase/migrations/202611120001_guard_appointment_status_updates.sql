-- Compare the version while holding the same row lock as the approved status
-- workflow. The existing RPC still owns transitions, slot checks and outbox.
create or replace function public.update_dawa_mom_appointment_if_current(
  p_appointment_id text,
  p_expected_updated_at timestamptz,
  p_expected_status text,
  p_status text,
  p_appointment_date date default null,
  p_start_time time default null,
  p_end_time time default null
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_row public.appointments%rowtype;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Authentication is required';
  end if;
  select * into current_row from public.appointments
  where id = p_appointment_id and source_project = 'dawa_mom'
  for update;
  if current_row.id is null then
    raise exception using errcode = '42501', message = 'Appointment is unavailable';
  end if;
  if p_expected_updated_at is null
     or current_row.updated_at is distinct from p_expected_updated_at
     or current_row.status is distinct from p_expected_status then
    raise exception using errcode = '40001', message = 'Appointment changed. Refresh and review its current state.';
  end if;
  return public.update_dawa_mom_appointment_status(
    p_appointment_id, p_status, p_appointment_date, p_start_time, p_end_time, null
  );
end;
$$;
revoke all on function public.update_dawa_mom_appointment_if_current(text,timestamptz,text,text,date,time,time) from public, anon;
grant execute on function public.update_dawa_mom_appointment_if_current(text,timestamptz,text,text,date,time,time) to authenticated;
notify pgrst, 'reload schema';
