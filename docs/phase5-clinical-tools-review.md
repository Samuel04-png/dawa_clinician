# Phase 5 clinical-tools review

Follow-up: the three failures below have now been repaired, with further mobile and workflow improvements. See [Phase 5 follow-up fixes](phase5-followup-fixes.md) for the current validation and screenshots.

Reviewed the Phase 5 implementation on 12 November 2026 and corrected the issues below. The review preserves the existing routes, patient associations, examination workspaces, inference contracts, saving services, and clinical interpretation rules. No additional device connection service or periodic polling was introduced. Older tablet/demo tests were updated to find the current controls rather than the removed dashboard headings.

## Findings and fixes

| Finding | Correction |
| --- | --- |
| CaCx and Ultrasound lost their persistent overview navigation when their nested sidebars were removed | Added compact Overview / Patient Records / History tabs around the existing destinations, including a return path from records and history |
| The new anemia tab bar could switch views while inference or saving was active | Disabled secondary navigation during either operation and exposed the disabled state to semantics; retained existing inference/review/save behavior |
| Ultrasound and Anemia started model preparation during child initialization, notifying the already-mounted global device control during a Flutter build | Deferred entry preparation until the first frame, with a mounted check; existing manager, model selection and examination locking are retained |
| BP's wide layout calculated panel widths before subtracting scroll padding | Corrected available-width calculation so entry and interpretation fit side by side on desktop |
| Clinical global AppBar sat above the sidebar, shifting its top relative to Home | Kept the sidebar full height and placed the contextual module bar above the bounded module content; retained mobile drawer and examination headers |
| CT's existing static sample repository and placeholder create action were presented as a functioning record-creation workflow | Explicit demonstration notice and sample-data badge; primary action opens the existing sample records. No new CT persistence or inference was invented |
| CaCx's new follow-up metric inferred a queue from result text; loading/failure could also look like a real zero | Follow-up tracking is explicitly unavailable; available-patient and loaded-screening counts reflect successful reads, with unknown values otherwise. Loaded-screening wording reflects the existing 100-record history limit |
| Narrow/large-text content exposed card heading and summary-pill overflows | Wrapped/bounded the affected CaCx and BP presentation; stacked shared intro controls for narrow/large text |
| Anemia showed both a History intro button and the same secondary tab | Kept the persistent tab navigation and removed the duplicated intro action |
| Tabs lacked a distinct keyboard-focus border and could shrink into a centered strip | Added visible focus treatment and consistent full-width tab surface, preserving horizontally scrollable tabs and reduced-motion durations |
| Existing DM Sans styles depended on runtime font fetching | Bundled the five used upright weights from the installed Google Fonts package's exact metadata, verified their SHA-256 hashes and sizes, and included their OFL license. The existing font asset directory declaration loads them without changing font families |

## Changed files for this review

- `lib/components/clinical_navigation_shell.dart`
- `lib/components/clinical_page_intro.dart`
- `lib/components/clinical_tab_bar.dart`
- `lib/application/cacx/cacx_widget.dart`
- `lib/application/ultrasound/screens/ultrasound_app.dart`
- `lib/application/hemonix/screens/hemonix_app.dart`
- `lib/application/bp_monitor/bp_monitor_widget.dart`
- `lib/application/shared/clinical_tools/clinical_tool_dashboard.dart`
- `lib/application/ct_scan/widgets/ct_scan_module_shell.dart`
- `assets/fonts/DMSans-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf` and `DMSans-OFL.txt`
- `test/clinical_phase5_review_test.dart`, `test/anemia_workflow_test.dart`, `test/quick_access_pages_test.dart`, `test/ui_responsive_layout_test.dart`, `test/demo_capture_proof_test.dart`
- `docs/qa/phase5/*.png` and this report

The worktree also contains earlier phases and the user's existing changes. This list describes this review rather than every uncommitted file in the repository.

## Verification

The added review file contains 27 checks: 20 actual module/shared-shell combinations across expanded desktop (1440×1000), collapsed desktop, mobile (390×844), and narrow 200% text (320×900); return navigation; CT disclosure/action; BP panel geometry and actual reading entry/session history; mobile drawer open/close; and disabled-tab semantics. A separate anemia regression holds inference pending and verifies navigation cannot leave the active workflow, then verifies it unlocks after completion.

