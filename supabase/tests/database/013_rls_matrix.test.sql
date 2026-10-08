-- pgTAP: RLS matrix for all 13 public tables (complements 001; does not modify it)
begin;
create extension if not exists pgtap with schema extensions;

-- Alice / Bob fixtures (unique to this file)
-- Alice: ffffffff-0000-0000-0000-000000000201
-- Bob:   ffffffff-0000-0000-0000-000000000202

select plan(107);

-- ===== Fixture (superuser; bypasses RLS, respects triggers) =====
insert into auth.users (id, raw_user_meta_data) values
  ('ffffffff-0000-0000-0000-000000000201', '{"full_name":"RLS Alice"}'),
  ('ffffffff-0000-0000-0000-000000000202', '{"full_name":"RLS Bob"}');

insert into public.payments (id, user_id, amount, status, paid_at) values
  ('ffffffff-0000-0000-0000-000000000231', 'ffffffff-0000-0000-0000-000000000201', 100, 'SUCCESS', now()),
  ('ffffffff-0000-0000-0000-000000000232', 'ffffffff-0000-0000-0000-000000000202', 100, 'SUCCESS', now());

insert into public.tasks (id, user_id, name) values
  ('ffffffff-0000-0000-0000-000000000211', 'ffffffff-0000-0000-0000-000000000201', 'Alice Task'),
  ('ffffffff-0000-0000-0000-000000000214', 'ffffffff-0000-0000-0000-000000000201', 'Alice Task B'),
  ('ffffffff-0000-0000-0000-000000000212', 'ffffffff-0000-0000-0000-000000000202', 'Bob Task');

insert into public.routines (id, user_id, name) values
  ('ffffffff-0000-0000-0000-000000000221', 'ffffffff-0000-0000-0000-000000000201', 'Alice Routine'),
  ('ffffffff-0000-0000-0000-000000000222', 'ffffffff-0000-0000-0000-000000000202', 'Bob Routine');

insert into public.routine_tasks (routine_id, task_id, user_id, sort_order) values
  ('ffffffff-0000-0000-0000-000000000221', 'ffffffff-0000-0000-0000-000000000211', 'ffffffff-0000-0000-0000-000000000201', 0),
  ('ffffffff-0000-0000-0000-000000000222', 'ffffffff-0000-0000-0000-000000000212', 'ffffffff-0000-0000-0000-000000000202', 0);

insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at, updated_at
) values (
  'ffffffff-0000-0000-0000-000000000241',
  'ffffffff-0000-0000-0000-000000000201',
  'ffffffff-0000-0000-0000-000000000231',
  100, 'WAITING', now() - interval '1 hour', now() + interval '1 hour',
  now() - interval '2 hours', now() - interval '2 hours'
);

insert into public.challenge_tasks (
  id, challenge_id, user_id, task_id, task_name_snapshot, status
) values (
  'ffffffff-0000-0000-0000-000000000251',
  'ffffffff-0000-0000-0000-000000000241',
  'ffffffff-0000-0000-0000-000000000201',
  'ffffffff-0000-0000-0000-000000000211',
  'Alice Task', 'INCOMPLETE'
);

update public.challenges
   set status = 'IN_PROGRESS', started_at = now()
 where id = 'ffffffff-0000-0000-0000-000000000241';

update public.challenge_tasks
   set status = 'COMPLETED', completed_at = now()
 where id = 'ffffffff-0000-0000-0000-000000000251';

update public.challenges
   set status = 'SUCCESS', finished_at = now(), refunded_at = now()
 where id = 'ffffffff-0000-0000-0000-000000000241';

insert into public.qr_codes (id, challenge_id, user_id, status) values (
  'ffffffff-0000-0000-0000-000000000271',
  'ffffffff-0000-0000-0000-000000000241',
  'ffffffff-0000-0000-0000-000000000201',
  'AVAILABLE'
);

insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, created_at, updated_at
) values (
  'ffffffff-0000-0000-0000-000000000242',
  'ffffffff-0000-0000-0000-000000000202',
  'ffffffff-0000-0000-0000-000000000232',
  100, 'WAITING', now() - interval '1 hour', now() + interval '1 hour',
  now() - interval '2 hours', now() - interval '2 hours'
);

