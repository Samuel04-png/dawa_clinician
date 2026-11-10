# Dawa Real-Device Integration Test Report

**Date:** 2026-11-06. Sections 1–11 describe the earlier read-only test. A
subsequent controlled Chrome proxy test submitted one synthetic image after
the user confirmed the device was idle; see **Chrome synthetic-image test**
below. No real-device model switch or examination lock was exercised.

## Status legend
- **HW** = implemented and tested against real hardware
- **MOCK** = implemented, tested against mocks only
- **BLOCKED** = blocked by unavailable device API details
- **NOT IMPL** = not implemented

## 1. Configuration used

```
EDGE_DEVICE_BASE_URL=http://10.127.36.206   # dev network only; also http://dawa.local
EDGE_DEVICE_HUB_PORT=8080  EDGE_DEVICE_CERVICAL_PORT=8085  EDGE_DEVICE_ULTRASOUND_PORT=8086
EDGE_DEVICE_CERVICAL_MODEL_ID=cervitriage  EDGE_DEVICE_ULTRASOUND_MODEL_ID=ultrasound
EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED=true  EDGE_DEVICE_ULTRASOUND_INFERENCE_ENABLED=true   # integration builds only
```

The IP is passed with `--dart-define` and not hard-coded; defaults still keep both flags off. The IP and port defaults are the app's only device addresses.

**Platform networking review**
- **Android:** `INTERNET` permission is present. The network security config permits cleartext globally (`base-config cleartextTrafficPermitted="true"`, pre-existing). This is broader than needed. Narrow it to the device host or `dawa.local` before release.
- **iOS:** `NSAllowsLocalNetworking` (covers `.local` and IP literals) and `NSLocalNetworkUsageDescription` are present. Bonjour (`dawa.local`) resolution is subject to the local-network permission prompt.
- **macOS / desktop:** there is no `macos/` project in this repo. Flutter desktop on macOS would need the `com.apple.security.network.client` entitlement.
- **Flutter Web:** not viable against this device as it stands. A page served over HTTPS cannot call `http://` (mixed content), and the hub has no CORS (the cervitriage CORS option is off by default). Web needs a TLS reverse proxy with CORS, which is a device-side decision.
- TLS validation is not bypassed anywhere.
- The device has no authentication, so test only on an isolated network with non-patient data.

## 2. Device reachability (real, read-only)

| Check | Result |
|---|---|
| `GET http://10.127.36.206:8080/api/status` (curl) | HTTP 200, `active=cervitriage`, `state=ready`, `health={models_loaded:true,status:ok}` |
| `GET http://dawa.local:8080/api/status` (curl) | HTTP 200, same body |
| App's own `EdgeDeviceClient` (`tool/edge_device_readonly_check.dart`) against both hosts | Hub `/health` 200; hub status parsed (`modules={cervitriage, ultrasound}`); `:8085/health` → `modelLoaded=true`, `inferenceReady=true` |
| `:8086/health` | Connection refused. Expected: the hub runs one module at a time and ultrasound is not active. |
| `GET /api/exam/start` (existence probe only, no POST) | **404**. The device lock routes appear not to be deployed on the running device. |

## 3–4. Actual CaCx / Ultrasound request/response observations
Only the status and health responses above were observed on hardware. **No `/api/select`, no `/predict` was sent**, so there are no real CerviTriage or ultrasound inference observations (**NOT TESTED on hardware**). `GET :8085/health` and the hub status schema matched the source and parsed with the app's client (**HW, read-only**).

## 5. Model switching
- Already-ready requested module → no `/api/select` sent (**MOCK**).
- Different module → select, poll for `active == requested` and `ready`, then require affirmative module health (**MOCK**).
- Real-device switching: **not executed.**

## 6. Examination lock — **BLOCKED**
George confirmed `POST /api/exam/start|heartbeat|end` (30 s heartbeat, 120 s expiry, 409 `exam_in_progress`/`busy`), but **no request or response schemas were supplied**. The supplied zips contain none of it, and the live device returns 404 for the path. Therefore:
- Lock acquisition, heartbeat, end, and gating inference on a held lock are **NOT IMPL (blocked)**. No payloads were invented, and the app's local exam ID is not assumed to match any device lock id.
- The app only has a **local** lock. The new clinical workflow is **not** device-lock-protected and must not be described as fully working.
- 409 `exam_in_progress` / `busy` from `select` are surfaced as "Device busy" with the device's code in the message. There is no silent legacy fallback and no override (**MOCK**).
- Still to build once the schemas arrive: heartbeat timer, app-backgrounding and disconnect handling, stale-session handling and safe end.

## 7. Inference results from test images
None on hardware. Parsing was exercised against schema-faithful mock payloads only (**MOCK**).

## 8. Errors encountered
- Ultrasound port 8086 refused while CerviTriage was active (expected).
- `/api/exam/start` 404 (see §6).
- No app errors from real-device reads.

