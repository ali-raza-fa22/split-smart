create table public.balance_transactions (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  transaction_type text not null,
  amount numeric(10, 2) not null,
  title text not null,
  description text null,
  expense_share_id uuid null,
  group_id uuid null,
  balance_before numeric(10, 2) not null,
  balance_after numeric(10, 2) not null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint balance_transactions_pkey primary key (id),
  constraint balance_transactions_expense_share_id_fkey foreign KEY (expense_share_id) references expense_shares (id) on delete set null,
  constraint balance_transactions_group_id_fkey foreign KEY (group_id) references groups (id) on delete set null,
  constraint balance_transactions_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint balance_transactions_amount_check check ((amount > (0)::numeric)),
  constraint balance_transactions_transaction_type_check check (
    (
      transaction_type = any (
        array[
          'add'::text,
          'spend'::text,
          'loan'::text,
          'repay'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists balance_transactions_created_at_idx on public.balance_transactions using btree (created_at) TABLESPACE pg_default;

create index IF not exists balance_transactions_expense_share_id_idx on public.balance_transactions using btree (expense_share_id) TABLESPACE pg_default;

create index IF not exists balance_transactions_group_id_idx on public.balance_transactions using btree (group_id) TABLESPACE pg_default;

create index IF not exists balance_transactions_type_idx on public.balance_transactions using btree (transaction_type) TABLESPACE pg_default;

create index IF not exists balance_transactions_user_id_idx on public.balance_transactions using btree (user_id) TABLESPACE pg_default;

create trigger trigger_update_user_balance_on_transaction BEFORE INSERT on balance_transactions for EACH row
execute FUNCTION update_user_balance_on_transaction ();