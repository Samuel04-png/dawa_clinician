# Developer Notes

## Where To Start

If I am onboarding a new developer, I would start with these files:

- `lib/main.dart`
- `lib/backend/supabase/supabase_config.dart`
- `lib/backend/supabase/supabase_firestore_compat.dart`
- `lib/auth/firebase_auth/firebase_auth_manager.dart`
- `lib/application/patient_details/patient_details_widget.dart`
- `lib/application/cacx/cacx_upload_service.dart`
- `lib/application/cacx/cacx_widget.dart`
- `supabase/migrations/*.sql`

## Important Mental Model

The app still looks like Firebase in some generated code, but the runtime backend path is Supabase. Do not add Firebase SDK calls unless there is a deliberate reason.

The compatibility layer is the bridge. If a generated record query breaks, check `supabase_firestore_compat.dart` before rewriting screens.

## Common Pitfalls

- Do not place Supabase service role keys in Flutter code.
- Do not assume all `Firebase*` names mean Firebase is active.
- Do not change large generated maternal/encounter screens casually.
- Do not publish screenshots that show patient data or real keys.
- Do not claim HemoNix/CT persistence is complete until schemas and writes exist.
- Do not treat offline cache as full offline sync.

## Adding New Features Safely

1. Decide the Supabase table/storage/function shape first.
2. Add a migration.
3. Add repository/service code.
4. Wire UI through a small feature boundary.
5. Add tests for parsing, routing, and result persistence.
6. Update this documentation.

## Updating Docs

When changing app behavior:

- Update `completed-tasks.md` if the work is meaningful.
- Update feature pages if workflows change.
- Update `known-issues.md` if a risk is fixed or discovered.
- Add screenshots when the UI is stable.
- Keep secrets out of examples.

## Production Review Checklist

Before a production release:

- Confirm migrations are applied.
- Confirm RLS policies are strict.
- Confirm Edge Function secrets are configured.
- Confirm device API contract with real hardware.
- Run `flutter test`.
- Manually test auth, patient management, CaCx, offline behavior, and device behavior.
- Confirm clinical recommendation text with qualified reviewers.
