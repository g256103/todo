# Remote Edge ops (CORS, cron secrets, deploy)

Runbook for project `jblaaeziumdpkccarjcd`. **Do not commit secret values.**

## Prerequisites

- Supabase CLI logged in: `supabase link --project-ref jblaaeziumdpkccarjcd`
- User approval for any command that changes remote (`db push`, `secrets set`, `functions deploy`)

## 1. Database: `get_server_time` RPC

After merge, apply new migrations:

```powershell
supabase db push --dry-run
# BLOCKED until approved:
supabase db push
```

## 2. Edge secrets (CORS + optional point-expiry cron)

`CORS_ALLOWED_ORIGINS` is read by `supabase/functions/_shared.ts` (comma-separated origins). Default when unset: `http://127.0.0.1:3000`, `http://localhost:3000`.

Optional: `POINT_EXPIRY_CRON_SECRET` for `process-point-expiry` only (else falls back to deadlines / auto-start secrets). See `docs/cron-scheduler.md`.

Helper (reads from **your** environment variables, never from repo):

```powershell
.\supabase\scripts\set-remote-edge-secrets.ps1 -DryRun
# After approval, same without -DryRun
```

Set locally before running (examples only):

```powershell
$env:CORS_ALLOWED_ORIGINS = "http://localhost:3000,http://127.0.0.1:3000,https://your-app.example"
# Optional:
$env:POINT_EXPIRY_CRON_SECRET = "<generate-random>"
```

Then redeploy user-facing Edge functions so they pick up secrets (at minimum functions that use `_shared.ts` CORS):

```powershell
supabase functions deploy purchase-points --project-ref jblaaeziumdpkccarjcd
supabase functions deploy cashout-points --project-ref jblaaeziumdpkccarjcd
supabase functions deploy complete-task --project-ref jblaaeziumdpkccarjcd
supabase functions deploy create-challenge --project-ref jblaaeziumdpkccarjcd
# ... other JWT-protected POST edges as needed
```

Cron adapters (`process-point-expiry`, etc.) do not use browser CORS; redeploy when cron secret changes.

## 3. Vault + pg_cron (optional dedicated expiry bearer)

If using a dedicated `POINT_EXPIRY_CRON_SECRET`, store matching bearer in Vault as `cron_bearer_point_expiry` and run `supabase/scripts/schedule-process-point-expiry-cron.sql` in the SQL editor. Details in `docs/cron-scheduler.md`.

## 4. Verification

- Local: `supabase test db` (includes `014_cashout_success`, `015_get_server_time`)
- Remote smoke: `.\supabase\scripts\remote-cashout-smoke.ps1` (ineligible 409); add `-AttemptEligibleCashout` when test user meets 7 SUCCESS + 7d
- Web: Flutter `--web-port=3000` and point purchase / cashout flows
