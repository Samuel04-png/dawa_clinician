-- Reviewed lower-eyelid prototype classifications, not Hb measurements.
create table if not exists public.anemia_screening_records (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.mother(id),
  user_id uuid not null references auth.users(id),
  examination_id text not null unique,
  model_id text not null check (model_id = 'anemia'),
  device_id text not null,
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  review_notes text not null check (length(trim(review_notes)) > 0),
  review_status text not null check (review_status = 'reviewed'),
  created_at timestamptz not null default now()
);
create index if not exists anemia_records_patient_created
  on public.anemia_screening_records (patient_id, created_at desc);
alter table public.anemia_screening_records enable row level security;
create policy "clinicians read own anemia records" on public.anemia_screening_records
  for select to authenticated using (user_id = auth.uid());
create policy "clinicians insert own anemia records" on public.anemia_screening_records
  for insert to authenticated with check (user_id = auth.uid() and
    exists (select 1 from public.mother m where m.id = anemia_screening_records.patient_id));
create policy "clinicians update own anemia records" on public.anemia_screening_records
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid() and exists (select 1 from public.mother m where m.id = anemia_screening_records.patient_id));
