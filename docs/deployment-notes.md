# Deployment Notes

## Flutter Web Build

The repository has git history for prior Flutter web build and GitHub Pages setup. To build the current app:

```bash
flutter build web \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key
```

If the deployed web app needs access to a local device, remember that browsers block mixed content when an HTTPS site calls an HTTP LAN device. In that case, use one of these deployment patterns:

- Serve the Flutter web app over HTTP on the same trusted local network.
- Put HTTPS with a trusted certificate on the device API.
- Use an HTTPS gateway/proxy that can reach the device.

## Mobile Builds

Android and iOS project folders are present. Standard Flutter commands apply:

```bash
flutter build apk
flutter build appbundle
flutter build ios
```

Before production mobile builds, confirm:

- App icons and splash assets are correct.
- Supabase URL/key are injected for the right environment.
- Android local HTTP/device access is allowed only as intended.
- iOS local network permission text is correct.
- The device URL is configurable per clinic.

## Supabase Functions

Deploy functions with the Supabase CLI from the project root:

```bash
supabase functions deploy delete-user
supabase functions deploy send-sms
supabase functions deploy gemini
supabase functions deploy analyze-via-image
supabase functions deploy analyze-ultrasound-image
```

Set secrets in Supabase, not in the Flutter app:

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
supabase secrets set HUGGINGFACE_API_TOKEN=your_huggingface_token
supabase secrets set HUGGINGFACE_VIA_MODEL=your_huggingface_model
supabase secrets set SMS_API_TOKEN=your_sms_token
```

## Database Deployment

Apply migrations in order:

```text
20260507111000_clinician_supabase_schema.sql
20260507155500_add_firebase_uid_to_users.sql
20260602120000_add_cacx_screening_results.sql
```

After applying migrations, verify:

- Tables exist.
- RLS is enabled.
- Policies allow intended app flows and block cross-clinic access.
- `cacx_screening_results` accepts inserts for authenticated users.
- `user_id` in CaCx rows matches `auth.uid()`.

## Known Deployment Risks

- The current core-table RLS policies are broad for authenticated users.
- Several modules still use local/mock state.
- CaCx online second opinion depends on external Hugging Face/Gradio availability.
- Device calls need network and CORS validation for each deployment environment.
- Screenshot and production QA evidence should be added before client-facing GitBook publication.
