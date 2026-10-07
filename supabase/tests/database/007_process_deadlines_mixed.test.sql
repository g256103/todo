begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, raw_user_meta_data) values
  ('ffffffff-0000-0000-0000-000000000601', '{"full_name":"Mixed Alice"}'),
  ('ffffffff-0000-0000-0000-000000000602', '{"full_name":"Mixed Bob"}');

insert into public.payments (id, user_id, amount, status, paid_at)
values
  ('ffffffff-1000-4000-8000-000000000601', 'ffffffff-0000-0000-0000-000000000601', 1500, 'SUCCESS', now()),
  ('ffffffff-1000-4000-8000-000000000602', 'ffffffff-0000-0000-0000-000000000602', 1500, 'SUCCESS', now());

insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at, updated_at
)
values
  ('ffffffff-2000-4000-8000-000000000601',
   'ffffffff-0000-0000-0000-000000000601',
   'ffffffff-1000-4000-8000-000000000601',
   1500, 'WAITING', now() - interval '1 minute', now() + interval '5 seconds',
   now() - interval '2 minutes', now() - interval '2 minutes'),
  ('ffffffff-2000-4000-8000-000000000602',
   'ffffffff-0000-0000-0000-000000000602',
   'ffffffff-1000-4000-8000-000000000602',
   1500, 'WAITING', now() - interval '1 hour 59 minutes', now() + interval '5 seconds',
   now() - interval '2 hours', now() - interval '2 hours');

select set_config(
  'request.jwt.claim.sub',
  'ffffffff-0000-0000-0000-000000000601',
  true
);
set local role authenticated;
select public.start_challenge(
  'ffffffff-2000-4000-8000-000000000601', 'fixture-007-start-601'
);
reset role;

select pg_sleep(6);

set local role service_role;

select lives_ok(
  $$select public.process_deadlines()$$,
  '期限切れ WAITING と IN_PROGRESS が混在しても例外なく完了する'
);

select is(
  (select status from public.challenges where id = 'ffffffff-2000-4000-8000-000000000601'),
  'FAILED',
  '期限切れ IN_PROGRESS は FAILED に遷移する'
);

select is(
  (select status from public.challenges where id = 'ffffffff-2000-4000-8000-000000000602'),
  'WAITING',
  '期限切れ WAITING は変化しない'
);

select is(
  (select finished_at is null from public.challenges where id = 'ffffffff-2000-4000-8000-000000000602'),
  true,
  '期限切れ WAITING の finished_at は NULL のまま'
);

select is(
  (select count(*)::integer from public.point_transactions
    where challenge_id = 'ffffffff-2000-4000-8000-000000000601' and type = 'GRANT'),
  1,
  'IN_PROGRESS の FAILED 化で GRANT が1件作成される'
);

select is(
  (select count(*)::integer from public.point_transactions
    where challenge_id = 'ffffffff-2000-4000-8000-000000000602' and type = 'GRANT'),
  0,
  'WAITING には GRANT が作成されない'
);

select is(
  (select available_points from public.points
    where user_id = 'ffffffff-0000-0000-0000-000000000602'),
  0,
  'WAITING ユーザーの保有ポイントは変化しない'
);

select is(
  public.process_deadlines(),
  0,
  '再度実行しても対象はなく0件'
);

reset role;

select * from finish();
rollback;
