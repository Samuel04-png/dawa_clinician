# Firebase to Supabase migration tools

These tools move the Clinician app backend from Firebase to Supabase.

## What is already app-side

- Flutter uses `supabase_flutter`.
- Authentication calls go through `supabaseClient.auth`.
- Database calls go through `lib/backend/supabase/supabase_firestore_compat.dart`, which keeps the old FlutterFlow generated API shape while reading/writing Supabase tables.

The `auth/firebase_auth` and `FirebaseFirestore` names are compatibility names only. They do not import or initialize Firebase SDKs.

## Required secrets

Copy `.env.example` to `.env`, then fill in:

- `GOOGLE_APPLICATION_CREDENTIALS`: Firebase Admin SDK service-account JSON path.
- `SUPABASE_SERVICE_ROLE_KEY`: Supabase service-role key.

Do not commit `.env`, `firebase-service.json`, `supabase-service.json`, or anything in `migration_exports/`.

## Schema

Apply the SQL in:

```sh
supabase/migrations/20260507111000_clinician_supabase_schema.sql
```

You can paste it into the Supabase SQL editor or run it with the Supabase CLI.

## Auth users

Firebase Auth users were exported locally to:

```sh
migration_exports/firebase_auth_users.json
```

Use Supabase's official `firebase-to-supabase` auth importer for hash-preserving import into `auth.users`. It needs the Supabase Postgres connection password, not the public anon key.

For this project, the local generated SQL importer was used instead:

```sh
node generate_auth_import_sql.mjs
npx supabase db query --linked --file ../../migration_exports/import_auth_users.sql
```

Imported counts:

- Supabase Auth users: 79
- Supabase identities: 80
- App `public.user` rows: 80

Note: Firebase SCRYPT password hashes are not valid Supabase bcrypt hashes.
Existing users should use password reset unless a first-login Firebase hash
verifier is added.

## Firestore tables

Install tool dependencies:

```sh
cd tools/firebase_to_supabase
npm install
```

Then migrate all mapped collections:

```sh
npm run migrate:firestore
```

Or migrate selected collections:

```sh
node migrate_firestore_to_supabase.mjs user clinic doctor mother first_encounter encounter parity
```

Verify counts:

```sh
npm run verify
```

For this linked project, SQL files were generated and applied through the
Supabase CLI:

```sh
node generate_firestore_import_sql.mjs
npx supabase db query --linked --file ../../migration_exports/firestore_sql/user.sql
```
