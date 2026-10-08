---
name: supabase-change
description: Procedure for any Supabase change (new migration, RPC, RLS, constraint, Edge Function). Use before touching supabase/migrations, supabase/functions or supabase/tests.
---

# supabase-change

Follow in order. Skip a step only if it clearly does not apply, and say so in one line.

1. **Inspect (read-only).** List `supabase/migrations`; read ONLY the migrations that define the tables/functions you will touch (search by name). Note lock order (spec ch.13 / v5: challenges → challenge_tasks → qr_codes → points → point_transactions), state machine and idempotency pattern. Read the matching section of `docs/spec.md`.
2. **Stop check.** If the change needs RLS/GRANT changes, auth changes, spec changes, or a major schema change: print `BLOCKED: USER APPROVAL REQUIRED`, explain, and stop.
3. **Design in <=10 lines.** Tables/columns, function signature, who may call it, which rows are locked and in what order, which errors it can raise.
4. **New migration only.** `supabase migration new <name>`. Never edit applied migrations. Prefer one RPC per state change.
5. **Write pgTAP tests first or alongside** in `supabase/tests/`: happy path, illegal transition, wrong owner, duplicate idempotency key, same key + different request, RLS denial.
6. **Run locally.** `supabase start` (if not running); `supabase test db`. On failure: read the first error only, fix the root cause, re-run (max 3 attempts, then stop and report).
7. **Checklist before finishing** (answer each briefly):
   - RLS enabled on new tables, policies match spec?
   - New functions: `SET search_path = ''`, `auth.uid()` ownership check, REVOKE from PUBLIC/anon, minimal GRANT?
   - Single transaction, `FOR UPDATE` where state is checked then changed, lock order per spec ch.13 / v5 (report if code differs)?
   - Idempotency handled? Illegal transitions rejected? SUCCESS still immutable?
   - Flutter still calls the RPC/Edge Function instead of updating state directly?
8. **Remote.** If the change must reach the remote project: run read-only inspection and `--dry-run` only, then print `BLOCKED: USER APPROVAL REQUIRED` with the exact command and what it will change. Do not execute. After the user approves and runs it, verify the remote state read-only.
9. Update `docs/PROGRESS.md`.
