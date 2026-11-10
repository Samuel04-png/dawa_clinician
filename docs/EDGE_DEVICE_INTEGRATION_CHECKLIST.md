# Edge Device Integration Checklist

Companion to [GEORGE_EDGE_DEVICE_HANDOFF.md](./GEORGE_EDGE_DEVICE_HANDOFF.md). "Blocker" = who must act. Mock tests are **not** hardware verification.

| # | Item | Flutter (implemented) | Still missing | Blocker | File / config | Verified by |
|---|---|---|---|---|---|---|
| 1 | Device address/ports | Base URL + per-service ports configurable | Final host; `http://` not `https://` | Device (value) | `EDGE_DEVICE_BASE_URL`, `EDGE_DEVICE_*_PORT` → `edge_device_config.dart` | `curl http://<host>:8080/health` from a clinic tablet |
| 2 | Hub select/status | `selectModel`, `getHubStatus`, polling, active-module match | Real-device run | Device | `edge_device_client.dart`, `edge_device_manager.dart` | Start exam, observe status reach `ready`, `active` matches |
| 3 | Real readiness in hub | App requires affirmative module `/health` itself | Hub must check `ready`/`models_loaded` | **Device** | `dawa/main.py` `_watch`/`_probe` | With model files removed, hub never reports `ready` for ultrasound |
| 4 | Ultrasound model files | Handles `ready:false`/503 | Provide `ultrasam_*.onnx`, license review | **Device** | `ultrasound/storage` | `GET :8086/health` → `ready:true` |
| 5 | Cervitriage `/predict` | Multipart upload, 200 parse, 422 = rejected-quality | Hardware run | Device | `cacx_upload_service.dart` `parseCervitriageResponse` | Upload cervical image → classification shown; non-cervical → "Image rejected" |
| 6 | Ultrasound `/predict` | Strict parse of segmentation, ellipse, overlay, timings, record id; pixel vs mm display | Hardware run, calibration | Device | `ultrasound_models.dart`, `ultrasound_edge_service.dart` | Upload frame; overlay + px measurements shown; `found:false` shows "no segmentation" |
| 7 | Pixel spacing | Optional `pixelSpacingMm` param plumbed; mm shown only if returned | A validated calibration value per probe | **Device + clinical** | device `measurement.pixel_spacing_mm`; app call site passes none | Measure phantom of known size |
| 8 | Prompt box | App sends no `box` | Clinically tuned prompt | **Device + clinical** | `ultrasound/config.yaml` | Clinical sign-off |
| 9 | Exam ownership / lock | Local lock only; refuses concurrent local exams; no `/api/stop` | `/api/reserve`/`/api/release`, 409 on foreign select | **Device**, then app adapter | new device routes; `edge_device_manager.dart` | Second client's `select` mid-exam returns 409 |
| 10 | Completion | Local release only (no device endpoint exists) | Optional release call after item 9 | Device | `edge_device_manager.dart#completeExamination` | n/a until item 9 |
| 11 | Authentication | None embedded, no secrets | LAN isolation or token scheme | Device (decision) | `EdgeDeviceClient` headers | Unauthenticated request rejected |
| 12 | Image formats/size | JPEG/PNG gate | Confirm accepted formats and limits | Device | `EDGE_DEVICE_SUPPORTED_IMAGE_MIME_TYPES` | Upload each format |
| 13 | Legacy `/upload/cervical` | Fallback when hub absent | Confirm any legacy device exists | Device | `cacx_upload_service.dart` | Test against a legacy device |
| 14 | Feature flags | Both default off | Turn on in a controlled build after 2–9 pass | App (after device) | `EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED`, `EDGE_DEVICE_ULTRASOUND_INFERENCE_ENABLED` | Integration build smoke test |
| 15 | Supabase ultrasound persistence | Repository, `ultrasound_scan_records` migration (segmentation jsonb, owner RLS) | **Migration not deployed**; overlay image not stored | App/ops | `supabase/migrations/202611060001_add_ultrasound_scan_records.sql` | Deploy to staging; save, restart app, reload record |
| 16 | Clinician→patient authorization | Scan RLS is owner-only | Baseline `mother`/`encounter` policies are `using(true)` for all authenticated users | App/ops (**production blocker**) | baseline migrations | Cross-clinician read denied in staging |

## Test plan on hardware

1. `curl` hub `/health`, `/api/status`; `curl` each module `/health`.
2. App: start CaCx exam → status `starting` → `ready` → result; confirm `active=="cervitriage"`.
3. Finish exam, start ultrasound exam → switch → `ready:true` → upload → overlay/measurements.
4. Remove ultrasound model files → confirm app blocks inference with a model-initialization error.
5. Mid-exam `select` from another client → (after item 9) 409; app exam unaffected.
6. Unplug network mid-exam → app shows disconnected, no fabricated result.

## Automated checks (mock only)

`flutter test test/edge_device_contract_test.dart test/edge_device_mock_hub_test.dart`
