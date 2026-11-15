# Phase 12 — Settings and clinician account UX

## Findings

- Settings duplicated its title in the global app bar and content area, added a
  redundant return-to-Home action, constrained content to an unnecessarily
  narrow column, and used an oversized gradient profile banner.
- The supported clinician record fields are `name`, `phone_number`,
  `speciality`, `start_time`, and `end_time`. Organization is read from
  `clinic_name`; account email is read from the authenticated account. No
  authorization role is displayed or made editable.
- Support and Terms already used in-app dialogs. Services & pricing is retained
  only for users whom the existing `current_clinician_is_admin` RPC identifies
  as administrators.

## Changes

- Reworked `/profile` into the shared sidebar, app bar, edge-device indicator,
  mobile drawer, and bottom-navigation shell used by the redesigned workspace.
- Kept the single global app-bar title and added a concise page introduction;
  removed the duplicate in-content back control.
- Replaced the gradient profile banner with a neutral account summary: real
  profile display name, clinical speciality, organization, authenticated email,
  initials/photo avatar, and existing Edit profile route.
- Grouped actual actions under Account, Help & legal, and Session. Rows have
  outline icons, supporting text, keyboard focus/hover feedback, and a
  restrained destructive Sign out row.
- Rebuilt `/editProfile` in the shared shell with permanent labels, readable
  validation, responsive start/end-time fields, read-only account data, a
  saving state, backend-confirmed success message, retained input on failures,
  and confirmation before discarding edited values.

## Preserved behavior and limitations

- The original Firestore `DoctorRecord.reference.update(createDoctorRecordData(...))`
  update mechanism is retained for the same five editable fields.
- Authentication, Supabase, RLS, schema, membership, edge-device, clinical
  services, and routes were not modified.
- Support and legal content retain their existing in-app destinations. There is
  no existing password, recovery, security-preference, avatar-upload, or
  organization-edit capability; none was simulated.
- The app currently exposes version `v1.0.0` in the existing interface; it is
  retained as low-emphasis application information.

## Verification

- `flutter analyze` — passed.
- `flutter test --no-pub test/clinician_navigation_test.dart
  test/home_dashboard_phase2_test.dart test/patient_registry_phase3_test.dart`
  — 50 passed.
- `git diff --check` — passed.
- `flutter build web --release` — run after the presentation changes.

The test suite uses mocked/navigation data. It does not claim a live
authenticated profile update or live sign-out verification.
