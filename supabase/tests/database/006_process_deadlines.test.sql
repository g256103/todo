begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, raw_user_meta_data) values
  ('ffffffff-0000-0000-0000-000000000501', '{"full_name":"Deadline User"}');

insert into public.payments (id, user_id, amount, status, paid_at)
values
  ('ffffffff-1000-4000-8000-000000000501', 'ffffffff-0000-0000-0000-000000000501', 1500, 'SUCCESS', now());

insert into public.challenges (
  id, user_id, payment_id, amount, status, auto_start_at, deadline, started_at, created_at, updated_at
)
values
  ('ffffffff-2000-4000-8000-000000000501',
   'ffffffff-0000-0000-0000-000000000501',
   'ffffffff-1000-4000-8000-000000000501',
   1500, 'IN_PROGRESS', now() - interval '2 days', now() - interval '1 day',
   now() - interval '2 days', now() - interval '2 days', now() - interval '2 days');

-- 一般ユーザーは実行不可
select throws_ok(
  $$select public.process_deadlines()$$,
  '42501',
  null,
  '一般ロールからは実行不可'
);

-- service_role で実行
set local role service_role;

select is(
  public.process_deadlines(),
  1,
  '期限切れのチャレンジが1件処理される'
);

select is(
  (select status from public.challenges where id = 'ffffffff-2000-4000-8000-000000000501'),
  'FAILED',
  'チャレンジ状態はFAILEDに遷移する'
);

select is(
  (select count(*)::integer from public.point_transactions
    where challenge_id = 'ffffffff-2000-4000-8000-000000000501' and type = 'GRANT'),
  1,
  'ポイント付与トランザクションが1件作成される'
);

select is(
  (select amount from public.point_transactions
    where challenge_id = 'ffffffff-2000-4000-8000-000000000501' and type = 'GRANT'),
  1500,
  'コミット額1500円と同額の1500ptが付与される'
);

select is(
  (select available_points from public.points
    where user_id = 'ffffffff-0000-0000-0000-000000000501'),
  1500,
  'pointsテーブルの保有ポイントに反映される'
);

-- 再度実行しても二重処理されない
select is(
  public.process_deadlines(),
  0,
  '再度実行しても対象はなく0件'
);

select * from finish();
rollback;
