begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, raw_user_meta_data) values
  ('88888888-0000-0000-0000-000000000801', '{"full_name":"Clock User"}');

select set_config(
  'request.jwt.claim.sub',
  '88888888-0000-0000-0000-000000000801',
  true
);
set local role authenticated;

select isnt(
  public.get_server_time(),
  null,
  'authenticated can read server time'
);

select cmp_ok(
  public.get_server_time(),
  '>=',
  now() - interval '5 seconds',
  'server time is not far in the past'
);

reset role;
set local role anon;

select throws_ok(
  $$select public.get_server_time()$$,
  '42501',
  null,
  'anon cannot call get_server_time'
);
reset role;

select * from finish();
rollback;
