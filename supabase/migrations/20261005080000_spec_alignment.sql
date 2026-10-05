-- 0008: 仕様書10章との照合で見つかったずれの修正
-- (適用済みの 0001〜0007 は書き換えず、差分をここで行う)
-- 注意: 対象テーブルが空である前提(NOT NULL列を既定値なしで追加するため)

-- 1) purchases.item_name(仕様書10章に記載あり。0005で漏れていた)
alter table public.purchases
  add column item_name text not null
  constraint purchases_item_name_chk check (char_length(btrim(item_name)) between 1 and 200);

-- 2) idempotency_keys: 仕様書の列 operation / resource_id を追加
--    0005 で独自に入れた request_hash は必須をやめる(仕様にない列でINSERTが失敗しないように)
alter table public.idempotency_keys
  add column operation text not null
    constraint idem_operation_chk check (char_length(btrim(operation)) >= 1),
  add column resource_id uuid,
  alter column request_hash drop not null;

-- 3) ポイント付与は FAILED のChallengeに対してのみ(仕様書7章: FAILED時に付与)
create or replace function public.guard_point_tx_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  if new.type = 'GRANT' then
    select status into v_status from public.challenges where id = new.challenge_id;
    if v_status is distinct from 'FAILED' then
      raise exception 'points can only be granted for a FAILED challenge';
    end if;
  end if;
  return new;
end $$;

revoke all on function public.guard_point_tx_insert() from public;

create trigger point_tx_guard_insert before insert on public.point_transactions
  for each row execute function public.guard_point_tx_insert();
