# PROGRESS

Keep this file under ~80 lines. Code and docs/spec.md win over this file if they disagree.

- Last updated: 2026-10-08
- Verified at commit: (local) 20261008042013 + pgTAP all green (11 files)

## Features (status: DONE / PARTIAL / TODO / UNKNOWN)
| Feature | Status | Where (key files) | Notes |
|---|---|---|---|
| Google Auth / AuthGate | DONE | lib/features/auth/*, lib/main.dart | Google OAuth (web redirect + native) |
| Task CRUD | DONE | lib/features/tasks/*, home_page.dart (TaskEditorPage) | test/task_name_validator_test.dart |
| Routine CRUD, N:M, Editor | DONE | lib/features/routines/*, test/routine_repository_test.dart | |
| Mock Payment (server-side) | DONE | 20261006104500, mock-payment-*, mock_payment_service.dart, pgTAP 003 | |
| Challenge creation | DONE | 20261005090000, create-challenge, create_challenge_service.dart, pgTAP 002 | |
| Challenge start (manual / auto share one DB path) | PARTIAL | 20261006140000, start-challenge, process-auto-start, pgTAP 004, docs/cron-scheduler.md | RPC+Edge done; pg_cron jobs remote-only (see doc checklist) |
| Challenge task completion (server-validated) | DONE | 20261006180000–08034442, complete-task, complete_task_service.dart, battery_hold_to_complete_tile.dart, pgTAP 005/008 | Mock refund on SUCCESS (decision C, spec v9) |
| Deadline processing (FAILED + point grant) | PARTIAL | 20261006190000–074759, process-deadlines, pgTAP 006/007, docs/cron-scheduler.md | IN_PROGRESS only (decision A); cron schedule remote-only |
| Points | PARTIAL | point_repository.dart, PointsPage | GRANT on FAILED only; no purchase/cashout/expiry job |
| History | PARTIAL | history_repository.dart, HistoryPage | No long-press detail (spec 9) |
| Settings | PARTIAL | home_page.dart (_SettingsPage) | Logout only; no user_name / terms |
| QR | PARTIAL | 20261008103000, use-qr, qr_codes, pgTAP 008/009 | use_qr RPC+Edge DONE; セル割当・reveal・Flutter読取は決定E待ち |

## Next items (ordered, one line each)
1. ~~process_deadlines: IN_PROGRESS only; pgTAP 007 mixed WAITING/IN_PROGRESS.~~ DONE (20261007074123).
1b. ~~process_deadlines lock order (points before point_transactions).~~ DONE (20261007074759).
2. ~~complete_task: qr_codes on SUCCESS + lock order challenges -> challenge_tasks -> qr_codes.~~ DONE (20261007080340, 20261007080342).
3. ~~complete-task contract per spec ch.17 (result fields, not HTTP 409 for deadline_exceeded / invalid_state): Edge Function + Flutter service + tests.~~ DONE (2026-10-08).
4. ~~Long-press guards: background reset; idempotency key at hold start (memory only).~~ DONE (2026-10-08).
5. ~~use-qr RPC + Edge Function (+ pgTAP).~~ DONE (20261008103000, 2026-10-08).
6. ~~Mock refund on SUCCESS (decision C): migration `refunded_at`, `complete_task`+QR txn, response `refunded`/`refund_amount`, pgTAP, Flutter if needed.~~ DONE (20261008034442).
7. ~~Cron design + local runbook (pg_cron/pg_net extensions, verify_jwt, invoke script).~~ DONE (20261008150000, docs/cron-scheduler.md). **Remote execute:** same doc § Remote checklist — BLOCKED until approval.
8. ~~Overdue never-started WAITING blocks new create (L, decision c): index + `create_challenge` active check.~~ DONE (20261008042013, spec v10, pgTAP 011).

## Needs user decision
- E. QR cell assignment per task and reveal algorithm (spec v4/v5).
- G. Bottom nav order: spec 9 main/points/settings/history/edit vs code main/points/history/edit/settings (light fix).
- H. Liquid-charge UI (spec v4) vs BatteryPainter; Flutter drawing method undecided.
- I. Cron remote rollout (`db push` extensions, `secrets set`, `functions deploy`, Vault + `cron.schedule`) — design in docs/cron-scheduler.md; execution approval required.
- J. Purchase catalog; cashout “1 week+ continuity” definition.
- K. Server time offset; auth token refresh design.

## Decisions made (so they are not re-litigated)
- 2026-10-07 A: process_deadlines targets IN_PROGRESS only. Overdue WAITING is not rescued by process-auto-start or start_challenge.
- 2026-10-08 L (c) **ratified**: overdue never-started WAITING does not block `create_challenge`; DB enforces one `IN_PROGRESS` per user; `WAITING`→`FAILED` still forbidden (spec v10). (a)/(b) not adopted.
- 2026-10-07 B (provisional): point GRANT amount = challenge amount 1:1 until user reflects in spec.md (grant logic only in process_deadlines RPC today).
- 2026-10-08 D: complete-task Edge maps RPC `deadline_exceeded` → HTTP 200 `{ result: "deadline_exceeded" }`; state RPC errors → HTTP 200 `{ result: "invalid_state", error_code }`; other failures keep error_code + 4xx/5xx. Documented in spec.md ch.17 (2026-10-08).
- 2026-10-08 M: spec ch.17 complete-task HTTP/`result` vs `error_code` wording added per user (changelog v8).
- 2026-10-08 C: Mock refund on SUCCESS — `complete_task` same txn as SUCCESS+QR; ledger `challenges.refunded_at`; full `challenges.amount`; `challenge_success` adds `refunded`+`refund_amount`; no new Mock Payment Edge (spec v9).
- 2026-10-07 F: Riverpod phased adoption approved; add flutter_riverpod when first new feature needs it — no mass migration.
- 2026-10-05 QR at SUCCESS; one active challenge/user; FIFO points 3-month expiry (spec v5).
- 2026-10-06 Single-RPC pattern for Edge Functions (spec v6/v7).

## Known issues / flaky tests
- 2026-10-08 baseline: dart analyze 0 issues; flutter test 61 passed, 0 failed.
- supabase test db (local): 11 files; run `supabase db reset` then `supabase test db` (migrations through 20261008042013).
- Cron Edge deno tests: `deno test --allow-env` in process-auto-start / process-deadlines dirs.
- Remote: SUCCESS challenges created before 20261007080340 may lack `qr_codes` rows; backfill needs approval (one-off migration or ops), not done in this change.
- Lock timeout (SQLSTATE `55P03`, PG message e.g. `canceling statement due to lock timeout`): migrations set `lock_timeout` but no RPC maps to `temporary_unavailable`; `_shared.dbErrorCode` uses `message` only → single-RPC Edges (complete-task, use-qr, mock-payment-*, start/create-challenge) likely HTTP 500. Spec ch. Mock Payment: 503 `temporary_unavailable`. Cron edges map any RPC error to 503. Cross-cutting fix needs approval.

## Remote state (update only after user confirms)
- Last applied remote migration: spec v5 says 0001–0007 applied; 0008+ unconfirmed
- Deployed functions: unknown
