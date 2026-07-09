# Dawa Mom to Dawa Clinician Patient Sync

## Phase 1 Findings

- Clinician Supabase project ref: `eatliepvwrviogsnqavu`.
- Clinician Supabase URL: `https://eatliepvwrviogsnqavu.supabase.co`.
- The local Flutter config points at the clinician project and uses the existing publishable key. The full key is intentionally not documented here.
- The Supabase CLI link in `supabase/.temp/project-ref` points at `eatliepvwrviogsnqavu`.
- The checked-in schema and live zero-row REST probes show the app's current patient backing table is `public.mother`, not `public.patients`.
- `public.patients` returned 404 from the linked project REST API during analysis; `public.mother` responded successfully.
- The Patients page is `lib/application/moms/moms_widget.dart`. It loads `MotherRecord.collection`, which maps to `public.mother` through `lib/backend/supabase/supabase_firestore_compat.dart`.
- Existing generated Flutter patient wrapper: `lib/backend/schema/mother_record.dart`. No `PatientsTable` or `PatientsRow` class exists in this repository.

## Current Patient Schema

Current patient demographic columns discovered in `public.mother`:

| Clinician column | Meaning |
| --- | --- |
| `id` | Internal text primary key used by the Flutter compatibility layer |
| `dateOfBirth` | Patient date of birth |
| `occupation` | Patient occupation |
| `address` | Patient address |
| `user_Id` | Clinician-project user document reference path |
| `name` | Patient full name |
| `phone_number` | Patient phone number |
| `mother_id` | Patient-facing identifier |
| `first_encounter_id` | First encounter reference path |
| `created_at` | Local created timestamp |
| `updated_at` | Local updated timestamp |

The sync migration adds:

| Sync column | Meaning |
| --- | --- |
| `source_project` | Source system marker, set to `dawa_mom` |
| `source_mother_id` | Dawa Mom `public.mothers.id` |
| `source_user_id` | Dawa Mom Auth user id, not a Clinician Auth foreign key |
| `registration_source` | Registration origin, set to `dawa_mom` for imported records |
| `synced_at` | Last successful webhook sync timestamp |
| `source_deleted_at` | Source deletion/archive marker |

Because `public.patients` is absent in the current project, the migration adds these columns to `public.mother` and creates `public.patients` as a `security_invoker` compatibility view over `public.mother`. If a future environment already has a real `public.patients` table, the same migration adds the columns and indexes there instead.

## Field Ownership

Dawa Mom-owned demographic fields:

- `name`
- `phone_number`
- `dateOfBirth`
- `address`
- `occupation`
- `mother_id` when supplied by Dawa Mom
- `source_project`
- `source_mother_id`
- `source_user_id`
- `registration_source`
- `synced_at`
- `source_deleted_at`

Clinician-owned fields and records:

- `first_encounter_id`
- `user_Id`
- patient status implied by first encounter state
- clinician assignment and clinic workflow records
- medical notes, encounters, appointments, parity, diagnoses, treatment plans
- CaCx, HemoNix, CT Scan, ultrasound, blood pressure, and other screening results

## Field Mapping

| Dawa Mom `public.mothers` | Dawa Clinician destination |
| --- | --- |
| `id` | `patients.source_mother_id`; destination `id` is generated as a deterministic `dawa_mom_...` value |
| `user_id` | `patients.source_user_id` |
| `auth_id` | `patients.source_user_id` fallback |
| `full_name` | `patients.name` |
| `name` | `patients.name` fallback |
| `mobile_number` | `patients.phone_number` |
| `phone_number` | `patients.phone_number` fallback |
| `phone` | `patients.phone_number` fallback |
| `date_of_birth` | `patients.dateOfBirth` |
| `dateOfBirth` | `patients.dateOfBirth` fallback |
| `dob` | `patients.dateOfBirth` fallback |
| `address` | `patients.address` |
| `occupation` | `patients.occupation` |
| `mother_id` | `patients.mother_id` |
| `patient_id` | `patients.mother_id` fallback |

## Duplicate Prevention

The migration creates this unique index on the backing patient table:

`patients_source_project_source_mother_id_uidx`

Columns:

