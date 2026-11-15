# Anemia automatic online fallback

Implemented 14 November 2026 at the user's request, superseding the earlier
Anemia device-only restriction. Cervical Cancer and Ultrasound behavior is unchanged.

## Discovery and routing

Previously, HemoNix prepared the Anemia model through the existing
`EdgeDeviceManager` (`http://dawa.local`), enabled screening only on matching
readiness, acquired an examination lock, uploaded to `/upload/anemia`, validated
four class probabilities and required clinician review/notes before saving.
Anemia had no online service. Its authorized patient-list/save RPCs are retained.

The public [NiADA Space](https://huggingface.co/spaces/kmunzwa/anemia_screening)
loads `dawahealth/anemia_screeniing`. Its published `app.py` and live
`/gradio_api/info` advertise `/predict_anaemia`, image input and Gradio LabelData
containing the four probabilities. The client uses the documented upload →
`/gradio_api/call/v2/predict_anaemia` → event-result sequence. These three HTTP
requests constitute one online analysis, not three inference attempts.

On **Start anemia screening**:

1. Require a selected authorized patient, a validated JPEG/PNG image, no active
   submission/save and no conflicting device examination.
2. If the manager confirms the Anemia model ready, analyze on the device only.
3. If it is unavailable/not ready, or the edge attempt fails with connection,
   timeout, model-initialization or HTTP 5xx failure, run online analysis once.
4. Completed device classifications, invalid/malformed results, HTTP 4xx,
   authorization failures and examination conflicts never trigger online analysis.
5. Navigation cancellation prevents a subsequent fallback and prevents further
   upload/prediction stages from starting. Already submitted remote computation
   cannot be recalled. A timeout prevents later HTTP stages; there are no retry
   loops, parallel inference paths or additional background connection polling.
6. Online failure produces a plain-language recovery message and **Retry screening**.
   An unresolved device examination remains protected by the existing manager;
   the existing session-reconciliation action is required before another attempt.

The shared manager still owns hub connectivity, model readiness, locks and device
checks. Its configured inference timeout also bounds the complete online attempt.
Preparing a patient/image does not transfer it. The notice before Start explains
that the prepared image can go online; patient identifiers and clinician notes
are not sent to the Space. A temporary upload filename contains no patient data.

## Configuration

- `ALLOW_ANEMIA_ONLINE_FALLBACK=true` by default. Set false with `--dart-define`
  for an installation that must remain device-only.
- `ANEMIA_ONLINE_BASE_URL=https://kmunzwa-anemia-screening.hf.space` by default.
  Only a valid HTTPS origin is accepted. No private API key is bundled in Flutter.
- The Space can sleep, queue or exhaust its GPU quota. Failures are surfaced;
  availability is not simulated or guaranteed by the client.

## Results, storage and clinical disclosures

No classifications, probabilities or haemoglobin values are invented. The online
parser accepts all four model-provided probabilities, checks consistency through
the existing `AnemiaResult` validator and rejects malformed or inconsistent output.
The prototype limitation and clinician-review requirements remain visible.

Results distinguish **Analysed on Dawa device** from **Analysed online (device
unavailable)**. Online source metadata (`analysis_provider: online`, `service_url`)
is carried in the existing result JSON through save/reopen. The legacy nonempty
`device_id` storage field contains `online:<service host>` for online records; it
is a service reference, never displayed as a physical device. Legacy device JSON
is unchanged and reopens as device-originated. No SQL migration, RPC, RLS or
clinical threshold change was made. The current SQL validator permits these
additional JSON properties, but an authenticated live online-result save/reopen
was not exercised in this change.

## Ultrasound discovery

No Ultrasound Hugging Face Space is configured in the codebase. Public Space
listings for `kmunzwa` and `dawahealth`, checked on 14 November 2026, contained no
Ultrasound Space. This does not rule out a private Space or another owner.

The active `UltrasoundApp._runAnalysis` uses `UltrasoundEdgeService`. An older
`UltrasoundAIService` can call the existing `analyze-ultrasound-image` Supabase
function using Gemini, but the active workflow does not automatically call it.
Missing Gemini configuration returns HTTP 503/unavailable, not clinical findings.
No Ultrasound fallback, substitute model or new Space was created here.

## Verified results

- Full fresh suite: **626 passed, 0 failed, 6 skipped**. Five skips are existing
  physical-device/storage/Cervical live checks; the sixth is the new opt-in online
  check. No existing test was removed or skipped to pass.
- Explicit live check: the actual Flutter `AnemiaOnlineService` completed one
  synthetic 1×1 PNG upload, inference and validated response in about 3 seconds.
  No patient image or identifying data was used. This verifies transport/parsing,
  not clinical accuracy, live patient access or persistence.
- An HTTP OPTIONS preflight for the prediction endpoint returned 200 and allowed
  `http://localhost:49666`, POST and content-type. A complete deployed browser
  session and deployed-origin policy remain unverified.
- Widget/mock checks cover offline → online, edge transport failure → online,
  online failure/recovery, missing patient/image and fallback-disabled controls,
  initialization, completed/invalid local results, exam conflict, navigation
  cancellation, save provenance and duplicate-submission prevention.
- Service tests cover binary transfer without patient/notes, probability parsing,
  saved-source round trip, server failure at each stage, invalid classes/results,
  cancellation and timeouts. Device state/locks use the existing manager tests.
- Synthetic result screenshots at 1440/1024/390 widths and 200% text, plus an
  edge-failure result, were inspected. No new overflow or overlap was observed;
  the one-pixel fixture intentionally leaves a blank image preview. Screenshots
  under ignored `coverage/anemia-online/` are test renders, not live clinical UI.
- Native line coverage: **80.2090% (29,395 / 36,648)** across 181 instrumented Dart
  files. HemoNix module: **81.1124% (700 / 863)**. Seventeen Dart files remain
  unreported by Flutter instrumentation. Branch/function coverage is not emitted.
- The existing 80% gate passes, now pinning both new production service files.
  `flutter analyze` reports no issues within the existing analyzer scope; format
  check passes with 246 Dart files unchanged; the release web build succeeds
  and produces `build/web` (181.2 seconds).

## Commands

```bash
flutter test --no-pub test/anemia_online_service_test.dart test/anemia_workflow_test.dart
flutter test --no-pub --dart-define=RUN_LIVE_ANEMIA_ONLINE_CHECK=true test/anemia_online_service_test.dart --plain-name 'real Space accepts'
flutter test --no-pub --update-goldens --dart-define=CAPTURE_ANEMIA_ONLINE=true test/anemia_workflow_test.dart --plain-name 'fallback is explicit'
dart format --output=none --set-exit-if-changed lib test
flutter analyze
bash tool/verify_coverage.sh
flutter build web --release
```

The live flag transfers one synthetic image to the public Space; routine tests
remain deterministic and make no live inference requests. The first full run
exposed a test scrolling timing problem on mobile; the harness was corrected,
then all six fallback scenarios and the fresh full suite passed. No production
logic was weakened to address that test failure.

## Changed files

- `lib/application/hemonix/services/anemia_online_service.dart` (new)
- `lib/application/hemonix/services/anemia_analysis_service.dart` (new)
- `lib/application/hemonix/models/anemia_result.dart`
- `lib/application/hemonix/screens/hemonix_app.dart`
- `test/anemia_online_service_test.dart` (new)
- `test/anemia_workflow_test.dart`
- `tool/coverage_required_sources.txt`
- `docs/environment-variables.md`
- `docs/ai-model-and-gradio.md`
- `docs/testing-and-verification.md`
- `docs/anemia-online-fallback.md` (new)

Working tree changes remain uncommitted/unpushed on `george/device-lock`.
A tracked rollback snapshot is retained at
`refs/backup/before-anemia-online-fallback`; pre-change Anemia files were also
copied locally to `/tmp/dawa-before-anemia-online/`. Earlier user changes and
Phase 13 artifacts remain intact. No physical-device or live database verification
was performed in this follow-up.
