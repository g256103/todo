-- use_qr: mark qr_codes AVAILABLE -> USED (spec ch.8 / ch.13)

create or replace function public.use_qr(
  p_token text,
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
  v_qr public.qr_codes%rowtype;
  v_challenge public.challenges%rowtype;
  v_response jsonb;
  v_now timestamptz;
begin
  set local lock_timeout = '3s';
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'unauthorized';
  end if;

  if p_token is null
     or btrim(p_token) = ''
     or p_token <> btrim(p_token)
     or char_length(p_token) > 200 then
    raise exception using errcode = 'P0001', message = 'invalid_token';
  end if;

  if p_idempotency_key is null
     or char_length(p_idempotency_key) < 1
     or char_length(p_idempotency_key) > 200
     or btrim(p_idempotency_key) = ''
     or p_idempotency_key <> btrim(p_idempotency_key) then
    raise exception using errcode = 'P0001', message = 'invalid_idempotency_key';
  end if;

  v_request_hash := pg_catalog.md5(
    (jsonb_build_object('token', p_token))::text
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
    if v_existing_operation <> 'use-qr'
       or v_existing_hash is distinct from v_request_hash then
      raise exception using errcode = 'P0001', message = 'idempotency_key_reused';
    end if;
    if v_existing_response is null then
      raise exception using errcode = 'P0001', message = 'use_qr_conflict';
    end if;
    return v_existing_response;
  end if;

  select *
    into v_qr
    from public.qr_codes
   where token = p_token
     and user_id = v_user_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'qr_not_found';
  end if;

  select *
    into v_challenge
    from public.challenges
   where id = v_qr.challenge_id
     and user_id = v_user_id
   for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'qr_not_found';
  end if;

  if v_challenge.status is distinct from 'SUCCESS' then
    raise exception using errcode = 'P0001', message = 'challenge_not_success';
  end if;

  perform 1
    from public.challenge_tasks
   where challenge_id = v_challenge.id
   for update;

  select *
    into v_qr
    from public.qr_codes
   where id = v_qr.id
   for update;

  if v_qr.status = 'USED' then
    raise exception using errcode = 'P0001', message = 'qr_already_used';
  end if;

  v_now := clock_timestamp();

  update public.qr_codes
     set status = 'USED',
         used_at = v_now
   where id = v_qr.id;

  v_response := jsonb_build_object(
    'result', 'used',
    'qr_code', jsonb_build_object(
      'id', v_qr.id,
      'challenge_id', v_qr.challenge_id,
      'status', 'USED',
      'used_at', v_now
    )
  );

  insert into public.idempotency_keys (
    user_id, key, request_hash, operation, resource_id, response
  )
  values (
    v_user_id, p_idempotency_key, v_request_hash, 'use-qr',
    v_qr.id, v_response
  );

  return v_response;
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'use_qr_conflict';
end;
$$;

revoke all on function public.use_qr(text, text)
  from public, anon, service_role;
grant execute on function public.use_qr(text, text)
  to authenticated;
