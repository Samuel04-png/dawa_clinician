# Edge Device Model Switching Contract

> Current Ultrasound initialization behavior (11 November 2026): the app uses
> `http://dawa.local/api/select` with `{"module":"ultrasound"}` automatically on
> workflow entry and polls `/api/status` every 3 seconds. HTTP 202 acknowledges
> selection only. Readiness requires matching `active`, boolean `ready: true`,
> and `state: "ready"`, as confirmed after model warm-up by the hub. Model management
> and verified local Ultrasound inference now default on.
> Typical startup is about 60 seconds cold or up to 30 seconds warm; the safety
> timeout remains 300 seconds. Patient/image preparation stays available and
> no automatic online fallback is used. The proposal sections below are historical;
> see `environment-variables.md` for the current configuration.


**Audience:** George and the Dawa edge-device team  
**Status: SUPERSEDED.** The proposed `/v1/*` model API below was replaced by the real hub API (`POST /api/select`, `GET /api/status`, per-module `/predict`). See `GEORGE_EDGE_DEVICE_HANDOFF.md`. Retained only as history. Original status: integration proposal; only the legacy CaCx endpoints below are verified from the clinician client. This is not evidence that the proposed model endpoints exist or are deployed.

## 1. Scope and compatibility

The clinician app currently communicates directly with a clinic-LAN HTTP(S) service. It sends CaCx images to `POST /upload/cervical` after checking `GET /health`. No device implementation or physical device was available when this contract was written.

New model-management traffic and Ultrasound edge inference are disabled by default in the Flutter app. Enable them only in a controlled integration build after the device team confirms endpoint paths, schemas, authentication, and lifecycle semantics. The app must not treat a timeout, `404`, or generic health success as proof that a model was selected or is ready.

## 2. Existing verified CaCx contract

### `GET /health` — existing

- The client accepts any 2xx response as reachable.
- The client does not inspect the response body for model readiness.
- This endpoint must not be used by the app as model-ready confirmation.

### `POST /upload/cervical` — existing

The client sends `multipart/form-data`:

| Field | Value |
|---|---|
| `image` | Cervical image bytes, with inferred filename and MIME type |
| `patient_id` | Patient ID or `unassigned` |
| `examination_type` | `cervical` |

The client accepts common result and confidence keys from a JSON response. A legacy response does not provide verified model identity, model version, or readiness correlation. Existing CaCx behavior—including offline queueing and cloud second opinion—must continue to work during migration.

## 3. Proposed model identifiers

The app's typed identifiers map to these proposed wire values:

| Clinical workflow | Proposed model ID |
|---|---|
| CaCx examination | `cervical_cancer` |
| Obstetric Ultrasound examination | `ultrasound` |

George must confirm the canonical identifiers and model versions. “Normal Scan” and “AI-Guided Scan” are workflow choices, not separate models, unless device requirements establish otherwise.

## 4. Proposed API

Every path in this section is **proposed and unverified**. The app has an explicit build-time feature gate that defaults off:

```text
EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED=false
EDGE_DEVICE_BASE_URL=https://dawa.local
```

`EDGE_DEVICE_BASE_URL` is the shared URL. If it is empty, the app falls back to `CERVICAL_DEVICE_BASE_URL`, then `PI_DEVICE_BASE_URL`. All CaCx and Ultrasound model-management, health, and upload clients use this shared configuration.

The Ultrasound inference adapter has a proposed typed multipart contract, but its route is empty by default and guarded separately:

```text
EDGE_DEVICE_ULTRASOUND_INFERENCE_ENABLED=false
EDGE_DEVICE_ULTRASOUND_INFERENCE_PATH=
```

The localhost test uses `/test-only/ultrasound/infer`; that test path must not be used in a deployed build.

### 4.1 Device capabilities — proposed

```http
GET /v1/capabilities
```

Example response:

```json
{
  "device_id": "dawa-edge-001",
  "api_version": "1",
  "supported_models": ["cervical_cancer", "ultrasound"],
  "model_switching": true,
  "supported_image_formats": ["image/jpeg", "image/png"]
}
```

