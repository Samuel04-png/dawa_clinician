# UI/UX Upgrades

The UI work is visible across the design system, main app theme, care tools, patient pages, CaCx results, and responsive layouts.

## Brand Refresh

I added a shared Dawa design system:

- `DawaTokens.brandPrimary`
- `DawaTokens.brandPrimaryLight`
- `DawaTokens.brandPrimaryPale`
- status colors for success, warning, danger, and info
- surface and border colors
- text colors
- shared radii
- shared shadows
- Dawa cards, badges, avatars, stat cards, and AI confidence bar

Confirmed files:

- `lib/components/dawa_design_system.dart`
- `lib/flutter_flow/flutter_flow_theme.dart`
- `lib/main.dart`

## Global Theme

The app theme now uses Dawa tokens for:

- Color scheme.
- Scaffold background.
- App bar.
- Bottom navigation.
- Floating action button.
- Dialogs.
- Text buttons.
- Switches.
- Date picker.
- Inputs.
- Elevated buttons.
- Outlined buttons.

## Responsive Layouts

Confirmed responsive work:

- `MomsWidget` switches between desktop sidebar and mobile drawer/bottom nav.
- `PatientDetailsWidget` switches between wide two-column and narrow stacked layouts.
- Care Tools and Quick Access modules are tested at desktop, tablet, and mobile widths.
- CaCx dashboard and result views handle sidebar/mobile navigation.

Tests:

- `test/ui_responsive_layout_test.dart`
- `test/quick_access_pages_test.dart`

## Patient Details UI

The patient details screen now focuses on:

- Patient identity.
- Last screening.
- Contact and demographic fields.
- Add Screening action.
- Open full maternal record action.
- Risk summary.
- Latest screening card.
- Screening history list.
- Screening details modal.

## CaCx Results UI

The CaCx result page includes:

- Result image card.
- Diagnosis/risk summary.
- Confidence card and progress visualization.
- Prediction breakdown.
- Primary device and second-opinion summary.
- Clinical recommendation card.
- Language selector.
- Disclaimer.
- Save and share actions.

## Modal And Navigation Fixes

Confirmed improvements include:

- Image source picker dialog.
- CaCx auto-start from patient details.
- Return-to-previous behavior after patient-launched screening.
- Quick-access dashboards that avoid dead "Coming soon" states.

## Needs More UI Work

- Real screenshots should be captured and added.
- HemoNix and CT need real clinical flows beyond mock dashboards.
- Legacy generated screens are still large and visually mixed.
- Design consistency should be checked on small Android devices and browser tablets.
