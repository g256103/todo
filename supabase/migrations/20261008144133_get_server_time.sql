-- Lightweight server clock for client UX guards (spec appendix A ⑰).

create or replace function public.get_server_time()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select pg_catalog.clock_timestamp();
$$;

revoke all on function public.get_server_time() from public, anon, service_role;
grant execute on function public.get_server_time() to authenticated;
