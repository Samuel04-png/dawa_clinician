# Phase 5 follow-up fixes

This follow-up addresses the three failures documented in the original Phase 5 review and improves the clinical-tool views. Home dashboard cards, examination services, model contracts, patient identifiers, and BP interpretation thresholds are preserved.

## Repaired failures

**Sync migration:** restored `supabase/migrations/202607170001_add_dawa_platform_sync.sql` byte-for-byte from commit `f81f886`. Commit `7b33a9b` had replaced that 1,311-line source with `add_dawa_platform_sync;`. The restored source has SHA-256 `90b70730ba14e8fbd144b0e598ded255b1c6e36c7f8d174bae00bce11b51aba2`, also matching commit `6e43040`. All nine architecture tests pass with the restored assertions unchanged. This is a source recovery; the historical migration was not rerun against the live database, and no new production SQL was applied in this follow-up.

**Screenshot baseline:** repaired `test/demo_capture_proof_test.dart` with explicit mock hub transport, mocked app-link channels, bundled font loading, and the application's blue theme. Added and visually reviewed its missing synthetic training-patient baseline at `demo_assets/raw/dawa_clinician/patients/patient_registry_training_fixture.png`. The normal test compares against this baseline; golden generation is only used deliberately when updating screenshots. No real patient data or physical-device calls are used by the fixture.

## UI and behavior improvements

- **CaCx:** patient headers, filters, and rows use a single lazy scroll. Results controls scroll with their records, so large text cannot consume the entire viewport. Patient identity/status rows fit narrow widths. Search text stays visible after switching tabs, and Clear filters updates both the query and the field. Intro margins align with the cards. Unknown class breakdowns say Unavailable; their headings wrap cleanly.
- **CT:** Records now actually filters its rows. Opening a sample record uses its stable patient identifier. Clearing search or reopening the full sample list restores all rows. Results and search share a single lazy scroll; on short viewports the intro also joins the scroll, keeping search usable with a mobile keyboard. Sample actions explicitly review sample records/results and no longer imply a patient chart or follow-up was saved. Follow-up tracking stays unknown rather than equating flagged results with scheduled follow-ups.
- **BP:** manual entry and session-only history are explicit. Each interpreted entry records a local timestamp and retains its full notes. Optional ages must parse as positive whole years when provided. Pressure units remain visible while typing, and Clear form retains session history. Existing pressure validation and interpretation calculations are unchanged.
- **Ultrasound / Anemia:** returning to patient selection retains the visible search query. Ultrasound's intro aligns with the rest of its content.
- **Shared status badges:** labels wrap and their width responds to text scale, preserving the full status instead of ellipsis. Ordinary badges shrink to their contents.

No CT storage schema, replacement connection service, local patient-data persistence, new clinical scoring rules, or new polling loop was introduced.

## Changed files

| Files | Purpose |
| --- | --- |
| `supabase/migrations/202607170001_add_dawa_platform_sync.sql` | Exact recovery of original migration source |
| `test/demo_capture_proof_test.dart` and its baseline PNG | Deterministic, passing visual regression fixture |
| `lib/application/cacx/cacx_widget.dart` | Responsive records/results, synchronized patient search, margins and missing-breakdown presentation |
| `lib/application/shared/clinical_tools/clinical_tool_dashboard.dart` | CT filtering, honest sample actions and responsive scrolling |
| `lib/application/shared/clinical_tools/clinical_tool_controller.dart` | Stable patient-ID filtering |
| `lib/application/bp_monitor/bp_monitor_widget.dart` | Session provenance, entry validation and timestamps |
| `lib/application/ultrasound/screens/ultrasound_app.dart` | Retained visible search and intro alignment |
| `lib/application/hemonix/screens/hemonix_app.dart` | Retained visible patient search |
| `lib/components/dawa_design_system.dart` | Readable, compact status badges |
| `test/clinical_phase5_review_test.dart` | Expanded secondary-view, scroll, keyboard, search and BP regression coverage |
| `docs/qa/phase5/*.png` | Updated module screenshots plus narrow secondary views and keyboard fixture |
| `docs/phase5-clinical-tools-review.md` | Link from original review to this follow-up |

## Verification

The expanded review file covers 41 cases, including all five module overview screens at four sidebar/viewport combinations, secondary views at 320px with normal and 200% text, scrolling to real rendered result cards, a 300px mobile keyboard inset, patient-search return/reset, stable sample record filtering, and BP entry provenance/validation. The review plus demo baseline run passes all 42 tests. The broader focused clinical run passed 78 tests before the final badge refinement.

Updated screenshots are fixtures using synthetic/demo records and mocked device transport. They establish rendering and interaction behavior, not physical-device inference or live clinical persistence. Reviewed [CaCx patient registry at 200%](qa/phase5/cacx-view-1-scale-2.0.png), [CaCx history at 200%](qa/phase5/cacx-view-2-scale-2.0.png), [CT results at 200%](qa/phase5/ct-view-2-scale-2.0.png), [CT mobile keyboard](qa/phase5/ct-mobile-keyboard.png), [CT desktop](qa/phase5/ct-desktop.png), and [BP desktop](qa/phase5/bp-desktop.png), alongside the refreshed module overview set.

Final validation:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --concurrency=4` on the final source: **300 passed, 4 opt-in live tests skipped, zero failures**.
- Release web build: passed, including the Wasm dry run.
- After the final responsive patient-row adjustment, the complete 42-case review/baseline run passed again. The local web preview recompiled successfully at the existing localhost origin.
- `git diff --check`: clean.

The four skipped tests require physical-device or authenticated live-anemia opt-in configuration. They were not replaced with mock success claims.

## Remaining boundaries

CT is still backed by the existing sample repository; production CT creation/saving requires a defined clinical storage/workflow integration. BP history remains scoped to the current page. Physical-device inference, real screen-reader operation and live clinical saves were not exercised. Existing clinical URLs and legacy routes remain unchanged. The original GitHub backup branch is preserved, and all follow-up changes remain local.
