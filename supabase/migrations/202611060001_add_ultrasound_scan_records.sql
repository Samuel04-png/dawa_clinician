create table if not exists public.ultrasound_scan_records (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.mother(id),
  user_id uuid not null references auth.users(id),
  examination_id text not null unique,
  workflow text not null check (workflow in ('manual', 'ai_guided')),
  analysis_provider text not null check (analysis_provider in ('cloud', 'edgeDevice')),
  model_id text,
  model_version text,
  device_id text,
  overall_assessment text not null,
  overall_level text check (overall_level in ('normal', 'monitor', 'urgent')),
  recommendation text,
  estimated_gestational_age integer
    check (estimated_gestational_age between 4 and 45),
  measurements jsonb,
  findings jsonb not null default '[]'::jsonb,
  segmentation jsonb,
  created_at timestamptz not null default now(),
  constraint ultrasound_scan_records_result_shape check (
    (segmentation is not null and analysis_provider = 'edgeDevice')
    or (overall_level is not null and recommendation is not null)
  )
);

create index if not exists idx_ultrasound_scan_records_patient_created
  on public.ultrasound_scan_records (patient_id, created_at desc);
create index if not exists idx_ultrasound_scan_records_user_created
  on public.ultrasound_scan_records (user_id, created_at desc);

alter table public.ultrasound_scan_records enable row level security;

drop policy if exists "clinicians can read own ultrasound scan records"
  on public.ultrasound_scan_records;
create policy "clinicians can read own ultrasound scan records"
on public.ultrasound_scan_records
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "clinicians can create own ultrasound scan records"
  on public.ultrasound_scan_records;
create policy "clinicians can create own ultrasound scan records"
on public.ultrasound_scan_records
for insert
to authenticated
with check (user_id = auth.uid());
