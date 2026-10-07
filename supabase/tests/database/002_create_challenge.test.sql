begin;
create extension if not exists pgtap with schema extensions;
select plan(29);

insert into auth.users (id, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000101', '{"full_name":"Create Challenge Alice"}'),
  ('bbbbbbbb-0000-0000-0000-000000000102', '{"full_name":"Create Challenge Bob"}'),
  ('cccccccc-0000-0000-0000-000000000103', '{"full_name":"Create Challenge Carol"}'),
  ('dddddddd-0000-0000-0000-000000000104', '{"full_name":"Create Challenge Dave"}');

insert into public.payments(id, user_id, amount, status, paid_at) values
  ('10000000-0000-0000-0000-000000000101', 'aaaaaaaa-0000-0000-0000-000000000101', 1000, 'SUCCESS', now()),
  ('10000000-0000-0000-0000-000000000102', 'bbbbbbbb-0000-0000-0000-000000000102', 1100, 'SUCCESS', now()),
  ('10000000-0000-0000-0000-000000000103', 'cccccccc-0000-0000-0000-000000000103', 1200, 'SUCCESS', now()),
  ('10000000-0000-0000-0000-000000000104', 'dddddddd-0000-0000-0000-000000000104', 1300, 'SUCCESS', now()),
  ('10000000-0000-0000-0000-000000000105', 'aaaaaaaa-0000-0000-0000-000000000101', 1400, 'PENDING', null),
  ('10000000-0000-0000-0000-000000000106', 'aaaaaaaa-0000-0000-0000-000000000101', 1500, 'FAILED', null),
  ('10000000-0000-0000-0000-000000000107', 'bbbbbbbb-0000-0000-0000-000000000102', 1600, 'SUCCESS', now()),
  ('10000000-0000-0000-0000-000000000108', 'dddddddd-0000-0000-0000-000000000104', 1700, 'SUCCESS', now());

insert into public.tasks(id, user_id, name) values
  ('20000000-0000-0000-0000-000000000101', 'aaaaaaaa-0000-0000-0000-000000000101', 'Alice A'),
  ('20000000-0000-0000-0000-000000000102', 'aaaaaaaa-0000-0000-0000-000000000101', 'Alice B'),
  ('20000000-0000-0000-0000-000000000103', 'bbbbbbbb-0000-0000-0000-000000000102', 'Bob Task'),
  ('20000000-0000-0000-0000-000000000104', 'cccccccc-0000-0000-0000-000000000103', 'Carol A'),
  ('20000000-0000-0000-0000-000000000105', 'cccccccc-0000-0000-0000-000000000103', 'Carol B'),
  ('20000000-0000-0000-0000-000000000106', 'dddddddd-0000-0000-0000-000000000104', 'Dave Task');

insert into public.routines(id, user_id, name) values
  ('30000000-0000-0000-0000-000000000101', 'aaaaaaaa-0000-0000-0000-000000000101', 'Alice Routine'),
  ('30000000-0000-0000-0000-000000000102', 'bbbbbbbb-0000-0000-0000-000000000102', 'Bob Routine'),
  ('30000000-0000-0000-0000-000000000103', 'cccccccc-0000-0000-0000-000000000103', 'Carol Routine');

insert into public.routine_tasks(routine_id, task_id, user_id, sort_order) values
  ('30000000-0000-0000-0000-000000000101', '20000000-0000-0000-0000-000000000102', 'aaaaaaaa-0000-0000-0000-000000000101', 0),
  ('30000000-0000-0000-0000-000000000101', '20000000-0000-0000-0000-000000000101', 'aaaaaaaa-0000-0000-0000-000000000101', 1),
  ('30000000-0000-0000-0000-000000000102', '20000000-0000-0000-0000-000000000103', 'bbbbbbbb-0000-0000-0000-000000000102', 0),
  ('30000000-0000-0000-0000-000000000103', '20000000-0000-0000-0000-000000000105', 'cccccccc-0000-0000-0000-000000000103', 0),
  ('30000000-0000-0000-0000-000000000103', '20000000-0000-0000-0000-000000000104', 'cccccccc-0000-0000-0000-000000000103', 1);

select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000101', true);
select lives_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000101',
      array['20000000-0000-0000-0000-000000000101'::uuid],
      '{}'::uuid[],
      'create-direct-101'
    )$$,
  'Task直接選択で作成できる'
);

select is(
  (select count(*)::int from public.challenge_tasks ct
    join public.challenges c on c.id = ct.challenge_id
   where c.payment_id = '10000000-0000-0000-0000-000000000101'),
  1,
  'Task直接選択でChallengeTaskが1件作成される'
);