insert into public.challenge_tasks (
  id, challenge_id, user_id, task_id, task_name_snapshot, status
) values (
  'ffffffff-0000-0000-0000-000000000252',
  'ffffffff-0000-0000-0000-000000000242',
  'ffffffff-0000-0000-0000-000000000202',
  'ffffffff-0000-0000-0000-000000000212',
  'Bob Task', 'INCOMPLETE'
);

update public.challenges
   set status = 'IN_PROGRESS', started_at = now()
 where id = 'ffffffff-0000-0000-0000-000000000242';

update public.challenges
   set status = 'FAILED', finished_at = now()
 where id = 'ffffffff-0000-0000-0000-000000000242';

insert into public.point_transactions (
  user_id, type, amount, challenge_id, remaining_amount, expires_at
) values (
  'ffffffff-0000-0000-0000-000000000202',
  'GRANT', 50,
  'ffffffff-0000-0000-0000-000000000242',
  50, now() + interval '3 months'
);

insert into public.purchases (
  id, user_id, points_used, item_name, status, completed_at
) values (
  'ffffffff-0000-0000-0000-000000000281',
  'ffffffff-0000-0000-0000-000000000201',
  10, 'RLS Matrix Book', 'COMPLETED', now()
);

insert into public.cashouts (
  id, user_id, points_used, fee_points, cash_amount, status, completed_at
) values (
  'ffffffff-0000-0000-0000-000000000291',
  'ffffffff-0000-0000-0000-000000000201',
  100, 10, 90, 'COMPLETED', now()
);

insert into public.idempotency_keys (user_id, key, operation, resource_id, request_hash) values (
  'ffffffff-0000-0000-0000-000000000201',
  'rls-matrix-alice-key',
  'complete-task',
  'ffffffff-0000-0000-0000-000000000241',
  'hash-alice'
);

-- ===== Session helpers (inline) =====
-- Alice authenticated session follows each block.

-- ---------- users ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.users where id = 'ffffffff-0000-0000-0000-000000000201'),
  1, 'users: own SELECT');
select lives_ok(
  $$update public.users set user_name = 'RLS Alice Updated' where id = 'ffffffff-0000-0000-0000-000000000201'$$,
  'users: own UPDATE user_name');
select is(
  (select count(*)::int from public.users where id = 'ffffffff-0000-0000-0000-000000000202'),
  0, 'users: other SELECT returns 0');
update public.users set user_name = 'hack'
 where id = 'ffffffff-0000-0000-0000-000000000202';
reset role;
select is(
  (select user_name from public.users where id = 'ffffffff-0000-0000-0000-000000000202'),
  'RLS Bob', 'users: other UPDATE affects 0 rows');
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$delete from public.users where id = 'ffffffff-0000-0000-0000-000000000201'$$,
  '42501', null, 'users: DELETE denied');
select throws_ok(
  $$insert into public.users (id, user_name) values ('ffffffff-0000-0000-0000-000000000299', 'x')$$,
  '42501', null, 'users: INSERT denied');
select throws_ok(
  $$update public.users set deleted_at = now() where id = 'ffffffff-0000-0000-0000-000000000201'$$,
  '42501', null, 'users: UPDATE non-granted column denied');

reset role;
set local role anon;
select throws_ok($$select * from public.users$$, '42501', null, 'users: anon SELECT denied');
select throws_ok(
  $$insert into public.users (id, user_name) values ('ffffffff-0000-0000-0000-000000000299', 'anon')$$,
  '42501', null, 'users: anon INSERT denied');
select throws_ok(
  $$update public.users set user_name = 'anon' where id = 'ffffffff-0000-0000-0000-000000000201'$$,
  '42501', null, 'users: anon UPDATE denied');
select throws_ok(
  $$delete from public.users where id = 'ffffffff-0000-0000-0000-000000000201'$$,
  '42501', null, 'users: anon DELETE denied');
reset role;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.users (id, user_name) values ('ffffffff-0000-0000-0000-000000000202', 'impersonate')$$,
  '42501', null, 'users: impersonate INSERT with other id denied');
reset role;

-- ---------- points ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.points where user_id = 'ffffffff-0000-0000-0000-000000000201'),
  1, 'points: own SELECT');
select throws_ok(
  $$insert into public.points (user_id) values ('ffffffff-0000-0000-0000-000000000201')$$,
  '42501', null, 'points: INSERT denied');
