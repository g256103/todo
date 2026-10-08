begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, raw_user_meta_data) values
  ('eeeeeeee-0000-0000-0000-000000000601', '{"full_name":"Points Shop User"}');

insert into public.payments (id, user_id, amount, status, paid_at)
values
  ('eeeeeeee-1000-4000-8000-000000000601', 'eeeeeeee-0000-0000-0000-000000000601', 2000, 'SUCCESS', now());

insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at, updated_at
)
values
  ('eeeeeeee-2000-4000-8000-000000000601',
   'eeeeeeee-0000-0000-0000-000000000601',
   'eeeeeeee-1000-4000-8000-000000000601',
   2000, 'WAITING', now() - interval '1 minute', now() + interval '30 seconds',
   now() - interval '2 minutes', now() - interval '2 minutes');

select set_config(
  'request.jwt.claim.sub',
  'eeeeeeee-0000-0000-0000-000000000601',
  true
);
set local role authenticated;
select public.start_challenge(
  'eeeeeeee-2000-4000-8000-000000000601', 'fixture-012-start'
);
select pg_sleep(31);
reset role;

set local role service_role;
select public.process_deadlines();
reset role;

set local role authenticated;
select public.purchase_points('book_1000', 'idem-purchase-012');

select is(
  (select available_points from public.points
    where user_id = 'eeeeeeee-0000-0000-0000-000000000601'),
  1000,
  'purchase debits catalog price from balance'
);

select is(
  (select status from public.purchases
    where user_id = 'eeeeeeee-0000-0000-0000-000000000601'),
  'COMPLETED',
  'purchase row is COMPLETED immediately'
);

select throws_ok(
  $$select public.purchase_points('cert_2000', 'idem-purchase-fail')$$,
  'P0001',
  'insufficient_balance',
  'cannot purchase when balance is too low'
);

select throws_ok(
  $$select public.cashout_points(1000, 'idem-cashout-fail')$$,
  'P0001',
  'cashout_not_eligible',
  'cashout blocked without 7 successes and 7-day continuity'
);

select throws_ok(
  $$select public.cashout_points(500, 'idem-cashout-invalid')$$,
  'P0001',
  'invalid_points_used',
  'cashout requires at least 1000 points and multiple of 10'
);
reset role;

set session_replication_role = replica;
update public.point_transactions
   set expires_at = now() - interval '1 hour'
 where user_id = 'eeeeeeee-0000-0000-0000-000000000601'
   and type = 'GRANT';
set session_replication_role = default;

set local role service_role;
select is(
  public.process_point_expiry(),
  1,
  'expiry job processes expired grant rows'
);

select is(
  (select available_points from public.points
    where user_id = 'eeeeeeee-0000-0000-0000-000000000601'),
  0,
  'expired remaining balance is removed'
);

select is(
  (select count(*)::integer from public.point_transactions
    where user_id = 'eeeeeeee-0000-0000-0000-000000000601' and type = 'EXPIRE'),
  1,
  'EXPIRE ledger row is created'
);
reset role;

set local role authenticated;
select throws_ok(
  $$select public.process_point_expiry()$$,
  '42501',
  null,
  'authenticated cannot run expiry job'
);
reset role;

select * from finish();
rollback;
