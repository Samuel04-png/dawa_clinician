create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public."user" (
  id text primary key,
  email text,
  display_name text,
  photo_url text,
  uid text,
  created_time timestamptz,
  phone_number text,
  role text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clinic (
  id text primary key,
  name text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.doctor (
  id text primary key,
  speciality text,
  "user_Id" text,
  clinic_name text,
  start_time text,
  end_time text,
  name text,
  phone_number text,
  doctor_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mother (
  id text primary key,
  "dateOfBirth" timestamptz,
  occupation text,
  address text,
  "user_Id" text,
  name text,
  phone_number text,
  mother_id text,
  first_encounter_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.first_encounter (
  id text primary key,
  gravidity text,
  diabetes_mellitus text,
  hypertension text,
  perceiving_foetal_movement text,
  draining_any_liquor text,
  "mother_Id" text,
  sign_of_imminent_eclampsia text[],
  signs_of_anaemia text[],
  symptoms_of_uti text[],
  estimated_due_date timestamptz,
  last_vl text,
  lnmp timestamptz,
  hiv_status text,
  cardiac_disease text,
  parity integer,
  herbs_taken text,
  any_allergies text,
  side_effect text,
  menstruation_regular text,
  cacx text,
  cd4 text,
  epilepsy text,
  asthma text,
  tb text,
  sickle_cell text,
  cacx_date_of_screen timestamptz,
  booked_date timestamptz,
  duration_of_menstruation text,
  drugs_taken text[],
  age_of_menarche text,
  parity_id text[],
  sti text[],
  anc_dates timestamptz[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.encounter (
  id text primary key,
  bp text,
  pulse integer,
  next_visit timestamptz,
  comment text,
  us_obstetrics text,
  leucocytes_esterase text,
  nitrates text,
  urologobulin text,
  protein text,
  ph text,
  blood text,
  ketones text,
  bilirubin text,
  glucose text,
  color text,
  clarity text,
  odor text,
  casts text,
  date timestamptz,
  mother_id text,
  refer_for_anemia text,
  heart_beat integer,
  heart_beat_quality text,
  womb_position text,
  estimated_baby_size integer,
  hemocheck integer,
  specific_gravity text,
  foetal_hemocheck integer,
  clinic_id text,
  doctor_id text,
  status text,
  is_instant boolean,
  time text,
  performed_by text,
  date_performed timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.parity (
  id text primary key,
  weight text,
  state text,
  mode_of_delivery text,
  complications text[],
  first_encounter_id text,
  year_of_birth text,
  marital_status text,
  mothers_height text,
  prepregnancy_weight text,
  mothers_education text,
  fathers_age text,
  fathers_education text,
  kids_alive integer,
  kids_dead integer,
  miscarriages integer,
  birth_number integer,
  prenatal_care_start integer,
  expected_prenatal_visits integer,
  cigarettes_before_pregnancy integer,
  cigarettes_during_1st_trim integer,
  cigarettes_during_2nd_trim integer,
  cigarettes_during_3rd_trim integer,
  risk_factors text,
  delivery_information text,
  induced_labor text,
  augmented_labor text,
  antibiotics text,
  method_of_delivery text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.appointments (
  id text primary key,
  "mother_Id" text,
  mother_id text,
  doctor_id text,
  status text,
  date timestamptz,
  time text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_user_uid on public."user" (uid);
create index if not exists idx_user_email on public."user" (email);
create index if not exists idx_doctor_user_id on public.doctor ("user_Id");
create index if not exists idx_mother_user_id on public.mother ("user_Id");
create index if not exists idx_mother_first_encounter_id on public.mother (first_encounter_id);
create index if not exists idx_first_encounter_mother_id on public.first_encounter ("mother_Id");
create index if not exists idx_parity_first_encounter_id on public.parity (first_encounter_id);
create index if not exists idx_encounter_doctor_status on public.encounter (doctor_id, status);
create index if not exists idx_encounter_doctor_date_time_status on public.encounter (doctor_id, date, time, status);
create index if not exists idx_encounter_mother_date_time_status on public.encounter (mother_id, date, time, status);
create index if not exists idx_appointments_mother_date on public.appointments ("mother_Id", date);
create index if not exists idx_appointments_mother_status_date on public.appointments ("mother_Id", status, date);

drop trigger if exists set_user_updated_at on public."user";
create trigger set_user_updated_at
before update on public."user"
for each row execute function public.set_updated_at();

drop trigger if exists set_clinic_updated_at on public.clinic;
create trigger set_clinic_updated_at
before update on public.clinic
for each row execute function public.set_updated_at();

drop trigger if exists set_doctor_updated_at on public.doctor;
create trigger set_doctor_updated_at
before update on public.doctor
for each row execute function public.set_updated_at();

drop trigger if exists set_mother_updated_at on public.mother;
create trigger set_mother_updated_at
before update on public.mother
for each row execute function public.set_updated_at();

drop trigger if exists set_first_encounter_updated_at on public.first_encounter;
create trigger set_first_encounter_updated_at
before update on public.first_encounter
for each row execute function public.set_updated_at();

drop trigger if exists set_encounter_updated_at on public.encounter;
create trigger set_encounter_updated_at
before update on public.encounter
for each row execute function public.set_updated_at();

drop trigger if exists set_parity_updated_at on public.parity;
create trigger set_parity_updated_at
before update on public.parity
for each row execute function public.set_updated_at();

drop trigger if exists set_appointments_updated_at on public.appointments;
create trigger set_appointments_updated_at
before update on public.appointments
for each row execute function public.set_updated_at();

alter table public."user" enable row level security;
alter table public.clinic enable row level security;
alter table public.doctor enable row level security;
alter table public.mother enable row level security;
alter table public.first_encounter enable row level security;
alter table public.encounter enable row level security;
alter table public.parity enable row level security;
alter table public.appointments enable row level security;

drop policy if exists "authenticated users can manage user records" on public."user";
create policy "authenticated users can manage user records"
on public."user"
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated users can manage clinics" on public.clinic;
create policy "authenticated users can manage clinics"
on public.clinic
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated users can manage doctors" on public.doctor;
create policy "authenticated users can manage doctors"
on public.doctor
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated users can manage mothers" on public.mother;
create policy "authenticated users can manage mothers"
on public.mother
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated users can manage first encounters" on public.first_encounter;
create policy "authenticated users can manage first encounters"
on public.first_encounter
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated users can manage encounters" on public.encounter;
create policy "authenticated users can manage encounters"
on public.encounter
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated users can manage parity" on public.parity;
create policy "authenticated users can manage parity"
on public.parity
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated users can manage appointments" on public.appointments;
create policy "authenticated users can manage appointments"
on public.appointments
for all
to authenticated
using (true)
with check (true);
