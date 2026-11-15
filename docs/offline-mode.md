# Offline Mode

Offline mode is partially implemented. I have enough confirmed code to say the app supports cached auth identity, cached Supabase query/document reads, visible connectivity status, and a device-only CaCx path when offline.

## What Currently Exists

| Feature | Status | Files |
| --- | --- | --- |
| Supabase reachability check | Done | `lib/services/offline_connectivity_service.dart` |
| Internet probe checks | Done | `lib/services/offline_connectivity_service.dart` |
| Device `/health` check | Done | `lib/services/offline_connectivity_service.dart` |
| Offline banner | Done | `lib/components/offline_status_banner.dart`, `lib/main.dart` |
| Cached Supabase user identity | Partially Done | `lib/services/offline_auth_cache.dart` |
| Offline cached sign-in fallback | Partially Done | `lib/auth/firebase_auth/firebase_auth_manager.dart` |
| Cached query/document rows | Partially Done | `lib/backend/supabase/supabase_offline_cache.dart` |
| CaCx offline device-only flow | Partially Done | `lib/application/cacx/cacx_widget.dart` |
| Pending CaCx result queue | Partially Done | `lib/application/cacx/cacx_upload_service.dart` |

## Intended Offline Behavior

The intended behavior is:

1. A user logs in online once.
2. The app caches that user identity.
3. If Supabase becomes unreachable, the user can continue with cached access.
4. Previously fetched rows can be shown from local cache where available.
5. CaCx can still be used offline if the local Arduino/Raspberry Pi device service is connected.
6. Offline CaCx should not rely on online Hugging Face/Gradio services.
7. Successful offline device results should queue locally and sync to Supabase when connectivity returns.

## Confirmed CaCx Offline Flow

When CaCx starts analysis, it refreshes connectivity. If the app is offline:

- It checks whether the device is reachable.
- If the device is not reachable, it shows an offline-device-unavailable message.
- If the device is reachable, it sends the image to the device.
- If the device succeeds, it queues the primary result locally.
- It opens the results screen with the device interpretation.

## What Is Cached

### Auth

`OfflineAuthCache` stores:

- `uid`
- `email`
- `displayName`
- `photoUrl`
- `phoneNumber`
- `emailVerified`
- `cachedAt`

### Supabase Rows

`SupabaseOfflineCache` stores:

- Query result rows by generated query key.
- Document rows by table and ID.

## What Still Needs Implementation

- Durable sync engine for all writes, not only CaCx pending inserts.
- Conflict handling when the same record is edited offline and online.
- Cache expiry rules.
- Encrypted local storage for sensitive clinical cache.
- A manual sync status screen.
- Offline test coverage with simulated Supabase outage.
- End-to-end testing with the physical device while offline.

## Important Limit

Offline mode should be described as field-support work, not as complete production-grade offline EHR behavior yet.

## Cervical patient selection (2026-11-14)

The cervical screening patient repository now saves successful patient-list reads
in the existing local cache, keyed by clinician ID and workflow. Known offline
sessions read that snapshot without requesting Supabase. A connection failure
also falls back after confirming an outage; explicit auth and database errors
are surfaced rather than bypassed. An empty successful response replaces the
previous snapshot, and a clinician switch cannot reuse another user's list.

To prepare: sign in online and open cervical screening once on the browser/device
that will be used offline. Then connect to the local Dawa device to analyse images
without internet. First-time offline use without a downloaded patient list remains
unavailable. Clearing browser storage removes downloaded records. This change
covers cervical patient selection; ultrasound and anemia repositories still need
separate offline patient and save workflows. Existing cache encryption and durable
sync limitations above still apply.

Validation: `flutter test test/screening_patient_offline_test.dart
test/cacx_second_opinion_flow_test.dart` (36 tests). Physical-device offline
verification remains required.

## Captures when both analysis services are unavailable (2026-11-14)

Cervical screening now offers **Save scan for later** after selecting a patient
and preparing an image, including when Analyze is disabled. It persists the full
image data URI, patient reference, clinician reference and a stable UUID locally.
Saved captures appear with **Resume**; they remain explicitly awaiting analysis.
Patient selection is no longer locked merely because an image exists before a
patient has been selected. Home/Patients reads also warm the cervical patient cache.

