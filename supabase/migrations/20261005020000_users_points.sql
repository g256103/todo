-- 0002: users / points / サインアップ時の自動作成

create table public.users (
  id          uuid primary key references auth.users (id) on delete restrict,
  user_name   text not null default 'ユーザー'
              constraint users_user_name_chk check (char_length(btrim(user_name)) between 1 and 50),
  deleted_at  timestamptz,                       -- 退会は論理削除
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.points (
  user_id          uuid primary key references public.users (id) on delete restrict,
  available_points integer not null default 0
                   constraint points_available_chk check (available_points >= 0),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- auth.users への INSERT 時に users + points を作る
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  v_name := nullif(btrim(left(coalesce(
              new.raw_user_meta_data ->> 'full_name',
              new.raw_user_meta_data ->> 'name', ''), 50)), '');

  insert into public.users (id, user_name)
  values (new.id, coalesce(v_name, 'ユーザー'))
  on conflict (id) do nothing;

  insert into public.points (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
