begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

insert into auth.users (id, raw_user_meta_data) values
  ('dddddddd-0000-0000-0000-000000000401', '{"full_name":"Complete Alice"}'),
  ('eeeeeeee-0000-0000-0000-000000000402', '{"full_name":"Complete Bob"}');

insert into public.payments (id, user_id, amount, status, paid_at)
values
  ('dddddddd-1000-4000-8000-000000000401', 'dddddddd-0000-0000-0000-000000000401', 1000, 'SUCCESS', now()),
  ('eeeeeeee-1000-4000-8000-000000000402', 'eeeeeeee-0000-0000-0000-000000000402', 1000, 'SUCCESS', now());

insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at, updated_at
)
values
  ('dddddddd-2000-4000-8000-000000000401',
   'dddddddd-0000-0000-0000-000000000401',
   'dddddddd-1000-4000-8000-000000000401',
   1000, 'WAITING', now() - interval '9 minutes', now() + interval '1 hour',
   now() - interval '10 minutes', now() - interval '10 minutes'),
  ('eeeeeeee-2000-4000-8000-000000000402',
   'eeeeeeee-0000-0000-0000-000000000402',
   'eeeeeeee-1000-4000-8000-000000000402',
   1000, 'WAITING', now() - interval '1 hour 59 minutes', now() + interval '5 seconds',
   now() - interval '2 hours', now() - interval '2 hours');

insert into public.challenge_tasks (
  id, challenge_id, user_id, task_name_snapshot, sort_order, status
)
values
  ('dddddddd-3000-4000-8000-000000000401',
   'dddddddd-2000-4000-8000-000000000401',
   'dddddddd-0000-0000-0000-000000000401',
   'Alice Task 1', 1, 'INCOMPLETE'),
  ('dddddddd-3000-4000-8000-000000000402',
   'dddddddd-2000-4000-8000-000000000401',
   'dddddddd-0000-0000-0000-000000000401',
   'Alice Task 2', 2, 'INCOMPLETE'),
  ('eeeeeeee-3000-4000-8000-000000000401',
   'eeeeeeee-2000-4000-8000-000000000402',
   'eeeeeeee-0000-0000-0000-000000000402',
   'Bob Task 1 (Expired)', 1, 'INCOMPLETE');

select set_config(
  'request.jwt.claim.sub',
  'dddddddd-0000-0000-0000-000000000401',
  true
);
select public.start_challenge(
  'dddddddd-2000-4000-8000-000000000401', 'fixture-008-start-401'
);
select set_config(
  'request.jwt.claim.sub',
  'eeeeeeee-0000-0000-0000-000000000402',
  true
);
select public.start_challenge(
  'eeeeeeee-2000-4000-8000-000000000402', 'fixture-008-start-402'
);
select pg_sleep(6);
select set_config('request.jwt.claim.sub', '', true);

select set_config(
  'request.jwt.claim.sub',
  'dddddddd-0000-0000-0000-000000000401',
  true
);

select lives_ok(
  $$select public.complete_task(
    'dddddddd-3000-4000-8000-000000000401', 'complete-008-1'
  )$$,
  'Alice Task 1 を完了できる'
);

select is(
  (select count(*)::int from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  0,
  '途中完了時点では qr_codes 行はない'
);

select lives_ok(
  $$select public.complete_task(
    'dddddddd-3000-4000-8000-000000000402', 'complete-008-2'
  )$$,
  'Alice Task 2 を完了して SUCCESS にできる'
);

select is(
  (select status from public.challenges
    where id = 'dddddddd-2000-4000-8000-000000000401'),
  'SUCCESS',
  '全タスク完了でチャレンジが SUCCESS'
);

select is(
  (select count(*)::int from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  1,
  'SUCCESS 時に qr_codes が1行作成される'
);

select is(
  (select status from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  'AVAILABLE',
  'QR は AVAILABLE で作成される'
);

select is(
  (select used_at from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  null,
  '作成直後は used_at は null'
);

select is(
  (select user_id from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  'dddddddd-0000-0000-0000-000000000401'::uuid,
  'qr_codes.user_id はチャレンジ所有者と一致'
);

select isnt(
  (select btrim(token) from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  '',
  'token は非空'
);

select is(
  (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000402', 'complete-008-2'
  )->>'result'),
  'challenge_success',
  '同一キー・同一リクエストは保存済みレスポンスを返す'
);

select is(
  (select count(*)::int from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  1,
  '冪等リプレイ後も qr_codes は1行'
);

select is(
  (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000401', 'complete-008-1-again'
  )->>'result'),
  'already_completed',
  '別キーで完了済みタスクは already_completed'
);

select is(
  (select count(*)::int from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  1,
  'already_completed 後も qr_codes は1行'
);

select ok(
  not (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000402', 'complete-008-2'
  ) ? 'token'),
  'complete_task レスポンスに token は含めない'
);

select set_config(
  'request.jwt.claim.sub',
  'eeeeeeee-0000-0000-0000-000000000402',
  true
);

select throws_ok(
  $$select public.complete_task(
    'eeeeeeee-3000-4000-8000-000000000401', 'complete-008-expired'
  )$$,
  'P0001',
  'deadline_exceeded',
  '期限超過後のタスク完了は拒否される'
);

select is(
  (select count(*)::int from public.qr_codes
    where challenge_id = 'eeeeeeee-2000-4000-8000-000000000402'),
  0,
  '期限超過で SUCCESS しないため Bob の qr_codes はない'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'dddddddd-0000-0000-0000-000000000401',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"dddddddd-0000-0000-0000-000000000401","role":"authenticated"}',
  true
);

select is(
  (select count(*)::int from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  1,
  'authenticated: 本人は自分の qr_codes を SELECT できる'
);

select set_config(
  'request.jwt.claim.sub',
  'eeeeeeee-0000-0000-0000-000000000402',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"eeeeeeee-0000-0000-0000-000000000402","role":"authenticated"}',
  true
);

select is(
  (select count(*)::int from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000401'),
  0,
  'authenticated: 他人の qr_codes は見えない'
);

reset role;

select ok(pg_catalog.has_function_privilege(
  'authenticated',
  'public.complete_task(uuid,text)'::regprocedure,
  'EXECUTE'
), 'authenticated は complete_task を実行できる');
select ok(not pg_catalog.has_function_privilege(
  'anon',
  'public.complete_task(uuid,text)'::regprocedure,
  'EXECUTE'
), 'anon は complete_task を実行できない');

select * from finish();
rollback;
