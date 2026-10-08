# PROGRESS

Keep this file under ~80 lines. Code and docs/spec.md win over this file if they disagree.

- Last updated: 2026-10-08 (settings + points)
- Verified at commit: `68a470f` + branch `feat/settings-and-points` (uncommitted) — local checks above; **remote** `jblaaeziumdpkccarjcd`: Flutter Web (`:3000`) point **purchase/exchange smoke OK** (user 2026-10-08)

## Features (status: DONE / PARTIAL / TODO / UNKNOWN)
| Feature | Status | Where (key files) | Notes |
|---|---|---|---|
| Google Auth / AuthGate | DONE | lib/features/auth/*, lib/main.dart | Google OAuth (web redirect + native) |
| Task CRUD | DONE | lib/features/tasks/*, home_page.dart (TaskEditorPage) | test/task_name_validator_test.dart |
| Routine CRUD, N:M, Editor | DONE | lib/features/routines/*, test/routine_repository_test.dart | |
| Mock Payment (server-side) | DONE | mock-payment-*, mock_payment_service.dart, pgTAP 003 | Edge HTTP error mapping (#2) |
| Challenge creation / start / complete / deadlines | DONE | migrations, Edge, pgTAP 002–008, 011 | Remote cron 2026-10-08 |
| QR | DONE | lib/features/qr/*, use-qr, pgTAP 008/009 | PR #1 merged |
| History | DONE | history_repository.dart, HistoryPage | |
| Settings (UC26) | DONE | settings_tab.dart, user_profile_repository.dart | user_name + terms (example.com mock) |
| Points (UC20–23) | PARTIAL | purchase/cashout RPC+Edge, PointsPage, pgTAP 012 | Remote purchase E2E OK (Web); cashout not smoke-tested; expiry **cron** not scheduled |

## Next items (ordered, one line each)
1. ~~#1–#9 core challenge/QR/cron/L.~~ DONE
10. ~~Settings UC26 (user_name, terms link).~~ DONE (2026-10-08, branch).
11. ~~Points: purchase-points / cashout-points / expiry RPC+Edge.~~ DONE remote deploy + Web purchase smoke (2026-10-08); **pg_cron `process-point-expiry`** still needs approval.
12. Remote: migration + Edge `purchase-points` / `cashout-points` / `process-point-expiry` DONE 2026-10-08. Optional: `POINT_EXPIRY_CRON_SECRET` + `process-point-expiry-every-minute` cron (see docs/cron-scheduler.md) — **BLOCKED until approved**.

## Needs user decision
- H. Liquid-charge UI vs BatteryPainter.
- K. Server time offset; auth token refresh design.

## Decisions made (so they are not re-litigated)
- 2026-10-08 **J (ratified)**: Catalog `book_1000` / `material_500` / `cert_2000`; purchase COMPLETED mock; cashout min 1000, 10pt steps, fee 10%, `cash_amount = points_used - fee_points`; eligibility = ≥7 SUCCESS + 7 days after `min(finished_at)`; progress UI uses `available_points`, `success_count`, days-left formula.
- 2026-10-07 A–M, E, G, C, L(c), etc. — unchanged (see git history / prior PROGRESS).
- 2026-10-05 FIFO points 3-month expiry (spec v5).

## Known issues / flaky tests
- Web Edge CORS: default `localhost:3000` / `127.0.0.1:3000` or set `CORS_ALLOWED_ORIGINS` on deploy (not done on remote in this change).
- `supabase test db` requires Docker Desktop running locally.
- Lock timeout → `temporary_unavailable` mapping still cross-cutting (unchanged).
- Remote expiry: without `process-point-expiry` cron, GRANT rows expire only via manual cron POST or future schedule.

## Remote state (project `jblaaeziumdpkccarjcd`, last confirmed 2026-10-08)
- Migrations through `20261008150000` + `082534`; Edge includes `purchase-points`, `cashout-points`, `process-point-expiry` (2026-10-08). Web purchase smoke OK. Expiry pg_cron not scheduled.
