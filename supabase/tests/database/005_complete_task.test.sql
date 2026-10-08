begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

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
  'dddddddd-2000-4000-8000-000000000401', 'fixture-005-start-401'
);
select set_config(
  'request.jwt.claim.sub',
  'eeeeeeee-0000-0000-0000-000000000402',
  true
);
select public.start_challenge(
  'eeeeeeee-2000-4000-8000-000000000402', 'fixture-005-start-402'
);
select pg_sleep(6);
select set_config('request.jwt.claim.sub', '', true);

-- 未認証は失敗
select throws_ok(
  $$select public.complete_task(
    'dddddddd-3000-4000-8000-000000000401', 'complete-401-unauth'
  )$$,
  'P0001',
  'unauthorized',
  '未認証呼び出しは拒否される'
);

-- Alice として認証
select set_config(
  'request.jwt.claim.sub',
  'dddddddd-0000-0000-0000-000000000401',
  true
);

-- 他ユーザーのタスクは not found
select throws_ok(
  $$select public.complete_task(
    'eeeeeeee-3000-4000-8000-000000000401', 'complete-401-other'
  )$$,
  'P0001',
  'task_not_found',
  '他ユーザーのタスクはnot found'
);

-- 1件目のタスク完了
select is(
  (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000401', 'complete-401-1'
  )->>'result'),
  'completed',
  'Alice Task 1 を完了できる'
);

select ok(
  not (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000401', 'complete-401-1'
  ) ? 'refunded'),
  '途中完了のレスポンスに refunded は含めない'
);

select is(
  (select status from public.challenge_tasks
    where id = 'dddddddd-3000-4000-8000-000000000401'),
  'COMPLETED',
  'タスク1はCOMPLETEDになる'
);

select is(
  (select status from public.challenges
    where id = 'dddddddd-2000-4000-8000-000000000401'),
  'IN_PROGRESS',
  'タスク2が未完了のためチャレンジはまだIN_PROGRESS'
);

-- 冪等性テスト: 同一キー同一リクエスト
select is(
  (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000401', 'complete-401-1'
  )->>'result'),
  'completed',
  '同一キー・同一リクエストは保存済みレスポンスを返す'
);

-- 別キーで完了済みタスクを呼び出した場合
select is(
  (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000401', 'complete-401-1-again'
  )->>'result'),
  'already_completed',
  '別キーでも完了済みタスクはalready_completedを返す'
);

select is(
  (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000402', 'complete-401-2'
  )->>'result'),
  'challenge_success',
  '最終タスク完了は challenge_success を返す'
);

select is(
  (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000402', 'complete-401-2'
  )->>'refunded'),
  'true',
  'challenge_success に refunded: true'
);

select is(
  (select public.complete_task(
    'dddddddd-3000-4000-8000-000000000402', 'complete-401-2'
  )->>'refund_amount'),
  '1000',
  'refund_amount は challenges.amount と同額'
);

select is(
  (select status from public.challenges
    where id = 'dddddddd-2000-4000-8000-000000000401'),
  'SUCCESS',
  '全タスク完了によりチャレンジが自動的にSUCCESSになる'
);

select isnt(
  (select finished_at from public.challenges
    where id = 'dddddddd-2000-4000-8000-000000000401'),
  null,
  'finished_atが設定される'
);

select isnt(
  (select refunded_at from public.challenges
    where id = 'dddddddd-2000-4000-8000-000000000401'),
  null,
  'SUCCESS 時に refunded_at が設定される'
);

select is(
  (select status from public.payments
    where id = 'dddddddd-1000-4000-8000-000000000401'),
  'SUCCESS',
  'モック返金後も payments.status は SUCCESS を維持'
);

-- Bob として認証して期限切れチャレンジのタスク完了
select set_config(
  'request.jwt.claim.sub',
  'eeeeeeee-0000-0000-0000-000000000402',
  true
);

select throws_ok(
  $$select public.complete_task(
    'eeeeeeee-3000-4000-8000-000000000401', 'complete-402-expired'
  )$$,
  'P0001',
  'deadline_exceeded',
  '期限超過後のタスク完了は拒否される'
);

-- idempotency key 再利用
select throws_ok(
  $$select public.complete_task(
    'eeeeeeee-3000-4000-8000-000000000401', 'complete-401-1'
  )$$,
  'P0001',
  'deadline_exceeded',
  'deadline超過が先に評価される、またはキー検証'
);

select * from finish();
rollback;
