-- Add the Clinician-authoritative service catalog and DawaMom sync outbox.
-- This is the source of truth for services and pricing used by the DawaMom consumer.

begin;

create table if not exists public.clinician_services (
  id uuid primary key default gen_random_uuid(),
  external_service_id text not null,
  external_clinic_id text,
  name text not null,
  description text,
  category text,
  is_paid boolean not null default false,
  price numeric(12,2) not null default 0,
  currency text not null default 'ZMW',
  is_active boolean not null default true,
  source_updated_at timestamptz not null default now(),
  synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clinician_services_name_check check (length(trim(name)) between 2 and 160),
  constraint clinician_services_price_check check (price >= 0),
  constraint clinician_services_paid_price_check check (
    (is_paid and price > 0) or (not is_paid and price = 0)
  ),
  constraint clinician_services_currency_check check (currency ~ '^[A-Z]{3}$'),
  constraint clinician_services_external_id_check check (length(trim(external_service_id)) between 1 and 240)
);

create unique index if not exists clinician_services_external_id_uidx
  on public.clinician_services(external_service_id);

create index if not exists clinician_services_active_idx
  on public.clinician_services(is_active, name);

create index if not exists clinician_services_clinic_idx
  on public.clinician_services(external_clinic_id, is_active)
  where external_clinic_id is not null;

create table if not exists public.service_catalog_sync_outbox (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null default gen_random_uuid(),
  event_type text not null default 'service.catalog.changed',
  aggregate_type text not null default 'service',
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
  constraint clinician_service_sync_outbox_event_unique unique (event_id),
  constraint clinician_service_sync_outbox_event_type_check check (event_type = 'service.catalog.changed'),
  constraint clinician_service_sync_outbox_aggregate_type_check check (aggregate_type = 'service'),
  constraint clinician_service_sync_outbox_status_check check (
    status in ('pending', 'processing', 'completed', 'retrying', 'failed', 'permanently_failed')
  ),
  constraint clinician_service_sync_outbox_attempt_check check (attempt_count >= 0),
  constraint clinician_service_sync_outbox_payload_object_check check (jsonb_typeof(payload) = 'object')
);

create index if not exists clinician_service_sync_outbox_ready_idx
  on public.service_catalog_sync_outbox(status, next_attempt_at, created_at)
  where status in ('pending', 'retrying', 'processing');

create index if not exists clinician_service_sync_outbox_aggregate_idx
  on public.service_catalog_sync_outbox(aggregate_type, aggregate_id, created_at);

