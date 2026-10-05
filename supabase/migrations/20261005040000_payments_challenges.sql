-- 0004: payments / challenges / challenge_tasks

create table public.payments (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete restrict,
  amount     integer not null
             constraint payments_amount_chk check (amount between 100 and 5000 and amount % 100 = 0),
  status     text not null default 'PENDING'
             constraint payments_status_chk check (status in ('PENDING', 'SUCCESS', 'FAILED')),
  paid_at    timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_paid_at_chk check ((status = 'SUCCESS') = (paid_at is not null)),
  unique (id, user_id, amount)
);
create index payments_user_id_idx on public.payments (user_id, created_at desc);

create table public.challenges (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users (id) on delete restrict,
  payment_id    uuid not null unique,
  amount        integer not null,
  status        text not null default 'WAITING'
                constraint challenges_status_chk
                check (status in ('WAITING', 'IN_PROGRESS', 'SUCCESS', 'FAILED')),
  auto_start_at timestamptz not null default (now() + interval '5 minutes'),
  deadline      timestamptz not null,
  started_at    timestamptz,
  finished_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  -- paymentと持ち主・金額が食い違う行を作れない
  foreign key (payment_id, user_id, amount)
    references public.payments (id, user_id, amount) on delete restrict,
  constraint challenges_deadline_chk   check (deadline > auto_start_at),
  constraint challenges_auto_start_chk check (auto_start_at > created_at),
  constraint challenges_status_times_chk check (
       (status = 'WAITING'           and started_at is null     and finished_at is null)
    or (status = 'IN_PROGRESS'       and started_at is not null and finished_at is null)
    or (status in ('SUCCESS','FAILED') and started_at is not null and finished_at is not null)
  ),
  constraint challenges_time_order_chk check (finished_at is null or finished_at >= started_at),
  unique (id, user_id)
);
create index challenges_user_id_idx on public.challenges (user_id, created_at desc);
-- ユーザーごとに WAITING / IN_PROGRESS は1件まで
create unique index challenges_one_active_per_user
  on public.challenges (user_id) where status in ('WAITING', 'IN_PROGRESS');
-- cron用の部分インデックス
create index challenges_auto_start_idx on public.challenges (auto_start_at) where status = 'WAITING';
create index challenges_deadline_idx   on public.challenges (deadline)      where status = 'IN_PROGRESS';

create table public.challenge_tasks (
  id                 uuid primary key default gen_random_uuid(),
  challenge_id       uuid not null,
  user_id            uuid not null references public.users (id) on delete restrict,
  task_id            uuid,                       -- 元タスク削除で NULL になる(履歴は snapshot が守る)
  task_name_snapshot text not null
                     constraint challenge_tasks_snapshot_chk check (char_length(btrim(task_name_snapshot)) >= 1),
  sort_order         integer not null default 0,
  status             text not null default 'INCOMPLETE'
                     constraint challenge_tasks_status_chk check (status in ('INCOMPLETE', 'COMPLETED')),
  completed_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint challenge_tasks_completed_chk check ((status = 'COMPLETED') = (completed_at is not null)),
  foreign key (challenge_id, user_id) references public.challenges (id, user_id) on delete restrict,
  -- PostgreSQL 15+ の列指定 SET NULL。user_id は残して task_id だけ NULL にする
  foreign key (task_id, user_id) references public.tasks (id, user_id) on delete set null (task_id),
  unique (challenge_id, task_id)
);
create index challenge_tasks_task_id_idx on public.challenge_tasks (task_id);
create index challenge_tasks_user_id_idx on public.challenge_tasks (user_id);
