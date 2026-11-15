# Phase 4: registry restoration and Appointments

Implemented and verified on 12 November 2026. The existing `/home`, `/moms`, and `/scheduledEncounters` routes and named destinations remain available. Changes are local; the original GitHub `backup_before_redesign` branch is preserved.

## Patient-registry diagnosis and restoration

The redesigned repository explicitly requested `nrc`, `village`, and `clinic_name` from `public.mother`. Those optional fields do not exist in the deployed schema, so PostgREST rejected the entire query. The former compatibility query selected the available columns and tolerated missing optional values.

`lib/application/home/data/home_dashboard_repository.dart` now selects the available row fields for the registry, preserving the smaller Home query. Optional text values are type-checked, malformed IDs are skipped, records are deduplicated by their stable IDs, and source-deleted records remain excluded. Batched first-encounter lookup preserves legacy associations. Errors remain distinct from empty results, and retry performs another authenticated request.

Authorized live verification at `http://localhost:49666/moms` showed **45 of 45 visible patients**, **3 needing completion**, and **3 linked first encounters**. Search/no-match/clear, completion filtering, opening a record with its matching identifier, returning, and browser refresh worked. No patient names or identifiers are included in this report or committed screenshots. Screenshots use synthetic fixtures.

An anonymous REST query returned HTTP 200 with zero visible rows. Deployed `mother` RLS still grants broad authenticated visibility; organization isolation is therefore **not established** by this check. No patient RLS policy was weakened or changed. `mother.user_Id` identifies a patient account and was not substituted for clinician authorization.

## Appointments behavior

Appointments uses the existing shared workspace shell and one title/action/device control. Compact rows support real patient identity, source, recorded status, appointment time, contextual actions, loading/error/empty states, patient search, source/status/date filters, and List/Calendar views.

- **Today:** the current clinic date and actual recorded statuses.
- **Upcoming:** future active bookings after today.
- **Requests:** pending bookings, including explicitly flagged past-dated requests.
- **History:** past or terminal records, preserving their actual statuses.

Clinic time follows the existing booking RPC's Africa/Lusaka UTC+02 convention. Booking and associated encounter rows are deduplicated without changing their identities. Missing names and links are explicit. Pending requests offer Confirm with Decline/Reschedule secondary actions; active bookings offer Open/Reschedule/Cancel; terminal bookings offer details and permitted associated encounter navigation. Clinical completion remains in the assessment workflow because the deployed backend rejects completion without an assessment.

Consequential changes require confirmation. Stale writes refresh and require another user decision. Existing Dawa Mom transition, notification, and outbox behavior is retained. The existing realtime appointment watcher is reused with a 350ms refresh debounce; no periodic polling was introduced. Auth changes clear stale records and cancel relevant overlays.

## Database change and live checks

**Deployed** the additive `202611120001_guard_appointment_status_updates.sql` migration. Its `update_dawa_mom_appointment_if_current` function is SECURITY INVOKER, checks the authenticated visible row under a lock, verifies expected status/version, then delegates to the approved existing status RPC. Public/anonymous execution is revoked. It introduces no replacement status logic, tables, or RLS policies.

`supabase/tests/appointment_status_guard.sql` verified confirm, duplicate/stale rejection, reschedule, cancel, decline, invalid restoration rejection, and unrelated-identity rejection under authenticated database roles. Synthetic fixture creation and transitions ran in a transaction that was **rolled back**. Follow-up checks found zero committed fixture patients, appointments, or outbox entries. This verifies backend behavior without submitting real bookings or claiming external Dawa Mom delivery.

The signed-in browser displayed the live Requests workspace and its actual counts (Today 0, Upcoming 0, Requests 1, History 4), past-dated context, and appointment details. No live booking status was changed through the UI.

## Files

| Files | Change |
| --- | --- |
| `lib/application/home/data/home_dashboard_repository.dart` | Registry schema compatibility and safe field mapping |
| `lib/features/appointments/domain/appointment_entry.dart` | Unified booking/legacy model, views and clinic date handling |
| `lib/features/appointments/data/appointment_workspace_repository.dart` | Authenticated reads, relationships and guarded mutations |
| `lib/features/appointments/presentation/appointment_workspace_content.dart` | Rows, filters, task tabs and calendar |
| `lib/application/scheduled_encounters/scheduled_encounters_widget.dart` | Shared shell, refresh, details, actions and realtime integration |
| `lib/application/scheduled_encounters/schedule_appointment_dialog.dart` | Existing scheduling flow, clinic time and responsive dialog |
| `lib/features/appointments/presentation/dawa_mom_appointment_requests.dart` | Existing notification repository reuse |
| `lib/components/workspace_page_header.dart` | Optional single-line title fitting on very narrow displays |
| `test/home_dashboard_repository_test.dart` | Registry query/mapping regressions |
| `test/appointment_workspace_repository_test.dart` | Eight data/domain/transition tests |
| `test/appointments_phase4_test.dart` | 26 widget, responsive, action and navigation tests |
| `test/clinician_navigation_test.dart` | Material icon font support for screenshots |
| `supabase/migrations/202611120001_guard_appointment_status_updates.sql` | Deployed additive concurrency guard |
| `supabase/tests/appointment_status_guard.sql` | Rolled-back live SQL verification |

## Visual and automated verification

Reviewed [Today](qa/phase4/appointments-today.png), [Upcoming](qa/phase4/appointments-upcoming.png), [Requests](qa/phase4/appointments-requests.png), [History](qa/phase4/appointments-history.png), [collapsed](qa/phase4/appointments-collapsed.png), [tablet](qa/phase4/appointments-tablet.png), [mobile](qa/phase4/appointments-mobile.png), [320px at 200% text](qa/phase4/appointments-large-text.png), and [restored-registry fixture](qa/phase4/patients-restored-fixture.png). Fixtures use mocked device transport and synthetic patient data. Sidebar geometry is compared between real Home, Patients, and Appointments widgets.

Phase 4 analysis and release web build passed. Its focused widget run passed 26 tests; the repository run passed eight. The pre-Phase-5 full suite finished with 255 passed, four skipped and three existing failures: two architecture assertions against the placeholder sync migration, and the demo-capture fixture/golden test. See the Phase 5 review for final combined validation after the subsequent clinical-tool changes.

Legacy encounter appointments, original notification/request components, existing appointment detail URLs, patient/encounter routes, and the approved status RPC remain for compatibility. Physical-device inference, actual screen-reader operation, live registration submission and external notification delivery were not exercised.