select is(
  (select c.deadline - c.created_at
     from public.challenges c
    where c.payment_id = '10000000-0000-0000-0000-000000000101'),
  interval '24 hours',
  'deadlineはcreated_atから24時間後'
);

select is(
  (select c.auto_start_at - c.created_at
     from public.challenges c
    where c.payment_id = '10000000-0000-0000-0000-000000000101'),
  interval '5 minutes',
  'auto_start_atはcreated_atから5分後'
);

select is(
  (select ct.task_name_snapshot from public.challenge_tasks ct
    join public.challenges c on c.id = ct.challenge_id
   where c.payment_id = '10000000-0000-0000-0000-000000000101'),
  'Alice A',
  'task_name_snapshotが保存される'
);

select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-000000000102', true);
select lives_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000102',
      '{}'::uuid[],
      array['30000000-0000-0000-0000-000000000102'::uuid],
      'create-routine-102'
    )$$,
  'Routine選択で作成できる'
);

select set_config('request.jwt.claim.sub', 'cccccccc-0000-0000-0000-000000000103', true);
select lives_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000103',
      array[
        '20000000-0000-0000-0000-000000000105'::uuid,
        '20000000-0000-0000-0000-000000000104'::uuid
      ],
      array['30000000-0000-0000-0000-000000000103'::uuid],
      'create-both-103'
    )$$,
  'TaskとRoutineを同時選択できる'
);

select is(
  (select count(*)::int from public.challenge_tasks ct
    join public.challenges c on c.id = ct.challenge_id
   where c.payment_id = '10000000-0000-0000-0000-000000000103'),
  2,
  '重複TaskはChallenge内で1件に排除される'
);

select is(
  (select array_agg(ct.task_id order by ct.sort_order)::text
     from public.challenge_tasks ct
     join public.challenges c on c.id = ct.challenge_id
    where c.payment_id = '10000000-0000-0000-0000-000000000103'),
  '{20000000-0000-0000-0000-000000000104,20000000-0000-0000-0000-000000000105}',
  'Task順序は安定した内部順序で保存される'
);

select is(
  (select array_agg(ct.sort_order order by ct.sort_order)::text
     from public.challenge_tasks ct
     join public.challenges c on c.id = ct.challenge_id
    where c.payment_id = '10000000-0000-0000-0000-000000000103'),
  '{0,1}',
  'ChallengeTask.sort_orderは0始まりで連番になる'
);

select set_config('request.jwt.claim.sub', 'dddddddd-0000-0000-0000-000000000104', true);
insert into public.idempotency_keys (
  user_id, key, request_hash, operation, response
)
values (
  'dddddddd-0000-0000-0000-000000000104',
  'existing-other-operation',
  'existing-hash',
  'other-operation',
  '{"wrong":"response"}'::jsonb
), (
  'dddddddd-0000-0000-0000-000000000104',
  'existing-null-hash',
  null,
  'create-challenge',
  '{"wrong":"response"}'::jsonb
);

select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000108',
      array['20000000-0000-0000-0000-000000000106'::uuid],
      '{}'::uuid[],
      'existing-other-operation'
    )$$,
  'P0001',
  'idempotency_key_reused',
  '別Operationのidempotency行はcreate-challenge結果として返さない'
);

select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000108',
      array['20000000-0000-0000-0000-000000000106'::uuid],
      '{}'::uuid[],
      'existing-null-hash'
    )$$,
  'P0001',
  'idempotency_key_reused',
  'NULL request_hashの既存行は安全側に拒否する'
);

select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000104',
      '{}'::uuid[],
      '{}'::uuid[],
      'create-empty-104'
    )$$,
  'P0001',
  'no_tasks_selected',
  'Task 0件は拒否される'
);

select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000101', true);
select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000105',
      array['20000000-0000-0000-0000-000000000101'::uuid],
      '{}'::uuid[],
      'create-pending-105'
    )$$,
  'P0001',
  'payment_not_successful',
  'Payment PENDINGは拒否される'
);

select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000106',
      array['20000000-0000-0000-0000-000000000101'::uuid],
      '{}'::uuid[],
      'create-failed-106'
    )$$,
  'P0001',
  'payment_not_successful',
  'Payment FAILEDは拒否される'
);

select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000102',
      array['20000000-0000-0000-0000-000000000101'::uuid],
      '{}'::uuid[],
      'create-other-payment-107'
    )$$,
  'P0001',
  'payment_not_found',
  '他ユーザーのPaymentは見つからない扱いになる'
);

