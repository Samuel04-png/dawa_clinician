# Future Improvements

## Backend And Security

- Replace broad RLS policies with clinic-aware and role-aware policies.
- Add Supabase Storage migrations for private clinical images and signed URLs.
- Add a device registry and device event audit tables.
- Add foreign keys or controlled reference mapping where safe.
- Add database-level constraints for important clinical statuses.
- Add structured audit logs for AI/device results.

## Offline And Sync

- Add an encrypted local store for clinical data.
- Create a general pending-write queue, not only CaCx insert queue.
- Add sync status UI.
- Add conflict handling.
- Add cache expiry and manual cache clear controls.
- Test offline login, navigation, CaCx, and reconnect behavior end to end.

## CaCx

- Move online AI calls behind a Supabase Edge Function.
- Store model name, model version, prompt/parser version, and endpoint version.
- Add private image upload to Supabase Storage.
- Add clinician review workflow.
- Add patient-safe report export.
- Add second-opinion retry status and error details.

## Device Integration

- Add the actual Raspberry Pi/Arduino/Flask service code or a separate linked repo.
- Add signed device requests or clinic-local authentication.
- Add CORS and HTTPS guidance per deployment type.
- Add idempotency keys to prevent duplicate result saves.
- Add device status dashboard and diagnostics.

## Patient Management

- Consolidate newer patient details and legacy maternal detail flows.
- Strengthen patient ID consistency between `mother.id`, `mother.mother_id`, and CaCx `patient_id`.
- Add richer patient timeline views.
- Add filtering by risk, missing data, and recent screening.

## Ultrasound, HemoNix, CT, BP

- Persist ultrasound records to Supabase.
- Add real HemoNix schema and device ingestion.
- Add CT scan media/report schema.
- Persist BP readings and interpretation details.
- Link all tool records to patient, clinician, clinic, and encounter.

## UI/UX

- Capture screenshots for GitBook.
- Continue responsive QA on mobile/tablet/desktop.
- Polish legacy generated screens.
- Fix text typos and inconsistent clinical wording.
- Add empty/loading/error states for every backend dependency.

## Testing

- Add Supabase repository tests with mocks.
- Add offline/connectivity tests.
- Add CaCx result save and sync tests.
- Add patient details history tests.
- Add Edge Function tests for malformed payloads.
- Add hardware contract tests against a mock local server.
