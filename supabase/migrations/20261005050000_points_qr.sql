-- 0005: purchases / cashouts / point_transactions / qr_codes / idempotency_keys

create table public.purchases (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users (id) on delete restrict,
  points_used  integer not null constraint purchases_points_chk check (points_used > 0),
  status       text not null default 'PENDING'
               constraint purchases_status_chk check (status in ('PENDING', 'COMPLETED', 'FAILED')),
  completed_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint purchases_completed_chk check ((status = 'COMPLETED') = (completed_at is not null)),
  unique (id, user_id)
);
create index purchases_user_id_idx on public.purchases (user_id, created_at desc);

create table public.cashouts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users (id) on delete restrict,
  points_used  integer not null
               constraint cashouts_points_chk check (points_used > 0 and points_used % 10 = 0),
  fee_points   integer not null
               constraint cashouts_fee_chk check (fee_points >= 0),
  cash_amount  integer not null
               constraint cashouts_cash_chk check (cash_amount >= 0),
  status       text not null default 'PENDING'
               constraint cashouts_status_chk check (status in ('PENDING', 'COMPLETED', 'FAILED')),
  completed_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint cashouts_fee_rate_chk  check (fee_points = points_used / 10),   -- 手数料10%
  constraint cashouts_completed_chk check ((status = 'COMPLETED') = (completed_at is not null)),
  unique (id, user_id)
);
create index cashouts_user_id_idx on public.cashouts (user_id, created_at desc);

-- ポイント台帳。GRANT行だけ remaining_amount / expires_at を持ち、期限が近い順に消費する
create table public.point_transactions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.users (id) on delete restrict,
  type             text not null
                   constraint point_tx_type_chk check (type in ('GRANT', 'PURCHASE', 'CASHOUT', 'EXPIRE')),
  amount           integer not null,            -- GRANTは正、それ以外は負
  challenge_id     uuid,
  purchase_id      uuid,
  cashout_id       uuid,
  remaining_amount integer,
  expires_at       timestamptz,
  created_at       timestamptz not null default now(),
  foreign key (challenge_id, user_id) references public.challenges (id, user_id) on delete restrict,
  foreign key (purchase_id,  user_id) references public.purchases  (id, user_id) on delete restrict,
  foreign key (cashout_id,   user_id) references public.cashouts   (id, user_id) on delete restrict,
  constraint point_tx_sign_chk check (
    (type = 'GRANT' and amount > 0) or (type <> 'GRANT' and amount < 0)),
  constraint point_tx_grant_chk check (
    type <> 'GRANT' or (challenge_id is not null and remaining_amount is not null
                        and expires_at is not null and remaining_amount between 0 and amount)),
  constraint point_tx_nongrant_chk check (
    type = 'GRANT' or (remaining_amount is null and expires_at is null)),
  constraint point_tx_purchase_chk check (type <> 'PURCHASE' or purchase_id is not null),
  constraint point_tx_cashout_chk  check (type <> 'CASHOUT'  or cashout_id  is not null)
);
-- 二重付与防止: 1つのChallengeにつきGRANTは1行まで
create unique index point_tx_one_grant_per_challenge
  on public.point_transactions (challenge_id) where type = 'GRANT';
-- FIFO消費・失効バッチ用
create index point_tx_fifo_idx
  on public.point_transactions (user_id, expires_at) where type = 'GRANT' and remaining_amount > 0;
create index point_tx_user_idx on public.point_transactions (user_id, created_at desc);

-- QR: SUCCESS時に初めて行を作る(トリガーで強制)
create table public.qr_codes (
  id           uuid primary key default gen_random_uuid(),
  challenge_id uuid not null unique,
  user_id      uuid not null references public.users (id) on delete restrict,
  token        text not null unique
               default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  status       text not null default 'AVAILABLE'
               constraint qr_status_chk check (status in ('AVAILABLE', 'USED')),
  used_at      timestamptz,
  created_at   timestamptz not null default now(),
  constraint qr_used_chk check ((status = 'USED') = (used_at is not null)),
  foreign key (challenge_id, user_id) references public.challenges (id, user_id) on delete restrict
);
create index qr_codes_user_id_idx on public.qr_codes (user_id);

create table public.idempotency_keys (
  user_id      uuid not null references public.users (id) on delete restrict,
  key          text not null constraint idem_key_chk check (char_length(key) between 1 and 200),
  request_hash text not null,
  response     jsonb,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default (now() + interval '24 hours'),
  primary key (user_id, key)
);
create index idempotency_keys_expires_idx on public.idempotency_keys (expires_at);
