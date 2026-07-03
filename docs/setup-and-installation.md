# Setup And Installation

These steps are for a developer setting up Dawa Clinician locally.

## Requirements

- Flutter stable with Dart `>=3.0.0 <4.0.0`.
- Node.js for Firebase-to-Supabase migration tools.
- Supabase project access if running live backend workflows.
- Firebase Admin service account only if running migration tools.
- A local Raspberry Pi/Arduino device API only if testing the CaCx hardware path.

## Install Flutter Dependencies

```bash
flutter pub get
```

## Run The App

```bash
flutter run
```

For web:

```bash
flutter run -d chrome
```

If the app needs custom Supabase or device values, pass dart defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key \
  --dart-define=PI_DEVICE_BASE_URL=http://device-host:8084
```

## Run Tests

```bash
flutter test
```

The confirmed tests include:

- App smoke test.
- Responsive layout test.
- Quick-access module dashboard/result tests.
- CaCx upload routing tests.
- CaCx prediction breakdown tests.

## Install Migration Tool Dependencies

```bash
cd tools/firebase_to_supabase
npm install
```

Then copy the example environment file and fill it locally:

```bash
cp .env.example .env
```

Do not commit `.env`, Firebase service account JSON, Supabase service role keys, database URLs, or migration exports.

## Apply Supabase Migrations

Use the Supabase CLI or the Supabase SQL editor to apply:

```text
supabase/migrations/20260507111000_clinician_supabase_schema.sql
supabase/migrations/20260507155500_add_firebase_uid_to_users.sql
supabase/migrations/20260602120000_add_cacx_screening_results.sql
```

## Verify Migration Counts

From `tools/firebase_to_supabase`:

```bash
npm run verify
```

This requires Firebase and Supabase service credentials in the local `.env`.

## Device Testing

To test CaCx device mode, the device service should expose:

```text
GET  /health
POST /upload/cervical
```

Run with:

```bash
flutter run --dart-define=PI_DEVICE_BASE_URL=http://device-host:8084
```

or override only CaCx:

```bash
flutter run --dart-define=CERVICAL_DEVICE_BASE_URL=http://device-host:8084
```