## 9. Flutter results
| Command | Result |
|---|---|
| `dart format lib test tool` | 0 files changed |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` | **74 passed, 3 failed** (all pre-existing, not caused by this work) |

New or updated tests: `test/edge_device_contract_test.dart` (17), `test/edge_device_mock_hub_test.dart` (14, including skip-select-if-ready and the `exam_in_progress` 409).

Pre-existing failures (unchanged, reported separately):
- 2 × `dawa_platform_sync_architecture_test`: `202607170001_add_dawa_platform_sync.sql` is a one-line stub. I did not reconstruct it from guesses.
- `demo_capture_proof_test`: missing golden file plus an `app_links` plugin exception.

## Feature classification

| Feature | Status |
|---|---|
| Hub reachability, status parse, CaCx module health read | **HW (read-only)** |
| CaCx select / readiness / `/predict` / 422 / legacy fallback | MOCK |
| Ultrasound select / readiness / `/predict` / segmentation display / `found:false` | MOCK |
| Switch-back to CaCx | MOCK |
| Skip select when already ready | MOCK |
| Busy / disconnect / timeout / invalid-response handling | MOCK |
| Status UI (cervical/ultrasound preparing, ready, busy, failed, unavailable) | MOCK (widget logic; not driven by a real device) |
| Exam lock start / heartbeat / end | **BLOCKED** (schemas missing; endpoint 404 on live device) |
| Ultrasound pixel-spacing calibration | NOT IMPL (needs a validated value from George) |
| Supabase ultrasound migration | Not deployed; not validated against a test database |

## 10. Remaining blockers
1. Lock API schemas and deployment (see §6).
2. Hardware test of select/predict on both modules is pending George's confirmation that the board is idle.
3. Ultrasound model files, placeholder prompt, calibration, validation and licensing (see the handoff doc).
4. Ultrasound migration: deploy only after testing on a staging database.
5. **Patient-access RLS:** the base `mother`/`encounter` policies are `using(true)` for all authenticated clinicians. Do not expand real patient use until fixed.
6. Android cleartext scope; Flutter Web not supported.
7. The 3 pre-existing test failures.

## 11. Actions for George
1. Send the exact JSON request/response schemas for `/api/exam/start`, `/heartbeat` and `/end` (lock id/token field, whether the client supplies an id, error body shapes), or the updated source. Deploy them: the live device returns 404 for `/api/exam/start` today.
2. Confirm when the board is idle and approve the live test sequence: select ultrasound → `/predict` with a non-patient phantom image → select cervitriage → `/predict` with a non-patient image.
3. Fix hub readiness to check module health bodies (`ready`, `models_loaded`).
4. Provide the ultrasound model files, validated pixel-spacing, a reviewed prompt and the license review.
5. Decide on network isolation or auth, and a TLS/CORS proxy if web is ever needed.

## CaCx connection fix: run instructions and findings

**Root cause of the `https://dawa.local/health` failure:** the app was started without
`--dart-define` values, so it used the default `https://dawa.local` with model
management off, and the offline router sent the scan to Gradio. Dart defines are
compile-time: stop the app and run again (hot restart is not enough).

```
flutter run -d <ios-or-android-device> \
  --dart-define=EDGE_DEVICE_BASE_URL=http://10.127.36.206 \
  --dart-define=EDGE_DEVICE_HUB_PORT=8080 \
  --dart-define=EDGE_DEVICE_CERVICAL_PORT=8085 \
  --dart-define=EDGE_DEVICE_ULTRASOUND_PORT=8086 \
  --dart-define=EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED=true
```
Optional: `EDGE_DEVICE_INFERENCE_TIMEOUT_SECONDS` (defaults to the upload timeout).
The base URL must be plain `http://` with no port; the app now refuses to start a
device call with a clear configuration error otherwise.

**Flutter Web:** the hub (:8080) and cervical server (:8085) return no
`Access-Control-Allow-*` headers (verified by preflight), and an HTTPS page cannot call
HTTP (mixed content). For development use `tool/edge_dev_proxy.dart` with a fixed
`http://localhost:<port>` web origin and `EDGE_DEVICE_BASE_URL=http://localhost`.
Production browser access needs an authenticated HTTPS gateway (not implemented).

**Fallback:** the online second opinion runs only after a classified device failure and
explicit clinician approval; the image is kept locally for retry.

**Supabase 401s:** from the app's own connectivity probes against `/rest/v1/`, which
rejects publishable keys. Harmless to CaCx; probes now use `/auth/v1/health`.

**Not yet verified on hardware:** `/api/select`, `:8085/predict`, exam lock.

## Flutter Web local development (proxy workflow)

