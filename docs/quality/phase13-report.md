# Phase 13 verified quality report

Verification date: 14 November 2026. Flutter 3.44.6 / Dart 3.12.2.

## Result

Native Flutter line coverage increased from **69.7012% (25,680/36,843)** to **80.0893% (29,239/36,508)**. The required 80% overall line target is met; the 85% stretch target is not. This is not an 80% claim for every module, branch coverage, function coverage or all repository languages.

| Metric | Fresh baseline | Final full run |
| --- | ---: | ---: |
| Line coverage | 69.7012% | 80.0893% |
| Covered / instrumented lines | 25,680 / 36,843 | 29,239 / 36,508 |
| Passing tests | 533 | 603 |
| Failing tests | 0 | 0 |
| Skipped tests | 5 | 5 |
| Instrumented production files | 179 | 179 |

Test counts exclude hidden setup/teardown events. The final Flutter run has 608 tests: 603 passed, 5 skipped and no failing test names. Six separate Python coverage-validator tests also pass; these are not added to the Flutter count. The skipped tests are opt-in live checks (one hub, one Anemia model initialization, two Anemia storage, one Cervical online service). None was enabled.

## Measurement integrity and iterations

All native LCOV records are counted unchanged, using actual DA hit counts checked against LF/LH. No coverage exclusions or analyzer suppressions were added. Formatting changed two instrumented line positions/counts before test development (36,843 → 36,845). Removing eleven verified, unreferenced presentation builders subsequently removed 337 instrumented lines (36,845 → 36,508). These are recorded in the source-cleanup inventory; clinical methods, routes, callbacks and persistence remain. Thus the net denominator change from the original baseline is -335 lines, not an unexplained coverage exclusion.

| Iteration | Covered / total | Line coverage | Outcome |
| --- | ---: | ---: | --- |
| Original fresh baseline | 25,680 / 36,843 | 69.7012% | 533 passed |
| Formatting-only baseline | 25,682 / 36,845 | 69.7028% | 533 passed |
| Contracts and auth tests, before dead-code removal | 27,597 / 36,845 | 74.9003% | 580 passed |
| Maternal and Ultrasound workflows | 28,703 / 36,508 | 78.6211% | 7 new test-harness failures, corrected |
| Query fixes and modal/save tests | 29,073 / 36,508 | 79.6346% | 599 passed |
| Prediction breakdown expansion | 29,205 / 36,508 | 79.9962% | 601 passed |
| Multipart upload contract and final gate | 29,239 / 36,508 | 80.0893% | 603 passed |

Raw iteration reports are retained under ignored `coverage/phase13/`; reports were never rewritten. Earlier failures were assumptions in new mocks (request metadata/response pagination and widget interaction), corrected before the final run. No existing test was deleted or marked skipped to pass.

Flutter emitted records for 179 of 196 Dart files. The same 179-source scope is pinned by `tool/coverage_required_sources.txt`; newly instrumented records are always included. Seventeen files were not reported by native instrumentation, including legacy Ultrasound paths, barrels, old navigation widgets and backend wrappers. They are listed below and in JSON. They were not removed or manually excluded. No percentage for uninstrumented code, SQL, Edge Functions or migration scripts is inferred.

## Coverage by module

