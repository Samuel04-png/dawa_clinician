# Authentication

Authentication is now Supabase-based, even though many files still live under `lib/auth/firebase_auth`.

## Login Flow

1. User enters email and password.
2. `emailSignInFunc` calls `supabaseClient.auth.signInWithPassword`.
3. `FirebaseAuthManager` receives the `AuthResponse`.
4. The current user is converted into `ClinicianFirebaseUser`.
5. `maybeCreateUser` ensures there is a row in `public.user`.
6. `OfflineAuthCache.saveSupabaseUser` stores basic identity data for future offline fallback.
7. The auth stream updates the router state.

## Signup Flow

Email account creation calls:

```dart
supabaseClient.auth.signUp(
  email: email.trim(),
  password: password,
);
```

If Supabase requires email confirmation and no session is returned, the UI tells the user to confirm their email before signing in.

## Password Reset

Password reset calls:

```dart
supabaseClient.auth.resetPasswordForEmail(email.trim());
```

This is important for migrated Firebase users because Firebase SCRYPT hashes do not directly become native Supabase email/password hashes.

## Session Persistence

Supabase manages its own session. The project adds:

- Session refresh in `ensureFreshSupabaseSession`.
- Request-level timeout handling.
- JWT-expired retry handling.
- Offline cached user identity.

## Role Data

The `public.user` table and `UserRecord` model include a `role` field. The codebase also includes an admin PIN confirmation component. I did not confirm strong role-based routing or RLS enforcement in the current code. Treat role-based access as needs review.

## Offline Login Behavior

Offline login is partially implemented:

- After a successful online login, basic Supabase user data is cached.
- If a later email login fails because Supabase is unreachable, the app can sign in with the cached account for that email.
- Credential errors do not allow offline fallback.

This is helpful for field use, but it is not a full offline password verifier and should be documented carefully for users.

## Files Involved

- `lib/auth/firebase_auth/email_auth.dart`
- `lib/auth/firebase_auth/firebase_auth_manager.dart`
- `lib/auth/firebase_auth/firebase_user_provider.dart`
- `lib/auth/firebase_auth/auth_util.dart`
- `lib/auth/base_auth_user_provider.dart`
- `lib/backend/backend.dart`
- `lib/services/offline_auth_cache.dart`
- `lib/backend/supabase/supabase_config.dart`
- `supabase/functions/delete-user/index.ts`

## Known Auth Risks

- Legacy Firebase names can confuse developers.
- Migrated users may need password resets.
- Role-based authorization is not fully confirmed.
- Broad database RLS policies should not be treated as production-ready.
