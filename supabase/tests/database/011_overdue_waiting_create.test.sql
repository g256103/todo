begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, raw_user_meta_data) values
  ('11111111-0000-0000-0000-000000000701', '{"full_name":"Overdue Waiting Alice"}'),
  ('11111111-0000-0000-0000-000000000702', '{"full_name":"Overdue Waiting Bob"}'),
  ('11111111-0000-0000-0000-000000000703', '{"full_name":"Overdue Waiting Carol"}');

insert into public.payments (id, user_id, amount, status, paid_at) values
  ('11111111-1000-4000-8000-000000000701', '11111111-0000-0000-0000-000000000701', 1000, 'SUCCESS', now()),
  ('11111111-1000-4000-8000-000000000702', '11111111-0000-0000-0000-000000000702', 1100, 'SUCCESS', now()),
  ('11111111-1000-4000-8000-000000000703', '11111111-0000-0000-0000-000000000703', 1200, 'SUCCESS', now()),
  ('11111111-1000-4000-8000-000000000704', '11111111-0000-0000-0000-000000000701', 1300, 'SUCCESS', now()),
  ('11111111-1000-4000-8000-000000000705', '11111111-0000-0000-0000-000000000702', 1400, 'SUCCESS', now()),
  ('11111111-1000-4000-8000-000000000706', '11111111-0000-0000-0000-000000000703', 1500, 'SUCCESS', now());

insert into public.tasks (id, user_id, name) values
  ('11111111-2000-4000-8000-000000000701', '11111111-0000-0000-0000-000000000701', 'Alice Task'),
  ('11111111-2000-4000-8000-000000000702', '11111111-0000-0000-0000-000000000702', 'Bob Task'),
  ('11111111-2000-4000-8000-000000000703', '11111111-0000-0000-0000-000000000703', 'Carol Task');

-- Alice: expired never-started WAITING (zombie)
insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at, updated_at
)
values (
  '11111111-3000-4000-8000-000000000701',
  '11111111-0000-0000-0000-000000000701',
  '11111111-1000-4000-8000-000000000701',
  1000, 'WAITING',
  now() - interval '2 days' + interval '5 minutes',
  now() - interval '1 day',
  now() - interval '2 days',
  now() - interval '2 days'
);

-- Bob: non-expired WAITING
insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at, updated_at
)
values (
  '11111111-3000-4000-8000-000000000702',
  '11111111-0000-0000-0000-000000000702',
  '11111111-1000-4000-8000-000000000702',
  1100, 'WAITING',
  now() - interval '1 minute',
  now() + interval '1 hour',
  now() - interval '2 minutes',
  now() - interval '2 minutes'
);

-- Carol: IN_PROGRESS (via start_challenge)
insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at, updated_at
)
values (
  '11111111-3000-4000-8000-000000000703',
  '11111111-0000-0000-0000-000000000703',
  '11111111-1000-4000-8000-000000000703',
  1200, 'WAITING',
  now() - interval '1 hour',
  now() + interval '1 hour',
  now() - interval '2 hours',
  now() - interval '2 hours'
);

insert into public.challenge_tasks (
  challenge_id, user_id, task_id, task_name_snapshot, sort_order, status
)
values (
  '11111111-3000-4000-8000-000000000703',
  '11111111-0000-0000-0000-000000000703',
  '11111111-2000-4000-8000-000000000703',
  'Carol Task',
  0,
  'INCOMPLETE'
);

select set_config(
  'request.jwt.claim.sub',
  '11111111-0000-0000-0000-000000000703',
  true
);
set local role authenticated;
select public.start_challenge(
  '11111111-3000-4000-8000-000000000703',
  'fixture-011-start-703'
);
reset role;

select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000701', true);
select lives_ok(
  $$select public.create_challenge(
      '11111111-1000-4000-8000-000000000704',
      array['11111111-2000-4000-8000-000000000701'::uuid],
      '{}'::uuid[],
      'create-after-overdue-waiting-701'
    )$$,
  '期限切れ WAITING があっても新規 Challenge を作成できる'
);

select is(
  (select count(*)::integer from public.challenges
    where user_id = '11111111-0000-0000-0000-000000000701'
      and status = 'WAITING'),
  2,
  'ユーザーは期限切れ WAITING と新規 WAITING を同時に持てる'
);

select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000702', true);
select throws_ok(
  $$select public.create_challenge(
      '11111111-1000-4000-8000-000000000705',
      array['11111111-2000-4000-8000-000000000702'::uuid],
      '{}'::uuid[],
      'create-blocked-active-waiting-702'
    )$$,
  'P0001',
  'active_challenge_exists',
  '期限内 WAITING がある場合は作成を拒否する'
);

select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000703', true);
select throws_ok(
  $$select public.create_challenge(
      '11111111-1000-4000-8000-000000000706',
      array['11111111-2000-4000-8000-000000000703'::uuid],
      '{}'::uuid[],
      'create-blocked-in-progress-703'
    )$$,
  'P0001',
  'active_challenge_exists',
  'IN_PROGRESS がある場合は作成を拒否する'
);

select is(
  (select status from public.challenges where id = '11111111-3000-4000-8000-000000000701'),
  'WAITING',
  '期限切れ WAITING は FAILED に遷移しない'
);

select throws_ok(
  $$update public.challenges
      set status = 'FAILED', finished_at = now(), started_at = now()
    where id = '11111111-3000-4000-8000-000000000701'$$,
  'P0001',
  null,
  'WAITING から FAILED への直接更新はトリガーで拒否される'
);

select * from finish();
rollback;
