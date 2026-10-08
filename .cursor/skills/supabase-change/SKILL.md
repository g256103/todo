---
name: supabase-change
description: Procedure for any Supabase change (new migration, RPC, RLS, constraint, Edge Function). Use before touching supabase/migrations, supabase/functions or supabase/tests.
---

# supabase-change

Follow in order. Skip a step only if it clearly does not apply, and say so in one line.

## Approval before implementation (new table / RLS / GRANT)

When the change adds a **`public` table**, or changes **RLS policies** or **GRANTs**:

1. Present a **design table** (operation × role × column GRANT × `USING` × `WITH CHECK`). Keep it ≤10 lines of prose besides the table.
2. **Stop the turn** and wait for the user’s reply before writing migrations or tests.
3. **Exception:** the user’s request **explicitly** includes both the design (or equivalent spec) **and** permission to implement in the **same** message (e.g. “この設計で実装してよい”).

Other changes: still use step 2 **Stop check** below for AGENTS.md hard stops.

## Policy rules (`USING` / `WITH CHECK`)

- **Forbidden** in migrations and in normal pgTAP: `USING (true)`, `WITH CHECK (true)` (do not loosen RLS/GRANT to make tests pass).
- **Only exception:** layer-isolation subtests at the end of `supabase/tests/database/013_rls_matrix.test.sql` may **temporarily** use a permissive SELECT policy (e.g. `using (true)`) **inside the test file** to prove DELETE or WITH CHECK in isolation. Must **restore** the real policy before `finish()`; never ship such policies in migrations.

## New `public` table — standards

- **`user_id`**: `references public.users (id)` — not `auth.users` directly (app pattern).
- **`unique (id, user_id)`** and **`create index … on … (user_id)`**.
- **Same migration**: `CREATE TABLE`, `ENABLE ROW LEVEL SECURITY`, per-operation policies, minimal column `GRANT`/`REVOKE` for `authenticated` / `anon` (mirror `20261005070000_rls_grants.sql`).
- **`013_rls_matrix.test.sql`**: fixture rows + matrix block (own / other / anon / impersonate / non-granted column as applicable); bump `plan(N)`. Pick fixture UUIDs in a **band that does not collide** with IDs already in that file.

## Workflow steps

1. **Inspect (read-only).** List `supabase/migrations`; read ONLY the migrations that define the tables/functions you will touch (search by name). Note lock order (spec ch.13 / v5: challenges → challenge_tasks → qr_codes → points → point_transactions), state machine and idempotency pattern. Read the matching section of `docs/spec.md`.
2. **Stop check.** If the change needs auth changes, spec changes, or a major schema change beyond routine RPC/migration work: print `BLOCKED: USER APPROVAL REQUIRED`, explain, and stop. (RLS/GRANT for new tables: use **Approval** section above.)
3. **Design.** Tables/columns, function signature, who may call it, which rows are locked and in what order, which errors it can raise. For new tables / RLS / GRANT, the design table is part of **Approval**.
4. **New migration only.** `supabase migration new <name>`. Never edit applied migrations. Prefer one RPC per state change.
5. **Write pgTAP tests first or alongside** in `supabase/tests/`: happy path, illegal transition, wrong owner, duplicate idempotency key, same key + different request, RLS denial. **New `public` table:** also extend `013_rls_matrix.test.sql` per **standards** above.
6. **Run locally.** `supabase start` (if not running); `supabase db advisors --local`; `supabase test db`. On failure: read the first error only, fix the root cause, re-run (max 3 attempts, then stop and report). Do not finish until both advisors and pgTAP pass. **New `public` table:** also run checks in **`verification`** (`supabase migration list`).
7. **Checklist before finishing** (answer each briefly):
   - RLS enabled on new tables, policies match spec?
   - New functions: `SET search_path = ''`, `auth.uid()` ownership check, REVOKE from PUBLIC/anon, minimal GRANT?
   - Single transaction, `FOR UPDATE` where state is checked then changed, lock order per spec ch.13 / v5 (report if code differs)?
   - Idempotency handled? Illegal transitions rejected? SUCCESS still immutable?
   - Flutter still calls the RPC/Edge Function instead of updating state directly?
8. **Remote.** If the change must reach the remote project: run read-only inspection and `--dry-run` only, then print `BLOCKED: USER APPROVAL REQUIRED` with the exact command and what it will change. Do not execute. After the user approves and runs it, verify the remote state read-only.
9. **Update `docs/PROGRESS.md`** when the change is a real deliverable. **Do not** update PROGRESS for spikes, dry-runs, or dummy exercises that will be reverted.
