# App and patient-page verification

Verified on 13 November 2026.

## Results

- `flutter analyze` completed with no issues.
- `flutter test --no-pub --reporter expanded` completed with 448 passed, 5 skipped and 0 failed.
- The new patient/account audit completed with 90 passed.
- The Home, Appointments, clinical-tool and registry screenshot run completed with 92 passed.
- `flutter build web --release --no-pub --no-wasm-dry-run` completed successfully.
- `git diff --check` completed successfully.

The five skipped tests require explicit live-environment configuration. They cover physical hub initialization, physical anemia-model initialization, the online second-opinion endpoint and two authenticated anemia-storage checks.

## Coverage

The new audit renders Patient Details, the full maternal record, maternal-record entry, encounter entry, encounter details, encounter editing, patient registration, Settings, Edit profile, both login pages, password recovery, clinician-registration completion and administrator account creation.

Each page is checked at 1440 × 1000, 1024 × 900, 1440 × 1000 with the sidebar collapsed, 390 × 844 and 390 × 1000 with 200% text. Screenshot captures are stored beside this report. Form-bottom captures verify that five final actions remain reachable at 200% text.

The administrator services route is checked for its existing unauthorized redirect to Settings. Its authorized catalog UI was outside the available fixture role. Redirect stubs are excluded from screenshots.

Additional interaction checks cover six incomplete patient/encounter links, opening the full maternal record from Patient Details, and opening and closing Support and Terms dialogs at 200% text. The existing full suite covers Home, the patient registry, Appointments, all five clinical modules, shared navigation, appointment notifications and analysis-state behavior.

## Corrections

- Incomplete patient and encounter links now offer an Open Patients recovery action.
- Missing legacy dates render safely in patient and encounter displays.
- Loading placeholders use finite dimensions inside legacy rows.
- Legacy form labels, field groups and actions reflow at narrow widths and large text sizes.
- Patient registration no longer creates an infinitely wide button. Occupation, date of birth, email and password fields remain readable at 200% text.
- Patient Details, Settings and Edit profile use the shared navigation shell.
- Profile action buttons wrap when space is constrained.
- Clinician registration remains visible on mobile. Its decorative image is restricted to wide layouts.
- Patient summary metrics scale with text. Encounter-detail labels, values and the clinician-context notice can wrap fully.
- The password-recovery primary button uses white text.
- The shared muted text color meets a 4.5 to 1 contrast ratio on all three neutral card surfaces. A regression test checks these combinations.
- The Settings services label matches the existing authorization-boundary assertion.

## Visual review

Reviewed desktop and large-text patient/account contact sheets, detailed patient, registration and encounter screenshots, and desktop/mobile Home, Appointments and clinical-module comparisons. The corrected screenshots show readable labels and reachable actions without the previously reproduced overflow or clipping.

Screenshots use isolated synthetic fixtures. The CT demonstration view and cervical training data appear in debug test captures. These captures do not establish production data availability. The existing registry screenshot baseline was refreshed and visually inspected to match the current UI, including its updated secondary-text contrast.

## Files changed in this verification pass

- `lib/application/create_mom/create_mom_widget.dart`
- `lib/application/edit_encounter/edit_encounter_widget.dart`
- `lib/application/encounter/encounter_widget.dart`
- `lib/application/encounter_dets/encounter_dets_widget.dart`
- `lib/application/mom_details/mom_details_widget.dart`
- `lib/application/mom_details2/mom_details2_widget.dart`
- `lib/application/patient_details/patient_details_widget.dart`
- `lib/auth/complete_clincian_reg/complete_clincian_reg_widget.dart`
- `lib/components/dawa_design_system.dart`
- `lib/components/missing_patient_context.dart`
- `lib/components/responsive_form_row.dart`
- `lib/components/shimmer_animation/shimmer_animation_widget.dart`
- `lib/edit_profile/edit_profile_widget.dart`
- `lib/profile/profile_widget.dart`
- `lib/reset_password/reset_password_widget.dart`
- `test/patient_pages_audit_test.dart`
- `demo_assets/raw/dawa_clinician/patients/patient_registry_training_fixture.png`
- Screenshot captures under `docs/qa/patient-audit`, `docs/qa/phase2`, `docs/qa/phase4` and `docs/qa/phase5`
- This report

The working tree also contains earlier phase changes. The list above identifies this verification pass.

## Live verification limits

The fresh web preview rendered Login in Chrome at `http://localhost:49667/`. An authenticated session was unavailable there. A later browser check failed because the computer-use service could no longer find the Chrome window, and its browser host was unavailable.

Live patient reads and saves, account changes, password-reset delivery, physical-device inference and the real online fallback endpoint remain unverified in this pass. No production patient records were created or changed during these checks. Functional assertions use mocked services or repositories. Formal screen-reader testing and every possible production-data combination also remain unverified.
