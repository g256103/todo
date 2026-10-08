begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, raw_user_meta_data) values
  ('dddddddd-0000-0000-0000-000000000501', '{"full_name":"UseQR Alice"}'),
  ('eeeeeeee-0000-0000-0000-000000000502', '{"full_name":"UseQR Bob"}');

insert into public.payments (id, user_id, amount, status, paid_at)
values
  ('dddddddd-1000-4000-8000-000000000501', 'dddddddd-0000-0000-0000-000000000501', 1000, 'SUCCESS', now()),
  ('eeeeeeee-1000-4000-8000-000000000502', 'eeeeeeee-0000-0000-0000-000000000502', 1000, 'SUCCESS', now());

insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at, updated_at
)
values
  ('dddddddd-2000-4000-8000-000000000501',
   'dddddddd-0000-0000-0000-000000000501',
   'dddddddd-1000-4000-8000-000000000501',
   1000, 'WAITING', now() - interval '9 minutes', now() + interval '1 hour',
   now() - interval '10 minutes', now() - interval '10 minutes'),
  ('eeeeeeee-2000-4000-8000-000000000502',
   'eeeeeeee-0000-0000-0000-000000000502',
   'eeeeeeee-1000-4000-8000-000000000502',
   1000, 'WAITING', now() - interval '9 minutes', now() + interval '1 hour',
   now() - interval '10 minutes', now() - interval '10 minutes');

insert into public.challenge_tasks (
  id, challenge_id, user_id, task_name_snapshot, sort_order, status
)
values
  ('dddddddd-3000-4000-8000-000000000501',
   'dddddddd-2000-4000-8000-000000000501',
   'dddddddd-0000-0000-0000-000000000501',
   'Alice Task', 1, 'INCOMPLETE'),
  ('eeeeeeee-3000-4000-8000-000000000502',
   'eeeeeeee-2000-4000-8000-000000000502',
   'eeeeeeee-0000-0000-0000-000000000502',
   'Bob Task', 1, 'INCOMPLETE');

select set_config(
  'request.jwt.claim.sub',
  'dddddddd-0000-0000-0000-000000000501',
  true
);
select public.start_challenge(
  'dddddddd-2000-4000-8000-000000000501', 'fixture-009-start-501'
);
select public.complete_task(
  'dddddddd-3000-4000-8000-000000000501', 'fixture-009-complete-501'
);

select set_config(
  'request.jwt.claim.sub',
  'eeeeeeee-0000-0000-0000-000000000502',
  true
);
select public.start_challenge(
  'eeeeeeee-2000-4000-8000-000000000502', 'fixture-009-start-502'
);

select set_config(
  'request.jwt.claim.sub',
  'dddddddd-0000-0000-0000-000000000501',
  true
);

select is(
  (select status from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000501'),
  'AVAILABLE',
  'fixture: Alice QR is AVAILABLE before use'
);

select lives_ok(
  $$select public.use_qr(
    (select token from public.qr_codes
      where challenge_id = 'dddddddd-2000-4000-8000-000000000501'),
    'use-009-1'
  )$$,
  'use_qr succeeds with valid token'
);

select is(
  (select public.use_qr(
    (select token from public.qr_codes
      where challenge_id = 'dddddddd-2000-4000-8000-000000000501'),
    'use-009-1'
  )->>'result'),
  'used',
  'first use returns result used'
);

select is(
  (select status from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000501'),
  'USED',
  'QR status becomes USED'
);

select isnt(
  (select used_at from public.qr_codes
    where challenge_id = 'dddddddd-2000-4000-8000-000000000501'),
  null,
  'used_at is set'
);

select is(
  (select public.use_qr(
    (select token from public.qr_codes
      where challenge_id = 'dddddddd-2000-4000-8000-000000000501'),
    'use-009-1'
  )->>'result'),
  'used',
  'same idempotency key replays stored response'
);

select throws_ok(
  $$select public.use_qr('other-fake-token', 'use-009-1')$$,
  'P0001',
  'idempotency_key_reused',
  'same key with different token hash is rejected'
);

select throws_ok(
  $$select public.use_qr(
    (select token from public.qr_codes
      where challenge_id = 'dddddddd-2000-4000-8000-000000000501'),
    'use-009-2'
  )$$,
  'P0001',
  'qr_already_used',
  'second use with different key is rejected'
);

select throws_ok(
  $$select public.use_qr('not-a-real-token', 'use-009-bad-token')$$,
  'P0001',
  'qr_not_found',
  'unknown token is qr_not_found'
);

select set_config(
  'request.jwt.claim.sub',
  'eeeeeeee-0000-0000-0000-000000000502',
  true
);

select throws_ok(
  $$select public.use_qr(
    (select token from public.qr_codes
      where challenge_id = 'dddddddd-2000-4000-8000-000000000501'),
    'use-009-bob-steal'
  )$$,
  'P0001',
  'qr_not_found',
  'other user cannot use Alice token'
);

select throws_ok(
  $$select public.use_qr('', 'use-009-empty')$$,
  'P0001',
  'invalid_token',
  'empty token is rejected'
);

select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$select public.use_qr('any-token', 'use-009-unauth')$$,
  'P0001',
  'unauthorized',
  'missing auth uid is unauthorized'
);

select set_config(
  'request.jwt.claim.sub',
  'eeeeeeee-0000-0000-0000-000000000502',
  true
);

select throws_ok(
  $$select public.use_qr('no-qr-yet-token', 'use-009-no-qr')$$,
  'P0001',
  'qr_not_found',
  'IN_PROGRESS challenge without qr row yields qr_not_found'
);

select ok(pg_catalog.has_function_privilege(
  'authenticated',
  'public.use_qr(text, text)'::regprocedure,
  'EXECUTE'
), 'authenticated can execute use_qr');

select ok(not pg_catalog.has_function_privilege(
  'anon',
  'public.use_qr(text, text)'::regprocedure,
  'EXECUTE'
), 'anon cannot execute use_qr');

select * from finish();
rollback;