select throws_ok(
  $$update public.points set available_points = 1 where user_id = 'ffffffff-0000-0000-0000-000000000201'$$,
  '42501', null, 'points: UPDATE denied');
select throws_ok(
  $$delete from public.points where user_id = 'ffffffff-0000-0000-0000-000000000201'$$,
  '42501', null, 'points: DELETE denied');
select is(
  (select count(*)::int from public.points where user_id = 'ffffffff-0000-0000-0000-000000000202'),
  0, 'points: other SELECT returns 0');
reset role;
set local role anon;
select throws_ok($$select * from public.points$$, '42501', null, 'points: anon SELECT denied');
reset role;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.points (user_id) values ('ffffffff-0000-0000-0000-000000000202')$$,
  '42501', null, 'points: impersonate INSERT denied');
reset role;

-- ---------- tasks ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select ok(
  (select count(*) >= 1 from public.tasks where user_id = 'ffffffff-0000-0000-0000-000000000201'),
  'tasks: own SELECT');
select lives_ok(
  $$insert into public.tasks (user_id, name) values ('ffffffff-0000-0000-0000-000000000201', 'New Alice Task')$$,
  'tasks: own INSERT');
select lives_ok(
  $$update public.tasks set name = 'Alice Task Renamed' where id = 'ffffffff-0000-0000-0000-000000000211'$$,
  'tasks: own UPDATE name');
select lives_ok(
  $$delete from public.tasks
    where user_id = 'ffffffff-0000-0000-0000-000000000201' and name = 'New Alice Task'$$,
  'tasks: own DELETE');
select is(
  (select count(*)::int from public.tasks where id = 'ffffffff-0000-0000-0000-000000000212'),
  0, 'tasks: other SELECT returns 0');
update public.tasks set name = 'hack' where id = 'ffffffff-0000-0000-0000-000000000212';
reset role;
select is(
  (select name from public.tasks where id = 'ffffffff-0000-0000-0000-000000000212'),
  'Bob Task', 'tasks: other UPDATE affects 0 rows');
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
delete from public.tasks where id = 'ffffffff-0000-0000-0000-000000000212';
reset role;
select ok(
  (select count(*)::int from public.tasks where id = 'ffffffff-0000-0000-0000-000000000212') = 1,
  'tasks: other DELETE affects 0 rows');
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.tasks (user_id, name) values ('ffffffff-0000-0000-0000-000000000202', 'impersonate')$$,
  '42501', null, 'tasks: impersonate INSERT denied');
select throws_ok(
  $$update public.tasks set user_id = 'ffffffff-0000-0000-0000-000000000202' where id = 'ffffffff-0000-0000-0000-000000000211'$$,
  '42501', null, 'tasks: UPDATE non-granted column denied');
reset role;
set local role anon;
select throws_ok($$select * from public.tasks$$, '42501', null, 'tasks: anon SELECT denied');
select throws_ok(
  $$insert into public.tasks (user_id, name) values ('ffffffff-0000-0000-0000-000000000201', 'anon')$$,
  '42501', null, 'tasks: anon INSERT denied');
reset role;

-- ---------- routines ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select ok(
  (select count(*) >= 1 from public.routines where user_id = 'ffffffff-0000-0000-0000-000000000201'),
  'routines: own SELECT');
select lives_ok(
  $$insert into public.routines (user_id, name) values ('ffffffff-0000-0000-0000-000000000201', 'New Routine')$$,
  'routines: own INSERT');
select lives_ok(
  $$update public.routines set name = 'Alice Routine Renamed' where id = 'ffffffff-0000-0000-0000-000000000221'$$,
  'routines: own UPDATE name');
select lives_ok(
  $$delete from public.routines
    where user_id = 'ffffffff-0000-0000-0000-000000000201' and name = 'New Routine'$$,
  'routines: own DELETE');
select is(
  (select count(*)::int from public.routines where id = 'ffffffff-0000-0000-0000-000000000222'),
  0, 'routines: other SELECT returns 0');
