# UI architecture and navigation

Maintained source map, consolidated from the superseded sidebar, Phase 1B,
Home and patient-registry implementation reports on 14 November 2026.
Historical test totals in those reports are superseded by the measured
[quality report](quality/phase13-report.md). This document describes the source;
it does not establish clinical validation or deployed authorization behavior.

## Shared shell

`lib/components/navigation_design_system.dart` defines shell tokens and outline
icons. `clinical_navigation_shell.dart` and `workspace_shell.dart` compose the
shared navigation. The expanded sidebar is 256px, the rail 64px; below 1024px
navigation uses a drawer. Default navigation rows are 44px (48px in the drawer)
and grow with text scale. Active selection follows the committed URL. Disclosure
and collapse preferences are session notifiers in `clinician_navigation.dart`.
The official cross asset is retained without recoloring or distortion.

The shell inherits DM Sans from the application theme. Navigation focus is a
visible navy outline; selected text and surfaces use the existing blue tokens.
The finite device pulse and transitions respect reduced motion. Icon-only
navigation has labels/tooltips. `clinician_account_menu.dart` supplies profile,
account information and sign-out without repeating the email in navigation.

`edge_device_indicator.dart` reuses `EdgeDeviceManager` and its configured client
(default `http://dawa.local`). Hub connectivity and model readiness are separate
observations. Details expose active model, readiness, last successful check,
retry and diagnostics. Automatic observations are throttled and coalesced;
checks defer during model preparation and active examinations. An observation
and its timestamp are not a continuously monitored connectivity guarantee.
See [device contract](edge-device-model-switching-contract.md) for the actual
protocol and examination-lock rules.

Existing named routes remain in `lib/flutter_flow/nav/nav.dart`, including
`/home`, `/moms`, `/scheduledEncounters`, `/care-tools`, `/cervical-cancer`,
`/ultrasound`, `/hemonix`, `/ct-scan`, `/bp-monitor`, `/profile` and `/editProfile`.
Legacy maternal and encounter routes remain supported. Settings and Profile use
the existing account screen. The Anemia label retains the HemoNix route.
CT is disabled in release by `ClinicalFeatures.ctScan`: its development records
do not establish production persistence. BP readings remain session-local.
Do not delete legacy views solely because the sidebar has a newer entry point.

## Home

`application/home/home_dashboard_header.dart` owns the greeting, local date and
compact global controls. `home_widget.dart` orchestrates refresh and navigation;
`home/widgets/home_dashboard_content.dart` supplies metrics, tasks and rows.
`home/data/home_dashboard_repository.dart` loads authenticated paginated records
and appointments and derives the displayed metrics.

Patient totals use unique visible mother IDs and exclude source-deleted records.
Today's schedule combines scheduled encounters and active imported appointments,
sorted by local start time. Failure of either source makes the combined metric
unavailable. No cross-tool review queue exists; an unavailable queue must not
be presented as zero. Activity dates come from actual timestamps, with stable
ID tie-breaking, rather than invented dates. Local device/browser time is used;
there is no clinic timezone configuration in this flow.

Registration completion requires name, valid birth date and phone; optional
fields do not create warnings. Registration opens the existing modal. The
examination selector uses existing tool routes without starting inference.
Booking and the monthly calendar use `scheduled_encounters/` dialogs. Calendar
and appointment query parameters preserve existing Appointments context.

## Patient registry

`application/moms/moms_widget.dart` reuses the workspace shell and header with a
single registration action. Search and filters operate on the full paginated
authorized snapshot before rendering rows. `patient_registry_filters.dart`
keeps completeness and first-encounter linkage distinct. Duplicate names remain
distinct by stable ID. Unknown age/activity stays unknown. Search includes name,
identifiers, phone, NRC, address, occupation and imported source references.

The shared Home repository handles source tombstones, authenticated reads,
account-change guards and explicit permission/error states. A batched first-
encounter lookup preserves legacy back-references. Registration, refresh and
returning from details reload data. Account changes clear visible records and
search; generation checks discard stale responses.

The checked-in mother policy grants broad authenticated access. Respecting
server RLS does not establish deployed organization isolation. `mother.user_Id`
identifies the patient's account and must not be reinterpreted as clinician
ownership. Live organization-boundary verification remains a release concern.

## Visual fixtures and verification boundaries

Keep `docs/qa/phase1b`, `docs/qa/sidebar-interaction`, `docs/qa/phase2`, and
`docs/qa/phase3` while referenced by optional capture tests. These use synthetic
fixtures and mocked transports. The required patient-registry training golden
under `demo_assets/raw/` remains part of the normal suite. Generated failure
diffs under `test/failures` are disposable; they are not reference goldens.

Capture flags and commands live beside `matchesGoldenFile` in the corresponding
`test/*_test.dart` files. For navigation captures:

```sh
flutter test --update-goldens --dart-define=CAPTURE_NAV_QA=true test/clinician_navigation_test.dart test/edge_device_indicator_test.dart
```

Widget tests cover route recreation, responsive geometry, semantic labels and
keyboard actions. They do not replace authenticated browser refresh, a real
screen-reader session, deployed RLS checks, real clinical saves or physical
hardware verification. Clinical disclosures, intended-use and model provenance
remain in their dedicated module and integration documentation.
