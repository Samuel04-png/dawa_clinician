# Appointment results implementation and live verification

Completed on 2026-07-21. Dawa Clinician and Dawa Mom remain separate Flutter
applications connected to separate Supabase projects. No Git commit, branch
switch, merge, or push was performed.

## Implemented workflow

The direct clinician Complete action was replaced with an appointment-linked
assessment workflow:

1. The assigned clinician opens the synced appointment and starts or continues
   its assessment.
2. A draft can be saved without changing the appointment to completed or
   sending patient results.
3. Completion validates the required blood-pressure collection state, clinical
   assessment, recommendation/follow-up, and patient-facing overall status.
   Optional measurements only become valid findings when their collection
   state, value, and interpretation are explicit.
4. One PostgreSQL RPC locks the appointment and atomically saves the encounter,
   completes the encounter and appointment, creates the allowlisted patient
   summary, records the audit entry, and queues one result event.
5. The existing clinician outbox sends
   `appointment.results_available` to the existing Dawa Mom appointment-status
   receiver. The receiver validates the server secret, allowlists the summary,
   applies only a newer version, records the processed event, and completes the
   mapped appointment.
6. Dawa Mom Appointment Details loads the summary. Completed appointments whose
   summary is still in transit show a safe waiting/retry state instead of a
   blank result or technical error.

Repeated completion and delivery are idempotent. A completed appointment keeps
its summary mapping, and a redelivered event cannot duplicate or downgrade the
stored summary.

## Clinical fields and visibility

The assessment reuses the established maternal/pregnancy encounter concepts:

- Maternal: blood pressure (required state), heart rate, and
  blood/haemoglobin level.
- Pregnancy/baby: pregnancy status, fetal heartbeat, heartbeat quality,
  fetal/womb position, and estimated baby size.
- Consultation: symptoms, observations, assessment, treatment,
  recommendations, follow-up, referral, next visit, and notes.

The clinician selects interpretations; Flutter does not invent medical
thresholds. `not_measured`, `unable_to_obtain`, and `not_applicable` are stored
explicitly instead of silently becoming zero.

Only the dedicated patient summary crosses into Dawa Mom. Clinician-only notes,
the unrestricted assessment payload, internal audit data, raw AI output,
credentials, and backend errors are excluded. Dawa Mom applies the allowlist a
second time in its Edge Function and PostgreSQL RPC.

## UI and overlay work

- Root cause of the red screen: Dawa Clinician's `MaterialApp.builder` ignored
  its routed child and mounted `OfflineStatusScope` outside the real
  Router/Navigator Overlay. The dismiss tooltip therefore had no Overlay
  ancestor.
- The app now uses one `MaterialApp.router`; routes are wrapped under the
  Navigator by a `ShellRoute`, with the offline scope and banner below that
  Overlay. No duplicate `MaterialApp` or Navigator was added.
- The clinician assessment is a light, structured, width-constrained form with
  mobile stacking, tablet grouping, a desktop action panel, clear required and
  optional states, draft feedback, patient-summary preview, and completion
  review.
- The duplicated clinician patient header was removed from presentation, and
  pregnancy labels now distinguish pregnant-with-data, pregnant-missing-dates,
  not-pregnant, not-provided, and preferred-not-to-say states.
- Dawa Mom Appointment Details and the legacy encounter-results page now use a
  light Dawa-blue design, readable maximum widths, responsive card grids,
  plain-language labels, recommendations/follow-up sections, and no technical
  identifier in the main UI.
- A final 1366/1440 px test found and fixed a desktop-only fixed-length list
  mutation in the new assessment measurement row before handoff.

## Additive migrations executed in production

### Dawa Clinician — `eatliepvwrviogsnqavu`

- `202607210001_add_appointment_assessments_and_results.sql`
- `202607210002_refresh_patients_view_for_pregnancy_sync.sql`

