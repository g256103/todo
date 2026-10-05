-- 0006: トリガー(CHECKで表せない整合性を守る)
-- ガード関数は SECURITY DEFINER + search_path 固定(RLSに左右されず親行を読むため)

-- ---------- updated_at 自動更新 ----------
do $$
declare t text;
begin
  foreach t in array array['users','points','tasks','routines','payments','challenges',
                           'challenge_tasks','purchases','cashouts'] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t);
  end loop;
end $$;

-- ---------- 物理削除の禁止 ----------
do $$
declare t text;
begin
  foreach t in array array['users','points','payments','challenges','challenge_tasks',
                           'point_transactions','qr_codes','purchases','cashouts'] loop
    execute format(
      'create trigger %I before delete on public.%I for each row execute function public.prevent_delete()',
      t || '_prevent_delete', t);
  end loop;
end $$;

-- ---------- payments ----------
create or replace function public.guard_payments_update()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.user_id is distinct from old.user_id or new.amount is distinct from old.amount then
    raise exception 'payments.user_id / amount are immutable';
  end if;
  if new.status is distinct from old.status
     and not (old.status = 'PENDING' and new.status in ('SUCCESS', 'FAILED')) then
    raise exception 'invalid payment status transition % -> %', old.status, new.status;
  end if;
  if old.paid_at is not null and new.paid_at is distinct from old.paid_at then
    raise exception 'payments.paid_at is immutable once set';
  end if;
  return new;
end $$;
create trigger payments_guard_update before update on public.payments
  for each row execute function public.guard_payments_update();

-- ---------- challenges ----------
create or replace function public.guard_challenges_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status <> 'WAITING' then
    raise exception 'challenge must be created as WAITING';
  end if;
  if not exists (select 1 from public.payments p where p.id = new.payment_id and p.status = 'SUCCESS') then
    raise exception 'payment must be SUCCESS';
  end if;
  return new;
end $$;
create trigger challenges_guard_insert before insert on public.challenges
  for each row execute function public.guard_challenges_insert();

create or replace function public.guard_challenges_update()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status in ('SUCCESS', 'FAILED') then
    raise exception 'finished challenge is immutable';
  end if;
  if new.user_id    is distinct from old.user_id
     or new.payment_id is distinct from old.payment_id
     or new.amount     is distinct from old.amount
     or new.deadline   is distinct from old.deadline then
    raise exception 'challenge user_id / payment_id / amount / deadline are immutable';
  end if;
  if new.status is distinct from old.status
     and not ((old.status = 'WAITING'     and new.status = 'IN_PROGRESS')
           or (old.status = 'IN_PROGRESS' and new.status in ('SUCCESS', 'FAILED'))) then
    raise exception 'invalid challenge status transition % -> %', old.status, new.status;
  end if;
  if new.status = 'SUCCESS' and old.status <> 'SUCCESS' then
    if not exists (select 1 from public.challenge_tasks where challenge_id = old.id)
       or exists (select 1 from public.challenge_tasks where challenge_id = old.id and status <> 'COMPLETED') then
      raise exception 'SUCCESS requires at least one task and all tasks COMPLETED';
    end if;
    if new.finished_at > new.deadline then
      raise exception 'SUCCESS requires finished_at <= deadline';
    end if;
  end if;
  return new;
end $$;
create trigger challenges_guard_update before update on public.challenges
  for each row execute function public.guard_challenges_update();

-- ---------- challenge_tasks ----------
create or replace function public.guard_challenge_tasks_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  select status into v_status from public.challenges where id = new.challenge_id;
  if v_status is distinct from 'WAITING' then
    raise exception 'tasks can only be added while the challenge is WAITING';
  end if;
  if new.status <> 'INCOMPLETE' then
    raise exception 'challenge_task must be created as INCOMPLETE';
  end if;
  return new;
end $$;
create trigger challenge_tasks_guard_insert before insert on public.challenge_tasks
  for each row execute function public.guard_challenge_tasks_insert();

create or replace function public.guard_challenge_tasks_update()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  if new.challenge_id        is distinct from old.challenge_id
     or new.user_id            is distinct from old.user_id
     or new.task_name_snapshot is distinct from old.task_name_snapshot
     or new.sort_order         is distinct from old.sort_order then
    raise exception 'challenge_tasks identity / snapshot columns are immutable';
  end if;
  -- task_id は「元タスク削除による NULL 化」だけ許可
  if new.task_id is distinct from old.task_id and new.task_id is not null then
    raise exception 'challenge_tasks.task_id can only be set to NULL';
  end if;
  if new.status is distinct from old.status then
    if not (old.status = 'INCOMPLETE' and new.status = 'COMPLETED') then
      raise exception 'invalid challenge_task status transition % -> %', old.status, new.status;
    end if;
    select status into v_status from public.challenges where id = old.challenge_id;
    if v_status is distinct from 'IN_PROGRESS' then
      raise exception 'tasks can only be completed while the challenge is IN_PROGRESS';
    end if;
  elsif new.completed_at is distinct from old.completed_at then
    raise exception 'completed_at can only change together with status';
  end if;
  return new;
end $$;
create trigger challenge_tasks_guard_update before update on public.challenge_tasks
  for each row execute function public.guard_challenge_tasks_update();

-- ---------- point_transactions(台帳: 追記専用、remaining_amount の減算のみ可) ----------
create or replace function public.guard_point_tx_update()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (to_jsonb(new) - 'remaining_amount') is distinct from (to_jsonb(old) - 'remaining_amount') then
    raise exception 'point_transactions are append-only (only remaining_amount may change)';
  end if;
  if new.remaining_amount > old.remaining_amount then
    raise exception 'remaining_amount cannot increase';
  end if;
  return new;
end $$;
create trigger point_tx_guard_update before update on public.point_transactions
  for each row execute function public.guard_point_tx_update();

-- ---------- qr_codes ----------
create or replace function public.guard_qr_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  select status into v_status from public.challenges where id = new.challenge_id;
  if v_status is distinct from 'SUCCESS' then
    raise exception 'qr_codes can only be created for a SUCCESS challenge';
  end if;
  if new.status <> 'AVAILABLE' then
    raise exception 'qr_code must be created as AVAILABLE';
  end if;
  return new;
end $$;
create trigger qr_codes_guard_insert before insert on public.qr_codes
  for each row execute function public.guard_qr_insert();

create or replace function public.guard_qr_update()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (to_jsonb(new) - 'status' - 'used_at') is distinct from (to_jsonb(old) - 'status' - 'used_at') then
    raise exception 'only status / used_at of qr_codes may change';
  end if;
  if new.status is distinct from old.status
     and not (old.status = 'AVAILABLE' and new.status = 'USED') then
    raise exception 'invalid qr status transition % -> %', old.status, new.status;
  end if;
  return new;
end $$;
create trigger qr_codes_guard_update before update on public.qr_codes
  for each row execute function public.guard_qr_update();

-- ガード関数は直接呼べないようにする
revoke all on function
  public.guard_payments_update(), public.guard_challenges_insert(), public.guard_challenges_update(),
  public.guard_challenge_tasks_insert(), public.guard_challenge_tasks_update(),
  public.guard_point_tx_update(), public.guard_qr_insert(), public.guard_qr_update()
from public;
