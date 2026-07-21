# Safe implementation plan

1. Correct the Dawa Clinician root widget tree so `OfflineStatusScope` and its
   tooltip are below a real Navigator/Overlay; add an offline-banner regression
   test.
2. Add an appointment-linked lifecycle to the existing clinician `encounter`
   table and a separate immutable/versioned patient-facing result-summary
   model. Preserve all legacy encounter fields and workflows.
3. Add assigned-clinician, security-definer draft and transactional-completion
   RPCs. A generic status update must reject direct completion.
4. Build a responsive clinician assessment screen that reuses existing fields,
   supports drafts, represents measured/not-measured/unavailable explicitly,
   validates the minimal completion rules, previews the safe summary, and only
   then completes.
5. Extend the existing clinician outbox/worker and existing Dawa Mom receiver
   with one idempotent `appointment.results_available` event. Do not create a
   parallel sync mechanism.
6. Store only patient-safe result sections in the Dawa Mom project under
   patient-owned RLS. Never transfer clinician-only notes, internal reasoning,
   audit payloads, or raw unrestricted encounter rows.
7. Load the result with Dawa Mom Appointment Details and present responsive,
   plain-language maternal, pregnancy/baby, recommendation, and follow-up
   cards. A completed appointment whose result is still retrying must show a
   calm pending state.
8. Extend patient sync with explicit pregnancy state and source dates while
   preserving Dawa Clinician's independent local pregnancy record.
9. After the workflow passes, simplify the duplicated clinician patient header
   and refresh the legacy Dawa Mom encounter-results screen using the same
   light responsive result components.
10. Apply additive migrations and deploy changed Edge Functions to each app's
    own linked project, verify schedules/secrets without exposing values, run
    SQL/RLS/idempotency tests, Dart format/analyze/tests, web builds, and an
    Android compile check. Do not push Git changes unless separately requested.
