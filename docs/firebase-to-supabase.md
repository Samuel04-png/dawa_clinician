# Firebase To Supabase

The project started with Firebase/FlutterFlow patterns and has been moved toward Supabase. I kept many generated class and file names so the app did not need a full rewrite, but the active backend calls are now Supabase-backed.

## Why I Moved To Supabase

The confirmed project direction is Supabase because it gives the app:

- Postgres tables and SQL migrations.
- Supabase Auth.
- Edge Functions for privileged operations and AI/service integrations.
- Easier schema control for clinical records and device results.
- A migration path from existing Firebase Auth and Firestore data.

## What Firebase Pieces Still Exist

| Firebase Piece | Current Status |
| --- | --- |
| `firebase/` folder | Still present with rules, indexes, and functions files. |
| `lib/backend/firebase` | Still present as generated/legacy app structure. |
| `lib/auth/firebase_auth` | Still named Firebase, but important methods call Supabase Auth. |
| `FirebaseFirestore` class name | Recreated as a compatibility facade in `supabase_firestore_compat.dart`. |
| Firebase migration tooling | Present under `tools/firebase_to_supabase`. |

## What Supabase Handles Now

- App initialization through `initSupabase()`.
- Auth through `supabaseClient.auth`.
- Database calls through `supabaseClient.from(table)`.
- Edge Functions through `supabaseClient.functions.invoke`.
- Core app data tables.
- CaCx screening result storage.

## Migration Bridge

The key bridge is `lib/backend/supabase/supabase_firestore_compat.dart`. It lets existing generated code keep calling:

```dart
FirebaseFirestore.instance.collection('mother').doc(id).get();
```

but internally it translates that into Supabase:

```dart
supabaseClient
    .from(collectionName)
    .select()
    .eq('id', id)
    .maybeSingle();
```

This is why the generated record models can continue to work without importing the real Firebase SDK.

## Auth Migration Details

Confirmed migration notes in `supabase/FIREBASE_TO_SUPABASE_MIGRATION.md` say:

- 79 Firebase Auth users were exported locally.
- 79 users were imported into Supabase Auth.
- 80 identities were imported.
- 79 Auth-backed rows were imported into `public.user`.
- 1 additional `public.user` row was preserved from Firestore without a matching Firebase Auth account.

Important limitation: Firebase Auth SCRYPT password hashes are not native Supabase bcrypt password hashes. Existing migrated users should use password reset unless a first-login Firebase hash verifier is added.

## Firestore Data Migration

Confirmed migrated Firestore counts in the migration notes:

| Collection/Table | Rows |
| --- | ---: |
| `clinic` | 1 |
| `doctor` | 20 |
| `mother` | 22 |
| `first_encounter` | 10 |
| `encounter` | 39 |
| `parity` | 4339 |
| `appointments` | 0 |

Relationship validation found orphaned references that already existed before the migration:

- `first_encounter -> mother`: 7 missing references.
- `encounter -> mother`: 34 missing references.
- `parity -> first_encounter`: 4325 missing references.

## Files Involved

- `lib/backend/supabase/supabase_config.dart`
- `lib/backend/supabase/supabase_firestore_compat.dart`
- `lib/backend/supabase/supabase_offline_cache.dart`
- `lib/auth/firebase_auth/*.dart`
- `supabase/migrations/*.sql`
- `supabase/FIREBASE_TO_SUPABASE_MIGRATION.md`
- `tools/firebase_to_supabase/*.mjs`
- `tools/firebase_to_supabase/README.md`

## Remaining Firebase Dependencies

Real Firebase packages are not listed in `pubspec.yaml`, based on the current dependency file. The remaining Firebase language is mostly naming, generated structure, migration files, and old Firebase configs.

## Risks

- Developers may misunderstand the legacy Firebase names and think the app still uses Firebase at runtime.
- Some Firebase folder contents may now be historical and should be labeled as migration/legacy.
- Migrated users may need password reset.
- Orphaned references should be cleaned or intentionally documented before production reporting depends on those relationships.
