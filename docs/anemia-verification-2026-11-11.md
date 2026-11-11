# Anemia integration verification — 11 November 2026

**Status: authenticated storage and access control verified; real NiADA image inference NOT VERIFIED.**
No approved, de-identified conjunctiva image is available. The user explicitly
instructed us to use mocked inference and synthetic records, and to leave real
image inference pending. No image was sent to the physical device in this run.

## George's reference

Reviewed `dawa_web_reference.zip`, including `WEB_DESIGN_GUIDE.md`,
`anemia/index.html`, and `anetriage-app/app.js`/`app.css`. It confirms the hub's
`POST /upload/anemia` multipart `image` endpoint, forwarding to NiADA's `/predict`,
the four returned classes/probabilities, the device disclaimer, and the prototype
limitations. The Flutter flow uses that verified route.

Adopted: patient-first preparation, 1024-pixel image selection with quality 85,
actual MIME detection, class-coloured result cards, real probability bars, explicit
low-confidence/prototype text, and patient-linked history. The reference's brand
colours already match DawaTokens.

The ZIP is a design/implementation reference, not authorization to overwrite
clinical policy. We retained the app's three-second status polling, strict
`active == anemia && ready == true && state == ready` gate, 300-second safety
limit, examination locks, clinician review, authenticated Supabase storage, and
patient browsing while loading. We did not copy browser-local patient storage,
client-generated patient identities, destructive erase actions, or its older
loading-time assumptions.

## Deployed authorization audit

Verified the remote migration history contains both existing versions:
`202611060001` and `202611110001`. Neither was reapplied or edited in this task.
The original anemia table had owner-based RLS and patient-existence checks, but
no clinician-role or clinic boundary. The existing mother policy permits broad
authenticated access; patient existence therefore cannot establish permission.
Original table grants also included unnecessary UPDATE/DELETE/TRUNCATE privileges.
There were no existing anemia examinations before verification.

Added, rollback-tested, then deployed **only** the new migration
`202611110002_harden_anemia_authorization.sql`, recording its version atomically:

- `anemia_clinician_memberships`: server-approved clinician membership per clinic.
- `anemia_patient_access`: explicit clinician/patient assignment in that clinic.
- `clinic_id` on examinations; no clinic is guessed or backfilled for legacy rows.
- Owner + active clinician membership + matching patient/clinic assignment required
  by examination RLS.
- Authenticated clients have SELECT and INSERT only; anonymous table access and
  client UPDATE/DELETE/TRUNCATE are revoked.
- `list_anemia_patients()` returns only permitted screening patients.
- `save_anemia_screening_review()` derives the authenticated owner and clinic on
  the server, requires explicit review and nonempty notes, validates the result,
  and atomically returns the same record for an identical examination retry.
  A conflicting duplicate is rejected instead of overwriting clinical provenance.
- Reviewed examinations are immutable to ordinary clients. Reopening queries the
  authenticated backend again; the UI does not rely solely on a cached history row.

Authorization does **not** trust editable `public.user.role`, doctor self-registration,
or JWT `user_metadata`. Access provisioning requires service-role/backend authority
or an admin role placed in trusted JWT `app_metadata`. No production patient or
clinician was automatically assigned access. Normal clinic assignments must be
provisioned by an authorized administrator.

The broader legacy mother/user policies were not globally rewritten in this
Anemia-specific change. That is a separate application-wide security concern;
this screening implementation does not use those broad policies as authorization.

### Provisioning approved clinical access

From a trusted backend only, call:

```text
grant_anemia_patient_access(
  p_user_id: approved clinician auth UUID,
  p_clinic_id: approved clinic ID,
  p_patient_id: permitted existing patient ID
)
```

Never put a service-role key into Flutter. This operation is denied to an ordinary
client, even if it claims `role: admin` in editable user metadata. To revoke access,
a trusted administrator deactivates the relevant membership or patient assignment.
Existing patient rows are not changed by these assignments.

## Verification results by environment

