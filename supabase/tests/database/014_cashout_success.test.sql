begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (id, raw_user_meta_data) values
  ('77777777-0000-0000-0000-000000000701', '{"full_name":"Cashout Eligible"}');

set local role service_role;

do $seed_successes$
declare
  i integer;
  v_payment_id uuid;
  v_challenge_id uuid;
  v_task_id uuid;
begin
  for i in 1..7 loop
    v_payment_id := ('77777777-1000-4000-8000-' || lpad(i::text, 12, '0'))::uuid;
    v_challenge_id := ('77777777-2000-4000-8000-' || lpad(i::text, 12, '0'))::uuid;
    v_task_id := ('77777777-3000-4000-8000-' || lpad(i::text, 12, '0'))::uuid;

    insert into public.payments (id, user_id, amount, status, paid_at)
    values (
      v_payment_id,
      '77777777-0000-0000-0000-000000000701',
      1000 + (i - 1) * 100,
      'SUCCESS',
      now() - interval '10 days'
    );

    insert into public.challenges (
      id, user_id, payment_id, amount, status,
      auto_start_at, deadline, created_at, updated_at
    )
    values (
      v_challenge_id,
      '77777777-0000-0000-0000-000000000701',
      v_payment_id,
      1000 + (i - 1) * 100,
      'WAITING',
      now() - interval '10 days',
      now() - interval '7 days',
      now() - interval '11 days',
      now() - interval '11 days'
    );

    insert into public.challenge_tasks (
      id, challenge_id, user_id, task_name_snapshot, sort_order, status
    )
    values (
      v_task_id,
      v_challenge_id,
      '77777777-0000-0000-0000-000000000701',
      'Cashout fixture task',
      1,
      'INCOMPLETE'
    );

    update public.challenges
       set status = 'IN_PROGRESS',
           started_at = now() - interval '9 days 30 minutes',
           updated_at = now() - interval '9 days 30 minutes'
     where id = v_challenge_id;

    update public.challenge_tasks
       set status = 'COMPLETED',
           completed_at = now() - interval '9 days',
           updated_at = now() - interval '9 days'
     where id = v_task_id;

    update public.challenges
       set status = 'SUCCESS',
           finished_at = now() - interval '8 days',
           refunded_at = now() - interval '8 days',
           updated_at = now() - interval '8 days'
     where id = v_challenge_id;
  end loop;
end;
$seed_successes$;

insert into public.payments (id, user_id, amount, status, paid_at)
values (
  '77777777-1000-4000-8000-000000000708',
  '77777777-0000-0000-0000-000000000701',
  2000,
  'SUCCESS',
  now()
);

insert into public.challenges (
  id, user_id, payment_id, amount, status,
  auto_start_at, deadline, created_at, updated_at
)
values (
  '77777777-2000-4000-8000-000000000708',
  '77777777-0000-0000-0000-000000000701',
  '77777777-1000-4000-8000-000000000708',
  2000,
  'WAITING',
  now() - interval '1 minute',
  now() + interval '30 seconds',
  now() - interval '2 minutes',
  now() - interval '2 minutes'
);

insert into public.challenge_tasks (
  id, challenge_id, user_id, task_name_snapshot, sort_order, status
)
values (
  '77777777-3000-4000-8000-000000000708',
  '77777777-2000-4000-8000-000000000708',
  '77777777-0000-0000-0000-000000000701',
  'Points grant fixture',
  1,
  'INCOMPLETE'
);

select set_config(
  'request.jwt.claim.sub',
  '77777777-0000-0000-0000-000000000701',
  true
);
set local role authenticated;
select public.start_challenge(
  '77777777-2000-4000-8000-000000000708',
  'fixture-014-start-grant'
);
select pg_sleep(31);
reset role;
set local role service_role;
select public.process_deadlines();
reset role;

select set_config(
  'request.jwt.claim.sub',
  '77777777-0000-0000-0000-000000000701',
  true
);
set local role authenticated;

select is(
  public.cashout_points(1000, 'idem-cashout-014-success') ->> 'result',
  'completed',
  'eligible user can cash out 1000 points'
);

select is(
  (select cash_amount from public.cashouts
    where user_id = '77777777-0000-0000-0000-000000000701'),
  900,
  'cash_amount is points_used minus 10% fee'
);

select is(
  (select available_points from public.points
    where user_id = '77777777-0000-0000-0000-000000000701'),
  1000,
  'balance debited after cashout'
);

select is(
  public.cashout_points(1000, 'idem-cashout-014-success') ->> 'result',
  'completed',
  'idempotent replay returns stored cashout response'
);

select throws_ok(
  $$select public.cashout_points(2000, 'idem-cashout-014-second')$$,
  'P0001',
  'insufficient_balance',
  'cannot cash out more than available balance'
);
reset role;

select * from finish();
rollback;