update public.routines set name = 'hack' where id = 'ffffffff-0000-0000-0000-000000000222';
reset role;
select is(
  (select name from public.routines where id = 'ffffffff-0000-0000-0000-000000000222'),
  'Bob Routine', 'routines: other UPDATE affects 0 rows');
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
delete from public.routines where id = 'ffffffff-0000-0000-0000-000000000222';
reset role;
select ok(
  (select count(*)::int from public.routines where id = 'ffffffff-0000-0000-0000-000000000222') = 1,
  'routines: other DELETE affects 0 rows');
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.routines (user_id, name) values ('ffffffff-0000-0000-0000-000000000202', 'impersonate')$$,
  '42501', null, 'routines: impersonate INSERT denied');
select throws_ok(
  $$update public.routines set user_id = 'ffffffff-0000-0000-0000-000000000202' where id = 'ffffffff-0000-0000-0000-000000000221'$$,
  '42501', null, 'routines: UPDATE non-granted column denied');
reset role;
set local role anon;
select throws_ok($$select * from public.routines$$, '42501', null, 'routines: anon SELECT denied');
reset role;

-- ---------- routine_tasks ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select ok(
  (select count(*) >= 1 from public.routine_tasks where user_id = 'ffffffff-0000-0000-0000-000000000201'),
  'routine_tasks: own SELECT');
select lives_ok(
  $$insert into public.routine_tasks (routine_id, task_id, user_id, sort_order)
    values ('ffffffff-0000-0000-0000-000000000221', 'ffffffff-0000-0000-0000-000000000214', 'ffffffff-0000-0000-0000-000000000201', 1)$$,
  'routine_tasks: own INSERT');
select lives_ok(
  $$update public.routine_tasks set sort_order = 2
    where routine_id = 'ffffffff-0000-0000-0000-000000000221'
      and task_id = 'ffffffff-0000-0000-0000-000000000214'$$,
  'routine_tasks: own UPDATE sort_order');
select lives_ok(
  $$delete from public.routine_tasks
    where routine_id = 'ffffffff-0000-0000-0000-000000000221'
      and task_id = 'ffffffff-0000-0000-0000-000000000214'$$,
  'routine_tasks: own DELETE');
select is(
  (select count(*)::int from public.routine_tasks where user_id = 'ffffffff-0000-0000-0000-000000000202'),
  0, 'routine_tasks: other SELECT returns 0');
update public.routine_tasks set sort_order = 9
 where routine_id = 'ffffffff-0000-0000-0000-000000000222'
   and task_id = 'ffffffff-0000-0000-0000-000000000212';
reset role;
select is(
  (select sort_order from public.routine_tasks
    where routine_id = 'ffffffff-0000-0000-0000-000000000222'
      and task_id = 'ffffffff-0000-0000-0000-000000000212'),
  0, 'routine_tasks: other UPDATE affects 0 rows');
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
delete from public.routine_tasks
 where routine_id = 'ffffffff-0000-0000-0000-000000000222'
   and task_id = 'ffffffff-0000-0000-0000-000000000212';
reset role;
select ok(
  (select count(*)::int from public.routine_tasks
    where routine_id = 'ffffffff-0000-0000-0000-000000000222'
      and task_id = 'ffffffff-0000-0000-0000-000000000212') = 1,
  'routine_tasks: other DELETE affects 0 rows');
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.routine_tasks (routine_id, task_id, user_id, sort_order)
    values ('ffffffff-0000-0000-0000-000000000221', 'ffffffff-0000-0000-0000-000000000214', 'ffffffff-0000-0000-0000-000000000202', 5)$$,
  '42501', null, 'routine_tasks: impersonate INSERT denied');
select throws_ok(
  $$update public.routine_tasks set user_id = 'ffffffff-0000-0000-0000-000000000202'
    where routine_id = 'ffffffff-0000-0000-0000-000000000221'
      and task_id = 'ffffffff-0000-0000-0000-000000000211'$$,
  '42501', null, 'routine_tasks: UPDATE non-granted column denied');
reset role;
set local role anon;
select throws_ok($$select * from public.routine_tasks$$, '42501', null, 'routine_tasks: anon SELECT denied');
reset role;

-- ---------- payments (read-only client) ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.payments where id = 'ffffffff-0000-0000-0000-000000000231'),
  1, 'payments: own SELECT');
select throws_ok(
  $$insert into public.payments (user_id, amount) values ('ffffffff-0000-0000-0000-000000000201', 100)$$,
  '42501', null, 'payments: INSERT denied');