| Check | Environment | Result |
|---|---|---|
| Classification/probability validation; no fabricated Hb | Mocked inference | Passed |
| Ready gate, conflicts, disconnection, navigation, locks | Mock hub | Passed |
| Clinician checkbox + nonempty notes; permission-error UI preserves results/notes | Flutter widget/mocks | Passed |
| Proposed SQL policy checks, duplicate/conflict handling and revocation | Real Supabase, rollback transaction | Passed; no fixture data committed |
| Deployed schema, RLS and exact table privileges | Real Supabase metadata | Passed |
| Sign-in using the supplied test account | Real authenticated Flutter Supabase client | Passed |
| Patient list excludes unassigned and other-clinic patients | Real authenticated Flutter Supabase client | Passed |
| Save synthetic reviewed result with correct patient, user, clinic, exam, model, device and result | Real Supabase + mocked inference | Passed |
| Concurrent duplicate submissions return one record | Real Supabase | Passed |
| Conflicting duplicate cannot overwrite saved content | Real Supabase | Passed |
| Response interrupted after server commit; retry recovers exactly one record | Real Supabase + controlled client transport interruption | Passed |
| Fresh authenticated Flutter client reopens exact stored result | Real Supabase | Passed |
| Fresh application instance opens saved history detail using authenticated queries | Flutter screen + real Supabase | Passed |
| Separate unauthorized account cannot read/change/delete the examination or self-grant access | Real Supabase, separate authenticated account | Passed |
| Anonymous record access | Real Supabase | Denied as expected |
| Anemia selection acknowledges HTTP 202 and hub reports the correct active/ready state | Physical Dawa device | Passed |
| Model switching while a device examination is active | Physical device safety gate | Refused; no force/stop used |
| Actual NiADA inference using an approved conjunctiva image | Physical device | **Pending — NOT VERIFIED** |
| Real-device result → reviewed save → application reopen | Full end-to-end | **Pending — NOT VERIFIED** |

Synthetic result fixtures are prominently marked as mocked inference and use a
mock device provenance value. They are not presented as clinical/device results.
Cleanup completed: 2 synthetic examinations, 3 synthetic patients, 2 synthetic
clinics, their 2 memberships and 2 assignments, and the temporary unauthorized
auth account were removed. The supplied test account and existing patient records
were preserved. Temporary credential/session files were deleted.

## Re-running the live checks

Opt-in tests are skipped in the normal test suite. A private configuration file
outside the repository identifies synthetic fixture patients and credential-file
paths. Do not pass credentials as command-line dart-defines or commit them.

```sh
ANEMIA_VERIFICATION_CONFIG_FILE=/private/path/live-config.json \
  flutter test --no-pub --dart-define=RUN_LIVE_ANEMIA_STORAGE_TESTS=true \
  test/anemia_supabase_live_test.dart

ANEMIA_VERIFICATION_CONFIG_FILE=/private/path/live-config.json \
  flutter test --no-pub --dart-define=RUN_LIVE_ANEMIA_DEVICE_INIT_TESTS=true \
  test/anemia_device_live_test.dart
```

The device test sends no image and restores the prior model when the device is
idle. It skips an occupied device rather than interrupting another examination.
An approved image must be provided before adding/running the real inference step.

## Separate credential finding

An existing database webhook definition contained embedded credentials. One
privileged schema inspection returned that definition. The saved audit was
redacted and subsequent inspections omit raw credential-bearing definitions.
Those exposed webhook/service credentials require rotation. They were not copied
into source, tests, documentation, or the verification report, and were not rotated
silently because that could disrupt existing production integrations.

## Build and regression checks

- `flutter analyze --no-pub`: passed, no issues.
- Web release build: passed.
- Dedicated mocked Anemia workflow tests: 15 passed.
- Live Supabase storage/UI tests: 2 passed.
- Live Anemia initialization test: 1 passed; no image submitted.
- Full default suite: 143 passed, 4 opt-in live tests skipped, 3 existing failures
  (two assertions against the existing platform-sync migration placeholder and
  one missing patient-registry screenshot fixture).

No complete physical-device inference/save/reopen success is claimed.
