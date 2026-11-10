# Dawa Edge Device — Clinician Integration Handoff

> **Superseded in part (2026-11-10).** Sections 4, 6 and 7 (readiness, legacy CaCx, examination lock) are answered and verified in
> [`DAWA_DEVICE_CONTRACT_VERIFIED.md`](DAWA_DEVICE_CONTRACT_VERIFIED.md). The device lock and a third scan (`anemia`) are now deployed on both boards; the hub listens on port 80.

**Audience:** George / edge-device team.
**Basis:** the supplied `dawa.zip` (and `dawa_update.zip`) source. Everything marked **Confirmed (source)** is read from that code. It has **not** been verified on physical hardware. Mock-server tests in this repo only prove the Flutter client matches the source schemas; they are not evidence about the real device.

## Current board update

The board owner reports that both modules expose `ready`, and that cervical
`models_loaded` alone does not confirm warm-up. The app now requires `ready`.
The hub may report `not_ready`, which is polled rather than treated as ready.
The development launcher defaults to `dawa.local:80`; if the boot service is
moved to port 8080, run `EDGE_DEVICE_HUB_PORT_REMOTE=8080 tool/run_web_dev.sh`.
The proxy allows the reported hub examination and stop routes, but the app
still uses only an in-process lock: the device-side lock lifecycle, including
selection ordering and the meaning of the `device` field, must be verified
before enabling it. This is not safe for concurrent clinical use.

## 1. Flow the app implements

| Exam | Steps |
|---|---|
| CaCx | `POST :8080/api/select {"module":"cervitriage"}` → poll `GET :8080/api/status` until `active=="cervitriage"` and `state=="ready"` → `GET :8085/health` must have `ready:true` and `status:"ok"` → `POST :8085/predict` (multipart `image`) |
| Ultrasound | `POST :8080/api/select {"module":"ultrasound"}` → poll status until `active=="ultrasound"`, `state=="ready"` → `GET :8086/health` must have `ready:true` and `status:"ok"` → `POST :8086/predict` (multipart `image`, optional `box`, `pixel_spacing_mm`) |

The app never calls `/api/stop`, never switches because of navigation, and refuses to switch while an examination is active in the app. All device paths stay behind `EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED` (and `EDGE_DEVICE_ULTRASOUND_INFERENCE_ENABLED` for ultrasound), both default **off**.

## 2. Confirmed endpoints (from source)

| Service | Port | Endpoint | Request | Response |
|---|---|---|---|---|
| Hub | 8080 | `GET /health` | – | `{"status":"ok","hub":true}` |
| Hub | 8080 | `GET /api/status` | – | `{active, state: stopped\|starting\|ready\|error, message, health, log_tail, since, elapsed_s, modules:{id:{label,subtitle,port}}, urls}` (update adds `name_url`, `ip_urls`) |
| Hub | 8080 | `POST /api/select` | JSON `{"module":"cervitriage"\|"ultrasound","restart"?:bool}` | 202 + status; 400 unknown module; 409 switch in progress; same module already starting/ready without `restart` is a no-op |
| Hub | 8080 | `POST /api/stop` | – | exists; **app never calls it** |
| Cervitriage | 8085 | `GET /health` | – | `{"status":"ok"\|"loading","models_loaded":bool}` |
| Cervitriage | 8085 | `POST /predict` | multipart `image` | 200 `{classification, confidence 0–1, probabilities{Normal,CIN1,CIN2,CIN3,Cancer}, gatekeeper_flagged, gatekeeper_scores, timings_ms{queue_wait,gatekeeper,diagnostic,total,decode}, record_id}`; **422** gatekeeper rejection `{classification:"Rejected", confidence:1.0, gatekeeper_flagged:true, message,…}`; 400 decode failure; 500 inference failure |
| Cervitriage | 8085 | `POST /upload/cervical` | multipart `image`, `patient_id`, `examination_type` | **Legacy** deployments only. Not present in the supplied cervitriage source; kept as app fallback (see §6). |
| Ultrasound | 8086 | `GET /health` | – | `{"status":"ok"\|"waiting_for_model","ready":bool,"mode","message"}` — **HTTP 200 even when `ready:false`** |
| Ultrasound | 8086 | `POST /predict` | multipart `image` (required), `box` = `x0,y0,x1,y1` pixels inside the image (optional), `pixel_spacing_mm` positive number (optional) | 200 `{found, area_px, circumference_px, ellipse{cx,cy,axis1_px,axis2_px,angle_deg}, circumference_mm?, area_mm2? (only with spacing), iou_score, image_size[w,h], overlay "data:image/jpeg;base64,…", timings_ms{preprocess,encoder,decoder,postprocess,decode,total}, record_id}`; `found:false` carries no measurement fields; 503 `{error, ready:false}`; 400 bad input; 500 failure |

