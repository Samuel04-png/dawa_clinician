# Firebase to Supabase migration

## Current app backend

The Flutter app initializes Supabase in `lib/main.dart` through
`lib/backend/supabase/supabase_config.dart`.

The generated FlutterFlow code still uses names like `FirebaseFirestore` and
`FirebaseAuthManager`, but those are compatibility wrappers:

- Auth uses `supabaseClient.auth`.
- Database reads/writes use Supabase tables through
  `lib/backend/supabase/supabase_firestore_compat.dart`.
- Real Firebase packages are not listed in `pubspec.yaml`.

## Supabase project

- URL: `https://eatliepvwrviogsnqavu.supabase.co`
- Public anon/publishable key is configured in `supabase_config.dart`.
- Service-role keys and database passwords must stay local and must not be added
  to Flutter code.

## Schema

Apply:

```text
supabase/migrations/20260507111000_clinician_supabase_schema.sql
```

It creates the app tables:

- `user`
- `clinic`
- `doctor`
- `mother`
- `first_encounter`
- `encounter`
- `parity`
- `appointments`

## Auth users

Firebase Auth export completed locally:

```text
migration_exports/firebase_auth_users.json
```

Export summary:

- 79 Firebase Auth users exported
- 79 have email addresses
- 79 include password hash material in the local export

Import summary:

- 79 users imported into Supabase Auth
- 80 identities imported (`79` email identities and `1` Google identity)
- 79 Auth-backed rows imported into `public.user`
- 1 additional `public.user` row was preserved from Firestore even though it had
  no matching Firebase Auth account

Firebase Auth exports SCRYPT password hashes, while Supabase Auth stores bcrypt
password hashes in `auth.users.encrypted_password`. The migration preserved the
Firebase hash/salt in restricted Auth metadata, but native Supabase email/password
login requires users to reset their password unless a first-login verifier is
added.

## Firestore data

Use:

```text
tools/firebase_to_supabase/migrate_firestore_to_supabase.mjs
```

Firestore data has been migrated into Supabase:

- `clinic`: 1 row
- `doctor`: 20 rows
- `mother`: 22 rows
- `first_encounter`: 10 rows
- `encounter`: 39 rows
- `parity`: 4339 rows
- `appointments`: 0 rows

The migration preserved document IDs as `id` and converted Firestore references
to path strings. Firebase user references were remapped to the new Supabase Auth
UUIDs.

Relationship validation found the same orphaned references in Firebase and
Supabase:

- `first_encounter -> mother`: 7 missing references
- `encounter -> mother`: 34 missing references
- `parity -> first_encounter`: 4325 missing references

These gaps existed in Firebase before migration; they were not introduced by the
Supabase import.

## Verification

Use:

```text
tools/firebase_to_supabase/verify_migration_counts.mjs
```

It compares Firebase collection counts with Supabase table counts and compares
the Firebase Auth export count with Supabase Auth user count.
