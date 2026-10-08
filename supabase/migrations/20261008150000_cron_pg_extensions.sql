-- Cron scheduler: enable extensions only. Job schedule + Vault secrets: docs/cron-scheduler.md
-- (remote cron.schedule and Vault values require explicit user approval).

create extension if not exists pg_cron with schema pg_catalog;

create extension if not exists pg_net with schema extensions;
