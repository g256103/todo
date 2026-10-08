---
name: verification
description: Run only the checks relevant to the files you changed, then confirm against the spec. Use after any code, SQL or function change and before declaring a task done.
---

# verification

Goal: prove the change works with the fewest commands. PowerShell syntax (`;`, not `&&`). For long output show only the last 40 lines, e.g. `<cmd> 2>&1 | Select-Object -Last 40`.

New table / RLS / GRANT approval: see **`supabase-change`** (design table, wait for user unless exception applies).

## 1. See what changed
`git status --short; git diff --stat; git diff --check`
Any file you did not mean to change? Revert only YOUR accidental edits (never the user's).

## 2. Pick checks by changed paths

| Changed | Run |
|---|---|
| `lib/**`, `test/**` | `dart format <changed files>; dart analyze; flutter test <related test files>` |
| `pubspec.yaml`, `web/**`, routing/entry, platform-conditional code | above + `flutter build web` |
| `supabase/functions/**` | in that function dir: `deno fmt --check; deno check <entry>; deno test` |
| `supabase/migrations/**` or `supabase/tests/**` (adds a new `public` table) | `supabase migration list` — every local migration row must have a matching **remote** (report any gap; local pgTAP alone does not protect production); `supabase db advisors --local`; `supabase test db`; confirm `013_rls_matrix.test.sql` updated |
| `supabase/migrations/**`, `supabase/tests/**` (no new `public` table) | `supabase db advisors --local`; `supabase test db` (local) |
| docs only | `git diff --check` only |

Do not run the full Flutter suite or `flutter build web` after every small edit. Run them once, right before declaring a multi-file task done.

## 3. On failure
Read the FIRST error, not the whole log. Find the root cause, fix, re-run only the failing check. Max 3 attempts on the same failure, then stop and report: command, error, what was tried, best hypothesis.

## 4. Spec check
Re-read the relevant `docs/spec.md` section and compare with the diff. Confirm: no invented behavior, invariants in AGENTS.md still hold, no direct client-side state updates added, no existing feature rebuilt.

## 5. Report (5 lines max)
Checks run and results; files changed; spec items verified; anything not verified and why; whether `docs/PROGRESS.md` was updated (skip for spikes/dummies per **`supabase-change`**).
