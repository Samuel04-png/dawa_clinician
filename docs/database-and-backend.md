# Database And Backend

The current backend direction is Supabase: Supabase Auth, Supabase Postgres tables, PostgREST via `supabase_flutter`, and Supabase Edge Functions for privileged or AI-related operations.

## Confirmed Tables

| Table | Purpose | Migration |
| --- | --- | --- |
| `public.user` | App user profile rows linked to auth users. | `20260507111000_clinician_supabase_schema.sql` |
| `public.clinic` | Clinic records. | `20260507111000_clinician_supabase_schema.sql` |
| `public.doctor` | Clinician/doctor profile records. | `20260507111000_clinician_supabase_schema.sql` |
| `public.mother` | Patient identity and top-level maternal record. | `20260507111000_clinician_supabase_schema.sql` |
| `public.first_encounter` | First ANC/pregnancy history and risk factors. | `20260507111000_clinician_supabase_schema.sql` |
| `public.encounter` | Visit/encounter data, vitals, urinalysis, and follow-up. | `20260507111000_clinician_supabase_schema.sql` |
| `public.parity` | Obstetric and previous pregnancy history. | `20260507111000_clinician_supabase_schema.sql` |
| `public.appointments` | Scheduled appointment records. | `20260507111000_clinician_supabase_schema.sql` |
| `public.cacx_screening_results` | Structured CaCx primary and second-opinion results. | `20260602120000_add_cacx_screening_results.sql` |

## Relationships

The project uses FlutterFlow-style document references, but the Supabase compatibility layer stores those values as text paths or IDs. Important links include:

- `doctor.user_Id` links a doctor profile to `user`.
- `mother.user_Id` links a patient/mother row to `user`.
- `mother.first_encounter_id` links to `first_encounter`.
- `first_encounter.mother_Id` links back to `mother`.
- `encounter.mother_id` links to `mother`.
- `encounter.doctor_id` and `encounter.performed_by` link to `doctor`.
- `parity.first_encounter_id` links to `first_encounter`.
- `cacx_screening_results.patient_id` links by patient identifier, not a formal foreign key.
- `cacx_screening_results.user_id` is a Supabase Auth UUID and is used by RLS.

## Backend Services

| Service | File | Status |
| --- | --- | --- |
| Supabase config and request wrapper | `lib/backend/supabase/supabase_config.dart` | Done |
| Firestore compatibility layer | `lib/backend/supabase/supabase_firestore_compat.dart` | Done |
| Offline Supabase row cache | `lib/backend/supabase/supabase_offline_cache.dart` | Partially Done |
| Firebase-to-Supabase migration tools | `tools/firebase_to_supabase` | Done |
| CaCx result repository | `lib/application/cacx/cacx_upload_service.dart` | Done |

## Edge Functions

| Function | Purpose | Status |
| --- | --- | --- |
| `delete-user` | Deletes the app user row and Supabase Auth user through a service-role client. | Done, needs deployed secrets. |
| `send-sms` | Sends SMS through an external provider token. | Present, needs provider configuration. |
| `gemini` | General Gemini proxy for text/image generation and token counting. | Present, needs `GEMINI_API_KEY`. |
| `analyze-via-image` | Hugging Face inference endpoint for VIA images. | Present, needs `HUGGINGFACE_API_TOKEN` and `HUGGINGFACE_VIA_MODEL`. |
| `analyze-ultrasound-image` | Gemini-backed ultrasound review with fallback if no key is configured. | Done, model output needs clinical review. |

## Known Backend Risks

- Core table RLS policies currently allow any authenticated user to manage broad table data.
- `cacx_screening_results` RLS is stricter and ties rows to `auth.uid()`, but the patient link is still a plain text field.
- Several care-tool modules still keep records in local state or mock data.
- Supabase Storage buckets for CaCx images are not confirmed in the current migrations.
- The existing docs file `docs/hardware-integration-map.md` says CaCx structured persistence was missing; that was true for an earlier state but the current code now has a CaCx results migration and repository.
