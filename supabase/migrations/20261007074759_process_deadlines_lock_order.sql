-- process_deadlines: lock order points before point_transactions (spec ch.13 / v5)

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
     where status = 'IN_PROGRESS'
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

    if not exists (
      select 1
        from public.point_transactions
       where challenge_id = v_challenge.id
         and type = 'GRANT'
    ) then
      update public.points
         set available_points = available_points + v_challenge.amount,
             updated_at = v_now
       where user_id = v_challenge.user_id;

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
    end if;

    v_processed := v_processed + 1;
  end loop;

  return v_processed;
end;
$$;
