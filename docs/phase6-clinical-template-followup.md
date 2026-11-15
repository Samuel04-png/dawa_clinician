# Clinical screening template follow-up

Implemented presentation changes:

- `clinical_screening_layout.dart`: image-first 7:5 desktop columns; stacked
  acquisition/review below 920px available width and at large text sizes.
- Cervical screening workspace: removed the repeated heading and placed patient
  selection plus the existing analysis controls beside the image workspace.
- HemoNix: image workspace left, patient and analysis panels right; existing
  prototype disclosure behind a compact About this model expansion; one-line
  clinician-review reminder; patient choices include age and a short reference.
- Shared workflow status: neutral plain-language hub and model states plus the
  existing retry action. Device/service operations unchanged.
- Ultrasound: missing gestational age is explicit; saved examination rows show
  time and short references, with a copy-full-reference action in detail.

Verification:

- Flutter analysis passed.
- Clinical workspace/capture suite: 48 passed, including 1440px, 1024px,
  collapsed navigation, mobile, and 200% text layout checks.
- Anemia workflow suite: 16 passed, including readiness gating, inference
  interlocks, and selected-patient saving.
- Full suite: 328 passed, 5 skipped, 2 failed:
  `dawa_platform_sync_architecture_test.dart`: service catalog UI uses the
  existing admin authorization boundary;
  `demo_capture_proof_test.dart`: captures clinician patient registry desktop
  training fixture.
- Final screenshot generation after disclosure spacing adjustment: 48 passed.
- Screenshots under `docs/qa/phase5/`. Anemia desktop, laptop and mobile were
  visually inspected. These are mocked widget captures, not live clinical data.

## Continuation verification

- CT is now hidden in release from sidebar, Home selector and Care Tools. Its
  existing route displays `Not available in this release`; its seeded controller
  is not instantiated. Debug/profile retain the development workspace.
- Ultrasound frame metadata follows the actual fitted image bounds. A widget
  test verifies its position for a 4:1 image in a 4:3 viewport.
- Ultrasound records now show time, exam type, result status and short ref;
  full examination reference remains copyable in detail.
- Current Cervical/Anemia results explicitly state when the model does not
  provide an analysis timestamp. No timestamp is fabricated.
- Review reminders are present on current Cervical, Ultrasound and Anemia
  output. Patient choices show available age plus short ref.
- The new image-frame test and neutral text-colour AA contrast test both pass.
- Focused clinical suites: 84 passed before the final additional two tests;
  subsequent focused workflow/image run: 38 passed.
- Full suite including the new tests: 330 passed, 5 skipped, 2 failed (same two
  test names listed above).
- Visual review caught and corrected the model-disclosure layout at 200% text;
  it now wraps the chip and expander label rather than squeezing the label
  beside a fixed leading chip.

Outstanding: complete per-tool offline/error, selected-patient, image,
analysing and result screenshot matrix; complete keyboard traversal audit;
contrast measurements for every legacy clinical result/status colour; live
hardware and authenticated saving verification. The existing screenshot suite
uses mock device responses and fixtures; it is not live clinical verification.
