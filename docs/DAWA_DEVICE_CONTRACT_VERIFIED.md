# Dawa edge device: verified contract for the clinician app

**From:** George (device side). **For:** Samuel. Replaces the "unverified patch claims" in
`GEORGE_EDGE_DEVICE_HANDOFF.md` sections 4, 6 and 7. Everything below is read from the deployed hub source
(`main.py`) and was exercised on the two real boards (`dawa.local` 192.168.0.194, `dawa2.local` 192.168.0.195).

## 1. Addresses
- **Hub: port 80** (boot service `dawa.service`). Use `EDGE_DEVICE_HUB_PORT_REMOTE=80` with `tool/run_web_dev.sh`; manual runs use 8080.
- Module ports (internal; prefer the hub's `/upload/*`): cervical 8085, ultrasound 8086, **anaemia 8087 (new)**.
- Hub CORS is `*` and answers OPTIONS, so a browser can call the hub directly. No authentication yet: test on an isolated network, non-patient images only.

## 2. Modules (ids for `/api/select`)
`cervitriage`, `ultrasound`, `anemia` (note the spelling). One runs at a time. `GET /api/status` lists them in `order`.

## 3. Hub endpoints
| Endpoint | Notes |
|---|---|
| `GET /hub/health` | always 200 `{"hub":true,"status":"ok"}` |
| `GET /health` | **200 only when the active module is ready**, otherwise 503 `{"status":"no_scan_selected"\|...}` |
| `GET /api/status` | `{active, state: stopped\|starting\|ready\|not_ready\|error, ready, busy, message, health, exam, order, modules, urls, ip_urls, name_url, since, elapsed_s, log_tail}` |
| `POST /api/select` `{"module":"..","restart"?:bool,"force"?:bool}` | 202 + status. Same module already starting/ready = no-op. |
| `POST /api/stop` | exists; the app never calls it |
| `POST /upload/cervical \| /upload/ultrasound \| /upload/anemia` | multipart `image` (+ optional `patient_id`, and for ultrasound `box`, `pixel_spacing_mm`). Forwarded to the active module's `/predict`. 409 `wrong_module` if another scan is active. |

`state:"not_ready"` means the process runs but its model failed or is still loading: poll, do not treat as ready. `ready` is true only after a real warm-up inference.

## 4. Examination lock (verified)
All JSON. Error body is always `{"error": "<message>", "code": "<code>"}`.

| Call | Request | Success | Errors |
|---|---|---|---|
| `POST /api/exam/start` | `{"module":"anemia","device":"app-1a2b3c4d","ttl_s":120?}` | **201** `{"exam_id":"<12 hex>","ttl_s":120}` | 409 `exam_in_progress` (held by another device); 409 `module_not_ready` (that module is not the running, ready one) |
| same, same `device` + `module` while held | same | **201** `{"exam_id":<same id>,"ttl_s":120,"resumed":true}` | – |
| `POST /api/exam/heartbeat` | `{"exam_id":".."}` | 200 `{"ttl_s":120}` | 404 `exam_not_found` (expired/wrong id) |
| `POST /api/exam/end` | `{"exam_id":".."}` | 200 `{"ended":true}`; if already ended/expired `{"ended":false}` (idempotent) | 404 `exam_not_found` if another exam holds the lock |

Rules: the client supplies `module` and a `device` label; the **device returns `exam_id`**. TTL default 120 s (10 to 900 allowed): send a heartbeat every 30 s. While the lock is held, `select`/`stop`/`restart` return **409 `exam_in_progress`**; while a scan is being processed they return **409 `busy`**; a second switch in flight returns 409 `switch_in_progress`. `force:true` works only from localhost or with the `X-Dawa-Admin` token (the app must not use it). Start the exam **after** the module is ready, end it when the clinician finishes or cancels.

Other codes: `unknown_type`, `forbidden`, `wrong_module`, `not_ready`.

## 5. Module responses
- **Cervical** `/predict`: unchanged (422 `classification:"Rejected"` for non-cervical images).
- **Anaemia** `/predict` 200: `{classification: "No Anemia"|"Mild Anemia"|"Moderate Anemia"|"Severe Anemia", class_index 0..3, confidence 0..1, probabilities{4 classes}, timings_ms, image_size, disclaimer, record_id}`. Prototype model, 57.7% validation accuracy; show the disclaimer. Fed with a close-up of the lower eyelid.
- **Ultrasound** `/predict` 200: as before plus `prompt` (`auto|user|fixed`) and `box_px`. `found:false` has no measurement fields.
- Health of every module has `ready` (true only after warm-up) and `busy`.

## 6. Current state of the models (be honest in the UI)
| Scan | State |
|---|---|
| Cervical | MedSigLip on the NPU, about 3 to 4 s per image. Same results on both boards. |
| Anaemia | PyTorch DINOv2 + head, about 1 to 5 s on CPU. **Only the head was supplied**; the fine-tuned backbone is pending from the NiADA team. Low-confidence results (<50%) are common. |
| Ultrasound | Fine-tuned UltraSam (SAM ViT-B) now installed, PyTorch, **about 45 s per image**. Prompt: automatic box search (heuristic, unvalidated) unless the app sends `box`. `pixel_spacing_mm` is not calibrated, so results are in pixels. Not validated for clinical use. |

Set client timeouts accordingly: inference at least **120 s** for ultrasound.

## 7. What the app needs to change
1. Add the third scan (`anemia`, `/upload/anemia` or `:8087/predict`) alongside cervical and ultrasound.
2. Implement the lock using section 4 (the client/manager patch in `dawa_clinician_device_patch.zip`: `startExam`, 30 s heartbeat, `endExam`, error mapping from `code`). Add `/api/exam/*` to the dev proxy allowlist (already listed in `tool/edge_dev_proxy.dart`).
3. Read the `code` field of error bodies (not only `error`).
4. Ultrasound inference timeout >= 120 s; show the `prompt`/`box_px` result and do not present pixel results as millimetres.

## 8. Device self-test (George runs before every app test)
`tool/device_selftest.sh http://dawa.local /path/to/non-patient-eyelid.jpg ultrasound`
Checks reachability, anaemia readiness, lock start/resume/conflict/heartbeat/end, the 409 on switching while locked, and one anaemia upload. All lines must say PASS before the app is tested.
