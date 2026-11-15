# Three-model screening integration

Implemented 11 November 2026 against George's `DAWA_DEVICE_CONTRACT_VERIFIED.md`.

## Device communication

CaCx, Ultrasound and HemoNix/Anemia initialize their model on workflow entry.
They share `EdgeDeviceManager` and the configured hub (`http://dawa.local`, port 80).
Selection uses `POST /api/select` with `cervitriage`, `ultrasound` or `anemia`.
HTTP 202 is acknowledgement only. Polling every three seconds requires a matching
`active`, `ready:true` and `state:"ready"`. The verified hub sets readiness only
after real model warm-up; direct module ports are not a prerequisite for screening.

Inference uses the hub's multipart `image` routes:

| Workflow | Model ID | Hub route |
|---|---|---|
| Cervical Cancer | cervitriage | /upload/cervical |
| Ultrasound | ultrasound | /upload/ultrasound |
| Anemia | anemia | /upload/anemia |

Preparation does not reserve the device. Navigation cancels obsolete monitoring
and serializes switches; a superseded navigation request cannot publish readiness.
An existing device examination or inference prevents a switch. Each real inference
requires a device examination lock and rechecks hub readiness before upload.
Locks heartbeat every 30 seconds. Failed release remains protected for explicit
reconciliation. No force, stop or automatic online fallback is used.

## Clinician experience

Patient browsing and image preparation remain available while loading. Readiness
is shown for the current workflow, never borrowed from another model's status.
Loading indicators are indeterminate and display the real device message.
Ultrasound alone has confirmed expected startup durations: roughly one minute cold,
up to 30 seconds warm. Slower loading keeps monitoring until the 300-second safety
limit. Check Again resumes monitoring without repeating an accepted selection.

CaCx loads authenticated patient data by default. Training fixtures require an
explicit demonstration mode, are visibly labelled, and cannot submit screenings.
An already-prepared image is kept while selecting an existing patient. HTTP 422
cervical image-quality rejection stays distinct from connection errors. Any online
second opinion remains a separate consented action after local initialization;
no image is automatically sent to an external service.

HemoNix now implements lower-eyelid image screening, replacing sample Hb values:

1. Select an existing patient from authenticated records.
2. Prepare a JPEG/PNG lower-eyelid image; the MIME type follows the real bytes.
3. Start local screening when Anemia AI is ready.
4. Review the original image, actual class probabilities, confidence and device disclaimer.
5. Enter clinician notes and acknowledge review before saving to that patient.
6. Reopen saved reviewed screenings from history.

The deployed anemia classifier is a prototype with reported 57.7% validation
accuracy and a pending fine-tuned backbone. Low-confidence output is labelled.
It does not measure Hb, establish a diagnosis, or generate treatment advice.
Malformed responses never become clinical results. Changing patient/image clears
previous results. A failed save preserves the prepared image, result and notes.

## Storage and deployment

The Ultrasound and Anemia base-schema migrations have been deployed. Do not
reapply them. `202611110002_harden_anemia_authorization.sql` adds the verified
clinician/clinic access boundary and idempotent save RPC. Reviewed records contain the owner, patient,
examination ID, model/device provenance, validated result, disclaimer and notes.
Examination IDs make retries idempotent; RLS requires the authenticated owner,
an active server-approved clinician membership, and an explicit patient assignment
in the same clinic. Reviewed examinations are immutable to ordinary clients.
No image bytes are persisted by the new anemia repository. Existing authenticated
patient access policies remain in effect and require the deployment's existing
clinic/organization access controls.

The new authorization migration was deployed and verified against Supabase.
See `anemia-verification-2026-11-11.md` for the current verification status.
Screening access must be explicitly provisioned by a trusted administrator.

## Verification

- Mock tests cover readiness, cancellation/latest navigation, conflicts, malformed
  results, actual hub multipart routing, locks, clinician review, patient correlation,
  and desktop/tablet/mobile layouts.
- Opt-in live check: `flutter test --no-pub --dart-define=RUN_LIVE_EDGE_DEVICE_CHECKS=true test/edge_device_live_test.dart`.
  Run on an idle board. It sends no images or patient data, checks all three models,
  starts/releases nonclinical examination locks, and restores the original model.
- On 11 November the live hub acknowledged all selections with HTTP 202 and
  confirmed readiness for CaCx (~17 s), Anemia (~6 s), Ultrasound (~59 s).
  These are observations from one run, not new expected loading guarantees.
- The opt-in Flutter live test also passed for all three models and confirmed
  examination locks were acquired and released through the app client.
- Clinical image compatibility, diagnostic quality, and real authenticated
  Supabase save/reopen require supervised acceptance testing with approved data.
