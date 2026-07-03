# Changelog

This changelog summarizes meaningful project history from the available git log and confirmed code changes. Dates are commit dates from the local repository.

## 2026-06-30

### Missing Modules And Care Tools

- Added the BP Monitor feature in `lib/application/bp_monitor/bp_monitor_widget.dart`.
- Added EchoWave A bridge work and a scan record page for ultrasound media handoff.
- Updated home and care tools to launch the added modules.
- Updated clinician bottom navigation.

Related commit: `f9cf29f updated the missing modules`.

### Offline Mode Update

- Added offline auth cache in `lib/services/offline_auth_cache.dart`.
- Added connectivity checks in `lib/services/offline_connectivity_service.dart`.
- Added `SupabaseOfflineCache` for query/document fallback data.
- Added the offline status banner.
- Updated auth streams and sign-in behavior to support cached users.
- Updated CaCx flow for offline device-only behavior and queued Supabase saves.

Related commit: `3e1dbfc Dawa clinician offline mode update`.

## 2026-06-23

### UI Fixes

- Continued UI stabilization after the brand refresh.
- Confirmed by commit history as `0cda061 updated the ui fixes`.

The exact file-level changes should be reviewed with `git show 0cda061` if more detail is needed.

## 2026-06-17

### Raspberry Pi URL Update

- Updated the Raspberry Pi/device URL behavior around `http://DAWA:8084` / `http://DAWA.local:8084`.
- The current code uses `PI_DEVICE_BASE_URL` and `CERVICAL_DEVICE_BASE_URL` dart defines, with default behavior in `CervicalDeviceConfig` and `PiDeviceConfig`.

Related commit: `4e8b160 updated the ip address for the reasberry pi http://DAWA:8084`.

## 2026-06-16

### Supabase Function Deployment

- Commit history shows `871b84f deployed function`.
- Current function folder includes `delete-user`, `send-sms`, `gemini`, `analyze-via-image`, and `analyze-ultrasound-image`.

Needs confirmation: which functions were deployed to the linked Supabase project and whether all secrets were configured.

## 2026-06-15

### Ultrasound Refactor

- Refactored the ultrasound module.
- Added or improved clinician ultrasound dashboard views.
- Confirmed files include `lib/application/ultrasound/screens/ultrasound_app.dart`, `services/ultrasound_ai_service.dart`, models, mock data, and EchoWave work added later.

Related commit: `c23aa5c feat: refactor ultrasound module and improve clinician ultrasound dashboard`.

## 2026-06-04

### Patient Details And Cervix Scan History

- Added `lib/application/patient_details/patient_details_widget.dart`.
- Added patient-linked CaCx history loading from `public.cacx_screening_results`.
- Added an Add Screening flow that launches CaCx with the selected patient.

Related commit: `099c417 added patient details page and cervix scan history`.

### CaCx Result UI And Device Wait Flow

- Improved CaCx results UI and responsive layout.
- Renamed "cloud skip" language to "online scan".
- Added demo/device-wait flow and a way to use online scan while device response is pending.
- Improved result presentation and recommendation UI.

Related commits: `a611a6b`, `2b560e4`, `4d6ba28`, `8910147`.

## 2026-05-24

### Brand Blue Refresh

- Added/updated Dawa brand colors and design tokens.
- Mapped updated brand values into app theme.

Related commit: `baf34c9 Refresh Dawa Clinician brand colors`.

## 2026-05-13

### Web Build And GitHub Pages History

- Git history includes web build deployment and GitHub Pages setup commits:
  - `8abdea1 Deploy Flutter web build`
  - `58b3569 Fix GitHub Pages base path`
  - `63218d3 Add GitHub Pages nojekyll marker`
  - `1689479 Update mobile home page build`

Needs review: current deployment process should be revalidated after the Supabase and offline work.
