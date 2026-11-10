# Environment Variables

This project uses a mix of Flutter dart defines, Supabase Function secrets, and local migration tool environment variables.

Do not commit real secrets. The values below are placeholders.

## Flutter Dart Defines

For `tool/run_web_dev.sh`, `EDGE_DEVICE_IP` selects the device host (default
`dawa.local`), and `EDGE_DEVICE_HUB_PORT_REMOTE` selects the device's hub port
(default `80`; set `8080` if the hub is started on that port).
`EDGE_PROXY_HUB_PORT`, `EDGE_PROXY_CERVICAL_PORT`, and
`EDGE_PROXY_ULTRASOUND_PORT` change only the local proxy listening ports.
The proxy accepts requests only from the configured browser origin; curl
requests to the proxy need an `Origin` header.

| Variable | Purpose | Default In Code | Notes |
| --- | --- | --- | --- |
| `SUPABASE_URL` | Supabase project URL used by the Flutter app. | Yes | Use a placeholder in docs and CI examples. |
| `SUPABASE_ANON_KEY` | Public anon/publishable key for the Flutter app. | Yes | Public anon keys still need RLS to be safe. |
| `EDGE_DEVICE_BASE_URL` | Shared edge-device API base URL for CaCx and Ultrasound. | Empty | Preferred when set; otherwise `CERVICAL_DEVICE_BASE_URL`, then `PI_DEVICE_BASE_URL`. |
| `CERVICAL_DEVICE_BASE_URL` | Legacy edge-device base URL fallback. | Empty | Used only when `EDGE_DEVICE_BASE_URL` is empty. |
| `PI_DEVICE_BASE_URL` | Legacy shared device/Pi URL fallback. | `http://dawa.local` | Used only when the shared and cervical URLs are empty. |
| `EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED` | Enables hub `POST /api/select` + `GET /api/status`, module health checks and CaCx `/predict`. | `false` | Keep disabled until hardware integration is verified. Flag off = legacy `/upload/cervical` only. |
| `EDGE_DEVICE_ULTRASOUND_INFERENCE_ENABLED` | Enables ultrasound `POST /predict` on port 8086. | `false` | Requires model management enabled. Research-stage model; see handoff. |
| `EDGE_DEVICE_API_VERSION` | Optional `X-API-Version` header for the shared device API. | Empty | George must confirm version negotiation and supported value. |
| `EDGE_DEVICE_HEALTH_PATH` | Shared health route. | `/health` | Client route only; health means reachability, not model readiness. |
| `EDGE_DEVICE_CERVICAL_UPLOAD_PATH` | Legacy CaCx multipart upload route. | `/upload/cervical` | Preserve compatibility with deployed legacy devices. |
| `EDGE_DEVICE_CERVICAL_MODEL_ID` | Hub module id for CaCx. | `cervitriage` | From `dawa/dawa.yaml`. |
| `EDGE_DEVICE_ULTRASOUND_MODEL_ID` | Hub module id for ultrasound. | `ultrasound` | From `dawa/dawa.yaml`. |
| `EDGE_DEVICE_REQUEST_TIMEOUT_SECONDS` | Timeout for shared device health/status requests. | Falls back to `CERVICAL_HEALTH_TIMEOUT_SECONDS` (`5`) | Shared setting for both workflows. |
| `EDGE_DEVICE_UPLOAD_TIMEOUT_SECONDS` | Timeout for shared device image uploads. | Falls back to `CERVICAL_IMAGE_TIMEOUT_SECONDS` (`120`) | Shared setting for both workflows. |
| `EDGE_DEVICE_MODEL_REQUEST_TIMEOUT_SECONDS` | Timeout for activation requests. | `30` | Tune to confirmed device behavior. |
| `EDGE_DEVICE_MODEL_READY_TIMEOUT_SECONDS` | Process-switch timeout (hub `ready_timeout_s` is 300). | `300` | Total wait for hub `ready` plus affirmative module health. |
| `EDGE_DEVICE_MODEL_POLL_INTERVAL_MILLISECONDS` | Delay between model status polls. | `1000` | Tune to confirmed device behavior. |
| `EDGE_DEVICE_HUB_PORT` / `EDGE_DEVICE_CERVICAL_PORT` / `EDGE_DEVICE_ULTRASOUND_PORT` | Hub and module ports replacing the port in the base URL. | `80` / `8085` / `8086` | From device configs. `EDGE_DEVICE_BASE_URL` must be plain `http://<host>`. |
| `EDGE_DEVICE_HUB_SELECT_PATH` / `EDGE_DEVICE_HUB_STATUS_PATH` | Hub routes. | `/api/select` / `/api/status` | Confirmed in `dawa/main.py`. |
| `EDGE_DEVICE_MODULE_HEALTH_PATH` / `EDGE_DEVICE_PREDICT_PATH` | Module routes. | `/health` / `/predict` | Confirmed in module sources. |
| `EDGE_DEVICE_CERVICAL_HEALTH_READY_FIELD` / `EDGE_DEVICE_ULTRASOUND_HEALTH_READY_FIELD` | Boolean field in module `/health` that must be `true`. | `ready` / `ready` | Readiness must include model warm-up, not just model loading. |
| `EDGE_DEVICE_SUPPORTED_IMAGE_MIME_TYPES` | Accepted image MIME types. | `image/jpeg,image/png` | Confirm against device decoders. |
| `EDGE_DEVICE_MODULE_HEALTH_GRACE_SECONDS` | Legacy configuration retained for compatibility. | `10` | Readiness now waits up to the model-ready timeout instead. |
| `CERVICAL_IMAGE_TIMEOUT_SECONDS` | Timeout for cervical image upload/response. | `120` | Used by device upload flow. |
| `CERVICAL_HEALTH_TIMEOUT_SECONDS` | Timeout for device health checks. | `5` | Used by device and offline reachability checks. |
| `CERVICAL_DEVICE_RETRY_INTERVAL_SECONDS` | Retry interval for device wait UI. | `5` | Currently confirmed as a config constant and tested default. |

