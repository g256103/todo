# AGENTS.md

## Project
Flutter + Supabase "PayPay ToDo Commit" app. Users create a Challenge with a stake, set Tasks, and must finish them before the deadline. Payment is MOCK (no real PayPay API).
Stack: Flutter/Dart + Riverpod, Supabase (Postgres, Auth, Edge Functions on Deno, migrations, pgTAP). Dev machine: Windows, PowerShell (chain commands with `;`, not `&&`).
Reply to the user in Japanese. Code, comments, commit messages in English.

## Source of truth (never chat history)
Priority: `docs/spec.md` > code, tests, migrations > `docs/PROGRESS.md` > everything else.

Session start (keep it cheap, do NOT scan the whole repo):
1. Read `docs/PROGRESS.md`.
2. `git status --short; git log -5 --oneline`
3. Read only the parts of `docs/spec.md` relevant to the next task (search by heading).
4. Check PROGRESS.md claims against the code you will touch. If they conflict, code wins; fix PROGRESS.md.

Never invent specs. If spec.md is silent or marks something undecided (e.g. QR cell task assignment, QR reveal algorithm, point calculation), STOP and ask the user.
Never rebuild or refactor existing features. Change only what the task needs. Keep diffs small. Do not touch unrelated files.

## Work loop
next unfinished item in PROGRESS.md -> read relevant spec/code -> plan in <=10 lines -> smallest change -> run the `verification` skill (only checks relevant to changed files) -> on failure find root cause, fix, re-run -> compare with spec -> update PROGRESS.md -> next item.
Continue to the next safe item without asking.

## Cost guards
- Same failure: max 3 fix attempts, then STOP and report (what was tried, best hypothesis).
- After ~5 completed items, tell the user to start a new chat.
- Prefer search + partial reads over reading whole files. Show only the last ~40 lines of long command output.
- Run narrow tests first; the full suite only once before declaring done.

## Hard stops
Print `BLOCKED: USER APPROVAL REQUIRED` with what and why, then stop, for:
- Anything on the REMOTE Supabase: `supabase db push`, remote migrations, function deploy, remote SQL, production data.
- RLS or GRANT changes.
- Secrets, Vault, `.env`, cron secrets, pg_cron / cron jobs, external service connections.
- Auth method or Google OAuth changes.
- Destructive operations, large dependency changes, spec changes, major DB schema changes.
- `git commit` / `git push` (only when the user explicitly asks).

Always forbidden: `git reset --hard`, `git clean -fd`, editing an already-applied migration, discarding the user's uncommitted changes.

## Security
Never print secrets (service_role key, DB password, JWTs, OAuth/API/cron secrets, `.env` values). To confirm a secret exists, write `exists: YES, value: [REDACTED]`. service_role must never appear in Flutter code.

## Domain invariants (details live in docs/spec.md)
- Challenge states: WAITING -> IN_PROGRESS -> SUCCESS / FAILED. SUCCESS is immutable.
- Important state changes (challenge, payment, task completion) happen server-side (RPC / Edge Function). Flutter never UPDATEs them directly.
- Mock payment state is managed server-side.
- Manual Start and Auto Start share ONE DB logic path. Do not duplicate transitions.
- Task completion: the 4s long-press is UX only. The server validates; never rely on UI timing for security.
- Idempotency: same key + same request = same result; same key + different request = error.
- Check the existing lock order in migrations before adding any new locking.

## Scoped rules and skills
Flutter/Riverpod rules: `.cursor/rules/flutter.mdc`. Supabase/SQL/Edge rules: `.cursor/rules/supabase.mdc`.
Skills: `supabase-change` (any DB/RPC/function change), `verification` (before finishing any change).
