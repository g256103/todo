-- Remote runbook only (Vault names must match docs/cron-scheduler.md).
-- Idempotent: drop existing job name if present.
select cron.unschedule(jobid)
  from cron.job
 where jobname = 'process-point-expiry-every-minute';

select cron.schedule(
  'process-point-expiry-every-minute',
  '* * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/process-point-expiry',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(
        (select decrypted_secret from vault.decrypted_secrets where name = 'cron_bearer_point_expiry'),
        (select decrypted_secret from vault.decrypted_secrets where name = 'cron_bearer_deadlines'),
        (select decrypted_secret from vault.decrypted_secrets where name = 'cron_bearer_auto_start')
      )
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);
