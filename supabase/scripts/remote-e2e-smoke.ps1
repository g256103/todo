# Remote E2E smoke (stdout: JSON summary only; no secrets)
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
  if ($start -lt 0 -or $end -le $start) {
    throw "db query parse failed: no JSON object"
  }
  $doc = $out.Substring($start, $end - $start + 1) | ConvertFrom-Json
  if ($null -eq $doc.rows) { return @() }
  return @($doc.rows)
}

function Get-UserAccessToken([string]$ServiceRole, [string]$UserId, [string]$Email) {
  $adminHeaders = @{
    apikey         = $ServiceRole
    Authorization  = "Bearer $ServiceRole"
    "Content-Type" = "application/json"
  }
  $smokePassword = "SmokeE2E-" + [guid]::NewGuid().ToString("N")
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
  $token = $session.access_token
  if (-not $token) { throw "password grant missing access_token" }
  return $token
}

function Invoke-Edge(
  [string]$Name,
  [string]$AccessToken,
  [hashtable]$Body
) {
  $headers = @{
    apikey         = $env:SUPABASE_ANON_KEY
    Authorization  = "Bearer $AccessToken"
    "Content-Type" = "application/json"
  }
  try {
    $resp = Invoke-WebRequest -Uri "$Base/functions/v1/$Name" -Method Post -Headers $headers -Body ($Body | ConvertTo-Json -Compress) -UseBasicParsing
    $parsed = $null
    if ($resp.Content) {
      $parsed = $resp.Content | ConvertFrom-Json
    }
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

function New-Idem { return ("smoke-" + [guid]::NewGuid().ToString()) }

$summary = [ordered]@{
  success_path = @{}
  failed_path  = @{}
  cron         = @{}
  errors       = @()
}

try {
  $serviceRole = Get-ServiceRoleKey
  $users = @(Invoke-DbQuery "select u.id::text as id, u.email from auth.users u inner join auth.identities i on i.user_id = u.id and i.provider = 'google' order by u.created_at desc limit 1;")
  if ($users.Count -lt 1) {
    $users = @(Invoke-DbQuery "select id::text as id, email from auth.users order by created_at desc limit 1;")
  }
  if ($users.Count -lt 1) { throw "No auth.users row for smoke" }
  $userId = $users[0].id
  $email = $users[0].email
  $token = Get-UserAccessToken $serviceRole $userId $email

  $inProgress = Invoke-DbQuery "select id::text as id from public.challenges where user_id = '$userId' and status = 'IN_PROGRESS' limit 1;"
  if ($inProgress -and $inProgress.Count -gt 0) {
    $summary.success_path.skip_reason = "existing IN_PROGRESS challenge $($inProgress[0].id)"
  } else {
    $tasks = @(Invoke-DbQuery "select id::text as id from public.tasks where user_id = '$userId' order by created_at desc limit 1;")
    if ($tasks.Count -lt 1) {
      Invoke-SupabaseCli @(
        "db", "query", "--linked",
        "insert into public.tasks (user_id, name) values ('$userId', 'smoke-e2e-task') returning id::text as id;"
      ) | Out-Null
      $tasks = @(Invoke-DbQuery "select id::text as id from public.tasks where user_id = '$userId' and name = 'smoke-e2e-task' limit 1;")
    }
    if ($tasks.Count -lt 1) { throw "No tasks for user" }
    $taskId = $tasks[0].id

    $payCreate = Invoke-Edge "mock-payment-create" $token @{ amount = 1000; idempotency_key = (New-Idem) }
    $summary.success_path.mock_payment_create_status = $payCreate.status
    if ($payCreate.status -notin 200, 201) { throw "mock-payment-create failed: $($payCreate.raw)" }
    $paymentId = $payCreate.body.payment.id

    $payOk = Invoke-Edge "mock-payment-success" $token @{ payment_id = $paymentId; idempotency_key = (New-Idem) }
    $summary.success_path.mock_payment_success_status = $payOk.status
    if ($payOk.status -ne 200) { throw "mock-payment-success failed: $($payOk.raw)" }

    $create = Invoke-Edge "create-challenge" $token @{
      payment_id      = $paymentId
      task_ids        = @($taskId)
      routine_ids     = @()
      idempotency_key = (New-Idem)
    }
    $summary.success_path.create_challenge_status = $create.status
    if ($create.status -notin 200, 201) { throw "create-challenge failed: $($create.raw)" }
    $challengeId = $create.body.challenge.id

    $start = Invoke-Edge "start-challenge" $token @{
      challenge_id    = $challengeId
      idempotency_key = (New-Idem)
    }
    $summary.success_path.start_challenge_status = $start.status
    if ($start.status -ne 200) { throw "start-challenge failed: $($start.raw)" }

    $ctRows = Invoke-DbQuery "select id::text as id from public.challenge_tasks where challenge_id = '$challengeId' and user_id = '$userId' order by sort_order limit 1;"
    $ctId = $ctRows[0].id

    $complete = Invoke-Edge "complete-task" $token @{
      challenge_task_id = $ctId
      idempotency_key   = (New-Idem)
    }
    $summary.success_path.complete_task_status = $complete.status
    $summary.success_path.complete_task_result = $complete.body.result
    $summary.success_path.refunded = $complete.body.refunded
    $summary.success_path.refund_amount = $complete.body.refund_amount
    $summary.success_path.challenge_status = $complete.body.challenge_status

    $chRow = Invoke-DbQuery "select status, refunded_at is not null as refunded_at_set from public.challenges where id = '$challengeId';"
    $summary.success_path.db_challenge_status = $chRow[0].status
    $summary.success_path.db_refunded_at_set = $chRow[0].refunded_at_set
  }

  # FAILED path: separate challenge, backdate deadline, wait for cron
  $inProgress2 = Invoke-DbQuery "select id::text as id from public.challenges where user_id = '$userId' and status = 'IN_PROGRESS' limit 1;"
  if ($inProgress2 -and $inProgress2.Count -gt 0) {
    $summary.failed_path.skip_reason = "IN_PROGRESS still active; cannot create another"
  } else {
    $tasks = @(Invoke-DbQuery "select id::text as id from public.tasks where user_id = '$userId' order by created_at desc limit 1;")
    if ($tasks.Count -lt 1) {
      Invoke-SupabaseCli @(
        "db", "query", "--linked",
        "insert into public.tasks (user_id, name) values ('$userId', 'smoke-e2e-task-fail') returning id;"
      ) | Out-Null
      $tasks = @(Invoke-DbQuery "select id::text as id from public.tasks where user_id = '$userId' and name = 'smoke-e2e-task-fail' limit 1;")
    }
    $taskId = $tasks[0].id
    $payCreate2 = Invoke-Edge "mock-payment-create" $token @{ amount = 1000; idempotency_key = (New-Idem) }
    if ($payCreate2.status -notin 200, 201) { throw "mock-payment-create (fail path) status $($payCreate2.status)" }
    $paymentId2 = $payCreate2.body.payment.id
    Invoke-Edge "mock-payment-success" $token @{ payment_id = $paymentId2; idempotency_key = (New-Idem) } | Out-Null
    $create2 = Invoke-Edge "create-challenge" $token @{
      payment_id      = $paymentId2
      task_ids        = @($taskId)
      routine_ids     = @()
      idempotency_key = (New-Idem)
    }
    $failChallengeId = $create2.body.challenge.id
    Invoke-Edge "start-challenge" $token @{
      challenge_id    = $failChallengeId
      idempotency_key = (New-Idem)
    } | Out-Null
    Invoke-SupabaseCli @(
      "db", "query", "--linked",
      "update public.challenges set deadline = now() - interval '2 minutes' where id = '$failChallengeId' and status = 'IN_PROGRESS';"
    ) | Out-Null
    $summary.failed_path.challenge_id = $failChallengeId
    $summary.failed_path.deadline_backdated = $true
    Start-Sleep -Seconds 75
    $failRow = Invoke-DbQuery "select status from public.challenges where id = '$failChallengeId';"
    $summary.failed_path.db_status_after_cron = $failRow[0].status
    $pts = Invoke-DbQuery "select count(*)::int as n from public.point_transactions pt join public.challenges c on c.id = pt.challenge_id where c.id = '$failChallengeId';"
    $summary.failed_path.point_transaction_count = $pts[0].n
  }

  $jobs = Invoke-DbQuery "select jobname, schedule, active from cron.job where jobname like 'process-%' order by jobname;"
  $summary.cron.jobs = $jobs
  $runs = Invoke-DbQuery "select j.jobname, d.status, d.return_message, d.start_time from cron.job_run_details d join cron.job j on j.jobid = d.jobid where j.jobname like 'process-%' order by d.start_time desc limit 6;"
  $summary.cron.recent_runs = $runs
  $http = Invoke-DbQuery "select status_code, left(coalesce(error_msg, ''), 120) as error_msg, created from net._http_response order by created desc limit 6;"
  $summary.cron.recent_http = $http
} catch {
  $summary.errors += $_.Exception.Message
  if ($_.InvocationInfo) {
    $summary.errors += ("at " + $_.InvocationInfo.PositionMessage)
  }
}

$summary | ConvertTo-Json -Depth 8
