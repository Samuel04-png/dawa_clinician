# Testing And Verification

## Automated Tests

Run:

```bash
flutter test
```

Confirmed test files:

| Test File | What It Covers |
| --- | --- |
| `test/widget_test.dart` | App smoke test with Supabase init, app state, and mocked video player platform. |
| `test/ui_responsive_layout_test.dart` | Care Tools, CaCx, and quick-access responsive layouts. |
| `test/quick_access_pages_test.dart` | CaCx and quick-access dashboards, mobile views, results search/filter, and no "Coming soon" states. |
| `test/cacx_upload_routing_test.dart` | CaCx risk routing and device URL defaults. |
| `test/cacx_prediction_breakdown_test.dart` | CaCx confidence normalization and duplicate label merging. |

## Manual QA Checklist

### Authentication

- Sign in with valid email/password.
- Try invalid migrated credentials and confirm reset-password guidance.
- Reset password.
- Sign out.
- Confirm cached offline sign-in after one successful online login.

### Patient Management

- Open patient list.
- Search/filter patients.
- Create a patient.
- Open patient details.
- Open legacy maternal record.
- Add pregnancy data.
- Add and open encounters.

### CaCx

- Open CaCx from Home.
- Open CaCx from Care Tools.
- Open CaCx from Patient Details.
- Select camera/gallery image.
- Test local device success.
- Test local device timeout/failure.
- Test online second opinion.
- Save result.
- Confirm result appears in patient details history.
- Test language selector.

### Arduino / Device

- Confirm `/health` returns expected status.
- Confirm `/upload/cervical` accepts multipart image.
- Confirm response parser handles expected JSON.
- Confirm timeout behavior.
- Confirm offline device-only behavior.
- Confirm pending result sync after reconnect.

### Offline Mode

- Log in online.
- Disable network or block Supabase.
- Restart app and confirm cached account behavior.
- Open previously loaded patient data.
- Start CaCx offline with device connected.
- Start CaCx offline with device disconnected.
- Reconnect and confirm queued CaCx result sync.

### Supabase

- Confirm core tables exist.
- Confirm `cacx_screening_results` exists.
- Confirm authenticated insert/select policies work as intended.
- Confirm another user cannot read private CaCx rows.
- Confirm Edge Functions have required secrets.

### UI Responsiveness

- Desktop width.
- Tablet width.
- Small mobile width.
- Long patient names.
- Long recommendations and translations.
- Empty states.
- Loading states.
- Error states.

## Verification Gaps

- I did not run live hardware tests while creating these docs.
- I did not confirm live Supabase migration state.
- Real screenshots still need to be captured.
- Clinical recommendations and translations need expert review.