Sample requests:

```http
POST http://dawa.local:8080/api/select
Content-Type: application/json

{"module":"ultrasound"}
```
```bash
curl -F image=@scan.jpg -F pixel_spacing_mm=0.3 http://dawa.local:8086/predict
```

## 3. Settings and where George's values go

`EDGE_DEVICE_BASE_URL` must be plain `http://<host>` (no port, no credentials, no query). The app replaces the port per service. All values below are `--dart-define`s read in [`edge_device_config.dart`](../lib/services/edge_device/edge_device_config.dart).

| Setting | Current value | Confirmed? | What George must provide |
|---|---|---|---|
| Host/address | `EDGE_DEVICE_BASE_URL` (legacy fallback `http://dawa.local:8080`) | Source: plain HTTP | Final hostname/IP strategy (mDNS `dawa.local` vs. static IP); TLS or not |
| Ports | 8080 / 8085 / 8086 (`EDGE_DEVICE_*_PORT`) | Source | Confirm unchanged on deployment |
| Select / status paths | `/api/select`, `/api/status` | Source | – |
| Module health / predict | `/health`, `/predict` | Source | – |
| Module IDs | `cervitriage`, `ultrasound` | Source | – |
| Readiness fields | `ready` for both modules | Board owner | Verify against deployed modules |
| Process-switch timeout | 300 s (`EDGE_DEVICE_MODEL_READY_TIMEOUT_SECONDS`) | Matches `ready_timeout_s` | Measured real cold-start time on the Pi |
| Image formats | `image/jpeg,image/png` | **No** | Formats the decoders accept; max size |
| API version header | none | n/a | Not in source; confirm none needed |
| Authentication | none | Source: none | See §5 |
| Ultrasound calibration | not sent | **No** | See §7 |

Config-only changes: addresses, ports, paths, module ids, ready field names, timeouts, MIME types. **Adapter changes** (Dart code in `edge_device_models.dart` / `edge_device_client.dart` / `ultrasound_models.dart`): any change to response field names or structure, a different health schema, authentication, an examination-reservation protocol, or per-module completion calls.

## 4. Device-side fix: real readiness (REQUIRED)

`dawa/main.py` marks a module `ready` as soon as its `/health` returns HTTP 200 with JSON. The ultrasound server returns 200 with `ready:false`/`status:"waiting_for_model"` when model files are missing (and cervitriage returns `status:"loading"`). The hub must:

1. Treat a module as ready only when its health body affirms it (`ready == true` for ultrasound, `models_loaded == true` and `status == "ok"` for cervitriage) — keep state `starting` otherwise, or move to `error` after the timeout.
2. Surface that body in `/api/status.health`.

Until fixed, the app independently reads module `/health` and blocks inference unless the field is affirmative, so the app is safe either way — but the hub status would still be misleading for other clients.

Note: in the supplied ultrasound server the model loads before the HTTP server starts and failures leave `ready:false` persistently. The app therefore gives up after `moduleHealthGrace` (10 s) of hub-ready-but-unhealthy.