`supported_models` is required. Other fields may be omitted only if the client and device agree on a versioned schema. The device must not advertise a model that cannot be loaded and used on that hardware/software release.

### 4.2 Activate model — proposed

```http
POST /v1/models/activate
Content-Type: application/json
```

Request:

```json
{
  "model": "ultrasound",
  "request_id": "unique-client-request-id",
  "exam_id": "unique-examination-id"
}
```

The device validates the model allowlist and request authorization, then atomically admits or rejects the activation. It must not unload a model used by another active examination. Repeating the same `request_id` and `exam_id` must be idempotent.

The endpoint may return `loading` or `ready`. It must echo both correlation IDs even when loading begins:

```json
{
  "active_model": "ultrasound",
  "model_version": "1.0",
  "status": "loading",
  "device_id": "dawa-edge-001",
  "exam_id": "unique-examination-id",
  "request_id": "unique-client-request-id"
}
```

### 4.3 Model status — proposed

```http
GET /v1/models/status
```

Example:

```json
{
  "active_model": "ultrasound",
  "model_version": "1.0",
  "status": "ready",
  "device_id": "dawa-edge-001",
  "exam_id": "unique-examination-id",
  "request_id": "unique-client-request-id"
}
```

`ready` is authoritative only when the model ID, exam ID, and request ID match the activation being awaited. A generic `ready` for a different request must not unlock capture or inference.

Supported response states expected by the current client proposal:

| State | Meaning |
|---|---|
| `loading` | Model initialization is in progress; the client may poll status. |
| `ready` | The requested model is initialized and usable for the correlated examination. |
| `busy` | Another incompatible examination owns the device; no model switch occurred. |
| `unsupported` | The device does not support or has rejected the requested model. |
| `error` | Initialization failed; include a safe diagnostic message/code. |
| `completed` | The examination is terminal. A status response must echo the active model, exam ID, and request ID so an unresolved client can reconcile safely. |

### 4.4 Examination completion — proposed

The client needs an explicit terminal acknowledgement before releasing its local examination lock. Confirm or replace this candidate path:

```http
POST /v1/examinations/{exam_id}/complete
Content-Type: application/json
```

```json
{
  "exam_id": "unique-examination-id"
}
```

Example response:

```json
{
  "status": "completed",
  "active_model": "ultrasound",
  "device_id": "dawa-edge-001",
  "exam_id": "unique-examination-id",
  "request_id": "unique-client-request-id"
}
```

A client timeout or error must not be treated as completion. The current client requires matching model, exam ID, and activation request ID before releasing its local lock. The device should make repeated completion requests idempotent and define a separate safe cancellation/recovery operation.

### 4.5 Ultrasound inference — proposed adapter contract, endpoint unverified

The clinician app does not have a production Ultrasound endpoint configured. A typed multipart adapter is implemented behind both the model-management and separate Ultrasound-inference feature gates. Its endpoint path remains empty by default. Before enabling it, George must define:

- The production inference route and whether it is synchronous or job-based.
- How the `exam_id`, `request_id`, and active model are bound to each inference.
- Accepted still-image/frame or video formats, size limits, quality requirements, and MIME behavior.
- Structured result schema, model/device provenance, error states, and idempotency behavior.
- Whether a probe feed, EchoWave export, or clinician-selected image is supported.

The adapter sends `image`, `examination_type=ultrasound`, `model_id`, `exam_id`, and `request_id`. It accepts a synchronous `status=completed` response only when model/exam/request correlation matches and structured findings/provenance validate. Any difference in the deployed route or schema requires updating the typed adapter. The local mock schema is not device or clinical validation.

## 5. Lifecycle and concurrency rules

1. Opening a module, changing a tab, viewing patient records, or merely selecting a patient must not activate a model.
2. The clinician begins an explicit examination; the app generates an examination ID and activation request ID.
3. The app confirms device reachability, checks capabilities, requests activation, and waits for a correlated `ready` status.
4. The UI enables edge capture/inference only after readiness is confirmed.
5. Inference is bound to the active examination and selected model/version.
6. By default, assume one model/examination at a time per device. Do not assume both models fit in memory or can execute concurrently.
7. A conflicting activation must return `busy`/`409` without interrupting the active examination. The device—not only the Flutter UI—must enforce this.
8. The app must not repeat a timed-out activation blindly. It first queries status and reconciles by exam/request IDs. If status cannot be reconciled, remain in an error/unknown state and require a safe recovery action.
9. The app releases its active examination state only after the device confirms completion or a separately agreed safe cancellation/recovery flow.