select throws_ok(
  $$update public.payments set status = 'FAILED' where id = 'ffffffff-0000-0000-0000-000000000231'$$,
  '42501', null, 'payments: UPDATE denied');
select throws_ok(
  $$delete from public.payments where id = 'ffffffff-0000-0000-0000-000000000231'$$,
  '42501', null, 'payments: DELETE denied');
select is(
  (select count(*)::int from public.payments where id = 'ffffffff-0000-0000-0000-000000000232'),
  0, 'payments: other SELECT returns 0');
reset role;
set local role anon;
select throws_ok($$select * from public.payments$$, '42501', null, 'payments: anon SELECT denied');
reset role;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.payments (user_id, amount) values ('ffffffff-0000-0000-0000-000000000202', 100)$$,
  '42501', null, 'payments: impersonate INSERT denied');
reset role;

-- ---------- challenges ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.challenges where id = 'ffffffff-0000-0000-0000-000000000241'),
  1, 'challenges: own SELECT');
select throws_ok(
  $$insert into public.challenges (user_id, payment_id, amount, deadline)
    values ('ffffffff-0000-0000-0000-000000000201', 'ffffffff-0000-0000-0000-000000000231', 100, now() + interval '1 day')$$,
  '42501', null, 'challenges: INSERT denied');
select throws_ok(
  $$update public.challenges set status = 'FAILED' where id = 'ffffffff-0000-0000-0000-000000000241'$$,
  '42501', null, 'challenges: UPDATE denied');
select throws_ok(
  $$delete from public.challenges where id = 'ffffffff-0000-0000-0000-000000000241'$$,
  '42501', null, 'challenges: DELETE denied');
select is(
  (select count(*)::int from public.challenges where id = 'ffffffff-0000-0000-0000-000000000242'),
  0, 'challenges: other SELECT returns 0');
reset role;
set local role anon;
select throws_ok($$select * from public.challenges$$, '42501', null, 'challenges: anon SELECT denied');
reset role;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.challenges (user_id, payment_id, amount, deadline)
    values ('ffffffff-0000-0000-0000-000000000202', 'ffffffff-0000-0000-0000-000000000232', 100, now() + interval '1 day')$$,
  '42501', null, 'challenges: impersonate INSERT denied');
reset role;

-- ---------- challenge_tasks ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.challenge_tasks where id = 'ffffffff-0000-0000-0000-000000000251'),
  1, 'challenge_tasks: own SELECT');
select throws_ok(
  $$insert into public.challenge_tasks (challenge_id, user_id, task_id, task_name_snapshot)
    values ('ffffffff-0000-0000-0000-000000000241', 'ffffffff-0000-0000-0000-000000000201', 'ffffffff-0000-0000-0000-000000000211', 'x')$$,
  '42501', null, 'challenge_tasks: INSERT denied');
select throws_ok(
  $$update public.challenge_tasks set status = 'INCOMPLETE' where id = 'ffffffff-0000-0000-0000-000000000251'$$,
  '42501', null, 'challenge_tasks: UPDATE denied');
select throws_ok(
  $$delete from public.challenge_tasks where id = 'ffffffff-0000-0000-0000-000000000251'$$,
  '42501', null, 'challenge_tasks: DELETE denied');
select is(
  (select count(*)::int from public.challenge_tasks where id = 'ffffffff-0000-0000-0000-000000000252'),
  0, 'challenge_tasks: other SELECT returns 0');
reset role;
set local role anon;
select throws_ok($$select * from public.challenge_tasks$$, '42501', null, 'challenge_tasks: anon SELECT denied');
reset role;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.challenge_tasks (challenge_id, user_id, task_id, task_name_snapshot)
    values ('ffffffff-0000-0000-0000-000000000242', 'ffffffff-0000-0000-0000-000000000201', 'ffffffff-0000-0000-0000-000000000211', 'x')$$,
  '42501', null, 'challenge_tasks: impersonate INSERT denied');
reset role;

-- ---------- point_transactions ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.point_transactions where user_id = 'ffffffff-0000-0000-0000-000000000201'),
  0, 'point_transactions: own SELECT (no rows is ok)');
select throws_ok(
  $$insert into public.point_transactions (user_id, type, amount, challenge_id, remaining_amount, expires_at)
    values ('ffffffff-0000-0000-0000-000000000201', 'GRANT', 1, 'ffffffff-0000-0000-0000-000000000241', 1, now())$$,
  '42501', null, 'point_transactions: INSERT denied');
