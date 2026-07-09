begin;

do $$
declare
  patients_kind "char";
  sync_table text;
begin
  select c.relkind
    into patients_kind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'patients';

  if patients_kind in ('r', 'p') then
    sync_table := 'public.patients';
  elsif to_regclass('public.mother') is not null then
    sync_table := 'public.mother';
  else
    raise exception
      'Dawa Mom patient sync could not find public.patients or public.mother';
  end if;

  execute format('alter table %s add column if not exists source_project text', sync_table);
  execute format('alter table %s add column if not exists source_mother_id text', sync_table);
  execute format('alter table %s add column if not exists source_user_id text', sync_table);
  execute format('alter table %s add column if not exists registration_source text', sync_table);
  execute format('alter table %s add column if not exists synced_at timestamptz', sync_table);
  execute format('alter table %s add column if not exists source_deleted_at timestamptz', sync_table);

  execute format(
    'alter table %s alter column registration_source set default %L',
    sync_table,
    'clinician'
  );

  execute format(
    'update %s set registration_source = %L where registration_source is null',
    sync_table,
    'clinician'
  );
end $$;

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

  if patients_kind is null and to_regclass('public.mother') is not null then
    create view public.patients
      with (security_invoker = true)
      as select * from public.mother;
  elsif patients_kind = 'v' and to_regclass('public.mother') is not null then
    create or replace view public.patients
      with (security_invoker = true)
      as select * from public.mother;
  end if;

  if to_regclass('public.patients') is not null then
    grant select, insert, update, delete on public.patients
      to authenticated, service_role;
  end if;
end $$;

do $$
declare
  patients_kind "char";
  index_table text;
begin
  select c.relkind
    into patients_kind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'patients';

  if patients_kind in ('r', 'p') then
    index_table := 'public.patients';
  elsif to_regclass('public.mother') is not null then
    index_table := 'public.mother';
  else
    raise exception
      'Dawa Mom patient sync could not find a table for unique indexing';
  end if;

  execute format(
    'create unique index if not exists patients_source_project_source_mother_id_uidx
       on %s (source_project, source_mother_id)
     where source_project is not null
       and source_mother_id is not null',
    index_table
  );

  execute format(
    'create index if not exists patients_registration_source_idx
       on %s (registration_source)',
    index_table
  );

  execute format(
    'create index if not exists patients_source_deleted_at_idx
       on %s (source_deleted_at)',
    index_table
  );
end $$;

commit;
