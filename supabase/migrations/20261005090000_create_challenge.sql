-- 0009: create_challenge RPC

create or replace function public.create_challenge(
  p_payment_id uuid,
  p_task_ids uuid[] default '{}'::uuid[],
  p_routine_ids uuid[] default '{}'::uuid[],
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_task_ids uuid[];
  v_routine_ids uuid[];
  v_ordered_task_ids uuid[];
  v_request_hash text;
  v_existing_operation text;
  v_existing_hash text;
  v_existing_response jsonb;
  v_payment_amount integer;
  v_payment_status text;
  v_created_at timestamptz;
  v_challenge_id uuid;
  v_response jsonb;
  v_missing_count integer;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'unauthorized';
  end if;

  if p_payment_id is null then
    raise exception using errcode = 'P0001', message = 'payment_not_found';
  end if;

  if p_idempotency_key is null
     or char_length(p_idempotency_key) < 1
     or char_length(p_idempotency_key) > 200 then
    raise exception using errcode = 'P0001', message = 'invalid_idempotency_key';
  end if;

  if exists (
    select 1
      from unnest(coalesce(p_task_ids, '{}'::uuid[])) as requested(task_id)
     where requested.task_id is null
  ) or exists (
    select 1
      from unnest(coalesce(p_routine_ids, '{}'::uuid[])) as requested(routine_id)
     where requested.routine_id is null
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_uuid';
  end if;

  v_task_ids := coalesce(
    (select array_agg(task_id order by task_id)
     from (select distinct task_id from unnest(coalesce(p_task_ids, '{}'::uuid[])) as input(task_id)) normalized),
    '{}'::uuid[]
  );
  v_routine_ids := coalesce(
    (select array_agg(routine_id order by routine_id)
     from (select distinct routine_id from unnest(coalesce(p_routine_ids, '{}'::uuid[])) as input(routine_id)) normalized),
    '{}'::uuid[]
  );

  v_request_hash := pg_catalog.md5(
    (
      jsonb_build_object(
        'payment_id', p_payment_id::text,
        'task_ids', to_jsonb(v_task_ids),
        'routine_ids', to_jsonb(v_routine_ids)
      )
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
    if v_existing_operation <> 'create-challenge'
       or v_existing_hash is null
       or v_existing_hash is distinct from v_request_hash then
      raise exception using errcode = 'P0001', message = 'idempotency_key_reused';
    end if;
    if v_existing_response is null then
      raise exception using errcode = 'P0001', message = 'challenge_creation_conflict';
    end if;
    return v_existing_response;
  end if;

  select p.amount, p.status
    into v_payment_amount, v_payment_status
    from public.payments p
   where p.id = p_payment_id
     and p.user_id = v_user_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'payment_not_found';
  end if;
  if v_payment_status <> 'SUCCESS' then
    raise exception using errcode = 'P0001', message = 'payment_not_successful';
  end if;

  if not exists (
    select 1
      from public.payments p
     where p.id = p_payment_id
       and exists (
         select 1
           from public.challenges c
          where c.payment_id = p.id
       )
  ) then
    null;
  else
    raise exception using errcode = 'P0001', message = 'challenge_creation_conflict';
  end if;

  select count(*)
    into v_missing_count
    from unnest(v_task_ids) as requested(task_id)
    left join public.tasks t
      on t.id = requested.task_id
     and t.user_id = v_user_id
   where t.id is null;
  if v_missing_count > 0 then
    raise exception using errcode = 'P0001', message = 'task_not_found';
  end if;

  if exists (
    select 1
      from public.challenges c
     where c.user_id = v_user_id
       and c.status in ('WAITING', 'IN_PROGRESS')
  ) then
    raise exception using errcode = 'P0001', message = 'active_challenge_exists';
  end if;

  select count(*)
    into v_missing_count
    from unnest(v_routine_ids) as requested(routine_id)
    left join public.routines r
      on r.id = requested.routine_id
     and r.user_id = v_user_id
   where r.id is null;
  if v_missing_count > 0 then
    raise exception using errcode = 'P0001', message = 'routine_not_found';
  end if;

  select coalesce(array_agg(candidate.task_id order by
                             candidate.group_order,
                             candidate.routine_id nulls first,
                             candidate.routine_sort_order nulls first,
                             candidate.task_id), '{}'::uuid[])
    into v_ordered_task_ids
    from (
      select distinct on (candidate.task_id)
             candidate.task_id,
             candidate.group_order,
             candidate.routine_id,
             candidate.routine_sort_order
        from (
          select requested.task_id,
                 0 as group_order,
                 null::uuid as routine_id,
                 null::integer as routine_sort_order
            from unnest(v_task_ids) as requested(task_id)
          union all
          select rt.task_id,
                 1 as group_order,
                 rt.routine_id,
                 rt.sort_order as routine_sort_order
            from public.routine_tasks rt
           where rt.user_id = v_user_id
             and rt.routine_id = any(v_routine_ids)
        ) candidate
       order by candidate.task_id,
                candidate.group_order,
                candidate.routine_id nulls first,
                candidate.routine_sort_order nulls first
    ) candidate;

  if coalesce(cardinality(v_ordered_task_ids), 0) = 0 then
    raise exception using errcode = 'P0001', message = 'no_tasks_selected';
  end if;

  select count(*)
    into v_missing_count
    from unnest(v_ordered_task_ids) as selected(task_id)
    left join public.tasks t
      on t.id = selected.task_id
     and t.user_id = v_user_id
   where t.id is null;
  if v_missing_count > 0 then
    raise exception using errcode = 'P0001', message = 'task_not_found';
  end if;

  v_created_at := clock_timestamp();

  insert into public.challenges (
    user_id,
    payment_id,
    amount,
    status,
    auto_start_at,
    deadline,
    created_at,
    updated_at
  )
  values (
    v_user_id,
    p_payment_id,
    v_payment_amount,
    'WAITING',
    v_created_at + interval '5 minutes',
    v_created_at + interval '24 hours',
    v_created_at,
    v_created_at
  )
  returning id into v_challenge_id;

  insert into public.challenge_tasks (
    challenge_id,
    user_id,
    task_id,
    task_name_snapshot,
    sort_order,
    status,
    created_at,
    updated_at
  )
  select v_challenge_id,
         v_user_id,
         selected.task_id,
         t.name,
         selected.sort_order - 1,
         'INCOMPLETE',
         v_created_at,
         v_created_at
    from unnest(v_ordered_task_ids) with ordinality as selected(task_id, sort_order)
    join public.tasks t
      on t.id = selected.task_id
     and t.user_id = v_user_id;

  select jsonb_build_object(
           'challenge', jsonb_build_object(
             'id', c.id,
             'payment_id', c.payment_id,
             'amount', c.amount,
             'status', c.status,
             'auto_start_at', c.auto_start_at,
             'deadline', c.deadline,
             'created_at', c.created_at
           ),
           'challenge_tasks', coalesce(
             (
               select jsonb_agg(
                 jsonb_build_object(
                   'id', ct.id,
                   'task_id', ct.task_id,
                   'task_name_snapshot', ct.task_name_snapshot,
                   'sort_order', ct.sort_order,
                   'status', ct.status
                 )
                 order by ct.sort_order
               )
                 from public.challenge_tasks ct
                where ct.challenge_id = c.id
             ),
             '[]'::jsonb
           )
         )
    into v_response
    from public.challenges c
   where c.id = v_challenge_id;

  insert into public.idempotency_keys (
    user_id,
    key,
    request_hash,
    operation,
    resource_id,
    response
  )
  values (
    v_user_id,
    p_idempotency_key,
    v_request_hash,
    'create-challenge',
    v_challenge_id,
    v_response
  );

  return v_response;
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'challenge_creation_conflict';
end;
$$;

revoke all on function public.create_challenge(uuid, uuid[], uuid[], text)
  from public, anon, service_role;
grant execute on function public.create_challenge(uuid, uuid[], uuid[], text)
  to authenticated;