select throws_ok(
  $$update public.point_transactions set amount = 1 where user_id = 'ffffffff-0000-0000-0000-000000000202'$$,
  '42501', null, 'point_transactions: UPDATE denied');
select throws_ok(
  $$delete from public.point_transactions where user_id = 'ffffffff-0000-0000-0000-000000000202'$$,
  '42501', null, 'point_transactions: DELETE denied');
select is(
  (select count(*)::int from public.point_transactions where user_id = 'ffffffff-0000-0000-0000-000000000202'),
  0, 'point_transactions: other SELECT returns 0');
reset role;
set local role anon;
select throws_ok($$select * from public.point_transactions$$, '42501', null, 'point_transactions: anon SELECT denied');
reset role;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.point_transactions (user_id, type, amount, challenge_id, remaining_amount, expires_at)
    values ('ffffffff-0000-0000-0000-000000000202', 'GRANT', 1, 'ffffffff-0000-0000-0000-000000000242', 1, now())$$,
  '42501', null, 'point_transactions: impersonate INSERT denied');
reset role;

-- ---------- qr_codes ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.qr_codes where id = 'ffffffff-0000-0000-0000-000000000271'),
  1, 'qr_codes: own SELECT');
select throws_ok(
  $$insert into public.qr_codes (challenge_id, user_id) values ('ffffffff-0000-0000-0000-000000000241', 'ffffffff-0000-0000-0000-000000000201')$$,
  '42501', null, 'qr_codes: INSERT denied');
select throws_ok(
  $$update public.qr_codes set status = 'USED', used_at = now() where id = 'ffffffff-0000-0000-0000-000000000271'$$,
  '42501', null, 'qr_codes: UPDATE denied');
select throws_ok(
  $$delete from public.qr_codes where id = 'ffffffff-0000-0000-0000-000000000271'$$,
  '42501', null, 'qr_codes: DELETE denied');
select is(
  (select count(*)::int from public.qr_codes where user_id = 'ffffffff-0000-0000-0000-000000000202'),
  0, 'qr_codes: other SELECT returns 0');
reset role;
set local role anon;
select throws_ok($$select * from public.qr_codes$$, '42501', null, 'qr_codes: anon SELECT denied');
reset role;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.qr_codes (challenge_id, user_id) values ('ffffffff-0000-0000-0000-000000000242', 'ffffffff-0000-0000-0000-000000000201')$$,
  '42501', null, 'qr_codes: impersonate INSERT denied');
reset role;

-- ---------- purchases ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.purchases where id = 'ffffffff-0000-0000-0000-000000000281'),
  1, 'purchases: own SELECT');
select throws_ok(
  $$insert into public.purchases (user_id, points_used, item_name) values ('ffffffff-0000-0000-0000-000000000201', 10, 'x')$$,
  '42501', null, 'purchases: INSERT denied');
select throws_ok(
  $$update public.purchases set status = 'FAILED' where id = 'ffffffff-0000-0000-0000-000000000281'$$,
  '42501', null, 'purchases: UPDATE denied');
select throws_ok(
  $$delete from public.purchases where id = 'ffffffff-0000-0000-0000-000000000281'$$,
  '42501', null, 'purchases: DELETE denied');
select is(
  (select count(*)::int from public.purchases where user_id = 'ffffffff-0000-0000-0000-000000000202'),
  0, 'purchases: other SELECT returns 0');
reset role;
set local role anon;
select throws_ok($$select * from public.purchases$$, '42501', null, 'purchases: anon SELECT denied');
reset role;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.purchases (user_id, points_used, item_name) values ('ffffffff-0000-0000-0000-000000000202', 10, 'x')$$,
  '42501', null, 'purchases: impersonate INSERT denied');
reset role;

-- ---------- cashouts ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.cashouts where id = 'ffffffff-0000-0000-0000-000000000291'),
  1, 'cashouts: own SELECT');
select throws_ok(
  $$insert into public.cashouts (user_id, points_used, fee_points, cash_amount)
    values ('ffffffff-0000-0000-0000-000000000201', 100, 10, 90)$$,
  '42501', null, 'cashouts: INSERT denied');