| Module | Before | After | Final covered / total |
| --- | ---: | ---: | ---: |
| `app/account/other` | 79.03% | 80.25% | 634 / 790 |
| `application/bp_monitor` | 95.62% | 95.62% | 415 / 434 |
| `application/cacx` | 63.85% | 69.51% | 2,262 / 3,254 |
| `application/care_tools` | 91.36% | 91.36% | 201 / 220 |
| `application/create_mom` | 67.65% | 79.57% | 1,102 / 1,385 |
| `application/ct_scan` | 94.64% | 94.64% | 53 / 56 |
| `application/edit_encounter` | 92.76% | 92.76% | 2,947 / 3,177 |
| `application/encounter` | 90.49% | 90.49% | 2,874 / 3,176 |
| `application/encounter_dets` | 84.24% | 84.24% | 358 / 425 |
| `application/hemonix` | 75.38% | 75.38% | 545 / 723 |
| `application/home` | 81.12% | 81.12% | 550 / 678 |
| `application/mom_details` | 71.70% | 91.17% | 4,398 / 4,824 |
| `application/mom_details2` | 75.72% | 79.54% | 3,138 / 3,945 |
| `application/moms` | 89.94% | 89.94% | 286 / 318 |
| `application/patient_details` | 87.30% | 87.30% | 385 / 441 |
| `application/scheduled_encounters` | 70.83% | 70.83% | 323 / 456 |
| `application/shared` | 49.33% | 49.33% | 257 / 521 |
| `application/ultrasound` | 42.89% | 72.84% | 1,515 / 2,080 |
| `auth` | 79.50% | 85.17% | 1,683 / 1,976 |
| `backend` | 25.20% | 76.43% | 1,453 / 1,901 |
| `components` | 63.83% | 82.68% | 1,661 / 2,009 |
| `features/appointments` | 66.99% | 66.99% | 696 / 1,039 |
| `features/services` | 15.00% | 66.88% | 107 / 160 |
| `flutter_flow` | 37.19% | 40.26% | 655 / 1,627 |
| `services` | 77.27% | 82.98% | 741 / 893 |

Every uncovered instrumented line is listed in `coverage/summary.json` → `files` → `uncovered_lines`. Largest remaining gaps include legacy maternal/birth forms, Cervical camera/language and save/recovery branches, generated Cervical model accessors, Ultrasound secondary paths, generic tool dashboards, legacy appointment requests and FlutterFlow/router utilities. Some clinical modules remain below 80% even though the overall threshold passes.

### Files not reported by Flutter

- `lib/application/ultrasound/screens/scan_record_page.dart`
- `lib/application/ultrasound/services/echowave_service.dart`
- `lib/application/ultrasound/ultrasound.dart`
- `lib/application/ultrasound/ultrasound_model.dart`
- `lib/application/ultrasound/ultrasound_module.dart`
- `lib/application/ultrasound/ultrasound_widget.dart`
- `lib/backend/firebase/firebase_config.dart`
- `lib/backend/gemini/gemini.dart`
- `lib/backend/schema/index.dart`
- `lib/backend/schema/structs/index.dart`
- `lib/components/clinical_features.dart`
- `lib/components/navlink/navlink_model.dart`
- `lib/components/navlink/navlink_widget.dart`
- `lib/components/top_nav/top_nav_model.dart`
- `lib/components/top_nav/top_nav_widget.dart`
- `lib/flutter_flow/flutter_flow_button_tabbar.dart`
- `lib/index.dart`

## Repository discovery and safe cleanup

The application is Flutter/Dart with Supabase Auth/PostgREST/Realtime, Provider/FlutterFlow state, GoRouter, image picker, shared navigation/design components and an existing edge-device manager. Maternal/patient/encounter records use a legacy schema compatibility layer. The clinical tools depend on patient repositories and the existing manager; Cervical also has its existing online fallback. Supporting code includes SQL migrations/policy tests, Supabase Edge Functions and a Node migration utility. No replacement connection service or clinical workflow was introduced.

The working tree already contained substantial user changes and untracked files. They were preserved. Before cleanup, the tracked snapshot was saved at `refs/backup/phase13-before-cleanup` (`6fb04c8a27d3cb1ca6bb56eff477f10488bed974`), with the 57 pre-existing untracked code/test/tool files backed up locally in `.git/phase13-untracked-code-backup.tar.gz`. Four superseded text documents were backed up separately in `.git/phase13-superseded-docs-backup.tar.gz`. No screenshot archive was made and no remote push occurred. Restore only selected files after inspecting the snapshot; do not reset this dirty working tree wholesale.

`phase13-deletion-inventory.json` was written before deletion and records purpose, tracked state, references, classification, removal safety, size and hashes. Of 271 candidates, 16 were removed: twelve disposable captures/diffs and four superseded phase notes. All were untracked at the start. The other 255 reference captures remain because tests/documentation depend on them. Unknown-purpose files, production assets, required goldens, `demo_assets` test fixtures, migration/policy files, license/font attributions, model limitations, privacy/security and external-reporting evidence remain. No dependency was removed: uncertain usage is not proof of obsolescence.

