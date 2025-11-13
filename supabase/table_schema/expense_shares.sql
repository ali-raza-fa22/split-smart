create table public.expense_shares (
  id uuid not null default gen_random_uuid (),
  expense_id uuid not null,
  user_id uuid not null,
  amount_owed numeric(10, 2) not null,
  is_paid boolean null default false,
  paid_at timestamp with time zone null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint expense_shares_pkey primary key (id),
  constraint expense_shares_expense_id_user_id_key unique (expense_id, user_id),
  constraint expense_shares_expense_id_fkey foreign KEY (expense_id) references expenses (id) on delete CASCADE,
  constraint expense_shares_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint expense_shares_amount_owed_check check ((amount_owed >= (0)::numeric))
) TABLESPACE pg_default;

create index IF not exists expense_shares_expense_id_idx on public.expense_shares using btree (expense_id) TABLESPACE pg_default;

create index IF not exists expense_shares_user_id_idx on public.expense_shares using btree (user_id) TABLESPACE pg_default;