select set_config('request.jwt.claim.sub', 'dddddddd-0000-0000-0000-000000000104', true);
select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000104',
      array['20000000-0000-0000-0000-000000000101'::uuid],
      '{}'::uuid[],
      'create-other-task-108'
    )$$,
  'P0001',
  'task_not_found',
  '他ユーザーのTaskは拒否される'
);

select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000104',
      '{}'::uuid[],
      array['30000000-0000-0000-0000-000000000101'::uuid],
      'create-other-routine-109'
    )$$,
  'P0001',
  'routine_not_found',
  '他ユーザーのRoutineは拒否される'
);

select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000104',
      '{}'::uuid[],
      '{}'::uuid[],
      'create-no-task-110'
    )$$,
  'P0001',
  'no_tasks_selected',
  '最終Task 0件は拒否される'
);

select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000104',
      '{}'::uuid[],
      '{}'::uuid[],
      ''
    )$$,
  'P0001',
  'invalid_idempotency_key',
  '空のidempotency keyは拒否される'
);

select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-000000000102', true);
select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000107',
      array['20000000-0000-0000-0000-000000000103'::uuid],
      '{}'::uuid[],
      'create-active-111'
    )$$,
  'P0001',
  'active_challenge_exists',
  'active Challengeがある場合は拒否される'
);

select set_config('request.jwt.claim.sub', 'cccccccc-0000-0000-0000-000000000103', true);
select lives_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000103',
      array[
        '20000000-0000-0000-0000-000000000105'::uuid,
        '20000000-0000-0000-0000-000000000105'::uuid,
        '20000000-0000-0000-0000-000000000104'::uuid
      ],
      array['30000000-0000-0000-0000-000000000103'::uuid],
      'create-both-103'
    )$$,
  '配列順序を変えた同一Requestを再送できる'
);

select is(
  (
    select public.create_challenge(
      '10000000-0000-0000-0000-000000000103',
      array[
        '20000000-0000-0000-0000-000000000105'::uuid,
        '20000000-0000-0000-0000-000000000104'::uuid
      ],
      array['30000000-0000-0000-0000-000000000103'::uuid],
      'create-both-103'
    ) -> 'challenge' ->> 'id'
  ),
  (
    select c.id::text
      from public.challenges c
     where c.payment_id = '10000000-0000-0000-0000-000000000103'
  ),
  '同一key・同一Requestは保存済みChallengeを返す'
);

select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000103',
      '{}'::uuid[],
      array['30000000-0000-0000-0000-000000000101'::uuid],
      'create-both-103'
    )$$,
  'P0001',
  'idempotency_key_reused',
  '同一key・異なるRequestは拒否される'
);

create or replace function public._test_create_challenge_rollback()
returns trigger
language plpgsql
as $$
begin
  raise exception 'forced create_challenge rollback';
end;
$$;
create trigger _test_create_challenge_rollback
  before insert on public.idempotency_keys
  for each row execute function public._test_create_challenge_rollback();

select set_config('request.jwt.claim.sub', 'dddddddd-0000-0000-0000-000000000104', true);
select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000108',
      array['20000000-0000-0000-0000-000000000106'::uuid],
      '{}'::uuid[],
      'create-rollback-113'
    )$$,
  'P0001',
  'forced create_challenge rollback',
  'idempotency保存失敗時にTransaction全体が失敗する'
);

select is(
  (select count(*)::int
     from public.challenges
    where payment_id = '10000000-0000-0000-0000-000000000108'),
  0,
  'Challenge作成失敗時にChallengeが残らない'
);

select is(
  (select count(*)::int
     from public.challenge_tasks ct
    where ct.user_id = 'dddddddd-0000-0000-0000-000000000104'
      and ct.task_id = '20000000-0000-0000-0000-000000000106'),
  0,
  'idempotency保存失敗時にChallengeTaskが残らない'
);

select is(
  (select count(*)::int
     from public.idempotency_keys
    where user_id = 'dddddddd-0000-0000-0000-000000000104'
      and key = 'create-rollback-113'),
  0,
  'idempotency保存失敗時にidempotency行が残らない'
);

drop trigger _test_create_challenge_rollback on public.idempotency_keys;
drop function public._test_create_challenge_rollback();

select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select public.create_challenge(
      '10000000-0000-0000-0000-000000000104',
      array['20000000-0000-0000-0000-000000000101'::uuid],
      '{}'::uuid[],
      'create-unauthorized-112'
    )$$,
  'P0001',
  'unauthorized',
  '未認証は拒否される'
);

select * from finish();
rollback;
