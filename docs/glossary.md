# Glossary

| Term | Meaning |
| --- | --- |
| Dawa Clinician | The clinician-facing Flutter app for patient management, screening workflows, AI/device-assisted analysis, and clinical decision support. |
| CaCx | Cervical cancer screening workflow, including VIA image capture/analysis and result handling. |
| VIA | Visual inspection with acetic acid, a cervical cancer screening method. |
| Supabase | Backend platform used here for Auth, Postgres database, Edge Functions, and future Storage needs. |
| Firebase | Legacy/source backend pattern used by the original FlutterFlow app and migration source. |
| Firestore compatibility layer | The Supabase-backed Dart facade that lets generated Firestore-style calls keep working. |
| RLS | Row Level Security, Supabase/Postgres policies controlling which rows each user can access. |
| Edge Function | Supabase server-side function used for privileged operations or backend integrations. |
| MedSigLip | Model/backbone referenced in CaCx model comments for cervical image classification. |
| Gradio | Web/API interface used by Hugging Face Spaces. The CaCx online path calls Gradio-style endpoints. |
| Hugging Face Space | Hosted AI demo/API endpoint used by the CaCx online second-opinion path. |
| Arduino/device service | Local device API expected to expose `/health` and `/upload/cervical` for CaCx image interpretation. |
| Raspberry Pi | Local gateway/device host referenced by the app's default device URL. |
| Screening | A clinical workflow that captures patient data, test input, analysis, and follow-up result. |
| Clinical recommendation | The guidance text shown after AI/device analysis. It must be clinically reviewed. |
| Offline mode | Cached-user and cached-data behavior that helps the app work when Supabase is unreachable. |
| Pending queue | Local storage for CaCx result payloads that failed to save to Supabase immediately. |
| HemoNix | Quick-access hemoglobin/anemia workflow shell. Real persistence still needs work. |
| CT Scan | Quick-access imaging workflow shell. Real radiology workflow still needs work. |
| BP Monitor | Local blood pressure interpretation tool. |
| EchoWave A | Ultrasound-related native/media handoff workflow referenced by the scan record page and service. |
