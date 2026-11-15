# Cervical automatic online fallback

## Discovery

The previous flow prepared an image, required local model readiness, submitted
to the existing `http://dawa.local` device manager, stored the primary result,
then offered a consent dialog for a second opinion. A separate online action
could bypass the edge. The online service uploads image bytes to the existing
configured service; patient identity is not included in that request.

## Implemented behavior

- `Analyze image` starts one guarded attempt. A ready Cervical model uses the
  device first. An unavailable/not-ready model uses online directly when enabled.
- Network, transport, timeout, initialization, configuration and server failures
  permit one online attempt after the device attempt finishes.
- Successful edge outcomes (including high risk), gatekeeper rejection,
  malformed predictions, request validation, authorization and application
  errors do not start online analysis.
- Missing patient/image and cancelled image selection send nothing. The attempt
  lock spans submission, persistence and fallback to prevent double taps.
- A completed inference survives a failed device-lock release. The existing
  manager retains the uncertain session for reconciliation; no fallback is
  triggered by that cleanup failure.
- Removed the separate online and in-flight skip actions. The online image
  transfer notice is visible before Analyze; fallback status is non-modal.
- Retry is clinician initiated and starts a new guarded attempt. No provider
  retry loop or new connection service was added. Existing timeouts are reused.
- `allowOnlineFallback` defaults to true; deployments can disable it using
  `--dart-define=ALLOW_CACX_ONLINE_FALLBACK=false`. The widget accepts the same
  flag for embedding/testing.

## Storage and provenance

Existing primary and `second_opinion_*` fields are retained. The primary failure
and subsequent online result use the same screening row and patient. Online
save failure remains visible and can be retried without resending the image.
History now prefers a completed stored online result rather than displaying
its failed primary attempt as the diagnosis.

Current results identify `Analysed on Dawa device` or
`Analysed online (device unavailable)`. Stored history derives provider from
the existing device and second-opinion statuses. No schema migration was made.
An explicit durable provider/fallback-reason column would require a future
schema change if direct provenance queries are needed; older successful-device
second opinions cannot be labelled as infrastructure fallback with certainty.

## Verification

- Flutter analysis and diff whitespace checks passed.
- Policy plus widget suite: 42 passed, covering ready normal/high-risk device
  results, disconnected device, initialization failure, timeout, transport
  failure, validation/rejection, disabled fallback, missing patient, cancelled
  image selection, both paths failing, double submission, failed lock release,
  patient-context persistence, and save-only retries.
- Earlier broader Cervical policy/flow/device/routing run: 59 passed.
- Final full suite: **356 passed, 5 skipped, 2 failed**. The failures are the
  previously observed `dawa_platform_sync_architecture_test.dart` test
  `service catalog UI uses the existing admin authorization boundary` and
  `demo_capture_proof_test.dart` test
  `captures clinician patient registry desktop training fixture`.

Changed files in this phase: `lib/application/cacx/cacx_widget.dart`,
`cacx_analysis_policy.dart`, `cacx_device_failure.dart`,
`cacx_upload_service.dart`, `test/cacx_analysis_policy_test.dart`,
`test/cacx_second_opinion_flow_test.dart`, and this report.

These tests use injected HTTP clients and the injected online service callback.
They exercise the actual widget/orchestration paths, but do not verify live
device hardware, live online inference, or live authenticated database writes.
Anemia and Ultrasound were not modified for this phase.