The first migration adds the appointment/encounter lifecycle, patient summary,
audit, guarded writes/completion, validation, draft and atomic completion RPCs,
result event, RLS, constraints, and indexes. The second refreshes the legacy
`patients` compatibility view so all five new pregnancy-source columns are
available to the deployed receiver. Both versions are present in the live
migration ledger and now match local-to-remote in the Supabase CLI.

The unrelated local migration `202607130001` is intentionally not recorded in
production and was not applied by this work.

### Dawa Mom — `himbfndvsuwiudtzjojh`

- `202607210001_receive_appointment_results.sql`
- `202607210002_sync_patient_pregnancy_state.sql`

These add the owner-readable/server-write-only result summary, secure
idempotent result RPC, pregnancy-aware patient payload/triggers, and the
one-time additive backfill. Both versions were first executed inside a
transaction ending in `ROLLBACK`, then committed in one production transaction
with their migration-ledger entries. Live SQL subsequently confirmed both
entries.

## Edge Functions, schedules, and secrets

- Dawa Clinician `sync-dawa-mom-patient`: deployed ACTIVE as version 6.
- Dawa Mom `receive-dawa-clinician-appointment-status`: deployed ACTIVE as
  version 5 with result-event support.
- The existing workers and webhook architecture were reused; no competing
  webhook or second sync system was introduced.
- Live schedule checks found exactly one active minute schedule on each side:
  `dawa-clinician-status-outbox-every-minute` and
  `dawa-mom-platform-outbox-every-minute`, both `* * * * *`.
- Each required worker secret exists in Supabase Vault. Values were not read or
  documented.

## Backfill and live receipt evidence

The Dawa Mom migration queued 19 pregnancy-aware patient events. The initial
delivery correctly remained retryable because the clinician compatibility view
did not yet expose the five new fields. After applying the additive view
refresh, the existing scheduled worker was invoked using its existing Vault
secret.

Final production state:

- Dawa Mom backfill: 19 completed, 0 active/retrying, 0 permanently failed.
- Dawa Clinician receipt: 5 of 5 pregnancy columns exposed.
- Imported Dawa Mom patients: 19.
- Imported patients with pregnancy status: 19.
- Imported patients with patient provenance: 19.
- Failed clinician result-outbox events: 0.

No patient-identifying values, tokens, service-role keys, or webhook secrets
were included in verification output.

## RLS and server protections verified live

- Clinician patient summary RLS enabled; one assigned-clinician/admin read
  policy; client inserts/updates/deletes revoked.
- Clinician audit RLS enabled; authenticated/anonymous access revoked.
- Both assessment guard triggers active; draft and completion RPCs present.
- Dawa Mom result RLS enabled; owner and admin read policies present; client
  writes revoked; result RPC restricted to service role.
- Receiver filtering accepts only approved result sections, states, units,
  interpretations, pregnancy statuses, and bounded patient-facing text.

## Test and build evidence

Before final documentation:

- Dawa Clinician `flutter analyze`: no issues.
- Dawa Clinician full `flutter test`: 45 tests passed.
- Dawa Clinician `flutter build web --release`: passed.
- Dawa Clinician `flutter build apk --debug`: passed.
- Dawa Mom `flutter analyze`: no issues.
- Dawa Mom full `flutter test`: 57 tests passed.
- Dawa Mom `flutter build web --release`: passed.
- Dawa Mom `flutter build apk --debug`: passed.
- Both changed Edge Functions passed Deno type checking.

The final targeted suite additionally covers the Overlay regression,
completion validation, draft preservation, privacy/RLS structure,
idempotency/versioning, pregnancy-state language, and responsive layouts at
390, 768, 1024, 1366, and 1440 px. Full analyze/tests were rerun after the
desktop-width fix.

Android emitted existing future Gradle/AGP/Kotlin and NDK-version advisories but
completed both builds. A full iOS build remains unavailable because the Mac
does not have the full Xcode application; no iOS project workaround was made.

No synthetic production consultation was completed because that would create
false clinical data and alter a real appointment. The production database
objects, permissions, functions, ledgers, workers, schedules, and the real
pregnancy backfill/receiver path were verified without fabricating a medical
record.
