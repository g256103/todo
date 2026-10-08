# Invoke process-auto-start and process-deadlines on local Edge (functions serve).
# Prerequisites: supabase start; functions serve with --no-verify-jwt --env-file supabase/functions/.env

param(
  [string]$BaseUrl = "http://127.0.0.1:54321",
  [string]$CronSecret = $env:AUTO_START_CRON_SECRET,
  [string]$DeadlinesSecret = $env:DEADLINES_CRON_SECRET
)

if (-not $CronSecret) {
  Write-Error "Set AUTO_START_CRON_SECRET (env or supabase/functions/.env)."
  exit 1
}

if (-not $DeadlinesSecret) {
  $DeadlinesSecret = $CronSecret
}

$headers = @{
  Authorization = "Bearer $CronSecret"
  "Content-Type" = "application/json"
}

Write-Host "POST $BaseUrl/functions/v1/process-auto-start"
$auto = Invoke-RestMethod -Uri "$BaseUrl/functions/v1/process-auto-start" -Method POST -Headers $headers -Body "{}"
$auto | ConvertTo-Json -Compress

$headersDeadlines = @{
  Authorization = "Bearer $DeadlinesSecret"
  "Content-Type" = "application/json"
}

Write-Host "POST $BaseUrl/functions/v1/process-deadlines"
$deadlines = Invoke-RestMethod -Uri "$BaseUrl/functions/v1/process-deadlines" -Method POST -Headers $headersDeadlines -Body "{}"
$deadlines | ConvertTo-Json -Compress
