# Environment Variables

This project uses a mix of Flutter dart defines, Supabase Function secrets, and local migration tool environment variables.

Do not commit real secrets. The values below are placeholders.

## Flutter Dart Defines

| Variable | Purpose | Default In Code | Notes |
| --- | --- | --- | --- |
| `SUPABASE_URL` | Supabase project URL used by the Flutter app. | Yes | Use a placeholder in docs and CI examples. |
| `SUPABASE_ANON_KEY` | Public anon/publishable key for the Flutter app. | Yes | Public anon keys still need RLS to be safe. |
| `PI_DEVICE_BASE_URL` | Shared local device/Pi API base URL. | `http://DAWA.local:8084` | Used by CaCx unless the cervical-specific URL is provided. |
| `CERVICAL_DEVICE_BASE_URL` | CaCx-specific device API base URL. | Empty | Overrides `PI_DEVICE_BASE_URL` for CaCx. |
| `CERVICAL_IMAGE_TIMEOUT_SECONDS` | Timeout for cervical image upload/response. | `120` | Used by device upload flow. |
| `CERVICAL_HEALTH_TIMEOUT_SECONDS` | Timeout for device health checks. | `5` | Used by device and offline reachability checks. |
| `CERVICAL_DEVICE_RETRY_INTERVAL_SECONDS` | Retry interval for device wait UI. | `5` | Currently confirmed as a config constant and tested default. |

Example:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
PI_DEVICE_BASE_URL=http://device-ip-or-host:8084
CERVICAL_DEVICE_BASE_URL=http://device-ip-or-host:8084
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
