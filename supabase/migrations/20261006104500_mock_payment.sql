-- Mock Payment RPCs

create or replace function public.mock_payment_create(
  p_amount integer,
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
  v_payment_id uuid;
  v_response jsonb;
begin
  set local lock_timeout = '3s';

  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'unauthorized';
  end if;

  if p_amount is null
     or p_amount < 100
     or p_amount > 5000
     or p_amount % 100 <> 0 then
    raise exception using errcode = 'P0001', message = 'invalid_amount';
  end if;

  if p_idempotency_key is null
     or char_length(p_idempotency_key) < 1
     or char_length(p_idempotency_key) > 200
     or btrim(p_idempotency_key) = ''
     or p_idempotency_key <> btrim(p_idempotency_key) then
    raise exception using errcode = 'P0001', message = 'invalid_idempotency_key';
  end if;

  v_request_hash := pg_catalog.md5(
    (
      jsonb_build_object('amount', p_amount)
    )::text
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
    if v_existing_operation <> 'mock-payment-create'
       or v_existing_hash is distinct from v_request_hash then
      raise exception using errcode = 'P0001', message = 'idempotency_key_reused';
    end if;
    if v_existing_response is null then
      raise exception using errcode = 'P0001', message = 'payment_creation_conflict';
    end if;
    return jsonb_build_object(
      'response', v_existing_response,
      'replayed', true
    );
  end if;

  insert into public.payments (user_id, amount, status, paid_at)
  values (v_user_id, p_amount, 'PENDING', null)
  returning id into v_payment_id;

  select jsonb_build_object(
           'payment', jsonb_build_object(
             'id', p.id,
             'amount', p.amount,
             'status', p.status,
             'created_at', p.created_at
           )
         )
    into v_response
    from public.payments p
   where p.id = v_payment_id;

  insert into public.idempotency_keys (
    user_id,
    key,
    operation,
    resource_id,
    request_hash,
    response
  )
  values (
    v_user_id,
    p_idempotency_key,
    'mock-payment-create',
    v_payment_id,
    v_request_hash,
    v_response
  );

  return jsonb_build_object(
    'response', v_response,
    'replayed', false
  );
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'payment_creation_conflict';
end;
$$;

create or replace function public.mock_payment_success(
  p_payment_id uuid,
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
  v_payment public.payments%rowtype;
  v_response jsonb;
begin
  set local lock_timeout = '3s';

  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'unauthorized';
  end if;

  if p_idempotency_key is null
     or char_length(p_idempotency_key) < 1
     or char_length(p_idempotency_key) > 200
     or btrim(p_idempotency_key) = ''
     or p_idempotency_key <> btrim(p_idempotency_key) then
    raise exception using errcode = 'P0001', message = 'invalid_idempotency_key';
  end if;

  v_request_hash := pg_catalog.md5(
    (
      jsonb_build_object('payment_id', lower(p_payment_id::text))
    )::text
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
    if v_existing_operation <> 'mock-payment-success'
       or v_existing_hash is distinct from v_request_hash then
      raise exception using errcode = 'P0001', message = 'idempotency_key_reused';
    end if;
    if v_existing_response is null then
      raise exception using errcode = 'P0001', message = 'payment_creation_conflict';
    end if;
    return jsonb_build_object(
      'response', v_existing_response,
      'replayed', true
    );
  end if;

  select *
    into v_payment
    from public.payments p
   where p.id = p_payment_id
     and p.user_id = v_user_id
   for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'payment_not_found';
  end if;
  if v_payment.status <> 'PENDING' then
    raise exception using errcode = 'P0001', message = 'payment_not_pending';
  end if;

  update public.payments
     set status = 'SUCCESS',
         paid_at = clock_timestamp()
   where id = v_payment.id;

  select jsonb_build_object(
           'payment', jsonb_build_object(
             'id', p.id,
             'amount', p.amount,
             'status', p.status,
             'paid_at', p.paid_at
           )
         )
    into v_response
    from public.payments p
   where p.id = v_payment.id;

  insert into public.idempotency_keys (
    user_id,
    key,
    operation,
    resource_id,
    request_hash,
    response
  )
  values (
    v_user_id,
    p_idempotency_key,
    'mock-payment-success',
    v_payment.id,
    v_request_hash,
    v_response
  );

  return jsonb_build_object(
    'response', v_response,
    'replayed', false
  );
end;
$$;

create or replace function public.mock_payment_failure(
  p_payment_id uuid,
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
  v_payment public.payments%rowtype;
  v_response jsonb;
begin
  set local lock_timeout = '3s';

  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'unauthorized';
  end if;

  if p_idempotency_key is null
     or char_length(p_idempotency_key) < 1
     or char_length(p_idempotency_key) > 200
     or btrim(p_idempotency_key) = ''
     or p_idempotency_key <> btrim(p_idempotency_key) then
    raise exception using errcode = 'P0001', message = 'invalid_idempotency_key';
  end if;

  v_request_hash := pg_catalog.md5(
    (
      jsonb_build_object('payment_id', lower(p_payment_id::text))
    )::text
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
    if v_existing_operation <> 'mock-payment-failure'
       or v_existing_hash is distinct from v_request_hash then
      raise exception using errcode = 'P0001', message = 'idempotency_key_reused';
    end if;
    if v_existing_response is null then
      raise exception using errcode = 'P0001', message = 'payment_creation_conflict';
    end if;
    return jsonb_build_object(
      'response', v_existing_response,
      'replayed', true
    );
  end if;

  select *
    into v_payment
    from public.payments p
   where p.id = p_payment_id
     and p.user_id = v_user_id
   for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'payment_not_found';
  end if;
  if v_payment.status <> 'PENDING' then
    raise exception using errcode = 'P0001', message = 'payment_not_pending';
  end if;

  update public.payments
     set status = 'FAILED',
         paid_at = null
   where id = v_payment.id;

  select jsonb_build_object(
           'payment', jsonb_build_object(
             'id', p.id,
             'amount', p.amount,
             'status', p.status,
             'paid_at', p.paid_at
           )
         )
    into v_response
    from public.payments p
   where p.id = v_payment.id;

  insert into public.idempotency_keys (
    user_id,
    key,
    operation,
    resource_id,
    request_hash,
    response
  )
  values (
    v_user_id,
    p_idempotency_key,
    'mock-payment-failure',
    v_payment.id,
    v_request_hash,
    v_response
  );

  return jsonb_build_object(
    'response', v_response,
    'replayed', false
  );
end;
$$;

revoke all on function public.mock_payment_create(integer, text)
  from public, anon, service_role;
revoke all on function public.mock_payment_success(uuid, text)
  from public, anon, service_role;
revoke all on function public.mock_payment_failure(uuid, text)
  from public, anon, service_role;

grant execute on function public.mock_payment_create(integer, text)
  to authenticated;
grant execute on function public.mock_payment_success(uuid, text)
  to authenticated;
grant execute on function public.mock_payment_failure(uuid, text)
  to authenticated;