Example:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
PI_DEVICE_BASE_URL=http://dawa.local
EDGE_DEVICE_BASE_URL=http://dawa.local
EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED=false
EDGE_DEVICE_ULTRASOUND_INFERENCE_ENABLED=false
CERVICAL_IMAGE_TIMEOUT_SECONDS=120
CERVICAL_HEALTH_TIMEOUT_SECONDS=5
CERVICAL_DEVICE_RETRY_INTERVAL_SECONDS=5
```

## Supabase Edge Function Secrets

| Variable | Used By | Purpose |
| --- | --- | --- |
| `SUPABASE_URL` | `delete-user` | Supabase project URL for function runtime. |
| `SUPABASE_ANON_KEY` | `delete-user` | User-scoped client creation. |
| `SUPABASE_SERVICE_ROLE_KEY` | `delete-user` | Admin delete operation. Must never be in Flutter code. |
| `SMS_API_TOKEN` | `send-sms` | SMS provider token. |
| `GEMINI_API_KEY` | `gemini`, `analyze-ultrasound-image` | Gemini model access. |
| `GEMINI_MODEL` | `gemini`, `analyze-ultrasound-image` | Optional model override. |
| `GEMINI_ULTRASOUND_MODEL` | `analyze-ultrasound-image` | Optional ultrasound-specific Gemini model override. |
| `HUGGINGFACE_API_TOKEN` | `analyze-via-image` | Hugging Face inference token. |
| `HUGGINGFACE_VIA_MODEL` | `analyze-via-image` | VIA/CaCx model identifier. |

## Migration Tool Variables

Confirmed from `tools/firebase_to_supabase/.env.example` and migration scripts:

```env
FIREBASE_PROJECT_ID=your_firebase_project_id
GOOGLE_APPLICATION_CREDENTIALS=./firebase-service.json
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
SUPABASE_DB_URL=your_supabase_database_url
FIREBASE_AUTH_EXPORT=../../migration_exports/firebase_auth_users.json
```

## Security Notes

- The Flutter app can use a public anon key, but only if RLS policies are strict enough.
- Service role keys belong only in local tools or Supabase Function secrets.
- Firebase service account JSON should stay local.
- Migration exports should stay local because they can contain user identity data and password hash material.
- This documentation intentionally avoids copying real keys from source files.
