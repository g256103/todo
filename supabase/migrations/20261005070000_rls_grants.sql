-- 0007: 権限(GRANT/REVOKE)と RLS
-- 方針: anon は何も不可 / authenticated は最小限 / 書き込みは基本サーバー関数のみ

-- 1) 既定権限: 今後作るテーブル・関数にも勝手に権限を付けない
alter default privileges in schema public revoke all on tables    from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

-- 2) 既存分も剥奪(service_role は影響なし)
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

-- 3) RLS を全テーブルで有効化
do $$
declare t text;
begin
  foreach t in array array['users','points','tasks','routines','routine_tasks','payments',
                           'challenges','challenge_tasks','point_transactions','qr_codes',
                           'purchases','cashouts','idempotency_keys'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- 4) GRANT(列単位で最小化)
grant select on public.users, public.points, public.payments, public.challenges,
                public.challenge_tasks, public.point_transactions, public.qr_codes,
                public.purchases, public.cashouts
  to authenticated;
grant update (user_name) on public.users to authenticated;

grant select, delete on public.tasks, public.routines, public.routine_tasks to authenticated;
grant insert (user_id, name), update (name) on public.tasks    to authenticated;
grant insert (user_id, name), update (name) on public.routines to authenticated;
grant insert (routine_id, task_id, user_id, sort_order), update (sort_order)
  on public.routine_tasks to authenticated;
-- idempotency_keys: GRANTもポリシーも無し(クライアントから完全に不可)

-- 5) ポリシー
create policy users_select_own on public.users
  for select to authenticated using (id = (select auth.uid()));
create policy users_update_own on public.users
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- 読み取り専用テーブル: 自分の行だけ SELECT
do $$
declare t text;
begin
  foreach t in array array['points','payments','challenges','challenge_tasks',
                           'point_transactions','qr_codes','purchases','cashouts'] loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (user_id = (select auth.uid()))',
      t || '_select_own', t);
  end loop;
end $$;

-- tasks / routines / routine_tasks: 自分の行だけ CRUD
do $$
declare t text;
begin
  foreach t in array array['tasks','routines','routine_tasks'] loop
    execute format('create policy %I on public.%I for select to authenticated using (user_id = (select auth.uid()))', t||'_select_own', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t||'_insert_own', t);
    execute format('create policy %I on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t||'_update_own', t);
    execute format('create policy %I on public.%I for delete to authenticated using (user_id = (select auth.uid()))', t||'_delete_own', t);
  end loop;
end $$;