Useful shell/Home/registry knowledge from the four phase notes is consolidated into `docs/ui-architecture.md`. Current commands, test categories and manual boundaries replace the stale testing guide. `.gitignore` now excludes generated `/coverage/`, `/test/failures/` and tool Python bytecode without hiding reference goldens or application assets.

The source-cleanup inventory records the eleven removed private presentation builders and their pre-removal locations. Identifier/reference checks included the library, routes, tests and absence of library parts/reflection dependencies; current render paths use the existing shared workspace. Two unused legacy navigation imports were removed from the maternal detail page. Other production diffs in this phase are Dart formatting only; there are no Phase 13 changes to authentication, authorization, clinical validation, saving, APIs, fallback policy, retries or model switching.

## Meaningful test additions

- `api_transport_contract_test.dart`: query encoding, JSON verbs/server rejection, network failure, cache parameter isolation/invalidation, body encodings, response parsing and multipart byte/reference preservation on success and rejection.
- `auth_manager_contract_test.dart`: actual auth-manager sign-in/profile creation/cache/sign-out, missing profile without privilege elevation, invalid/unconfirmed accounts, confirmation-required signup, logged-out mutations, password reset and OTP recovery against local mocked Auth/PostgREST.
- `legacy_record_contract_test.dart`: seven schema record types, nullable/zero distinctions, foreign references, serialization and identity contracts.
- `legacy_query_contract_test.dart`: limits/counts, once/stream reads, non-stream page order/offset/empty termination and documented legacy stream failure.
- `ultrasound_repository_contract_test.dart`: authorization boundaries, patient links, malformed persisted results, actual provenance, save failure and uncalibrated measurements without invented millimetres or clinical risk.
- `ultrasound_workspace_workflow_test.dart`: real upload → manager/device analysis → result → save UI in manual and guided modes at 1440/1024/390, duplicate-submission prevention, model provenance and released exam locks.
- Expanded `patient_pages_audit_test.dart`: real maternal/birth inputs and dropdown callbacks, first-encounter/ANC/save payloads, status presentation, modal required-field validation, existing-patient duplicate recovery, authorized service creation/price validation and responsive render/capture evidence.
- Expanded `cacx_second_opinion_flow_test.dart`: inspect all returned class scores at 834/1440 and collapse/expand without another image transfer or inference call.

## Verification boundaries

| Category | Verified | Not established |
| --- | --- | --- |
| Unit/contract | Existing clinical parsers, BP thresholds, Cervical policy, device state/locks; new serialization, transport and coverage-parser tests | Clinical validity or model accuracy |
| Widget | Navigation, patient/maternal/account pages, appointments/notifications, screening flows and responsive/error states exercised by the full suite | Exhaustive real-browser interactions, assistive technology or every state/viewport combination |
| Mocked integration | Actual auth/repository/compatibility code and UI callbacks with synthetic local HTTP/device fixtures; upload/save payloads | Live Supabase RLS, realtime delivery, deployed schema or physical-device behavior |
| Live services/hardware | None in this phase | Five opt-in checks, real online inference, camera/probe and storage authorization |
| Build/tooling | Local analysis, format, full coverage gate and parser tests | Hosted GitHub Actions has not run; workflow is unpushed |

Captured and inspected eleven synthetic widget images: Patient Details expanded 1440/1024, collapsed 1440, mobile 390 and 200% text at 390; Ultrasound result view manual/guided at 1440/1024/390. Text wraps, actions stay separated, and no render overflow/overlap was observed in those captures. The first Ultrasound captures exposed missing test-harness fonts; the harness now loads/applies the bundled QA font and captures were regenerated. No application layout was redesigned. The Ultrasound image is deliberately a one-pixel synthetic fixture, leaving the reserved preview visually blank; this does not verify real scan appearance. Mobile result disclosures continue below the viewport and are scrollable. No live clinician/patient screenshots were used or copied.

