# PROGRESS

Keep this file under ~80 lines. Code and docs/spec.md win over this file if they disagree.

- Last updated: 2026-10-07
- Verified at commit: ab3a8e9 (baseline tests run same day; see Known issues)

## Features (status: DONE / PARTIAL / TODO / UNKNOWN)
| Feature | Status | Where (key files) | Notes |
|---|---|---|---|
| Google Auth / AuthGate | DONE | lib/features/auth/*, lib/main.dart | Google OAuth (web redirect + native) |
| Task CRUD | DONE | lib/features/tasks/*, home_page.dart (TaskEditorPage) | test/task_name_validator_test.dart |
| Routine CRUD, N:M, Editor | DONE | lib/features/routines/*, test/routine_repository_test.dart | |
| Mock Payment (server-side) | DONE | 20261006104500, mock-payment-*, mock_payment_service.dart, pgTAP 003 | |
| Challenge creation | DONE | 20261005090000, create-challenge, create_challenge_service.dart, pgTAP 002 | |
| Challenge start (manual / auto share one DB path) | PARTIAL | 20261006140000, start-challenge, process-auto-start, pgTAP 004 | No pg_cron scheduler (approval needed) |
| Challenge task completion (server-validated) | PARTIAL | 20261006180000, complete-task, complete_task_service.dart, battery_hold_to_complete_tile.dart | QR/refund missing; lock order; contract vs spec ch.17 |
| Deadline processing (FAILED + point grant) | PARTIAL | 20261006190000, process-deadlines, pgTAP 006 | Code still selects WAITING; fix per decision A |
| Points | PARTIAL | point_repository.dart, PointsPage | GRANT on FAILED only; no purchase/cashout/expiry job |
| History | PARTIAL | history_repository.dart, HistoryPage | No long-press detail (spec 9) |
| Settings | PARTIAL | home_page.dart (_SettingsPage) | Logout only; no user_name / terms |
| QR | TODO | (none) | use-qr not implemented |

## Next items (ordered, one line each)
1. process_deadlines: IN_PROGRESS only; pgTAP first (+ assert auto-start before deadlines order if missing).
2. complete_task: qr_codes on SUCCESS + lock order challenges -> challenge_tasks -> qr_codes.
3. complete-task contract per spec ch.17 (result fields, not HTTP 409 for deadline_exceeded / invalid_state): Edge Function + Flutter service + tests.
4. Long-press guards: background reset; idempotency key at hold start (memory only).
5. use-qr RPC + Edge Function (+ pgTAP).

## Needs user decision
- C. Mock refund on SUCCESS: no ledger/field defined yet.
- E. QR cell assignment per task and reveal algorithm (spec v4/v5).
- G. Bottom nav order: spec 9 main/points/settings/history/edit vs code main/points/history/edit/settings (light fix).
- H. Liquid-charge UI (spec v4) vs BatteryPainter; Flutter drawing method undecided.
- I. Cron (pg_cron/pg_net/Vault) for auto-start and deadlines — approval required.
- J. Purchase catalog; cashout “1 week+ continuity” definition.
- K. Server time offset; auth token refresh design.

## Decisions made (so they are not re-litigated)
- 2026-10-07 A: process_deadlines targets IN_PROGRESS only; overdue WAITING is handled by process-auto-start first (pgTAP should cover order).
- 2026-10-07 B (provisional): point GRANT amount = challenge amount 1:1 until user reflects in spec.md (grant logic only in process_deadlines RPC today).
- 2026-10-07 D: spec ch.17 result contract wins over HTTP error_code for complete-task outcomes.
- 2026-10-07 F: Riverpod phased adoption approved; add flutter_riverpod when first new feature needs it — no mass migration.
- 2026-10-05 QR at SUCCESS; one active challenge/user; FIFO points 3-month expiry (spec v5).
- 2026-10-06 Single-RPC pattern for Edge Functions (spec v6/v7).

## Known issues / flaky tests
- 2026-10-07 baseline: dart analyze 0 issues; flutter test 51 passed, 0 failed.
- supabase test db (local): 6 files, 148 pgTAP tests passed (2026-10-07). 005/006 had been failing at fixture (`guard_challenges_insert`) so RPC assertions never ran; fixed by WAITING inserts + `start_challenge` / `pg_sleep` for expired deadlines. Apply migrations through `20261006190000` locally (`supabase db reset`) before `supabase test db`.

## Remote state (update only after user confirms)
- Last applied remote migration: spec v5 says 0001–0007 applied; 0008+ unconfirmed
- Deployed functions: unknown
