# Screening Workflows

This project now has several screening and care-tool workflows. Some are fully wired enough for app testing, while others are dashboard shells or local-state prototypes.

## CaCx / Cervical Cancer Screening

Status: Done with production gaps.

Confirmed flow:

1. Open CaCx from Home, Care Tools, Quick Access, or Patient Details.
2. Select or pre-load a patient.
3. Choose camera or gallery image.
4. Send image to local device service when available.
5. Save primary device result to Supabase.
6. If needed, send the same image for online second opinion.
7. Display diagnosis, confidence, breakdown, recommendation, language selector, and save/share actions.
8. Show saved patient-linked history in Patient Details.

Files:

- `lib/application/cacx/cacx_widget.dart`
- `lib/application/cacx/cacx_model.dart`
- `lib/application/cacx/cacx_upload_service.dart`
- `supabase/migrations/20260602120000_add_cacx_screening_results.sql`

## Ultrasound

Status: Partially Done.

Confirmed flow:

- Dashboard for ultrasound workflow.
- Manual and AI-guided scan modes.
- Image upload/capture through `image_picker`.
- Supabase Edge Function call to `analyze-ultrasound-image`.
- Gemini-backed analysis when `GEMINI_API_KEY` is configured.
- Fallback result when no model key is configured.
- Scan records shown in local/mock state.
- EchoWave A bridge page exists for native/media handoff work.

Needs work:

- Persist ultrasound scan records to Supabase.
- Add real patient/encounter linking.
- Validate Gemini output clinically.
- Finish native EchoWave integration.

## HemoNix

Status: Partially Done.

Confirmed behavior:

- Quick-access dashboard exists.
- Record, result, search, completed, and needs-review views exist.
- Uses mock `_QuickAccessRecord` data.

Needs work:

- Real hemoglobin device integration.
- Supabase persistence.
- Units, decimals, quality flags, and clinical review status.

## CT Scan

Status: Partially Done.

Confirmed behavior:

- Quick-access dashboard exists.
- Record, result, search, completed, and needs-review views exist.
- Uses mock `_QuickAccessRecord` data.

Needs work:

- Real imaging workflow.
- File/media storage.
- Radiology report schema.
- Review/escalation process.

## BP Monitor

Status: Partially Done.

Confirmed behavior:

- Dedicated `BpMonitorApp`.
- Captures patient name, age, systolic, diastolic, notes, and risk context.
- Supports diabetes, kidney disease, heart disease, and pregnancy flags.
- Interprets BP category, severity, summary, recommendation, and context notes.
- Keeps saved readings in session-local state.

Needs work:

- Supabase persistence.
- Patient linking.
- Audit/review behavior.

## Routine Follow-Up / Encounters

Status: Done in legacy maternal workflow.

Confirmed behavior:

- Encounters are stored in the `encounter` table.
- Patient detail legacy pages show and route encounters.
- Encounter fields include BP, pulse, urinalysis, anemia-related values, fetal heart values, comments, next visit, and status.

Needs review:

- Generated encounter files are very large and excluded from analyzer checks, so they need manual QA.