### Existing defects and release gaps retained

1. Generic legacy API requests with omitted headers use an immutable default map that body creation attempts to mutate; this can return an error before transport. Contract tests use explicit mutable headers for the supported path. No API logic was changed.
2. Legacy live pagination consumes a single-subscription stream with `.first` and then listens again, raising `StateError`. A regression test documents this existing failure; ordinary non-stream pagination passes. This does not assert live pagination works.
3. A legacy birth-form conditional tests marital status against `Positive`, although its choices are Single/Separated/Married. That subsection is unreachable via normal selection. It was not forced through invalid test state or changed under this cleanup scope.
4. Legacy compatibility writes can swallow backend exceptions. Mocked successful maternal saves do not prove recovery from every real backend write failure.
5. Populated realtime service-catalog rendering was not verified by the new tests; authorized create, validation and cancel were exercised.
6. Checked-in maternal RLS/ownership assumptions require deployment review, especially cross-clinician/organisation isolation. SQL policy tests and deployed migrations were not run against a live database.
7. Existing analyzer exclusions for legacy forms and existing ignored diagnostics were preserved; a clean analysis result has that pre-existing scope.
8. CT release flag/sample limitations, session-only BP state, model intended-use disclosures and expert clinical review remain documented release concerns.

## Security and privacy review

A targeted scan of current tracked text checked private-key material, common provider tokens, service-role assignments and decoded service-role JWT patterns without printing credentials. An additional current untracked source/config scan checked private-key/provider-token patterns. No matches were found in those scans. The only tracked environment template found was the migration utility example; local secret paths remain ignored. This is not a Git-history secret audit, comprehensive PHI review, credential rotation or a security certification. Existing images of uncertain purpose were retained and were not uploaded. No history rewrite occurred.

## Exact commands and artifacts

Baseline (before edits):
```bash
flutter test --coverage --coverage-path=/tmp/dawa-phase13-baseline.info --reporter json > /tmp/dawa-phase13-baseline-tests.jsonl 2>/tmp/dawa-phase13-baseline-stderr.log
```

Final tooling/build commands:
```bash
flutter pub get
dart format lib test
dart format --output=none --set-exit-if-changed lib test
flutter analyze
python3 -m unittest discover -s tool -p 'test_coverage_report.py'
bash -n tool/verify_coverage.sh
bash tool/verify_coverage.sh
flutter build web --release
git diff refs/backup/phase13-before-cleanup --check
```

`verify_coverage.sh` removes only the old generated `coverage/lcov.info`, runs `flutter test --coverage --reporter json`, then validates it with `python3 tool/coverage_report.py coverage/lcov.info --minimum 80 --required-sources tool/coverage_required_sources.txt --json coverage/summary.json`. `set -euo pipefail` propagates test/validation failure. Six validator tests include empty/truncated/invalid counts, missing production sources, threshold failure and lost scope. CI calls this same script; there is no allowed-to-fail coverage step.

Artifacts (local, ignored/reproducible): `coverage/lcov.info`, `coverage/summary.json`, `coverage/flutter-test.jsonl`; `coverage/phase13/baseline.info`, `baseline-summary.json`, `final.info`, `final-summary.json`, `module-coverage.csv`, `test-results.json`, `changed-files.json`, raw iteration evidence and eleven PNGs. Full test and build output remains local; no remote upload was performed.

Final LCOV SHA-256: `8642ecdcc68487d174153e0e615df3c49fbf29ca1bee7310cceb25983918278c`.

## Exact Phase 13 file changes

This inventory compares against the start-of-phase rollback snapshot and original untracked-file archive, not against HEAD (which also contains substantial earlier user work). Generated ignored evidence is excluded.

### modified relative to phase13 snapshot

- `.gitignore`
- `docs/testing-and-verification.md`
- `lib/application/cacx/cacx_device_failure.dart`
- `lib/application/cacx/cacx_widget.dart`
- `lib/application/ct_scan/repository/ct_scan_repository.dart`
- `lib/application/encounter_dets/encounter_dets_widget.dart`
- `lib/application/mom_details/mom_details_widget.dart`
- `lib/application/ultrasound/screens/ultrasound_app.dart`
- `lib/components/shimmer_animation/shimmer_animation_widget.dart`
- `lib/edit_profile/edit_profile_widget.dart`

