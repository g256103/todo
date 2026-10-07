-- process-deadlines: process expired challenges to FAILED and grant educational points

create or replace function public.process_deadlines()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_challenge public.challenges%rowtype;
  v_processed integer := 0;
  v_now timestamptz;
begin
  set local lock_timeout = '3s';

  for v_challenge in
    select *
      from public.challenges
     where status in ('WAITING', 'IN_PROGRESS')
       and deadline <= clock_timestamp()
     order by deadline, id
     for update skip locked
  loop
    v_now := clock_timestamp();

    update public.challenges
       set status = 'FAILED',
           finished_at = coalesce(finished_at, v_now),
           updated_at = v_now
     where id = v_challenge.id;

    -- 教育用途ポイント付与（3か月有効、1つのChallengeにつき1回のみ）
    if not exists (
      select 1
        from public.point_transactions
       where challenge_id = v_challenge.id
         and type = 'GRANT'
    ) then
      insert into public.point_transactions (
        user_id, type, amount, challenge_id, remaining_amount, expires_at, created_at
      )
      values (
        v_challenge.user_id,
        'GRANT',
        v_challenge.amount,
        v_challenge.id,
        v_challenge.amount,
        v_now + interval '3 months',
        v_now
      );

      update public.points
         set available_points = available_points + v_challenge.amount,
             updated_at = v_now
       where user_id = v_challenge.user_id;
    end if;

    v_processed := v_processed + 1;
  end loop;

  return v_processed;
end;
$$;

revoke all on function public.process_deadlines()
  from public, anon, authenticated;
grant execute on function public.process_deadlines()
  to service_role;
