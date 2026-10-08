param([switch]$AttemptEligibleCashout)

# Remote cashout smoke (stdout: JSON only; no secrets).
# - Always tests ineligible cashout (409) when user lacks 7 SUCCESS + 7 days.
# - Tests successful cashout only when -AttemptEligibleCashout and user already eligible.
$ErrorActionPreference = "Stop"

$ProjectRef = "jblaaeziumdpkccarjcd"
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$EnvFile = Join-Path $Root ".env"
if (-not (Test-Path $EnvFile)) { throw "Missing .env" }
Get-Content $EnvFile | ForEach-Object {
  if ($_ -match "^\s*([^#=]+)=(.*)$") {
    Set-Item -Path "env:$($matches[1].Trim())" -Value $matches[2].Trim()
  }
}
if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) {
  throw "SUPABASE_URL / SUPABASE_ANON_KEY required in .env"
}
$Base = $env:SUPABASE_URL.TrimEnd("/")

function Invoke-SupabaseCli([string[]]$CliArgs) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $lines = & supabase @CliArgs 2>&1 | ForEach-Object {
      if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.ToString() } else { "$_" }
    } | Where-Object {
      $_ -and $_ -notmatch "Supabase CLI is available" -and $_ -notmatch "We recommend updating"
    }
    return ($lines | Out-String)
  } finally {
    $ErrorActionPreference = $prev
  }
}

function Invoke-DbQuery([string]$Sql) {
  $out = Invoke-SupabaseCli @("db", "query", "--linked", $Sql)
  $start = $out.IndexOf("{")
  $end = $out.LastIndexOf("}")
  if ($start -lt 0 -or $end -le $start) { throw "db query parse failed" }
  $doc = $out.Substring($start, $end - $start + 1) | ConvertFrom-Json
  if ($null -eq $doc.rows) { return @() }
  return @($doc.rows)
}

function Get-ServiceRoleKey {
  if ($env:SUPABASE_SERVICE_ROLE_KEY) {
    return $env:SUPABASE_SERVICE_ROLE_KEY
  }
  $raw = Invoke-SupabaseCli @("projects", "api-keys", "--project-ref", $ProjectRef, "-o", "json")
  $start = $raw.IndexOf("[")
  $end = $raw.LastIndexOf("]")
  if ($start -lt 0 -or $end -le $start) { throw "api-keys output missing JSON array" }
  $keys = $raw.Substring($start, $end - $start + 1) | ConvertFrom-Json
  if ($keys -isnot [System.Array]) { $keys = @($keys) }
  foreach ($k in $keys) {
    if ($k.name -eq "service_role" -and $k.api_key) { return $k.api_key }
  }
  foreach ($k in $keys) {
    if (-not $k.api_key -or $k.api_key -notmatch '^eyJ') { continue }
    $parts = $k.api_key.Split(".")
    if ($parts.Length -lt 2) { continue }
    $pad = $parts[1] + ("=" * ((4 - ($parts[1].Length % 4)) % 4))
    $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pad))
    if ($json -match '"role"\s*:\s*"service_role"') { return $k.api_key }
  }
  throw "service_role key not found (set SUPABASE_SERVICE_ROLE_KEY in .env for smoke)"
}

function Get-UserAccessToken([string]$ServiceRole, [string]$UserId, [string]$Email) {
  $adminHeaders = @{
    apikey         = $ServiceRole
    Authorization  = "Bearer $ServiceRole"
    "Content-Type" = "application/json"
  }
  $smokePassword = "SmokeCashout-" + [guid]::NewGuid().ToString("N")
  Invoke-RestMethod -Uri "$Base/auth/v1/admin/users/$UserId" -Method Put -Headers $adminHeaders -Body (@{
      password      = $smokePassword
      email_confirm = $true
    } | ConvertTo-Json) | Out-Null
  $anonHeaders = @{
    apikey         = $env:SUPABASE_ANON_KEY
    Authorization  = "Bearer $env:SUPABASE_ANON_KEY"
    "Content-Type" = "application/json"
  }
  $session = Invoke-RestMethod -Uri "$Base/auth/v1/token?grant_type=password" -Method Post -Headers $anonHeaders -Body (@{
      email    = $Email
      password = $smokePassword
    } | ConvertTo-Json)
  return $session.access_token
}

function Invoke-Edge([string]$Name, [string]$AccessToken, [hashtable]$Body) {
  $headers = @{
    apikey         = $env:SUPABASE_ANON_KEY
    Authorization  = "Bearer $AccessToken"
    "Content-Type" = "application/json"
  }
  try {
    $resp = Invoke-WebRequest -Uri "$Base/functions/v1/$Name" -Method Post -Headers $headers -Body ($Body | ConvertTo-Json -Compress) -UseBasicParsing
    $parsed = $null
    if ($resp.Content) { $parsed = $resp.Content | ConvertFrom-Json }
    return @{ status = [int]$resp.StatusCode; body = $parsed; raw = $resp.Content }
  } catch {
    $r = $_.Exception.Response
    if ($r) {
      $reader = New-Object System.IO.StreamReader($r.GetResponseStream())
      $text = $reader.ReadToEnd()
      $parsed = $null
      if ($text) { try { $parsed = $text | ConvertFrom-Json } catch {} }
      return @{ status = [int]$r.StatusCode; body = $parsed; raw = $text }
    }
    throw
  }
}

$summary = [ordered]@{ errors = @(); ineligible = @{}; eligible = @{} }

try {
  $serviceRole = Get-ServiceRoleKey
  $users = @(Invoke-DbQuery "select id::text as id, email from auth.users order by created_at desc limit 1;")
  if ($users.Count -lt 1) { throw "No auth.users" }
  $userId = $users[0].id
  $email = $users[0].email
  $token = Get-UserAccessToken $serviceRole $userId $email

  $stats = Invoke-DbQuery @"
select
  (select coalesce(available_points, 0) from public.points where user_id = '$userId') as available_points,
  (select count(*)::int from public.challenges where user_id = '$userId' and status = 'SUCCESS') as success_count,
  (select min(finished_at) from public.challenges where user_id = '$userId' and status = 'SUCCESS') as first_success
"@
  $summary.user = @{
    id            = $userId
    available_pts = $stats[0].available_points
    success_count = $stats[0].success_count
    first_success = $stats[0].first_success
  }

  $idem = "smoke-cashout-ineligible-" + [guid]::NewGuid().ToString()
  $bad = Invoke-Edge "cashout-points" $token @{ points_used = 1000; idempotency_key = $idem }
  $summary.ineligible.status = $bad.status
  $summary.ineligible.error_code = $bad.body.error_code
  $summary.ineligible.ok = ($bad.status -eq 409 -and $bad.body.error_code -eq "cashout_not_eligible")

  if ($AttemptEligibleCashout) {
    $avail = [int]$stats[0].available_points
    $sc = [int]$stats[0].success_count
    if ($sc -lt 7 -or $avail -lt 1000) {
      $summary.eligible.skip_reason = "need success_count>=7 and available_points>=1000"
    } else {
      $idem2 = "smoke-cashout-ok-" + [guid]::NewGuid().ToString()
      $ok = Invoke-Edge "cashout-points" $token @{ points_used = 1000; idempotency_key = $idem2 }
      $summary.eligible.status = $ok.status
      $summary.eligible.result = $ok.body.result
      $summary.eligible.cash_amount = $ok.body.cashout.cash_amount
      $summary.eligible.ok = ($ok.status -eq 200 -and $ok.body.result -eq "completed")
    }
  }
} catch {
  $summary.errors += $_.Exception.Message
}

$summary | ConvertTo-Json -Depth 6