### modified preexisting untracked files

- `lib/application/home/widgets/home_examination_selector.dart`
- `test/cacx_analysis_policy_test.dart`
- `test/cacx_second_opinion_flow_test.dart`
- `test/clinical_image_frame_test.dart`
- `test/patient_pages_audit_test.dart`

### created

- `.github/workflows/flutter-quality.yml`
- `docs/ui-architecture.md`
- `docs/quality/phase13-deletion-inventory.json`
- `docs/quality/phase13-source-cleanup-inventory.json`
- `docs/quality/phase13-report.md`
- `tool/coverage_report.py`
- `tool/test_coverage_report.py`
- `tool/verify_coverage.sh`
- `tool/coverage_required_sources.txt`
- `test/api_transport_contract_test.dart`
- `test/ultrasound_repository_contract_test.dart`
- `test/auth_manager_contract_test.dart`
- `test/legacy_record_contract_test.dart`
- `test/legacy_query_contract_test.dart`
- `test/ultrasound_workspace_workflow_test.dart`

### deleted

- `docs/qa/device-offline.png`
- `docs/qa/device-ready.png`
- `docs/qa/sidebar-expanded.png`
- `docs/qa/device-error.png`
- `docs/qa/device-stopped.png`
- `docs/qa/sidebar-mobile.png`
- `docs/qa/sidebar-collapsed.png`
- `docs/qa/device-starting.png`
- `test/failures/patient_registry_training_fixture_maskedDiff.png`
- `test/failures/patient_registry_training_fixture_masterImage.png`
- `test/failures/patient_registry_training_fixture_testImage.png`
- `test/failures/patient_registry_training_fixture_isolatedDiff.png`
- `docs/phase1b-navigation-refinement.md`
- `docs/phase2-home-dashboard-redesign.md`
- `docs/phase3-patients-redesign.md`
- `docs/sidebar-appbar-redesign-qa.md`

## Git and release status

Branch: `george/device-lock`. HEAD: `0f47abcf2ba89b383f788f4d5e41c1385c14df59`. No new commit or remote push was made, so these Phase 13 changes remain reviewable in the existing working tree. The older `backup_before_redesign` branch was not changed. The locally verified coverage gate is ready for CI; its hosted execution remains unverified until committed and run.

Final command results: `flutter pub get` succeeded (existing dependency-update notices; no upgrades performed); Dart format check passed with 243 files unchanged; `flutter analyze` reported no issues within existing analyzer scope; all six Python validator tests passed; `bash -n` passed; the fresh full-suite coverage gate exited 0 at 80.0893%; the release web build exited 0 and produced `build/web` in 71.6 seconds. The build also reported a successful Wasm dry run; no deployed browser/Wasm runtime test is implied. `git diff refs/backup/phase13-before-cleanup --check` passed.

Tracked-file diff relative to the start-of-phase snapshot: 10 files, 124 insertions and 982 deletions. In addition, five pre-existing untracked files were improved/formatted, fifteen new files were created and sixteen obsolete untracked artifacts/documents were removed. The JSON changed-file inventory records each path. No dependency manifest, lockfile, migration or policy was changed by this phase.

Synthetic screenshots: [Patient Details 1440](../../coverage/phase13/patient-details-desktop.png), [Patient Details 1024](../../coverage/phase13/patient-details-laptop.png), [collapsed](../../coverage/phase13/patient-details-collapsed.png), [mobile](../../coverage/phase13/patient-details-mobile.png), [200% text](../../coverage/phase13/patient-details-large-text.png), [Ultrasound 1440](../../coverage/phase13/ultrasound-manualScan-1440.png), [1024](../../coverage/phase13/ultrasound-manualScan-1024.png), [mobile](../../coverage/phase13/ultrasound-manualScan-390.png). These ignored images are local artifacts; regenerate them with the command in the testing guide.
