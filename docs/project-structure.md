# Project Structure

The repository is a Flutter project generated from FlutterFlow patterns, then extended with Supabase, AI, offline, device, and care-tool work.

```text
.
|-- android/
|-- ios/
|-- web/
|-- assets/
|   |-- fonts/
|   |-- images/
|   |-- videos/
|   `-- Video_Not_a_GIF.mp4
|-- lib/
|   |-- application/
|   |   |-- bp_monitor/
|   |   |-- cacx/
|   |   |-- care_tools/
|   |   |-- create_mom/
|   |   |-- home/
|   |   |-- mom_details/
|   |   |-- mom_details2/
|   |   |-- moms/
|   |   |-- patient_details/
|   |   `-- ultrasound/
|   |-- auth/
|   |-- backend/
|   |   |-- api_requests/
|   |   |-- firebase/
|   |   |-- gemini/
|   |   |-- schema/
|   |   `-- supabase/
|   |-- components/
|   |-- flutter_flow/
|   |-- services/
|   |-- app_state.dart
|   `-- main.dart
|-- supabase/
|   |-- functions/
|   |-- migrations/
|   `-- FIREBASE_TO_SUPABASE_MIGRATION.md
|-- firebase/
|-- tools/
|   `-- firebase_to_supabase/
|-- test/
|-- docs/
|-- pubspec.yaml
`-- README.md
```

## Important Folders

| Path | Purpose |
| --- | --- |
| `lib/application/home` | Main clinician dashboard, recent patients, scheduled activity, and care-tool launch cards. |
| `lib/application/moms` | Patient list with search/filter UI and pagination patterns. |
| `lib/application/patient_details` | Newer patient details screen that loads CaCx screening history from Supabase. |
| `lib/application/mom_details` and `lib/application/mom_details2` | Legacy maternal record, pregnancy history, parity, and encounter flows. |
| `lib/application/cacx` | CaCx dashboard, image selection, device upload, Gradio/Hugging Face logic, result UI, quick-access dashboards, and CaCx persistence service. |
| `lib/application/ultrasound` | Ultrasound dashboard, scan modes, image picker, AI service, EchoWave bridge work, mock data, and scan result UI. |
| `lib/application/bp_monitor` | BP Monitor interpretation screen. |
| `lib/backend/supabase` | Supabase config, request wrapper, Firestore compatibility facade, and offline cache. |
| `lib/services` | Offline auth and connectivity services. |
| `lib/auth/firebase_auth` | Legacy Firebase-named auth wrappers that now call Supabase Auth. |
| `lib/backend/schema` | FlutterFlow-style record classes for app tables. |
| `supabase/migrations` | SQL migrations for core schema, Firebase UID support, and CaCx results. |
| `supabase/functions` | Edge Functions for SMS, Gemini, VIA image analysis, ultrasound image analysis, and user deletion. |
| `tools/firebase_to_supabase` | Node.js migration and verification tools for Firebase Auth and Firestore data. |
| `test` | Widget and unit tests for smoke, UI responsiveness, quick-access modules, and CaCx parsing/routing. |

## Firebase Remnants

The `firebase/` folder and `lib/backend/firebase` still exist, and many generated classes still use names like `FirebaseFirestore` and `FirebaseAuthManager`. In the current code, those names mostly act as compatibility names. The app-side data calls are routed through Supabase.