## 5. Authentication

The supplied hub and modules have **no authentication** and no CORS on the hub. The app embeds no device secrets. Production use requires George to decide on LAN isolation (VLAN / firewall / no WAN exposure) and, preferably, a short-lived per-session token issued out-of-band. Do not hard-code a long-lived key in the Flutter binary. Any scheme is an adapter change in `EdgeDeviceClient` (headers) plus a config value.

## 6. Legacy CaCx compatibility

Legacy upload is available only when model management is explicitly disabled. With model management enabled, a hub failure does not fall back to `POST {EDGE_DEVICE_BASE_URL}/upload/cervical`. The deployed hub initially returned 404 to GET and OPTIONS for that route; after reconnecting it returned 200 to OPTIONS. No POST was sent to validate the newer hub route. The confirmed cervical inference route remains `:8085/predict`. Ultrasound runs separately on port 8086.

## 7. Examination ownership / locking (device-side REQUIRED for clinical use)

The subsequently supplied `dawa_clinician_device_patch.zip` documents a possible
`POST /api/exam/start` with `module`, `device`, `ttl_s` and response `exam_id`,
and heartbeat/end bodies with `exam_id`. It also describes hub upload routes.
These are **unverified patch claims**, not a confirmed deployed contract.
Earlier on 2026-11-06 the hub returned 404 to GET and OPTIONS for all three
lock paths and `/upload/cervical`; after the device reconnected, OPTIONS returned
200 for each. This demonstrates that routes are now exposed, not that the
documented payloads, ownership, expiry, or error semantics are correct. George
must provide matching deployed source, confirm full schemas and errors, and
demonstrate them on an idle device before the app enables device-side locking.

The hub only prevents two *simultaneous switch requests* (409). It has no notion of an examination, so any client on the LAN can `select` a different module in the middle of a scan. Proposed (not implemented, not called by the app):

- `POST /api/reserve {"module", "exam_id"}` → token; `POST /api/release {"token"}`.
- While reserved, `/api/select` for another module returns 409 with the reservation holder; the reservation expires after an inactivity TTL.
- Optionally `/predict` echoes `exam_id` for correlation.

Until then, the app only guarantees *local* protection (it will not start a second examination while one is active). Do **not** enable uncontrolled switching for production clinical use.

## 8. Ultrasound items that must be resolved before any clinical use

| Item | Status |
|---|---|
| **Placeholder segmentation prompt** | `ultrasound/config.yaml` `prompt.default_box: [0.1,0.1,0.9,0.9]` is a placeholder, not a clinically tuned prompt. The app sends no `box` by default. |
| **Missing pixel-spacing calibration** | `measurement.pixel_spacing_mm: null`. The app shows pixel values only and labels them "not physical millimetres" unless the device returns `*_mm` fields. |
| **Physical-model validation** | `ultrasam_encoder.onnx` / `ultrasam_decoder.onnx` are not in the zip; no accuracy/validation evidence supplied. |
| **Model licensing review** | UltraSam/SAM-derived ONNX weights (and the MedSigLIP-based cervical models) need a license/redistribution review before clinical deployment. |
| **Interpretation** | Output is a segmentation + ellipse circumference. The app does not map it to risk, gestational age or normal/abnormal. `found:false` is shown as "no segmentation found", never as normal. |

## 9. Remaining clinical validation

Real-device end-to-end test; cold-start timing; behavior under concurrent clients; image-format/size limits; CaCx gatekeeper-422 clinical review; ultrasound calibration and accuracy vs. standard measurements; sign-off on provenance fields (`record_id` is the only device-side identifier returned — there is no device id or model version in responses).

## 10. Provenance the app records

`provider` (edge / cloud / manual), `modelId` (`cervitriage`/`ultrasound`), device host, device `record_id`, timings, and the local examination/request ids (local only; the device does not echo them).
