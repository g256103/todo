# PROGRESS

Keep this file under ~80 lines. Code and docs/spec.md win over this file if they disagree.

- Last updated: 2026-10-08 (points DONE path, K decided, remote-edge ops doc)
- Verified at commit: local — `supabase test db` 15/333 PASS (`014_cashout_success`, `015_get_server_time`, `get_server_time` migration); `flutter test` 70; `dart analyze` 0

## Features (status: DONE / PARTIAL / TODO / UNKNOWN)
| Feature | Status | Where (key files) | Notes |
|---|---|---|---|
| Google Auth / AuthGate | DONE | lib/features/auth/*, lib/main.dart | Google OAuth; `autoRefreshToken` + pre-Edge refresh |
| Task CRUD | DONE | lib/features/tasks/*, home_page.dart (TaskEditorPage) | test/task_name_validator_test.dart |
| Routine CRUD, N:M, Editor | DONE | lib/features/routines/*, test/routine_repository_test.dart | |
| Mock Payment (server-side) | DONE | mock-payment-*, mock_payment_service.dart, pgTAP 003 | Edge HTTP error mapping (#2) |
| Challenge creation / start / complete / deadlines | DONE | migrations, Edge, pgTAP 002–008, 011 | Remote cron 2026-10-08 |
| QR | DONE | lib/features/qr/*, use-qr, pgTAP 008/009 | PR #1 merged |
| History | DONE | history_repository.dart, HistoryPage | |
| Settings (UC26) | DONE | settings_tab.dart, user_profile_repository.dart | user_name + terms (example.com mock) |
| Points (UC20–23) | DONE | purchase/cashout RPC+Edge, PointsPage, pgTAP 012/014 | Eligible cashout pgTAP; remote purchase + ineligible smoke; expiry RPC + cron scheduled |
| Server clock / session (K) | DONE | `get_server_time` RPC, lib/services/server_clock.dart | See `docs/decisions-k-server-time-auth.md` |

## Next items (ordered, one line each)
13. ~~RLS matrix pgTAP push~~ local commit `c49431b` (push when ready).
14. ~~Points eligible cashout + expiry tests~~ pgTAP `014`; `012` expiry unchanged.
15. ~~Remote-edge ops runbook~~ `docs/remote-edge-ops.md`, `set-remote-edge-secrets.ps1` (remote apply needs approval).
16. ~~Decision K~~ documented + Flutter/Edge wiring.

## Needs user decision
- H. Liquid-charge UI vs BatteryPainter.

## Decisions made (so they are not re-litigated)
- 2026-10-08 **K (ratified)**: `get_server_time` RPC; client offset + offline fallback; SDK auto-refresh + 5m pre-Edge `refreshSession`. Details: `docs/decisions-k-server-time-auth.md`.
- 2026-10-08 **J (ratified)**: Catalog `book_1000` / `material_500` / `cert_2000`; purchase COMPLETED mock; cashout min 1000, 10pt steps, fee 10%; eligibility = ≥7 SUCCESS + 7 days after `min(finished_at)`.
- 2026-10-07 A–M, E, G, C, L(c), etc. — see git history.
- 2026-10-05 FIFO points 3-month expiry (spec v5).

## Known issues / flaky tests
- Optional `POINT_EXPIRY_CRON_SECRET` / Vault `cron_bearer_point_expiry`: see `docs/remote-edge-ops.md`.
- `supabase test db` requires Docker Desktop running locally.
- Lock timeout → `temporary_unavailable` mapping still cross-cutting (unchanged).

## Remote state (project `jblaaeziumdpkccarjcd`, last confirmed 2026-10-09)
- Migrations through `20261008144133_get_server_time` on remote (`db push --include-all`).
- `CORS_ALLOWED_ORIGINS`: `http://localhost:3000`, `http://127.0.0.1:3000` (Edge secrets + full functions redeploy).
- PR #3 merged. Cron jobs ×3 on remote.
