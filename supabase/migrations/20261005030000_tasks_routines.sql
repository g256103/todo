-- 0003: tasks / routines / routine_tasks

create table public.tasks (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete restrict,
  name       text not null
             constraint tasks_name_chk check (char_length(btrim(name)) between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)            -- 他テーブルの複合FK(持ち主の一致保証)用
);
create index tasks_user_id_idx on public.tasks (user_id);

create table public.routines (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete restrict,
  name       text not null
             constraint routines_name_chk check (char_length(btrim(name)) between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);
create index routines_user_id_idx on public.routines (user_id);

-- ルーティンとタスクは必ず同じユーザーのもの(複合FKでDBが保証)
create table public.routine_tasks (
  routine_id uuid not null,
  task_id    uuid not null,
  user_id    uuid not null references public.users (id) on delete restrict,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (routine_id, task_id),
  foreign key (routine_id, user_id) references public.routines (id, user_id) on delete cascade,
  foreign key (task_id, user_id)    references public.tasks (id, user_id)    on delete cascade
);
create index routine_tasks_task_id_idx on public.routine_tasks (task_id);
create index routine_tasks_user_id_idx on public.routine_tasks (user_id);
