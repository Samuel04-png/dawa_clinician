# George device-lock update: acceptance and follow-up

## Implemented on 2026-11-10

Both supplied patches were applied on `george/device-lock`, based on `George_start_here`.
The app acquires the examination lock after readiness, sends a heartbeat every
30 seconds, and releases it on completion. Recovery now resumes or reacquires
the board lock before enabling uploads. Heartbeat loss blocks uploads until recovery.
The hub default is port 80 (`http://dawa.local`); board 2 uses an explicit host.
The offline banner's dismiss control retains an accessibility label without
requiring a Navigator Overlay, fixing the debug exception on the login screen.

Local SDK: Flutter 3.44.6 stable, framework ee80f08bbf, Dart 3.12.2,
DevTools 2.57.0. `flutter pub get` succeeds with the existing `intl: 0.20.2`.
Use this Flutter version to reproduce the dependency resolution; no intl change
was needed for this update.

## Automated validation

- `flutter pub get`: passed with the existing dependency pins.
- `flutter analyze --no-pub`: no issues.
- Web release build with device management and ultrasound flags: passed.
- George's mock-hub suite: all 25 tests passed.
- Regression coverage: offline banner outside the Navigator at a narrow width,
  30-second heartbeat cadence, upload blocking after a lost lock, reacquisition,
  and stopping heartbeats after completion.
- Full suite: 120 passed, 3 failed. The broader suite has existing failures in two platform-sync migration checks
  and the demo screenshot/font test. These same three failures were reproduced
  on the untouched `George_start_here` commit `7b33a9b`.

## Pending meetup with George: board 2

Board 2 was not on this Mac's network; a connection to `192.168.0.195:80`
timed out. Samuel confirmed that hardware testing must wait for the meetup.
No real scan, hardware heartbeat, or signed-in end-to-end result is claimed.
George's `test/real_device_lock_smoke_test.dart` was not included in these two patches.

1. Connect this Mac and board 2 to the same network. Confirm the board is idle
   with George, then check `curl http://192.168.0.195/api/status`.
2. Start the app with:

   ```sh
   flutter pub get
   EDGE_DEVICE_HUB_PORT_REMOTE=80 tool/run_web_dev.sh 192.168.0.195
   ```

3. Sign in with a test account and use non-patient images only. Start cervical
   first. Wait for **Model ready** (about one minute, up to three after a switch).
   Verify the board shows an `app-…` lock owner before upload.
4. Keep the examination open for at least 65 seconds. Inspect network requests
   for successful `/api/exam/heartbeat` calls at about 30 and 60 seconds. A second
   client's attempt to select another module must receive 409 `exam_in_progress`.
5. Upload a non-patient image. A cervical quality rejection is a valid test
   outcome, not a successful clinical classification. Finish/cancel and verify
   `/api/exam/end` succeeds and the board lock clears.
6. Start ultrasound, wait for **Model ready**, and upload a non-patient fixture.
   Allow about 45 seconds for inference (the configured timeout is 120 seconds).
   Check that uncalibrated results remain pixels, then finish and verify release.
7. Record board firmware, app commit, readiness time, heartbeat responses,
   inference outcome and release response. If Supabase is unavailable, report
   persistence separately from device inference.

The supplied `tool/device_selftest.sh` is a board-level anemia/lock check,
not the cervical/ultrasound app acceptance flow. Run it only with George on an
idle board and a non-patient eyelid fixture; it changes the selected model.

## Separate anemia update

Samuel chose to plan anemia separately, with no anemia integration in this change.

- Review the existing HemoNix experience with George and choose its entry point
  and how test results relate to a patient/examination.
- Add `anemia` model selection, readiness, the same device lock lifecycle,
  and the `/upload/anemia` contract, including web proxy routing.
- Agree on the prototype disclaimer and presentation of confidence; do not
  introduce clinical decisions from the prototype model. Confirm delivery of
  the pending fine-tuned backbone before any clinical validation.
- Specify persistence, access rules, failure/rejection behavior, and tests for
  switching among all three scans. Validate with non-patient fixtures first.
