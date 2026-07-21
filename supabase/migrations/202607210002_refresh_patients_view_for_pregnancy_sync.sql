-- Keep the patients compatibility object aligned with the pregnancy fields
-- added to mother. PostgreSQL freezes SELECT * view columns at creation time.

begin;

do $$
declare
  patients_kind "char";
begin
  select c.relkind
    into patients_kind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'patients';

  if patients_kind = 'v' and to_regclass('public.mother') is not null then
    execute 'create or replace view public.patients '
      || 'with (security_invoker = true) as select * from public.mother';
  elsif patients_kind in ('r', 'p') then
    alter table public.patients
      add column if not exists source_pregnancy_status text,
      add column if not exists source_pregnancy_lnmp date,
      add column if not exists source_pregnancy_estimated_due_date date,
      add column if not exists source_pregnancy_updated_at timestamptz,
      add column if not exists source_pregnancy_provenance text;
  else
    raise exception 'Dawa Mom pregnancy sync could not find public.patients';
  end if;

  grant select, insert, update, delete on public.patients
    to authenticated, service_role;
end $$;

commit;
