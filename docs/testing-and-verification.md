# Testing and verification

Dawa Clinician uses Flutter/Dart, Supabase (PostgREST/Auth/Realtime), mocked HTTP/device transports, Flutter widget tests and checked-in golden references. The repository also contains SQL policy checks, opt-in live checks and legacy Firebase-to-Supabase migration tooling. A passing Flutter suite does not establish deployed RLS, device compatibility or clinical validity.

## Reproducible checks

Use Flutter 3.44.6 / Dart 3.12.2, the versions used for Phase 13. From the repository root:

```bash
flutter pub get
dart format lib test
dart format --output=none --set-exit-if-changed lib test
flutter analyze
python3 -m unittest discover -s tool -p 'test_coverage_report.py'
bash tool/verify_coverage.sh
flutter build web --release
```

The coverage command generates a **fresh** native Flutter LCOV file, validates all its production source records and requires at least 80% measured line coverage. No source records or lines are filtered. `tool/coverage_required_sources.txt` pins the source files instrumented at the Phase 13 baseline; dropping previously instrumented modules fails the check. Newly instrumented files are included automatically. Legitimate source retirement requires a reviewed manifest update. The report lists Dart files Flutter did not instrument; the percentage does not represent those files. Branch and function coverage are not emitted by this Flutter configuration and must not be inferred from line coverage.

Outputs under ignored `coverage/`: `lcov.info`, `summary.json` (module/file totals and uncovered line numbers), and `flutter-test.jsonl`. CI uses exactly the same script and threshold. Never edit LCOV, add exclusions, or remove clinical source to improve a percentage.

## Test map

| Area | Representative automated checks |
| --- | --- |
| Auth and permissions | `auth_manager_contract_test.dart`, `patient_registry_phase3_test.dart`, `ultrasound_repository_contract_test.dart`, `anemia_workflow_test.dart`, `anemia_online_service_test.dart` |
| Patient records and maternal forms | `patient_pages_audit_test.dart`, `legacy_record_contract_test.dart`, `legacy_query_contract_test.dart` |
| Appointments and notifications | `appointments_phase4_test.dart`, `appointment_workspace_repository_test.dart`, `global_notifications_test.dart` |
| Cervical Cancer | `cacx_second_opinion_flow_test.dart`, `cacx_analysis_policy_test.dart`, `cacx_second_opinion_service_test.dart`, `cacx_upload_routing_test.dart` |
| Ultrasound | `ultrasound_workspace_workflow_test.dart`, `ultrasound_repository_contract_test.dart`, `ultrasound_response_validation_test.dart`, `ultrasound_initialization_test.dart` |
| Anemia | `anemia_workflow_test.dart`, `anemia_online_service_test.dart` |
| CT / BP | `quick_access_pages_test.dart`, `clinical_phase5_review_test.dart`, `bp_interpretation_test.dart` |
| Device readiness, switching and locks | `edge_device_contract_test.dart`, `edge_device_lock_test.dart`, `edge_device_mock_hub_test.dart`, `edge_device_web_test.dart` |
| Navigation / responsive UI | `clinician_navigation_test.dart`, `ui_responsive_layout_test.dart`, `patient_pages_audit_test.dart` |
| Legacy API transport | `api_transport_contract_test.dart` |

List the complete current suite using `rg --files test -g '*test.dart'`. Tests use synthetic patients and local mocked endpoints. Mocked integration checks exercise actual repositories, UI callbacks and payload serialization; they do not contact a deployed database or physical device. SQL tests in `supabase/tests/` require a separately prepared database and are not run by `flutter test`.

Six opt-in live tests are skipped by default. Their flags are `RUN_LIVE_EDGE_DEVICE_CHECKS`, `RUN_LIVE_ANEMIA_DEVICE_INIT_TESTS`, `RUN_LIVE_ANEMIA_STORAGE_TESTS` (two tests), `RUN_LIVE_CACX_SECOND_OPINION_CHECK`, and `RUN_LIVE_ANEMIA_ONLINE_CHECK`. Read each test's prerequisites before enabling it. Use synthetic, authorized data only; these tests may transfer an image or write a screening record.

## Visual evidence

Existing `docs/qa/` references and `demo_assets/` fixtures remain while tests/documentation reference them. Do not bulk-delete or regenerate goldens during routine verification.

Generate separate Phase 13 synthetic widget captures without replacing existing references:

```bash
flutter test --no-pub --update-goldens --dart-define=CAPTURE_PHASE13=true test/patient_pages_audit_test.dart test/ultrasound_workspace_workflow_test.dart --name 'PatientDetails (desktop|laptop|collapsed|mobile|large-text) loaded|image analysis and save'
```

Captures are written to ignored `coverage/phase13/`. They are test-rendered evidence, not a live clinician session or clinical images.

## Manual release checks still required

- Confirm deployed Supabase migrations, ownership/RLS isolation across clinicians and organisations, expired-session behavior against the real service and production account recovery.
- Exercise actual device hub/model selection, readiness, transport failures and exam locks on supported hardware.
- Confirm Cervical automatic online fallback and patient-data notices using an approved synthetic image. A completed edge result must never trigger fallback. Anemia now supports the documented [online fallback](anemia-online-fallback.md); confirm image-transfer disclosure, source labels and saved provenance. Confirm Ultrasound's intended device upload/inference flow without claiming live scanning.
- Save/reopen authorized real-service test records and verify pending result synchronization after reconnect.
- Inspect camera/gallery permissions, real-browser keyboard/screen reader behavior, long names, 200% text, desktop/tablet/mobile and deployment deep links.
- Confirm CT is disabled in release while persistence is unavailable; BP readings are session-only. Obtain expert review for clinical thresholds, recommendations, translations and model limitations.

The measured Phase 13 results, legacy defects and boundaries are in [the quality report](quality/phase13-report.md). Automated checks are regression evidence, not production certification.
