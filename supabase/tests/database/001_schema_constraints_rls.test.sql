-- pgTAP: 制約・トリガー・RLS・権限のテスト(全体を1トランザクションで実行し、最後にロールバック)
begin;
create extension if not exists pgtap with schema extensions;
select plan(58);

-- ===== 準備: ユーザー(alice / bob) =====
insert into auth.users (id, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '{"full_name":"Alice"}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', null);

-- ===== 1. 全テーブルでRLS有効 / サインアップ時の自動作成 =====
select is((select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity),
          0, 'public の全テーブルでRLSが有効');
select is((select count(*)::int from public.users  where id in ('aaaaaaaa-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002')),
          2, 'サインアップで users が自動作成される');
select is((select count(*)::int from public.points where user_id in ('aaaaaaaa-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002')),
          2, 'サインアップで points が自動作成される');
select is((select user_name from public.users where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
          'Alice', 'メタデータの名前が user_name になる');
select is((select user_name from public.users where id = 'bbbbbbbb-0000-0000-0000-000000000002'),
          'ユーザー', '名前がなければ既定名になる');

-- ===== 2. payments =====
select throws_ok($$insert into public.payments(user_id, amount) values ('aaaaaaaa-0000-0000-0000-000000000001', 250)$$,
          '23514', null, 'amount が100の倍数でないと拒否');
select throws_ok($$insert into public.payments(user_id, amount, status) values ('aaaaaaaa-0000-0000-0000-000000000001', 500, 'SUCCESS')$$,
          '23514', null, 'SUCCESS なのに paid_at が無いと拒否');

insert into public.payments(id, user_id, amount, status, paid_at) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 500, 'SUCCESS', now()),
  ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 100, 'SUCCESS', now()),
  ('cccccccc-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 100, 'PENDING', null),
  ('cccccccc-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000002', 100, 'SUCCESS', now());

select throws_ok($$update public.payments set amount = 300 where id = 'cccccccc-0000-0000-0000-000000000001'$$,
          'P0001', null, 'payments.amount は変更不可');

-- ===== 3. challenges =====
select throws_ok($$insert into public.challenges(user_id, payment_id, amount, deadline)
          values ('aaaaaaaa-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000002', 200, now() + interval '1 hour')$$,
          '23503', null, 'paymentと金額が違うChallengeは作れない');
select throws_ok($$insert into public.challenges(user_id, payment_id, amount, deadline)
          values ('bbbbbbbb-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000002', 100, now() + interval '1 hour')$$,
          '23503', null, '他人のpaymentでChallengeは作れない');
select throws_ok($$insert into public.challenges(user_id, payment_id, amount, deadline)
          values ('aaaaaaaa-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 100, now() + interval '1 hour')$$,
          'P0001', null, '決済が SUCCESS でないとChallengeは作れない');
select lives_ok($$insert into public.challenges(id, user_id, payment_id, amount, deadline)
          values ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 500, now() + interval '1 hour')$$,
          '正しいChallengeは作れる');
select lives_ok($$insert into public.challenges(id, user_id, payment_id, amount, deadline)
          values ('dddddddd-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000002', 100, now() + interval '1 hour')$$,
          '2件目の期限内WAITINGはユニークインデックスでは許可される');
select throws_ok($$insert into public.challenges(user_id, payment_id, amount, deadline)
          values ('bbbbbbbb-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000004', 100, now())$$,
          '23514', null, 'deadline が auto_start_at 以前だと拒否');

-- ===== 4. challenge_tasks / ステータス遷移 =====
insert into public.tasks(id, user_id, name) values
  ('eeeeeeee-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Task A'),
  ('eeeeeeee-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'Task B');

select throws_ok($$insert into public.challenge_tasks(challenge_id, user_id, task_id, task_name_snapshot)
          values ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002', 'B')$$,
          '23503', null, '他人のタスクはChallengeに入れられない');
select lives_ok($$insert into public.challenge_tasks(challenge_id, user_id, task_id, task_name_snapshot)
          values ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001', 'Task A')$$,
          '自分のタスクはChallengeに入れられる');
select throws_ok($$update public.challenges set status = 'SUCCESS', started_at = now(), finished_at = now()
          where id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'P0001', null, 'WAITING から SUCCESS へ直接は遷移できない');
select throws_ok($$update public.challenge_tasks set status = 'COMPLETED', completed_at = now()
          where challenge_id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'P0001', null, 'IN_PROGRESS 前はタスクを完了できない');
select lives_ok($$update public.challenges set status = 'IN_PROGRESS', started_at = now()
          where id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'WAITING から IN_PROGRESS へ遷移できる');
select throws_ok($$update public.challenges set status = 'IN_PROGRESS', started_at = now()
          where id = 'dddddddd-0000-0000-0000-000000000006'$$,
          '23505', null, 'IN_PROGRESSはユーザーごとに1件まで');
select throws_ok($$update public.challenges set status = 'SUCCESS', finished_at = now()
          where id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'P0001', null, '未完了タスクがあると SUCCESS にできない');
select lives_ok($$update public.challenge_tasks set status = 'COMPLETED', completed_at = now()
          where challenge_id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'IN_PROGRESS 中はタスクを完了できる');
select lives_ok($$delete from public.tasks where id = 'eeeeeeee-0000-0000-0000-000000000001'$$,
          '元タスクは削除できる');
select is((select task_id from public.challenge_tasks where challenge_id = 'dddddddd-0000-0000-0000-000000000001'),
          null, '元タスク削除で task_id が NULL になる');
select is((select task_name_snapshot from public.challenge_tasks where challenge_id = 'dddddddd-0000-0000-0000-000000000001'),
          'Task A', '履歴(スナップショット)は残る');
select throws_ok($$update public.challenge_tasks set status = 'INCOMPLETE', completed_at = null
          where challenge_id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'P0001', null, 'COMPLETED から INCOMPLETE へは戻せない');
select lives_ok($$update public.challenges set status = 'SUCCESS', finished_at = now(), refunded_at = now()
          where id = 'dddddddd-0000-0000-0000-000000000001'$$,
          '全タスク完了なら SUCCESS にできる');
select throws_ok($$update public.challenges set amount = 100 where id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'P0001', null, '終了後のChallengeは変更できない');
select throws_ok($$delete from public.challenges where id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'P0001', null, 'Challengeは削除できない');

-- ===== 5. QR =====
insert into public.payments(id, user_id, amount, status, paid_at)
  values ('cccccccc-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000002', 100, 'SUCCESS', now());
insert into public.challenges(id, user_id, payment_id, amount, deadline)
  values ('dddddddd-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000005', 100, now() + interval '1 hour');

select throws_ok($$insert into public.qr_codes(challenge_id, user_id)
          values ('dddddddd-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002')$$,
          'P0001', null, 'SUCCESS 前はQRを作れない');
select lives_ok($$insert into public.qr_codes(challenge_id, user_id)
          values ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001')$$,
          'SUCCESS 後はQRを作れる');
select throws_ok($$insert into public.qr_codes(challenge_id, user_id)
          values ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001')$$,
          '23505', null, '1つのChallengeにQRは1つだけ');
select lives_ok($$update public.qr_codes set status = 'USED', used_at = now()
          where challenge_id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'QRは AVAILABLE から USED にできる');
select throws_ok($$update public.qr_codes set status = 'AVAILABLE', used_at = null
          where challenge_id = 'dddddddd-0000-0000-0000-000000000001'$$,
          'P0001', null, 'USED のQRは戻せない');

-- ===== 6. ポイント台帳 / cashouts =====
-- ポイント付与は FAILED のChallengeに対してのみ
select throws_ok($$insert into public.point_transactions(user_id, type, amount, challenge_id, remaining_amount, expires_at)
          values ('aaaaaaaa-0000-0000-0000-000000000001', 'GRANT', 50, 'dddddddd-0000-0000-0000-000000000001', 50, now() + interval '3 months')$$,
          'P0001', null, 'SUCCESS のChallengeにはポイントを付与できない');
update public.challenges set status = 'IN_PROGRESS', started_at = now() where id = 'dddddddd-0000-0000-0000-000000000002';
update public.challenges set status = 'FAILED', finished_at = now() where id = 'dddddddd-0000-0000-0000-000000000002';
select lives_ok($$insert into public.point_transactions(user_id, type, amount, challenge_id, remaining_amount, expires_at)
          values ('bbbbbbbb-0000-0000-0000-000000000002', 'GRANT', 50, 'dddddddd-0000-0000-0000-000000000002', 50, now() + interval '3 months')$$,
          'FAILED のChallengeにはポイントを付与できる');
select throws_ok($$insert into public.point_transactions(user_id, type, amount, challenge_id, remaining_amount, expires_at)
          values ('bbbbbbbb-0000-0000-0000-000000000002', 'GRANT', 50, 'dddddddd-0000-0000-0000-000000000002', 50, now() + interval '3 months')$$,
          '23505', null, '同じChallengeへの二重付与は拒否');
select lives_ok($$update public.point_transactions set remaining_amount = 20$$,
          'remaining_amount は減らせる');
select throws_ok($$update public.point_transactions set remaining_amount = 40$$,
          'P0001', null, 'remaining_amount は増やせない');
select throws_ok($$update public.point_transactions set amount = 1$$,
          'P0001', null, '台帳の他の列は変更できない');
select throws_ok($$delete from public.point_transactions$$,
          'P0001', null, '台帳は削除できない');
select throws_ok($$insert into public.cashouts(user_id, points_used, fee_points, cash_amount)
          values ('aaaaaaaa-0000-0000-0000-000000000001', 105, 10, 95)$$,
          '23514', null, 'points_used が10の倍数でないと拒否');
select throws_ok($$insert into public.cashouts(user_id, points_used, fee_points, cash_amount)
          values ('aaaaaaaa-0000-0000-0000-000000000001', 100, 5, 95)$$,
          '23514', null, '手数料が10%でないと拒否');

-- ===== 6b. 仕様書10章との整合 =====
select throws_ok($$insert into public.purchases(user_id, points_used) values ('aaaaaaaa-0000-0000-0000-000000000001', 10)$$,
          '23502', null, 'purchases は item_name が必須');
select lives_ok($$insert into public.purchases(user_id, points_used, item_name) values ('aaaaaaaa-0000-0000-0000-000000000001', 10, '参考書')$$,
          'purchases を item_name 付きで作れる');
select lives_ok($$insert into public.idempotency_keys(user_id, key, operation, resource_id)
          values ('aaaaaaaa-0000-0000-0000-000000000001', 'k1', 'complete-task', 'dddddddd-0000-0000-0000-000000000001')$$,
          'idempotency_keys を仕様書の列(operation / resource_id)で作れる');

-- ===== 7. ルーティン =====
insert into public.tasks(id, user_id, name) values ('eeeeeeee-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'Task C');
insert into public.routines(id, user_id, name) values ('ffffffff-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'Bob routine');
select throws_ok($$insert into public.routine_tasks(routine_id, task_id, user_id)
          values ('ffffffff-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002')$$,
          '23503', null, '他人のタスクをルーティンに入れられない');

-- ===== 8. RLS・権限(alice としてアクセス) =====
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);

select is((select count(*)::int from public.tasks where id = 'eeeeeeee-0000-0000-0000-000000000002'),
          0, '他人のタスクは見えない');
select is((select count(*)::int from public.payments where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'),
          0, '他人の決済は見えない');
select is((select count(*)::int from public.qr_codes where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
          1, '自分のQRは見える');
select throws_ok($$insert into public.tasks(user_id, name) values ('bbbbbbbb-0000-0000-0000-000000000002', 'hack')$$,
          '42501', null, '他人名義でタスクを作れない(RLS)');
select throws_ok($$select * from public.idempotency_keys$$,
          '42501', null, 'idempotency_keys はクライアントから触れない');
select throws_ok($$insert into public.payments(user_id, amount) values ('aaaaaaaa-0000-0000-0000-000000000001', 100)$$,
          '42501', null, 'クライアントは payments に書き込めない');
select throws_ok($$update public.points set available_points = 999999$$,
          '42501', null, 'クライアントは points を更新できない');
select throws_ok($$update public.users set deleted_at = now() where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
          '42501', null, 'users は user_name 以外を更新できない');
select lives_ok($$update public.users set user_name = 'Z' where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
          '自分の user_name は更新できる');
select throws_ok($$select public.handle_new_user()$$,
          '42501', null, '内部関数をクライアントから実行できない');

reset role;
set local role anon;
select throws_ok($$select * from public.tasks$$,
          '42501', null, 'anon は何も読めない');
reset role;

select * from finish();
rollback;
