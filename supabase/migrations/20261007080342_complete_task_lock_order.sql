-- complete_task: lock order challenges -> challenge_tasks (spec ch.13 / v5)

create or replace function public.complete_task(
  p_challenge_task_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_request_hash text;
  v_existing_operation text;
  v_existing_hash text;
  v_existing_response jsonb;
  v_task public.challenge_tasks%rowtype;
  v_challenge public.challenges%rowtype;
  v_now timestamptz;
  v_all_completed boolean;
  v_result text;
  v_response jsonb;
begin
  set local lock_timeout = '3s';
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'unauthorized';
  end if;

  if p_challenge_task_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_uuid';
  end if;

  if p_idempotency_key is null
     or char_length(p_idempotency_key) < 1
     or char_length(p_idempotency_key) > 200
     or btrim(p_idempotency_key) = ''
     or p_idempotency_key <> btrim(p_idempotency_key) then
    raise exception using errcode = 'P0001', message = 'invalid_idempotency_key';
  end if;

  v_request_hash := pg_catalog.md5(
    (jsonb_build_object('challenge_task_id', lower(p_challenge_task_id::text)))::text
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );

  select operation, request_hash, response
    into v_existing_operation, v_existing_hash, v_existing_response
    from public.idempotency_keys
   where user_id = v_user_id
     and key = p_idempotency_key
   for update;

  if found then
    if v_existing_operation <> 'complete-task'
       or v_existing_hash is distinct from v_request_hash then
      raise exception using errcode = 'P0001', message = 'idempotency_key_reused';
    end if;
    if v_existing_response is null then
      raise exception using errcode = 'P0001', message = 'complete_task_conflict';
    end if;
    return v_existing_response;
  end if;

  -- 行ロック順序: challenges -> challenge_tasks
  select *
    into v_task
    from public.challenge_tasks
   where id = p_challenge_task_id
     and user_id = v_user_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'task_not_found';
  end if;

  select *
    into v_challenge
    from public.challenges
   where id = v_task.challenge_id
     and user_id = v_user_id
   for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'challenge_not_found';
  end if;

  select *
    into v_task
    from public.challenge_tasks
   where id = p_challenge_task_id
     and user_id = v_user_id
   for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'task_not_found';
  end if;

  v_now := clock_timestamp();

  if v_challenge.status = 'SUCCESS' then
    if v_task.status = 'COMPLETED' then
      v_result := 'already_completed';
    else
      raise exception using errcode = 'P0001', message = 'challenge_already_success';
    end if;
  elsif v_challenge.status = 'FAILED' then
    raise exception using errcode = 'P0001', message = 'challenge_already_failed';
  elsif v_challenge.status <> 'IN_PROGRESS' then
    raise exception using errcode = 'P0001', message = 'challenge_not_in_progress';
  elsif v_now > v_challenge.deadline then
    raise exception using errcode = 'P0001', message = 'deadline_exceeded';
  elsif v_task.status = 'COMPLETED' then
    v_result := 'already_completed';
  else
    update public.challenge_tasks
       set status = 'COMPLETED',
           completed_at = v_now,
           updated_at = v_now
     where id = v_task.id;

    v_task.status := 'COMPLETED';
    v_task.completed_at := v_now;

    select not exists (
      select 1
        from public.challenge_tasks
       where challenge_id = v_challenge.id
         and status <> 'COMPLETED'
    ) into v_all_completed;

    if v_all_completed then
      update public.challenges
         set status = 'SUCCESS',
             finished_at = v_now,
             updated_at = v_now
       where id = v_challenge.id;

      insert into public.qr_codes (challenge_id, user_id)
      values (v_challenge.id, v_user_id);

      v_challenge.status := 'SUCCESS';
      v_challenge.finished_at := v_now;
      v_result := 'challenge_success';
    else
      v_result := 'completed';
    end if;
  end if;

  v_response := jsonb_build_object(
    'result', v_result,
    'challenge_task', jsonb_build_object(
      'id', v_task.id,
      'challenge_id', v_task.challenge_id,
      'status', v_task.status,
      'completed_at', v_task.completed_at
    ),
    'challenge_status', v_challenge.status
  );

  insert into public.idempotency_keys (
    user_id, key, request_hash, operation, resource_id, response
  )
  values (
    v_user_id, p_idempotency_key, v_request_hash, 'complete-task',
    v_task.id, v_response
  );

  return v_response;
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'complete_task_conflict';
end;
$$;

revoke all on function public.complete_task(uuid, text)
  from public, anon, service_role;
grant execute on function public.complete_task(uuid, text)
  to authenticated;
