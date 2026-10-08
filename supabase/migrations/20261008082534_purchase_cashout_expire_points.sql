-- purchase_points / cashout_points / process_point_expiry (spec ch.7–8, UC21–23)

create or replace function public.debit_points_fifo(
  p_user_id uuid,
  p_amount integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_remaining integer := p_amount;
  v_grant public.point_transactions%rowtype;
  v_take integer;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception using errcode = 'P0001', message = 'invalid_amount';
  end if;

  perform 1
    from public.points
   where user_id = p_user_id
   for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'insufficient_balance';
  end if;

  if (select available_points from public.points where user_id = p_user_id) < p_amount then
    raise exception using errcode = 'P0001', message = 'insufficient_balance';
  end if;

  for v_grant in
    select *
      from public.point_transactions
     where user_id = p_user_id
       and type = 'GRANT'
       and remaining_amount > 0
     order by expires_at asc, created_at asc
     for update
  loop
    exit when v_remaining <= 0;
    v_take := least(v_grant.remaining_amount, v_remaining);
    update public.point_transactions
       set remaining_amount = remaining_amount - v_take
     where id = v_grant.id;
    v_remaining := v_remaining - v_take;
  end loop;

  if v_remaining > 0 then
    raise exception using errcode = 'P0001', message = 'insufficient_balance';
  end if;

  update public.points
     set available_points = available_points - p_amount,
         updated_at = now()
   where user_id = p_user_id;
end;
$$;

revoke all on function public.debit_points_fifo(uuid, integer)
  from public, anon, authenticated, service_role;

create or replace function public.purchase_points(
  p_catalog_item_id text,
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
  v_points_used integer;
  v_item_name text;
  v_purchase_id uuid;
  v_response jsonb;
  v_now timestamptz;
begin
  set local lock_timeout = '3s';
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'unauthorized';
  end if;

  if p_catalog_item_id is null
     or btrim(p_catalog_item_id) = ''
     or p_catalog_item_id <> btrim(p_catalog_item_id)
     or char_length(p_catalog_item_id) > 100 then
    raise exception using errcode = 'P0001', message = 'invalid_catalog_item';
  end if;

  if p_idempotency_key is null
     or char_length(p_idempotency_key) < 1
     or char_length(p_idempotency_key) > 200
     or btrim(p_idempotency_key) = ''
     or p_idempotency_key <> btrim(p_idempotency_key) then
    raise exception using errcode = 'P0001', message = 'invalid_idempotency_key';
  end if;

  v_points_used := case p_catalog_item_id
    when 'book_1000' then 1000
    when 'material_500' then 500
    when 'cert_2000' then 2000
    else null
  end;
  v_item_name := case p_catalog_item_id
    when 'book_1000' then '参考書（モック）'
    when 'material_500' then '学習教材（モック）'
    when 'cert_2000' then '資格教材（モック）'
    else null
  end;
  if v_points_used is null then
    raise exception using errcode = 'P0001', message = 'invalid_catalog_item';
  end if;

  v_request_hash := pg_catalog.md5(
    (jsonb_build_object('catalog_item_id', p_catalog_item_id))::text
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
    if v_existing_operation <> 'purchase-points'
       or v_existing_hash is distinct from v_request_hash then
      raise exception using errcode = 'P0001', message = 'idempotency_key_reused';
    end if;
    if v_existing_response is null then
      raise exception using errcode = 'P0001', message = 'purchase_points_conflict';
    end if;
    return v_existing_response;
  end if;

  perform public.debit_points_fifo(v_user_id, v_points_used);

  v_now := clock_timestamp();
  insert into public.purchases (
    user_id, points_used, item_name, status, completed_at, created_at, updated_at
  )
  values (
    v_user_id, v_points_used, v_item_name, 'COMPLETED', v_now, v_now, v_now
  )
  returning id into v_purchase_id;

  insert into public.point_transactions (
    user_id, type, amount, purchase_id, created_at
  )
  values (
    v_user_id, 'PURCHASE', -v_points_used, v_purchase_id, v_now
  );

  v_response := jsonb_build_object(
    'result', 'completed',
    'purchase', jsonb_build_object(
      'id', v_purchase_id,
      'catalog_item_id', p_catalog_item_id,
      'item_name', v_item_name,
      'points_used', v_points_used,
      'status', 'COMPLETED',
      'completed_at', v_now
    ),
    'available_points', (
      select available_points from public.points where user_id = v_user_id
    )
  );

  insert into public.idempotency_keys (
    user_id, key, request_hash, operation, resource_id, response
  )
  values (
    v_user_id, p_idempotency_key, v_request_hash, 'purchase-points',
    v_purchase_id, v_response
  );

  return v_response;
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'purchase_points_conflict';
end;
$$;

revoke all on function public.purchase_points(text, text)
  from public, anon, service_role;
grant execute on function public.purchase_points(text, text)
  to authenticated;

create or replace function public.cashout_points(
  p_points_used integer,
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
  v_success_count integer;
  v_first_success timestamptz;
  v_fee_points integer;
  v_cash_amount integer;
  v_cashout_id uuid;
  v_response jsonb;
  v_now timestamptz;
begin
  set local lock_timeout = '3s';
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'unauthorized';
  end if;

  if p_points_used is null
     or p_points_used < 1000
     or p_points_used % 10 <> 0 then
    raise exception using errcode = 'P0001', message = 'invalid_points_used';
  end if;

  if p_idempotency_key is null
     or char_length(p_idempotency_key) < 1
     or char_length(p_idempotency_key) > 200
     or btrim(p_idempotency_key) = ''
     or p_idempotency_key <> btrim(p_idempotency_key) then
    raise exception using errcode = 'P0001', message = 'invalid_idempotency_key';
  end if;

  v_fee_points := p_points_used / 10;
  v_cash_amount := p_points_used - v_fee_points;

  v_request_hash := pg_catalog.md5(
    (jsonb_build_object('points_used', p_points_used))::text
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
    if v_existing_operation <> 'cashout-points'
       or v_existing_hash is distinct from v_request_hash then
      raise exception using errcode = 'P0001', message = 'idempotency_key_reused';
    end if;
    if v_existing_response is null then
      raise exception using errcode = 'P0001', message = 'cashout_points_conflict';
    end if;
    return v_existing_response;
  end if;

  select count(*)::integer,
         min(finished_at)
    into v_success_count, v_first_success
    from public.challenges
   where user_id = v_user_id
     and status = 'SUCCESS';

  if v_success_count < 7
     or v_first_success is null
     or clock_timestamp() < v_first_success + interval '7 days' then
    raise exception using errcode = 'P0001', message = 'cashout_not_eligible';
  end if;

  perform public.debit_points_fifo(v_user_id, p_points_used);

  v_now := clock_timestamp();
  insert into public.cashouts (
    user_id, points_used, fee_points, cash_amount, status, completed_at,
    created_at, updated_at
  )
  values (
    v_user_id, p_points_used, v_fee_points, v_cash_amount, 'COMPLETED', v_now,
    v_now, v_now
  )
  returning id into v_cashout_id;

  insert into public.point_transactions (
    user_id, type, amount, cashout_id, created_at
  )
  values (
    v_user_id, 'CASHOUT', -p_points_used, v_cashout_id, v_now
  );

  v_response := jsonb_build_object(
    'result', 'completed',
    'cashout', jsonb_build_object(
      'id', v_cashout_id,
      'points_used', p_points_used,
      'fee_points', v_fee_points,
      'cash_amount', v_cash_amount,
      'status', 'COMPLETED',
      'completed_at', v_now
    ),
    'available_points', (
      select available_points from public.points where user_id = v_user_id
    )
  );

  insert into public.idempotency_keys (
    user_id, key, request_hash, operation, resource_id, response
  )
  values (
    v_user_id, p_idempotency_key, v_request_hash, 'cashout-points',
    v_cashout_id, v_response
  );

  return v_response;
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'cashout_points_conflict';
end;
$$;

revoke all on function public.cashout_points(integer, text)
  from public, anon, service_role;
grant execute on function public.cashout_points(integer, text)
  to authenticated;

create or replace function public.process_point_expiry()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grant public.point_transactions%rowtype;
  v_processed integer := 0;
  v_now timestamptz := clock_timestamp();
begin
  set local lock_timeout = '3s';

  for v_grant in
    select *
      from public.point_transactions
     where type = 'GRANT'
       and remaining_amount > 0
       and expires_at <= v_now
     order by expires_at asc, created_at asc
     for update skip locked
  loop
    perform 1
      from public.points
     where user_id = v_grant.user_id
     for update;

    insert into public.point_transactions (
      user_id, type, amount, created_at
    )
    values (
      v_grant.user_id, 'EXPIRE', -v_grant.remaining_amount, v_now
    );

    update public.points
       set available_points = available_points - v_grant.remaining_amount,
           updated_at = now()
     where user_id = v_grant.user_id;

    update public.point_transactions
       set remaining_amount = 0
     where id = v_grant.id;

    v_processed := v_processed + 1;
  end loop;

  return v_processed;
end;
$$;

revoke all on function public.process_point_expiry()
  from public, anon, authenticated;
grant execute on function public.process_point_expiry()
  to service_role;
