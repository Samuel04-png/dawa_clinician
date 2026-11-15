# CaCx online fallback and modal verification

Verified and corrected on 12 November 2026, following the user's request to check UX, modals, and second opinion when the device is disconnected.

## What was actually wrong

With model management enabled, `_analyzeImage` returned early while the local cervical model was not ready. The only visible online shortcut required an already-running device examination. A disconnected hub therefore left the prepared image waiting for local readiness rather than offering a reachable online route.

There was also a provenance issue: the early readiness return happened before the patient/image context was prepared for the online path. Second-opinion updates did not report persistence success, allowing completed online analysis to look saved even when its update failed.

## Corrections

- A prepared image now offers **Use online second opinion** when local analysis is unavailable. It requires an existing selected patient and does not acquire a device lock or submit to the LAN device.
- Explicit approval is required before any online image submission. The dialog identifies the external service and provides Do not send, Retry device, and Send online. Cancelling preserves the prepared image without uploading or writing a fallback record.
- Patient/image provenance is initialized before the local-readiness return. Online-only records identify the unavailable device as failed rather than leaving a fictional pending device response. Changing the selected patient cannot reuse the previous patient's result ID/path.
- The original online upload → predict → completion service and classification mapping are reused. Its HTTP client is injectable for deterministic tests; this introduces no replacement device connection service.
- Duplicate online requests are guarded. Exceptions and unsuccessful results remain retryable, with fresh consent on retry. A failed online-only request does not render a successful diagnostic result.
- No-internet states preserve the image and explain that online analysis requires internet.
- Second-opinion updates verify the returned row, persist the required flag, and report failure. A completed but unsaved opinion is explicitly identified. When its primary record exists, Save retries the opinion update without resubmitting the image. Repeated Save taps are guarded, and failed persistence cannot claim success.
- Cloud debug logs no longer print uploaded paths, event identifiers, full model responses, or raw exception contents. Missing prediction labels are treated as failed responses.

## Modal UX

The image-source dialog now scrolls its complete heading, description, and camera/gallery choices. Cancel stays accessible at the bottom. It stacks choices on narrow screens and at large text sizes. It guards duplicate picker launches, disables choices while pending, and provides a safe inline error on picker failure. Camera/gallery choices expose button semantics.

Online consent and manual retry share one bounded, scrollable dialog with a white surface, restrained rounding, explicit choices, and the established blue action. Contextual examination headers remain in place. Earlier Appointments dialogs retain their existing responsive and confirmation coverage.

Reviewed eight screenshots across 1280×900 and 320×520, both at normal and 200% text. At large text, modal content scrolls while the decision controls remain accessible.

- [Consent on desktop](qa/second-opinion/consent-desktop-1.0.png)
- [Consent on mobile](qa/second-opinion/consent-1.0.png)
- [Consent at 200%](qa/second-opinion/consent-2.0.png)
- [Image source on desktop](qa/second-opinion/image-source-desktop-1.0.png)
- [Image source on mobile](qa/second-opinion/image-source-1.0.png)
- [Image source at 200%](qa/second-opinion/image-source-2.0.png)

## Live online verification

The first configuration request timed out. A subsequent check confirmed:

- The configured Hugging Face Space reports RUNNING.
- Its `/config` request returns HTTP 200 and exposes the existing `predict` API.
- The response permits the current `http://localhost:49666` origin.
- The **actual Flutter `HuggingFaceService`** completed upload, prediction, and completion retrieval with a synthetic 1×1 PNG in the opt-in live test.

`flutter test --no-pub test/cacx_second_opinion_live_test.dart --dart-define=RUN_LIVE_CACX_SECOND_OPINION_CHECK=true` passed. No patient data, real cervical image, database write, or physical-device inference was used. The synthetic output is intentionally not reported as a meaningful classification. This verifies connectivity/protocol behavior, not clinical model accuracy, production suitability, or a physical disconnected-device examination.

The live test is opt-in to avoid external uploads in routine test runs. It uses only its embedded synthetic PNG. The external service must remain available, and the clinician's app must have internet access.

## Automated coverage

The focused run passes all 21 tests: six online-service protocol/failure checks and 15 widget checks for disconnected-device approval/cancel, correct patient association, no-internet handling, thrown and returned failures, fresh-consent retry, unsaved-result disclosure and successful Save retry without image resubmission, duplicate online requests, eight modal viewport/text-scale combinations, and duplicate picker prevention.

Final validation:

- `flutter test --no-pub --concurrency=4`: **321 passed, 5 opt-in live tests skipped, zero failures**.
- The opt-in live CaCx online check was run separately and passed.
- `flutter analyze --no-pub`: no issues.
- `flutter build web --no-pub --release`: passed, including the Wasm dry run.
- `git diff --check`: clean.

## Changed files

- `lib/application/cacx/cacx_widget.dart`
- `lib/application/cacx/cacx_upload_service.dart`
- `lib/application/cacx/cacx_second_opinion_service.dart`
- `lib/application/cacx/widgets/cacx_second_opinion_dialog.dart`
- `lib/components/image_source_picker_dialog/image_source_picker_dialog_widget.dart`
- `test/cacx_second_opinion_flow_test.dart`
- `test/cacx_second_opinion_service_test.dart`
- `test/cacx_second_opinion_live_test.dart`
- `docs/qa/second-opinion/*.png` and this report

This online second-opinion workflow is specific to Cervical Cancer. Anemia and Ultrasound keep their existing device-only inference boundaries. No new cloud fallback was added to those modules. No clinical thresholds or recommendation mappings were changed, and no SQL migration was deployed in this work. Changes remain local.
