begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

insert into auth.users (id, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000201', '{"full_name":"Mock Payment Alice"}'),
  ('bbbbbbbb-0000-0000-0000-000000000202', '{"full_name":"Mock Payment Bob"}');

select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000201', true);

select lives_ok(
  $$select public.mock_payment_create(1000, 'mock-create-201')$$,
  'createが正常に完了する'
);

select is(
  (select count(*)::int from public.payments
    where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
      and amount = 1000
      and status = 'PENDING'),
  1,
  'PaymentはPENDINGで1件作成される'
);

select is(
  (select paid_at from public.payments
    where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
      and amount = 1000
      and status = 'PENDING'),
  null,
  'PENDINGのpaid_atはNULL'
);

select throws_ok($$select public.mock_payment_create(99, 'mock-create-202')$$,
  'P0001', 'invalid_amount', '100未満は拒否');
select throws_ok($$select public.mock_payment_create(5100, 'mock-create-203')$$,
  'P0001', 'invalid_amount', '5000超は拒否');
select throws_ok($$select public.mock_payment_create(1050, 'mock-create-204')$$,
  'P0001', 'invalid_amount', '100円単位でない金額は拒否');
select throws_ok($$select public.mock_payment_create(1000, ' ')$$,
  'P0001', 'invalid_idempotency_key', '空白keyは拒否');
select throws_ok($$select public.mock_payment_create(1000, ' mock-create-205')$$,
  'P0001', 'invalid_idempotency_key', '前後空白付きkeyは拒否');

select lives_ok(
  $$select public.mock_payment_create(1000, 'mock-create-201')$$,
  '同一key同一requestはreplayされる'
);
select throws_ok($$select public.mock_payment_create(1100, 'mock-create-201')$$,
  'P0001', 'idempotency_key_reused', '同一key別requestは拒否');
select throws_ok($$select public.mock_payment_success(
    (select id from public.payments
      where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
        and amount = 1000
        and status = 'PENDING'),
    'mock-create-201'
  )$$,
  'P0001', 'idempotency_key_reused', '別operationのkey再利用は拒否');

select lives_ok(
  $$select public.mock_payment_success(
    (select id from public.payments
      where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
        and amount = 1000
        and status = 'PENDING'),
    'mock-success-201'
  )$$,
  'PENDINGからSUCCESSへ遷移できる'
);

select is(
  (select status from public.payments
    where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
      and amount = 1000),
  'SUCCESS',
  'SUCCESS状態が保存される'
);
select isnt(
  (select paid_at from public.payments
    where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
      and amount = 1000),
  null,
  'SUCCESSではpaid_atが設定される'
);
select throws_ok($$select public.mock_payment_success(
    (select id from public.payments
      where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
        and amount = 1000),
    'mock-success-202'
  )$$,
  'P0001', 'payment_not_pending', 'SUCCESSの再SUCCESSは拒否');

select throws_ok($$select public.mock_payment_failure(
    (select id from public.payments
      where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
        and amount = 1000),
    'mock-failure-201'
  )$$,
  'P0001', 'payment_not_pending', 'SUCCESSのfailureは拒否');

select lives_ok(
  $$select public.mock_payment_create(1200, 'mock-failure-payment-201')$$,
  'failure対象Paymentを作成できる'
);
select lives_ok(
  $$select public.mock_payment_failure(
    (select id from public.payments
      where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
        and amount = 1200
        and status = 'PENDING'),
    'mock-failure-203'
  )$$,
  'PENDINGからFAILEDへ遷移できる'
);
select is(
  (select status from public.payments
    where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
      and amount = 1200),
  'FAILED',
  'FAILED状態が保存される'
);
select is(
  (select paid_at from public.payments
    where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
      and amount = 1200),
  null,
  'FAILEDのpaid_atはNULL'
);
select throws_ok($$select public.mock_payment_failure(
    (select id from public.payments
      where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
        and amount = 1200),
    'mock-failure-204'
  )$$,
  'P0001', 'payment_not_pending', 'FAILEDの再FAILEDは拒否');

select throws_ok($$select public.mock_payment_success(
    'ffffffff-0000-0000-0000-000000000999',
    'mock-success-203'
  )$$,
  'P0001', 'payment_not_found', '存在しないPaymentは拒否');

select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-000000000202', true);
select throws_ok($$select public.mock_payment_success(
    (select id from public.payments
      where user_id = 'aaaaaaaa-0000-0000-0000-000000000201'
        and amount = 1200),
    'mock-success-204'
  )$$,
  'P0001', 'payment_not_found', '他ユーザーのPaymentは拒否');

select is(
  (select count(*)::int from public.idempotency_keys
    where operation like 'mock-payment-%'),
  4,
  'Payment操作のidempotency recordが保存される'
);

select ok(pg_catalog.has_function_privilege(
  'authenticated',
  'public.mock_payment_create(integer,text)'::regprocedure,
  'EXECUTE'
), 'authenticatedはcreateを実行できる');
select ok(pg_catalog.has_function_privilege(
  'anon',
  'public.mock_payment_create(integer,text)'::regprocedure,
  'EXECUTE'
) = false, 'anonはcreateを実行できない');
select ok(pg_catalog.has_function_privilege(
  'public',
  'public.mock_payment_create(integer,text)'::regprocedure,
  'EXECUTE'
) = false, 'publicはcreateを実行できない');
select ok(pg_catalog.has_function_privilege(
  'service_role',
  'public.mock_payment_create(integer,text)'::regprocedure,
  'EXECUTE'
) = false, 'service_roleはcreateを実行できない');

select * from finish();
rollback;