The global connection check retries draft uploads every 25 seconds while the app
is running and Supabase is reachable. Only drafts for the authenticated clinician
are uploaded. Upserts use the original UUID, so interrupted uploads can retry
without duplicates. Failed uploads retain the image locally. Uploading a capture
does not run AI analysis; resume it when a device or online service is available.

Database support is in `202611140001_add_cacx_scan_drafts.sql`; it creates a separate
RLS-protected capture table. The migration must be installed before uploads can
succeed. Pending captures remain local if that table is unavailable.

Implementation verification: 54 focused tests passed across draft persistence,
patient caching, cervical workflows, dashboard repository and offline banner;
static analysis of the changed workflow/cache/banner files reported no issues.
The linked database lists the new draft migration as pending. Deployment checking
stalled at login-role initialization, so remote draft-table installation has not
been confirmed by this session.

## Offline edge analysis correction (2026-11-14)

Internet unavailability now keeps Analyze enabled for a local device attempt
unless another examination owns the device. An offline attempt prepares the local
cervical model if readiness has not yet been established; it never falls back to
cloud analysis. Completed results enqueue immediately without a Supabase request,
then display normally. Cached patient selection no longer depends on loading
online screening history. A reachable Dawa device on the local network is required.

The app-wide connection check now syncs completed screening results as well as
captures. Result queue operations are serialized, scoped to the authenticated
clinician, and use persisted UUIDs with upserts so reconnect retries do not create
duplicate records. Completed results use the existing `cacx_screening_results`
table; this workflow does not require the separate draft-table migration.

Verification: 40 tests passed for cervical flow, cached patients, result retry/sync
and offline banner. Includes an offline cached-user/patient → local-device
inference → results-screen test asserting one device call, zero cloud calls, zero
database writes and one queued result. Static analysis passed. Physical hardware
and real offline/reconnect behavior still require field verification.

## All three screening modules (2026-11-14)

Anemia and ultrasound now use clinician-scoped patient and history snapshots and
a durable result outbox in `ClinicalOfflineStore`. The app's online connection
check warms all three screening patient lists plus anemia/ultrasound histories.
Anemia caches only `list_anemia_patients` assignments, including their clinic IDs;
it never treats the general patient list as anemia authorization. Local reviewed
anemia saves retain the device provenance, review notes and confirmation. On
reconnect the server RPC revalidates current authorization and provides idempotent
saving by examination ID. Rejected uploads remain in the outbox.

Ultrasound caches pregnancy context and saved analyses. Patient loading remains
usable even if history cannot be fetched. Offline validated results save locally
and appear in history immediately; reconnect sync inserts into the existing
ultrasound table. Duplicate examination IDs are verified against the saved content
rather than requiring a new UPDATE policy. Anemia offline analysis prepares and
uses the edge model and never attempts cloud fallback while offline. Cervical
history now reads cached rows and includes pending device results.

Online patient downloads are still necessary before using a clinician's records
for the first time offline. The local Dawa network/device must remain reachable
for inference. Reconnect sync runs while the app is open; storage clearing removes
local snapshots. These flows use existing clinical tables and RPCs and do not
require the separate capture-draft migration.

Validation: 124 tests passed, one existing test skipped, across clinical-module
offline/reconnect tests, ultrasound repositories/workflows/initialization, anemia
workflows/services, cervical workflows/result sync and offline banners. Static
analysis passed for changed clinical modules. Hardware field verification remains
outstanding; automated network/device tests use controlled fixtures.

## Device priority with internet available (2026-11-14)

Anemia and cervical analysis now await local workflow/model preparation before
considering an online provider, regardless of internet availability. An initializing
model no longer causes an immediate cloud submission. The manager exposes the
preparation failure so busy/conflict, authorization and invalid-response failures
retain their original meaning instead of becoming generic device-unavailable
fallbacks. Ultrasound continues to use its local edge inference path.

Online fallback requires an unavailable local analysis path and available internet;
a Supabase outage alone does not mean internet is unavailable. Completed local
results never trigger automatic online analysis. Cervical screening also prevents
starting a new attempt while an unresolved device examination exists. Disabling
online fallback still allows a local connection/readiness attempt.

Validation: 86 workflow/routing tests and 27 device lock/hub tests passed. Cervical
workflow tests also passed after adding the unresolved-examination guard. Static
analysis passed. Physical device behavior remains subject to field verification.