select throws_ok(
  $$update public.cashouts set status = 'FAILED' where id = 'ffffffff-0000-0000-0000-000000000291'$$,
  '42501', null, 'cashouts: UPDATE denied');
select throws_ok(
  $$delete from public.cashouts where id = 'ffffffff-0000-0000-0000-000000000291'$$,
  '42501', null, 'cashouts: DELETE denied');
select is(
  (select count(*)::int from public.cashouts where user_id = 'ffffffff-0000-0000-0000-000000000202'),
  0, 'cashouts: other SELECT returns 0');
reset role;
set local role anon;
select throws_ok($$select * from public.cashouts$$, '42501', null, 'cashouts: anon SELECT denied');
reset role;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.cashouts (user_id, points_used, fee_points, cash_amount)
    values ('ffffffff-0000-0000-0000-000000000202', 100, 10, 90)$$,
  '42501', null, 'cashouts: impersonate INSERT denied');
reset role;

-- ---------- idempotency_keys (no client access) ----------
select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;

select throws_ok($$select * from public.idempotency_keys$$, '42501', null, 'idempotency_keys: SELECT denied');
select throws_ok(
  $$insert into public.idempotency_keys (user_id, key, operation, resource_id, request_hash)
    values ('ffffffff-0000-0000-0000-000000000201', 'k2', 'complete-task', 'ffffffff-0000-0000-0000-000000000241', 'h')$$,
  '42501', null, 'idempotency_keys: INSERT denied');
select throws_ok(
  $$update public.idempotency_keys set request_hash = 'x'
    where user_id = 'ffffffff-0000-0000-0000-000000000201'$$,
  '42501', null, 'idempotency_keys: UPDATE denied');
select throws_ok(
  $$delete from public.idempotency_keys where user_id = 'ffffffff-0000-0000-0000-000000000201'$$,
  '42501', null, 'idempotency_keys: DELETE denied');
reset role;
set local role anon;
select throws_ok($$select * from public.idempotency_keys$$, '42501', null, 'idempotency_keys: anon SELECT denied');
reset role;

-- ===== Layer isolation (inside file begin...rollback; leaves no local DB residue) =====
-- Nested BEGIN/ROLLBACK aborts this pgTAP tx; ROLLBACK TO SAVEPOINT also drops
-- pgTAP result rows. Each block: widen → assert → restore (same as rolled-back tx).

-- 1) tasks: widen column GRANT so WITH CHECK (RLS) alone rejects user_id reassignment
grant update (user_id) on public.tasks to authenticated;

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$update public.tasks
      set user_id = 'ffffffff-0000-0000-0000-000000000202'
    where id = 'ffffffff-0000-0000-0000-000000000211'$$,
  '42501',
  'new row violates row-level security policy for table "tasks"',
  'tasks: WITH CHECK rejects user_id reassignment (RLS unit)');
reset role;

revoke update (user_id) on public.tasks from authenticated;

-- 2) routine_tasks: loosen SELECT so DELETE policy alone blocks other-row delete
drop policy routine_tasks_select_own on public.routine_tasks;
create policy routine_tasks_select_all_temp on public.routine_tasks
  for select to authenticated
  using (true);

select set_config('request.jwt.claim.sub', 'ffffffff-0000-0000-0000-000000000201', true);
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000201","role":"authenticated"}', true);
set local role authenticated;
select is(
  (select count(*)::int from public.routine_tasks
    where routine_id = 'ffffffff-0000-0000-0000-000000000222'
      and task_id = 'ffffffff-0000-0000-0000-000000000212'),
  1, 'routine_tasks: loosened SELECT sees other row (precondition)');
delete from public.routine_tasks
 where routine_id = 'ffffffff-0000-0000-0000-000000000222'
   and task_id = 'ffffffff-0000-0000-0000-000000000212';
reset role;
select ok(
  (select count(*)::int from public.routine_tasks
    where routine_id = 'ffffffff-0000-0000-0000-000000000222'
      and task_id = 'ffffffff-0000-0000-0000-000000000212') = 1,
  'routine_tasks: DELETE policy alone blocks other row (layer unit)');

drop policy routine_tasks_select_all_temp on public.routine_tasks;
create policy routine_tasks_select_own on public.routine_tasks
  for select to authenticated
  using (user_id = (select auth.uid()));

select * from finish();
rollback;
