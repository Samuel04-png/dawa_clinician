# Known Issues

| Severity | Issue | Evidence | Status / Recommendation |
| --- | --- | --- | --- |
| Critical | Core table RLS policies are broad for authenticated users. | `supabase/migrations/20260507111000_clinician_supabase_schema.sql` uses `using (true)` and `with check (true)`. | Tighten policies by clinic, role, and ownership before production. |
| High | Supabase Storage buckets for CaCx images are not confirmed. | `cacx_screening_results` has image fields, but no storage migration was found. | Add private bucket migration and signed URL flow if images should be stored. |
| High | External CaCx online AI endpoint is hardcoded in client code. | `lib/application/cacx/cacx_widget.dart` points to a Hugging Face Space. | Move production AI calls behind an Edge Function with audit and versioning. |
| High | Physical Arduino/Raspberry Pi implementation is not in this repo. | Flutter expects `/health` and `/upload/cervical`; no device server code is present. | Confirm Flask/device service contract and add integration tests. |
| High | Offline mode is not a full sync engine. | Cache and queue code exists, but broad write sync/conflict handling is not implemented. | Add durable encrypted sync queue and conflict rules. |
| Medium | Legacy Firebase naming can confuse developers. | Auth and database wrappers still use Firebase class names. | Keep compatibility but document clearly, or rename gradually when safe. |
| Medium | Migrated Firebase users may need password reset. | Migration notes explain Firebase SCRYPT hashes are not native Supabase bcrypt hashes. | Communicate password reset flow to users. |
| Medium | HemoNix and CT Scan are quick-access/mock dashboards. | Confirmed `_QuickAccessRecord` mock data. | Add real schemas, persistence, and workflows before production claims. |
| Medium | Ultrasound scan records are mostly local/mock state. | `UltrasoundScanRecord` history is in app state/mock data. | Persist scans to Supabase and link to patient/encounter. |
| Medium | BP Monitor readings are session-local. | `_readings` list is local in `BpMonitorApp`. | Add patient-linked Supabase persistence. |
| Medium | Role enforcement is not fully confirmed. | `role` field and admin PIN exist, but strong policy/routing enforcement was not confirmed. | Implement role-aware routing and RLS. |
| Medium | Existing hardware map doc is stale in one area. | `docs/hardware-integration-map.md` says CaCx structured persistence is missing. | Update or archive that older note after this GitBook is reviewed. |
| Low | Real screenshots are missing. | No committed UI screenshots were found. | Capture app screenshots and add them to `docs/assets/screenshots`. |
| Low | Generated legacy screens are large and hard to review. | `mom_details`, `mom_details2`, `encounter`, and `edit_encounter` are large and analyzer-excluded. | Add targeted tests and avoid casual edits. |
| Low | Typos exist in some user-facing strings. | Example: "Kinldy" in create patient flow. | Clean text in a later UI polish pass. |
