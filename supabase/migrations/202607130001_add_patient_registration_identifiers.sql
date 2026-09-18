begin;

alter table public.mother
  add column if not exists nrc text,
  add column if not exists village text,
  add column if not exists clinic_name text;

create index if not exists idx_mother_nrc
  on public.mother (nrc);

create index if not exists idx_mother_village
  on public.mother (village);

create index if not exists idx_mother_clinic_name
  on public.mother (clinic_name);

commit;
