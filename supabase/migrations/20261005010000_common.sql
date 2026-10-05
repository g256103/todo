-- 0001: 共通関数
-- updated_at 自動更新 / 物理削除禁止(履歴・台帳テーブル用)

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.prevent_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'rows in % cannot be deleted', tg_table_name;
end;
$$;

revoke all on function public.set_updated_at() from public;
revoke all on function public.prevent_delete() from public;

-- pg_cron は、cronから呼ぶ関数を作る Migration で有効化する(ここでは作らない)