```
tool/run_web_dev.sh [device-ip] [web-port]     # default web port 5100
```
The script checks the device hub directly, starts `tool/edge_dev_proxy.dart`, verifies
the proxy can reach the device with the web origin, then runs
`flutter run -d chrome --web-port <port>` with `EDGE_DEVICE_BASE_URL=http://localhost`,
the hub/module ports 8080/8085/8086 and model management enabled. The browser only
talks to `localhost`; hub and module ports stay distinct through the proxy.
If those local ports are in use, set `EDGE_PROXY_HUB_PORT`,
`EDGE_PROXY_CERVICAL_PORT`, and `EDGE_PROXY_ULTRASOUND_PORT` before launching.
The proxy still forwards to device ports 8080, 8085, and 8086 respectively.

The proxy: loopback only; one device; exactly one `http://localhost:<port>` origin
(wildcards rejected); allow-listed routes only (`GET /api/status`, `POST /api/select`,
`GET /health`, `POST /predict`, `POST /upload/cervical`, each only on its proper port).
`/api/stop` and exam-lock routes are **not** proxied; lock routes are added only after
George supplies the schemas.

Diagnosing a failed browser request in Chrome DevTools > Network:
- `net::ERR_CONNECTION_REFUSED` on `localhost:8080` = proxy not running.
- CORS error with no response = page origin differs from `--allow-origin`.
- "mixed content" = page served over HTTPS; use the `http://localhost` origin.
- 502 from the proxy = device port unreachable (e.g. ultrasound module not active).
- 403 from the proxy = origin mismatch.

Verified read-only through the proxy against the real device (hub status, cervical
health, preflight, bad-origin refusal). Ultrasound health via proxy returned 502 because
the ultrasound module was not active. No `/api/select` or image was sent.

## Dev launch configuration (hub 10.127.36.206)
- Web (Chrome): `tool/run_web_dev.sh` (device defaults to `10.127.36.206`; override with an
  argument or `EDGE_DEVICE_IP`). The browser must use `http://localhost` because the device
  sends no CORS headers; the proxy forwards to the device IP, never `dawa.local`.
- Phone/tablet: `.vscode/launch.json` "direct" configuration uses `http://10.127.36.206`.
- The source default (`https://dawa.local`) is the legacy/production setting and is not used
  when `EDGE_DEVICE_BASE_URL` is supplied; no device IP is hardcoded in `lib/`.

## Chrome synthetic-image test

After the user confirmed the device was idle, an isolated Chrome session loaded
`http://localhost:5100` and submitted a synthetic blank PNG using browser
`fetch` through the development proxy. This exercised the network path, not a
CaCx UI submission or a diagnostic prediction:

| Browser request | Proxy upstream | Result |
|---|---|---|
| `GET localhost:18080/api/status` | `10.127.36.206:8080/api/status` | 200, active `cervitriage`, `ready` |
| `GET localhost:18085/health` | `10.127.36.206:8085/health` | 200, `models_loaded: true` |
| `POST localhost:18085/predict` | `10.127.36.206:8085/predict` | 422, gatekeeper rejected the synthetic image |

Responses carried `Access-Control-Allow-Origin: http://localhost:5100`. The
proxy's multipart preflight returned 204 with the allowed origin, method and
headers. No `/api/select` was sent. The physical response was a quality-gate
rejection, not successful diagnostic inference, and does not validate the UI.
Separately, a Chrome Flutter test drives the CaCx client and readiness banner
against a mock device, including request-ID generation and multipart routing.

The launch script uses local ports 8080/8085/8086 by default. The synthetic test
used overrides 18080/18085/18086 because another developer launch already held
the standard proxy ports. Chrome on this Mac also had port 5000 occupied.

## CaCx UI and patch follow-up

The later supplied patch ZIP contains eight files. Its `docs/dawa_hub_contract.md`
is useful as an **unverified** description of a possible newer hub and lock
contract; the other files use the older single-address `/upload/cervical`
integration and were not applied. The deployed hub returned 404 to GET and
OPTIONS for the documented hub upload and examination-lock paths initially.
After the device reconnected, OPTIONS returned 200 for those paths; their
payload and response contracts remain unverified.

During a later user-initiated CaCx screen run, the app logged selecting
`cervitriage`, waiting for readiness and receiving a gatekeeper rejection.
The image was not confirmed to be non-patient test data, and the exact HTTP
status and browser Network entries were not captured for that run. It is not a
controlled non-patient test or evidence of successful diagnostic inference.
The hub subsequently became unreachable and later reconnected.

That run also exposed an existing database constraint accepting only
`pending`, `success`, `failed`, and `timeout`. Rejected attempts are now
persisted as `failed`, retaining their rejection label and raw device response;
the interface continues to distinguish rejection from an inference result.

On the updated application, the user then confirmed an idle device and
submitted a synthetic image through the CaCx UI. The app logged a stopped hub,
selection of `cervitriage`, readiness, `POST localhost:18085/predict`, and HTTP
422 with a gatekeeper rejection; no valid diagnostic classification was
returned. The browser Network panel was not independently captured. The user
subsequently reported an AI-Guided ultrasound attempt that did not become ready;
the observed app logs contained no ultrasound selection and the hub remained
on `cervitriage`, so the cause and any ultrasound request remain unverified.
