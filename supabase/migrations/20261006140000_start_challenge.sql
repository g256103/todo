-- start-challenge: manual and scheduled challenge start

create or replace function public.start_challenge(
  p_challenge_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_is_system boolean;
  v_request_hash text;
  v_existing_operation text;
  v_existing_hash text;
  v_existing_response jsonb;
  v_challenge public.challenges%rowtype;
  v_response jsonb;
  v_now timestamptz;
begin
  set local lock_timeout = '3s';
  v_user_id := (select auth.uid());
  v_is_system := coalesce((select auth.role()), '') = 'service_role'
    and v_user_id is null;
  if v_user_id is null and not v_is_system then
    raise exception using errcode = 'P0001', message = 'unauthorized';
  end if;
  if p_challenge_id is null then
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
    (jsonb_build_object('challenge_id', lower(p_challenge_id::text)))::text
  );

  select *
    into v_challenge
    from public.challenges
   where id = p_challenge_id
     and (v_is_system or user_id = v_user_id)
   for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'challenge_not_found';
  end if;
  if v_is_system then
    v_user_id := v_challenge.user_id;
  end if;

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
    if v_existing_operation <> 'start-challenge'
       or v_existing_hash is distinct from v_request_hash then
      raise exception using errcode = 'P0001', message = 'idempotency_key_reused';
    end if;
    if v_existing_response is null then
      raise exception using errcode = 'P0001', message = 'start_challenge_conflict';
    end if;
    return v_existing_response;
  end if;

  v_now := clock_timestamp();
  if v_challenge.status = 'SUCCESS' then
    raise exception using errcode = 'P0001', message = 'challenge_already_success';
  end if;
  if v_challenge.status = 'FAILED' then
    raise exception using errcode = 'P0001', message = 'challenge_already_failed';
  end if;
  if v_challenge.status = 'IN_PROGRESS' then
    v_response := jsonb_build_object(
      'id', v_challenge.id,
      'payment_id', v_challenge.payment_id,
      'amount', v_challenge.amount,
      'status', v_challenge.status,
      'auto_start_at', v_challenge.auto_start_at,
      'deadline', v_challenge.deadline,
      'started_at', v_challenge.started_at,
      'created_at', v_challenge.created_at
    );
  elsif v_now >= v_challenge.deadline then
    raise exception using errcode = 'P0001', message = 'deadline_exceeded';
  else
    update public.challenges
       set status = 'IN_PROGRESS',
           started_at = v_now,
           updated_at = v_now
     where id = v_challenge.id;
    v_response := jsonb_build_object(
      'id', v_challenge.id,
      'payment_id', v_challenge.payment_id,
      'amount', v_challenge.amount,
      'status', 'IN_PROGRESS',
      'auto_start_at', v_challenge.auto_start_at,
      'deadline', v_challenge.deadline,
      'started_at', v_now,
      'created_at', v_challenge.created_at
    );
  end if;

  insert into public.idempotency_keys (
    user_id, key, request_hash, operation, resource_id, response
  )
  values (
    v_user_id, p_idempotency_key, v_request_hash, 'start-challenge',
    v_challenge.id, v_response
  );

  return v_response;
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'start_challenge_conflict';
end;
$$;

create or replace function public.process_auto_start()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_challenge public.challenges%rowtype;
  v_started integer := 0;
begin
  set local lock_timeout = '3s';
  for v_challenge in
    select *
      from public.challenges
     where status = 'WAITING'
       and auto_start_at <= clock_timestamp()
       and deadline > clock_timestamp()
     order by auto_start_at, id
     for update skip locked
  loop
    perform public.start_challenge(
      v_challenge.id,
      'auto-start-' || v_challenge.id::text
    );
    v_started := v_started + 1;
  end loop;
  return v_started;
end;
$$;

revoke all on function public.start_challenge(uuid, text)
  from public, anon, service_role;
grant execute on function public.start_challenge(uuid, text)
  to authenticated;

revoke all on function public.process_auto_start()
  from public, anon, authenticated;
grant execute on function public.process_auto_start()
  to service_role;
