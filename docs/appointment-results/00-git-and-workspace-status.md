# Git and workspace status

Checked on 2026-07-21 after `git fetch origin --prune`. No pull, merge,
rebase, branch switch, reset, or push was performed.

## Dawa Clinician

- Repository: `/Users/premierpluspawn/Desktop/dawa work/clinician_supabasev2`
- Remote: `https://github.com/Samuel04-png/dawa_clinician.git`
- Current branch: `feature/dawa-platform-sync`
- Current commit: `bd91f26cedf34f7c0573ccb48a5f2fa4332792a2`
- Upstream: `origin/feature/dawa-platform-sync`
- Ahead/behind: `0/0`
- Requested branch note: `brand-blue-refresh` and
  `origin/brand-blue-refresh` do not exist under those literal names. The
  closest remote branch is `origin/ui/brand-blue-refresh` at `6e43040`; the
  current branch contains that commit plus `bd91f26`.
- Update decision: no update was needed. The current branch is fully synced,
  and the dirty worktree makes an automatic branch switch or pull unsafe.

Existing work that must not be overwritten:

- iOS project/workspace, storyboard, privacy, and entitlement files have
  existing `.xml` replacement files alongside tracked deletions.
- `lib/application/cacx/cacx_model.dart`
- Existing ultrasound mock, model, screen, and service edits under
  `lib/application/ultrasound/`
- Existing untracked `docs/architecture/`
- Existing untracked `docs/ux-improvement-understanding-report.md`

## Dawa Mom

- Repository: `/Users/premierpluspawn/Desktop/dawa work/dawa_mom`
- Remote: `https://github.com/Samuel04-png/dawa-mom.git`
- Current branch: `sync/dawa-clinician-webhook`
- Current commit: `f022e643002d45dade0bdf85660d36ddc62dcdd4`
- Upstream: `origin/sync/dawa-clinician-webhook`
- Ahead/behind: `0/0`
- Requested branch note: `origin/main` is at `b31358b`; the current branch is
  one commit newer and contains the launcher-icon/GIF-splash restoration.
- Update decision: no update was needed. The current branch is fully synced,
  and the dirty worktree makes an automatic branch switch or pull unsafe.

Existing work that must not be overwritten:

- iOS project/workspace, storyboard, privacy, and entitlement files have
  existing `.xml` replacement files alongside tracked deletions.
- Existing backend edits under `lib/backend/`
- `lib/navbar/period_tracker/period_tracker_model.dart`
- Existing Supabase CLI temporary-version changes under `supabase/.temp/`
- Existing untracked iOS Flutter integration environment file

## Supabase separation

The applications are intentionally linked to different projects and must stay
separate:

- Dawa Clinician project ref: `eatliepvwrviogsnqavu`
- Dawa Mom project ref: `himbfndvsuwiudtzjojh`

Cross-project communication uses Edge Functions and integration outboxes. It
must not be replaced with direct client access to the other project's database.
