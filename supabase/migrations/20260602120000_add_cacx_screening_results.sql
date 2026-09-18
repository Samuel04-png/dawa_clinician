create extension if not exists pgcrypto;

create table if not exists public.cacx_screening_results (
  id uuid primary key default gen_random_uuid(),
  patient_id text,
  user_id uuid null,
  image_url text,
  image_path text,
  primary_source text not null default 'arduino_device',
  primary_result text,
  primary_confidence numeric,
  primary_raw_response jsonb not null default '{}'::jsonb,
  second_opinion_required boolean not null default false,
  second_opinion_status text not null default 'not_required',
  second_opinion_source text,
  second_opinion_result text,
  second_opinion_confidence numeric,
  second_opinion_raw_response jsonb,
  risk_level text not null default 'unknown',
  device_endpoint text,
  device_status text not null default 'pending',
  device_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.cacx_screening_results
  add column if not exists patient_id text,
  add column if not exists user_id uuid null,
  add column if not exists image_url text,
  add column if not exists image_path text,
  add column if not exists primary_source text not null default 'arduino_device',
  add column if not exists primary_result text,
  add column if not exists primary_confidence numeric,
  add column if not exists primary_raw_response jsonb not null default '{}'::jsonb,
  add column if not exists second_opinion_required boolean not null default false,
  add column if not exists second_opinion_status text not null default 'not_required',
  add column if not exists second_opinion_source text,
  add column if not exists second_opinion_result text,
  add column if not exists second_opinion_confidence numeric,
  add column if not exists second_opinion_raw_response jsonb,
  add column if not exists risk_level text not null default 'unknown',
  add column if not exists device_endpoint text,
  add column if not exists device_status text not null default 'pending',
  add column if not exists device_error text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.cacx_screening_results
  alter column user_id type uuid
  using case
    when user_id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then user_id::text::uuid
    else null
  end;

alter table public.cacx_screening_results
  drop constraint if exists cacx_screening_results_second_opinion_status_check,
  add constraint cacx_screening_results_second_opinion_status_check
    check (second_opinion_status in ('not_required', 'pending', 'completed', 'failed'));

alter table public.cacx_screening_results
  drop constraint if exists cacx_screening_results_risk_level_check,
  add constraint cacx_screening_results_risk_level_check
    check (risk_level in ('normal', 'low', 'borderline', 'high', 'unknown'));

alter table public.cacx_screening_results
  drop constraint if exists cacx_screening_results_device_status_check,
  add constraint cacx_screening_results_device_status_check
    check (device_status in ('pending', 'success', 'failed', 'timeout'));

create index if not exists idx_cacx_screening_results_patient_id
  on public.cacx_screening_results (patient_id);

create index if not exists idx_cacx_screening_results_user_id
  on public.cacx_screening_results (user_id);

create index if not exists idx_cacx_screening_results_created_at
  on public.cacx_screening_results (created_at);

create index if not exists idx_cacx_screening_results_risk_level
  on public.cacx_screening_results (risk_level);

create index if not exists idx_cacx_screening_results_second_opinion_status
  on public.cacx_screening_results (second_opinion_status);

create index if not exists idx_cacx_screening_results_patient_created
  on public.cacx_screening_results (patient_id, created_at desc);

create index if not exists idx_cacx_screening_results_user_created
  on public.cacx_screening_results (user_id, created_at desc);

create index if not exists idx_cacx_screening_results_second_opinion
  on public.cacx_screening_results (second_opinion_required, second_opinion_status);

drop trigger if exists set_cacx_screening_results_updated_at
  on public.cacx_screening_results;

create trigger set_cacx_screening_results_updated_at
before update on public.cacx_screening_results
for each row execute function public.set_updated_at();

alter table public.cacx_screening_results enable row level security;

drop policy if exists "authenticated users can manage cacx screening results"
  on public.cacx_screening_results;

drop policy if exists "authenticated users can select own cacx screening results"
  on public.cacx_screening_results;

drop policy if exists "authenticated users can insert own cacx screening results"
  on public.cacx_screening_results;

drop policy if exists "authenticated users can update own cacx screening results"
  on public.cacx_screening_results;

drop policy if exists "authenticated users can delete own cacx screening results"
  on public.cacx_screening_results;

create policy "authenticated users can select own cacx screening results"
on public.cacx_screening_results
for select
to authenticated
using (user_id = auth.uid());

create policy "authenticated users can insert own cacx screening results"
on public.cacx_screening_results
for insert
to authenticated
with check (user_id = auth.uid());

create policy "authenticated users can update own cacx screening results"
on public.cacx_screening_results
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "authenticated users can delete own cacx screening results"
on public.cacx_screening_results
for delete
to authenticated
using (user_id = auth.uid());
