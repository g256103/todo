# Decision K — server time offset and session refresh

Ratified for MVP (system behavior; spec appendix A ⑯ / ⑰).

## ⑰ Server time offset

| Topic | Decision |
| --- | --- |
| API | RPC `public.get_server_time()` → `timestamptz` (`clock_timestamp()`). `GRANT EXECUTE` to `authenticated` only. |
| Client sync | On login (`TabbedHomePage` init) and on app resume; optional retry on next resume if RPC fails. |
| Offset model | `offset = serverTime + RTT/2 - clientUtcAtResponse`; `nowUtc = DateTime.now().toUtc() + offset`. |
| Offline / RPC failure | Keep last offset; if never synced, offset `0` (device UTC). UX guards only — server remains authoritative for deadlines and cashout eligibility. |
| Uses | 5s-before-deadline long-press guard (`BatteryHoldToCompleteTile`), points cashout progress UI (`CashoutProgress`). |

## ⑯ Session refresh

| Topic | Decision |
| --- | --- |
| Primary | `supabase_flutter` `autoRefreshToken: true` (explicit in `main.dart`). |
| Before Edge invoke | If access token expires within 5 minutes, call `auth.refreshSession()` once (`ensureFreshSession` in `SupabaseMockPaymentFunctionInvoker`). |
| On sign-out | `ServerClock.reset()` so the next user does not inherit offset. |
