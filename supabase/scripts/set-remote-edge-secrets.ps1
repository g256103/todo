param(
  [string]$ProjectRef = "jblaaeziumdpkccarjcd",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Set-SecretIfPresent([string]$Name) {
  $value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    Write-Host "skip: $Name (not set in environment)"
    return
  }
  $cmd = "supabase secrets set ${Name}=[REDACTED] --project-ref $ProjectRef"
  if ($DryRun) {
    Write-Host "dry-run: $cmd"
    return
  }
  Write-Host "set: $Name"
  supabase secrets set "${Name}=$value" --project-ref $ProjectRef
  if ($LASTEXITCODE -ne 0) { throw "secrets set failed for $Name" }
}

Write-Host "Project: $ProjectRef DryRun: $($DryRun.IsPresent)"

Set-SecretIfPresent -Name "CORS_ALLOWED_ORIGINS"
Set-SecretIfPresent -Name "POINT_EXPIRY_CRON_SECRET"

Write-Host "Done. Redeploy Edge functions that use updated secrets (see docs/remote-edge-ops.md)."
