create table public.user_balances (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  current_balance numeric(10, 2) not null default 0.00,
  total_added numeric(10, 2) not null default 0.00,
  total_spent numeric(10, 2) not null default 0.00,
  total_loans numeric(10, 2) not null default 0.00,
  total_repaid numeric(10, 2) not null default 0.00,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint user_balances_pkey primary key (id),
  constraint user_balances_user_id_key unique (user_id),
  constraint user_balances_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists user_balances_user_id_idx on public.user_balances using btree (user_id) TABLESPACE pg_default;