The clinician manager provides an explicit `reconcileActiveExamination()` operation for an unresolved local session. It queries status using the original activation context, never sends another activation, restores readiness only for matching model/exam/request IDs, and clears the local lock only for a matching `completed` status. Any other response keeps the lock in place.

## 6. Authentication and authorization requirements

Authentication is **not confirmed** in the existing client/device protocol. Before enabling the proposed API:

- Define how the clinic app/device authenticate each other and how clinician authorization maps to an exam.
- Prefer short-lived, scoped credentials, a provisioned device identity, or an approved mutually authenticated gateway. Do not put long-lived service secrets in the Flutter bundle.
- Require TLS with a valid trusted certificate on all platforms. Do not disable certificate validation.
- Restrict browser CORS to approved app origins; handle preflight deliberately.
- Do not log raw images, patient identifiers, credentials, or full clinical payloads.
- Minimize data sent to the device. Use an opaque examination ID unless patient identity is explicitly required.
- Document device-side image/result retention and secure deletion behavior.
- Return safe error codes/messages without exposing secrets or internal stack traces.

The client currently classifies 401/403 as authorization failures but does not send a new model-management credential. The secure auth mechanism must be agreed before feature-gate enablement.

## 7. Backward compatibility

- Keep the legacy CaCx `GET /health` and `POST /upload/cervical` path operational.
- Old device builds must not be required to support `/v1/capabilities`, `/v1/models/activate`, `/v1/models/status`, or examination completion.
- A missing endpoint, timeout, malformed response, or unsupported version must not be interpreted as activation success.
- Preserve CaCx's current connectivity routing, offline result queue, Supabase persistence, and cloud second-opinion path.
- Do not claim that a legacy cervical upload confirms a requested model or readiness.
- Roll out device API and app changes using a tested compatibility/version negotiation plan.

## 8. Input and output requirements

### CaCx

The existing client sends a single multipart image with patient ID and `examination_type=cervical`. Confirm exact accepted image formats, image limits, preprocessing expectations, supported output keys, confidence units, and whether the device can bind this legacy request to an examination ID.

### Ultrasound

Supported acquisition is **unknown**. Current clinician-side camera/gallery still images are not verified probe frames. The EchoWave A flow is separate and its native bridge/save path is incomplete or unverified. Confirm probe hardware and integration, export format, frame metadata, image quality checks, and whether the model expects one frame or a series.

### Result provenance

For every accepted inference, return and persist at least:

- `device_id`, device/firmware version.
- `model`, immutable `model_version` (and preferably artifact hash).
- `exam_id`, inference/request ID.
- Server start/completion timestamps.
- Structured result, confidence semantics, quality warnings, and explicit error status.
- Whether the result was edge, cloud, or manually entered.

Do not return a success-shaped empty/default result when model inference did not complete.

## 9. Error behavior expected by the client

| HTTP / status | Suggested meaning | Client behavior |
|---|---|---|
| `400` | Invalid request or malformed ID | Show validation error; do not retry unchanged request. |
| `401` / `403` | Missing/invalid permission | Do not fall back silently; show authorization failure and audit safely. |
| `404` / `405` | API path/version unavailable | Keep model feature disabled; do not assume legacy readiness. |
| `409` / `423` | Device/model busy or conflicting exam | Preserve existing exam; do not switch or retry automatically. |
| `5xx` | Device/runtime failure | Reconcile status before any retry; preserve exam state as unknown if unresolved. |
| `loading` | Initialization pending | Poll status for the same request/exam within a bounded timeout. |
| `error` | Model failed to initialize/infer | Keep AI action disabled and offer only approved retry/manual workflow. |
| Network timeout | Outcome may be unknown | Query status once using the same IDs; do not issue a new activation ID automatically. |

