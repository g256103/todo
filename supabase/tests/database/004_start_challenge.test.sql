begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000301', '{"full_name":"Start Alice"}'),
  ('bbbbbbbb-0000-0000-0000-000000000302', '{"full_name":"Start Bob"}'),
  ('cccccccc-0000-0000-0000-000000000303', '{"full_name":"Start Carol"}');

insert into public.payments (id, user_id, amount, status, paid_at)
values
  ('aaaaaaaa-1000-4000-8000-000000000301', 'aaaaaaaa-0000-0000-0000-000000000301', 1000, 'SUCCESS', now()),
  ('bbbbbbbb-1000-4000-8000-000000000302', 'bbbbbbbb-0000-0000-0000-000000000302', 1200, 'SUCCESS', now()),
  ('cccccccc-1000-4000-8000-000000000303', 'cccccccc-0000-0000-0000-000000000303', 1400, 'SUCCESS', now());

insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at,
  updated_at
)
values
  ('aaaaaaaa-2000-4000-8000-000000000301',
   'aaaaaaaa-0000-0000-0000-000000000301',
   'aaaaaaaa-1000-4000-8000-000000000301',
   1000, 'WAITING', now() - interval '1 minute', now() + interval '1 hour',
   now() - interval '2 minutes', now() - interval '2 minutes'),
  ('bbbbbbbb-2000-4000-8000-000000000302',
   'bbbbbbbb-0000-0000-0000-000000000302',
   'bbbbbbbb-1000-4000-8000-000000000302',
   1200, 'WAITING', now() - interval '1 minute', now() + interval '1 hour',
   now() - interval '2 minutes', now() - interval '2 minutes'),
  ('cccccccc-2000-4000-8000-000000000303',
   'cccccccc-0000-0000-0000-000000000303',
   'cccccccc-1000-4000-8000-000000000303',
   1400, 'WAITING', now() - interval '1 minute', now() + interval '1 hour',
   now() - interval '2 minutes', now() - interval '2 minutes');

select set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-0000-0000-0000-000000000301',
  true
);
select lives_ok(
  $$select public.start_challenge(
    'aaaaaaaa-2000-4000-8000-000000000301', 'start-301'
  )$$,
  'WAITINGからIN_PROGRESSへ開始できる'
);
select is(
  (select status from public.challenges
    where id = 'aaaaaaaa-2000-4000-8000-000000000301'),
  'IN_PROGRESS',
  '開始後の状態はIN_PROGRESS'
);
select isnt(
  (select started_at from public.challenges
    where id = 'aaaaaaaa-2000-4000-8000-000000000301'),
  null,
  'started_atはサーバー時刻で設定される'
);
select is(
  (select count(*)::int from public.idempotency_keys
    where user_id = 'aaaaaaaa-0000-0000-0000-000000000301'
      and operation = 'start-challenge'),
  1,
  'start-challengeのidempotency recordが保存される'
);
select lives_ok(
  $$select public.start_challenge(
    'aaaaaaaa-2000-4000-8000-000000000301', 'start-301'
  )$$,
  '同一key同一requestはreplayされる'
);
insert into public.idempotency_keys (
  user_id, key, request_hash, operation, resource_id, response
)
values (
  'aaaaaaaa-0000-0000-0000-000000000301',
  'cross-operation-301',
  'cross-operation-hash',
  'create-challenge',
  null,
  '{}'::jsonb
);
select throws_ok(
  $$select public.start_challenge(
    'aaaaaaaa-2000-4000-8000-000000000301', 'cross-operation-301'
  )$$,
  'P0001', 'idempotency_key_reused',
  '別operationのkey再利用は拒否'
);

select set_config(
  'request.jwt.claim.sub',
  'bbbbbbbb-0000-0000-0000-000000000302',
  true
);
select lives_ok(
  $$select public.start_challenge(
    'bbbbbbbb-2000-4000-8000-000000000302', 'start-302'
  )$$,
  '2件目を開始できる'
);
select is(
  (select status from public.challenges
    where id = 'bbbbbbbb-2000-4000-8000-000000000302'),
  'IN_PROGRESS',
  '2件目もIN_PROGRESSになる'
);
select throws_ok(
  $$select public.start_challenge(
    'aaaaaaaa-2000-4000-8000-000000000301', 'start-other'
  )$$,
  'P0001', 'challenge_not_found',
  '他ユーザーのChallengeは開始できない'
);

select set_config(
  'request.jwt.claim.sub',
  'cccccccc-0000-0000-0000-000000000303',
  true
);
select is(
  public.process_auto_start(),
  1,
  '自動開始RPCは期限内のWAITINGを開始する'
);
select is(
  (select status from public.challenges
    where id = 'cccccccc-2000-4000-8000-000000000303'),
  'IN_PROGRESS',
  '自動開始後の状態はIN_PROGRESS'
);

select ok(pg_catalog.has_function_privilege(
  'authenticated',
  'public.start_challenge(uuid,text)'::regprocedure,
  'EXECUTE'
), 'authenticatedはstartを実行できる');
select ok(not pg_catalog.has_function_privilege(
  'anon',
  'public.start_challenge(uuid,text)'::regprocedure,
  'EXECUTE'
), 'anonはstartを実行できない');
select ok(pg_catalog.has_function_privilege(
  'service_role',
  'public.process_auto_start()'::regprocedure,
  'EXECUTE'
), 'service_roleはauto-startを実行できる');
select ok(not pg_catalog.has_function_privilege(
  'authenticated',
  'public.process_auto_start()'::regprocedure,
  'EXECUTE'
), 'authenticatedはauto-startを実行できない');

select * from finish();
rollback;