Captured and inspected all five module families. Screenshots use mock hub transport, empty authorized-repository fixtures for Ultrasound/Anemia, and explicitly marked built-in demonstration data for CaCx/CT. Connection/readiness values in screenshots are fixture inputs. Real DM Sans, bundled Poppins navigation fonts, and actual icon fonts are loaded for rendering. No clinical images or patient records were transmitted for these checks.

| Tool | Desktop | Collapsed | Mobile | 200% text |
| --- | --- | --- | --- | --- |
| Cervical Cancer | [image](qa/phase5/cacx-desktop.png) | [image](qa/phase5/cacx-collapsed.png) | [image](qa/phase5/cacx-mobile.png) | [image](qa/phase5/cacx-large-text.png) |
| Ultrasound | [image](qa/phase5/ultrasound-desktop.png) | [image](qa/phase5/ultrasound-collapsed.png) | [image](qa/phase5/ultrasound-mobile.png) | [image](qa/phase5/ultrasound-large-text.png) |
| Anemia | [image](qa/phase5/anemia-desktop.png) | [image](qa/phase5/anemia-collapsed.png) | [image](qa/phase5/anemia-mobile.png) | [image](qa/phase5/anemia-large-text.png) |
| CT Scan | [image](qa/phase5/ct-desktop.png) | [image](qa/phase5/ct-collapsed.png) | [image](qa/phase5/ct-mobile.png) | [image](qa/phase5/ct-large-text.png) |
| BP Monitor | [image](qa/phase5/bp-desktop.png) | [image](qa/phase5/bp-collapsed.png) | [image](qa/phase5/bp-mobile.png) | [image](qa/phase5/bp-large-text.png) |

At narrow widths tabs scroll horizontally, secondary text may use existing ellipsis, and longer workspaces scroll vertically. Global page titles retain their full semantic labels when visually truncated. The prototype caution remains readable in the anemia scroll content.

Validation completed:

- `flutter analyze --no-pub`: no issues.
- `flutter build web --no-pub --release`: passed; Wasm dry run succeeded.
- New review tests plus anemia workflow tests: 41 passed. The subsequent expanded review file passed all 27 checks, including drawer and BP entry checks.
- Existing tablet/Care Tools checks: both passed after updating obsolete heading assertions.
- All 20 fixed-viewport screenshots generated and inspected; no layout exceptions in the tested combinations.
- Final `flutter test --no-pub --concurrency=1`: **283 passed, 4 skipped, 3 existing failures**. Four opt-in physical-device/live-anemia tests are skipped by default.

The remaining failures are the two `dawa_platform_sync_architecture_test.dart` assertions against the existing placeholder migration (`202607170001_add_dawa_platform_sync.sql`) and the missing baseline `demo_assets/raw/dawa_clinician/patients/patient_registry_training_fixture.png` in `demo_capture_proof_test.dart`. The demo's obsolete navigation label was corrected, exposing its existing missing-baseline failure. Production sync SQL and the absent baseline were not invented to make these tests pass.

## Compatibility and limits

Existing `/cervical-cancer`, `/ultrasound`, `/hemonix`, `/ct-scan`, `/bp-monitor`, and `/care-tools` destinations remain. Module records/results/history/search views retain their existing controllers. Legacy internal profile implementations remain in source; global account navigation provides the clinician profile. Existing contextual examination headers are preserved.

CT remains a demonstration workspace with static records and no connected create/save backend. BP interpretations remain session-local. CaCx follow-up tracking has no persisted queue. These are existing functionality limits surfaced by the review, so Phase 5 should not be described as making all five modules production-complete.

Physical-device model loading/inference, real image acquisition on hardware, actual screen-reader use, and live clinical saves were not exercised in this review. Mocked workflow tests establish UI/service integration behavior, not model accuracy or clinical validity. The Phase 4 report documents the separate signed-in registry and rolled-back live appointment database checks, including its deployed additive concurrency-guard migration.

The original GitHub backup branch remains intact; these changes remain local.
