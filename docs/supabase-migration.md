# Supabase Migration

The Supabase migration work is split into SQL migrations, app-side Supabase wiring, Edge Functions, and local migration tools.

## Supabase Folder Structure

```text
supabase/
|-- FIREBASE_TO_SUPABASE_MIGRATION.md
|-- functions/
|   |-- _shared/
|   |-- analyze-ultrasound-image/
|   |-- analyze-via-image/
|   |-- delete-user/
|   |-- gemini/
|   `-- send-sms/
`-- migrations/
    |-- 20260507111000_clinician_supabase_schema.sql
    |-- 20260507155500_add_firebase_uid_to_users.sql
    `-- 20260602120000_add_cacx_screening_results.sql
```

## Migration Files

### Core Clinician Schema

`20260507111000_clinician_supabase_schema.sql` creates:

- `user`
- `clinic`
- `doctor`
- `mother`
- `first_encounter`
- `encounter`
- `parity`
- `appointments`

It also creates `set_updated_at()`, indexes, triggers, enables RLS, and adds broad authenticated-user policies.

### Firebase UID Column

`20260507155500_add_firebase_uid_to_users.sql` adds:

- `public.user.firebase_uid`
- `idx_user_firebase_uid`

### CaCx Screening Results

`20260602120000_add_cacx_screening_results.sql` creates or updates `public.cacx_screening_results`.

Important fields:

- `patient_id`
- `user_id`
- `image_url`
- `image_path`
- `primary_source`
- `primary_result`
- `primary_confidence`
- `primary_raw_response`
- `second_opinion_required`
- `second_opinion_status`
- `second_opinion_source`
- `second_opinion_result`
- `second_opinion_confidence`
- `risk_level`
- `device_endpoint`
- `device_status`
- `device_error`
- timestamps

It also adds indexes, a trigger, RLS, and user-scoped policies using `user_id = auth.uid()`.

## RLS Policies

Core tables have broad authenticated policies:

```sql
using (true)
with check (true)
```

This is useful while migrating, but it is not strict enough for production clinical data. I should replace these with clinic/role/patient-aware policies.

The CaCx table is more restrictive because it checks `user_id = auth.uid()`.

## Storage Buckets

Needs confirmation. The CaCx result table has `image_url` and `image_path`, and code builds paths like:

```text
cacx/{userId}/{patientId}/{timestamp}.jpg
```

However, I did not confirm a Supabase Storage bucket migration in the current repo. This should be added or documented before production uploads rely on storage paths.

## Setup For A New Developer

1. Create or access the Supabase project.
2. Apply the SQL migrations in order.
3. Configure Auth providers and email templates as needed.
4. Configure Edge Function secrets.
5. Run the app with the correct `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
6. Run migration verification scripts if validating imported Firebase data.

## Missing Or Unconfirmed Pieces

- Live database migration status.
- Storage bucket setup for images.
- Production RLS policies.
- Clinic-aware authorization.
- Complete device ingestion schema beyond CaCx.
- Whether all Edge Functions are deployed and configured with secrets.