## 10. Questions George must answer

1. Which edge API repository, release, hardware, and firmware are deployed?
2. Are `cervical_cancer` and `ultrasound` the canonical model IDs? What exact versions are supported?
3. What does `/health` mean on the device today, and what are its response semantics?
4. What is the existing implementation behind `/upload/cervical`? Does it load a model or require a preloaded model?
5. Are the proposed `/v1/*` paths acceptable, or does the device already expose equivalent operations?
6. What API version negotiation mechanism and error schema should be used?
7. Can both models stay loaded, or is a single active model required? What measured model-switch latency and hardware resource limits apply?
8. How does the device guard active inference/examination sessions against model changes across multiple clients?
9. What status fields can be echoed to correlate activation after a timeout/restart?
10. Is an explicit completion/cancel endpoint supported? How are abandoned sessions recovered?
11. What credentials and authorization scopes are supported? How are credentials issued, renewed, and revoked without embedding server secrets in the app?
12. What are exact CaCx and Ultrasound image formats, maximum sizes, preprocessing, and result schemas?
13. Which ultrasound probe/SDK/export path is supported? Are camera/gallery stills clinically valid inputs?
14. What are image/result retention, logging, audit, and secure deletion policies?
15. What TLS CA, `dawa.local` discovery, local-network permissions, and Flutter Web CORS setup are supported?
16. What acceptance dataset and clinical validation workflow are required before enabling model switching for clinical use?

## 11. Integration acceptance tests

Run these against the device implementation and a real target device before enabling the app feature flag:

1. `GET /health` reachability does not imply a model is ready.
2. Capabilities report only models actually installed and usable.
3. A CaCx activation returns ready for `cervical_cancer` with matching exam/request IDs.
4. An Ultrasound activation returns ready for `ultrasound` with matching exam/request IDs.
5. Unknown and unauthorized model IDs are rejected.
6. Loading, initialization failure, unsupported-model, and malformed response paths never enable inference.
7. Repeating the same activation request is idempotent; a second distinct examination/model is rejected while a session is active.
8. A timed-out activation followed by status reconciliation does not create a duplicate session or switch the model unexpectedly.
9. An active examination remains usable when another client requests a conflicting model.
10. Completion/cancellation releases the model lock only after a device-confirmed terminal state.
11. Disconnection, TLS failure, and browser CORS failure are distinguishable and do not produce success-shaped results.
12. CaCx legacy uploads continue working with old device builds.
13. Ultrasound inference accepts only confirmed acquisition formats and returns complete result provenance.
14. Device auth, logs, retention, and clinical-data handling meet the agreed clinic security requirements.

## 12. Current clinician-side implementation status

- **Implemented and locally tested:** Shared typed HTTP client/configuration, CaCx/Ultrasound model mapping, capability/status parsing, correlated activation/readiness, timeout reconciliation without activation replay, completion correlation, and active-examination conflict handling.
- **Implemented and locally tested:** CaCx keeps `GET /health` and multipart `POST /upload/cervical` behavior on the shared client.
- **Implemented behind separate default-off gates:** Typed Ultrasound multipart adapter and strict model/exam/request/result validation. The configured route remains blank; the mock server's `/test-only/ultrasound/infer` is not a production route.
- **Implemented:** Ultrasound Supabase patient/record repository and persistence migration; the migration is not known to be deployed.
- **Implemented:** Cloud analysis response provenance validation and unavailable/error results without fabricated findings.
- **Not hardware-validated:** Device switching, readiness, concurrency, inference, image compatibility, device authentication, and model quality.
- **Production blocker:** Existing `mother`, `first_encounter`, and `encounter` policies allow every authenticated user to access every row. Clinician-to-patient authorization must be defined and fixed before patient data access can be considered production-safe. See [George's edge-device handoff](./GEORGE_EDGE_DEVICE_HANDOFF.md).
- **Not enabled / awaiting confirmation:** Keep `EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED=false` and `EDGE_DEVICE_ULTRASOUND_INFERENCE_ENABLED=false` until the API/auth contract is accepted and tested against the physical device.