create or replace function public.bump_clinician_service_source_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.source_updated_at := coalesce(new.source_updated_at, now());
  elsif tg_op = 'UPDATE' then
    if (
      old.external_service_id is distinct from new.external_service_id
      or old.external_clinic_id is distinct from new.external_clinic_id
      or old.name is distinct from new.name
      or old.description is distinct from new.description
      or old.category is distinct from new.category
      or old.is_paid is distinct from new.is_paid
      or old.price is distinct from new.price
      or old.currency is distinct from new.currency
      or old.is_active is distinct from new.is_active
    ) then
      new.source_updated_at := now();
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.enqueue_service_catalog_sync_job(p_service_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  service_row public.clinician_services%rowtype;
  job_id uuid;
begin
  if p_service_id is null then
    raise exception 'A valid service id is required';
  end if;

  select * into service_row
  from public.clinician_services
  where id = p_service_id;

  if service_row.id is null then
    raise exception 'Service catalog row not found';
  end if;

  select o.id into job_id
  from public.service_catalog_sync_outbox o
  where o.aggregate_type = 'service'
    and o.aggregate_id = service_row.id::text
    and o.status in ('pending', 'retrying')
  order by o.created_at
  limit 1
  for update;

  if job_id is not null then
    update public.service_catalog_sync_outbox
    set payload = jsonb_strip_nulls(jsonb_build_object(
          'external_service_id', service_row.external_service_id,
          'external_clinic_id', service_row.external_clinic_id,
          'name', service_row.name,
          'description', service_row.description,
          'category', service_row.category,
          'is_paid', service_row.is_paid,
          'price', service_row.price,
          'currency', service_row.currency,
          'is_active', service_row.is_active,
          'source_updated_at', service_row.source_updated_at
        )),
        next_attempt_at = now(),
        attempt_count = 0,
        processing_started_at = null,
        locked_by = null,
        last_error_code = null,
        updated_at = now()
    where id = job_id;
  else
    insert into public.service_catalog_sync_outbox (
      event_id,
      event_type,
      aggregate_type,
      aggregate_id,
      payload
    ) values (
      gen_random_uuid(),
      'service.catalog.changed',
      'service',
      service_row.id::text,
      jsonb_strip_nulls(jsonb_build_object(
        'external_service_id', service_row.external_service_id,
        'external_clinic_id', service_row.external_clinic_id,
        'name', service_row.name,
        'description', service_row.description,
        'category', service_row.category,
        'is_paid', service_row.is_paid,
        'price', service_row.price,
        'currency', service_row.currency,
        'is_active', service_row.is_active,
        'source_updated_at', service_row.source_updated_at
      ))
    )
    returning id into job_id;
  end if;

  return job_id;
end;
$$;

create trigger set_clinician_service_updated_at
before insert or update on public.clinician_services
for each row execute function public.bump_clinician_service_source_updated_at();

create or replace function public.sync_service_catalog_after_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    perform public.enqueue_service_catalog_sync_job(new.id);
  end if;
  return coalesce(new, old);
end;
$$;

create trigger sync_service_catalog_after_write
after insert or update of external_service_id, external_clinic_id, name, description, category, is_paid, price, currency, is_active
on public.clinician_services
for each row execute function public.sync_service_catalog_after_write();

-- Initial Dawa-authoritative catalog. Stable external IDs are the cross-project
-- contract; future price changes must go through the admin-only catalog UI/RLS.
insert into public.clinician_services (
  external_service_id,
  name,
  description,
  category,
  is_paid,
  price,
  currency,
  is_active
) values
  (
    'maternal-ultrasound',
    'Ultrasound',
    'Ultrasound scan for pregnancy monitoring',
    'Maternal Health',
    true,
    150,
    'ZMW',
    true
  ),
  (
    'maternal-abo-blood-grouping',
    'ABO Blood Grouping',
    'ABO Blood Grouping test',
    'Maternal Health',
    true,
    50,
    'ZMW',
    true
  ),
  (
    'maternal-birth-kit',
    'Birth kit',
    'Birth kit for safe delivery',
    'Maternal Health',
    true,
    200,
    'ZMW',
    true
  ),
  (
    'cervical-hpv-test-kit',
    'HPV Test Kit',
    'HPV Test Kit for cervical cancer screening',
    'Cervical Cancer',
    true,
    50,
    'ZMW',
    true
  ),
  (
    'general-consultation',
    'Consultation',
    'General medical consultation',
    'General',
    true,
    100,
    'ZMW',
    true
  ),
  (
    'general-home-based-visit',
    'Home based visit',
    'Home based medical visit',
    'General',
    true,
    250,
    'ZMW',
    true
  ),
  (
    'general-sti-screening',
    'STI screening',
    'STI screening test',
    'General',
    true,
    100,
    'ZMW',
    true
  ),
  (
    'contraceptives-condoms',
    'Condoms',
    'Condoms with delivery',
    'Contraceptives',
    true,
    50,
    'ZMW',
    true
  ),
  (
    'contraceptives-injection',
    'Injection',
    'Contraceptive injection',
    'Contraceptives',
    true,
    100,
    'ZMW',
    true
  )
on conflict (external_service_id) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  is_paid = excluded.is_paid,
  price = excluded.price,
  currency = excluded.currency,
  is_active = excluded.is_active;

alter table public.clinician_services enable row level security;
alter table public.service_catalog_sync_outbox enable row level security;
revoke all on table public.clinician_services from anon, authenticated;
revoke all on table public.service_catalog_sync_outbox from anon, authenticated;

create policy clinician_service_catalog_read_admin_only
  on public.clinician_services
  for select
  to authenticated
  using (public.current_clinician_is_admin());

create policy clinician_service_catalog_admin_manage
  on public.clinician_services
  for all
  to authenticated
  using (public.current_clinician_is_admin())
  with check (public.current_clinician_is_admin());

create policy clinician_service_sync_outbox_admin_manage
  on public.service_catalog_sync_outbox
  for select
  to authenticated
  using (public.current_clinician_is_admin());

create or replace function public.claim_service_catalog_sync_jobs(
  p_limit integer,
  p_worker_id text
)
returns setof public.service_catalog_sync_outbox
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
    from public.service_catalog_sync_outbox o
    where (
      (o.status in ('pending', 'retrying') and o.next_attempt_at <= now())
      or (o.status = 'processing' and o.processing_started_at < now() - interval '10 minutes')
    )
    order by o.next_attempt_at, o.created_at
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 10), 25))
  )
  update public.service_catalog_sync_outbox o
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

create or replace function public.complete_service_catalog_sync_job(
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
  safe_error_code text := left(nullif(trim(p_error_code), ''), 120);
begin
  update public.service_catalog_sync_outbox o
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
    and (p_worker_id is null or o.locked_by = p_worker_id or o.processing_started_at is not null);
end;
$$;

revoke all on function public.bump_clinician_service_source_updated_at() from public;
revoke all on function public.enqueue_service_catalog_sync_job(uuid) from public;
revoke all on function public.claim_service_catalog_sync_jobs(integer, text) from public;
revoke all on function public.complete_service_catalog_sync_job(uuid, text, boolean, text, timestamptz, boolean) from public;

grant execute on function public.bump_clinician_service_source_updated_at() to authenticated;
grant execute on function public.enqueue_service_catalog_sync_job(uuid) to authenticated;
grant execute on function public.claim_service_catalog_sync_jobs(integer, text) to authenticated;
grant execute on function public.complete_service_catalog_sync_job(uuid, text, boolean, text, timestamptz, boolean) to authenticated;

comment on table public.clinician_services is 'Clinician-managed service catalog source of truth. DawaMom consumes a synchronized subset.';
comment on table public.service_catalog_sync_outbox is 'Outbox for clinician-to-DawaMom service catalog updates.';

commit;
