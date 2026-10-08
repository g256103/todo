begin;
select plan(2);

select ok(
  exists (
    select 1
      from pg_extension
     where extname = 'pg_cron'
  ),
  'pg_cron extension is installed'
);

select ok(
  exists (
    select 1
      from pg_extension
     where extname = 'pg_net'
  ),
  'pg_net extension is installed'
);

select * from finish();
rollback;
