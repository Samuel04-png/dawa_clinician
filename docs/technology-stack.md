# Technology Stack

| Area | Technology | Confirmed Files | Notes |
| --- | --- | --- | --- |
| App framework | Flutter | `pubspec.yaml`, `lib/main.dart` | FlutterFlow-style project using Material UI. |
| Language | Dart | `lib/**.dart` | Main application language. |
| Routing | `go_router` | `pubspec.yaml`, `lib/flutter_flow/nav/nav.dart` | Auth-aware route configuration. |
| State | `provider`, FlutterFlow app state | `pubspec.yaml`, `lib/app_state.dart` | App state is initialized before `runApp`. |
| Backend client | `supabase_flutter` | `pubspec.yaml`, `lib/backend/supabase/supabase_config.dart` | Used for Auth, PostgREST, and Edge Functions. |
| Database | Supabase Postgres | `supabase/migrations/*.sql` | Core tables plus `cacx_screening_results`. |
| Auth | Supabase Auth | `lib/auth/firebase_auth/*.dart` | Firebase names remain, but active calls go through Supabase. |
| Legacy backend | Firebase remnants | `firebase/`, `lib/backend/firebase` | Retained for migration/history and generated compatibility. |
| Migration tools | Node.js, Firebase Admin, Supabase JS, pg | `tools/firebase_to_supabase/package.json` | Used for auth/data migration and verification. |
| Local cache | `shared_preferences` | `lib/services/offline_auth_cache.dart`, `lib/backend/supabase/supabase_offline_cache.dart` | Stores cached auth identity and Supabase row snapshots. |
| Local database package | `sqflite` | `pubspec.yaml` | Present as dependency, but the confirmed offline cache currently uses shared preferences. |
| HTTP | `http`, `http_parser` | `pubspec.yaml`, CaCx services | Used for device, Gradio, and reachability calls. |
| Image input | `image_picker` | `pubspec.yaml`, CaCx and ultrasound services | Camera/gallery image selection. |
| AI | Hugging Face/Gradio, Gemini | `lib/application/cacx`, `supabase/functions/*` | CaCx second opinion and ultrasound image review. |
| Device API | Raspberry Pi/Arduino-style HTTP service | `lib/application/cacx/cacx_upload_service.dart`, `docs/pi_device_integration.md` | Local LAN HTTP contract. |
| Testing | `flutter_test` | `test/*.dart` | Smoke, responsive, quick-access, and CaCx tests. |
| Web deployment | Flutter web, GitHub Pages history | `web/`, git commits | Commits show prior web build and GitHub Pages setup. |