- `source_project`
- `source_mother_id`

The index is partial and only applies when both values are non-null. The Edge Function also checks these two columns before insert and handles unique conflicts by updating the existing record.

## Delete Handling

DELETE webhook events never hard-delete Clinician patient records. The receiver:

- looks up the imported patient by `source_project = 'dawa_mom'` and `source_mother_id`
- sets `source_deleted_at`
- updates `synced_at`
- preserves clinical history

The Patients page filters out records with `source_deleted_at` from the normal list while preserving the underlying record.

## Edge Function

Function name:

`sync-dawa-mom-patient`

Endpoint:

`https://eatliepvwrviogsnqavu.supabase.co/functions/v1/sync-dawa-mom-patient`

Required method:

`POST`

Required header:

`x-dawa-sync-secret: <DAWA_SYNC_SECRET>`

JWT verification:

`verify_jwt = false`

The function uses the Clinician project's hosted Edge Function environment variables. Do not place the service-role key in Flutter, web assets, Git, logs, Dawa Mom code, or webhook headers.

## Dawa Mom Webhook Handoff

- Source project ref: `himbfndvsuwiudtzjojh`
- Source project URL: `https://himbfndvsuwiudtzjojh.supabase.co`
- Source table: `public.mothers`
- Events: `INSERT`, `UPDATE`, `DELETE`
- Destination function: `sync-dawa-mom-patient`
- Destination endpoint: `https://eatliepvwrviogsnqavu.supabase.co/functions/v1/sync-dawa-mom-patient`
- Header name: `x-dawa-sync-secret`
- Header value: the separately generated `DAWA_SYNC_SECRET`

## Deployment Commands

Confirm the linked project before deploying:

```powershell
Get-Content .\supabase\.temp\project-ref
```

Expected output:

```text
eatliepvwrviogsnqavu
```

Apply migrations to the Dawa Clinician project:

```powershell
supabase migration up --linked
```

Set the shared webhook secret in the Dawa Clinician Edge Function environment:

```powershell
supabase secrets set DAWA_SYNC_SECRET="<generated-shared-secret>" --project-ref eatliepvwrviogsnqavu
```

If the hosted Edge Function environment does not already expose the service-role key, set it only as a Clinician Edge Function secret:

```powershell
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<clinician-service-role-key>" --project-ref eatliepvwrviogsnqavu
```

Deploy only to the Dawa Clinician project:

```powershell
supabase functions deploy sync-dawa-mom-patient --project-ref eatliepvwrviogsnqavu
```

Do not deploy this function to `himbfndvsuwiudtzjojh`.

## Safe Test Payloads

Fixtures live in:

`supabase/functions/sync-dawa-mom-patient/fixtures/`

Use a local environment variable for the shared secret. Do not commit its value.

```powershell
$env:DAWA_SYNC_SECRET = "<generated-shared-secret>"
$endpoint = "https://eatliepvwrviogsnqavu.supabase.co/functions/v1/sync-dawa-mom-patient"
```

INSERT:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: $env:DAWA_SYNC_SECRET" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/insert.json"
```

UPDATE:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: $env:DAWA_SYNC_SECRET" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/update.json"
```

DELETE:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: $env:DAWA_SYNC_SECRET" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/delete.json"
```

Missing secret:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/insert.json"
```

Incorrect secret:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: incorrect-secret" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/insert.json"
```

Invalid table name:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: $env:DAWA_SYNC_SECRET" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/invalid-table.json"
```

Missing source mother ID:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: $env:DAWA_SYNC_SECRET" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/missing-source-mother-id.json"
```

Repeated INSERT:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: $env:DAWA_SYNC_SECRET" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/insert.json"
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: $env:DAWA_SYNC_SECRET" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/insert.json"
```

UPDATE before INSERT:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: $env:DAWA_SYNC_SECRET" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/update-before-insert.json"
```

DELETE for a missing patient:

```powershell
curl.exe -i -X POST $endpoint -H "Content-Type: application/json" -H "x-dawa-sync-secret: $env:DAWA_SYNC_SECRET" --data-binary "@supabase/functions/sync-dawa-mom-patient/fixtures/delete-missing.json"
```
