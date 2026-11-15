-- Captures awaiting analysis; deliberately separate from clinical AI results.
create table if not exists public.cacx_scan_drafts (
  id uuid primary key,
  user_id uuid not null references auth.users(id),
  patient_id text not null references public.mother(id),
  patient_name text not null,
  image_data_uri text not null check (image_data_uri like 'data:image/%'),
  status text not null default 'awaiting_analysis' check (status in ('awaiting_analysis', 'analyzed')),
  created_at timestamptz not null default now()
);
alter table public.cacx_scan_drafts enable row level security;
grant select, insert, update on public.cacx_scan_drafts to authenticated;
create policy "clinicians read own cervical drafts" on public.cacx_scan_drafts
  for select to authenticated using (user_id = auth.uid());
create policy "clinicians insert own cervical drafts" on public.cacx_scan_drafts
  for insert to authenticated with check (user_id = auth.uid() and exists (
    select 1 from public.mother m where m.id = cacx_scan_drafts.patient_id));
create policy "clinicians update own cervical drafts" on public.cacx_scan_drafts
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid() and exists (
    select 1 from public.mother m where m.id = cacx_scan_drafts.patient_id));
