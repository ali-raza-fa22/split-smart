create table public.expenses (
  id uuid not null default gen_random_uuid (),
  group_id uuid not null,
  title text not null,
  description text null,
  total_amount numeric(10, 2) not null,
  paid_by uuid not null,
  created_by uuid not null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint expenses_pkey primary key (id),
  constraint expenses_created_by_fkey foreign KEY (created_by) references auth.users (id) on delete CASCADE,
  constraint expenses_group_id_fkey foreign KEY (group_id) references groups (id) on delete CASCADE,
  constraint expenses_paid_by_fkey foreign KEY (paid_by) references auth.users (id) on delete CASCADE,
  constraint expenses_total_amount_check check ((total_amount > (0)::numeric))
) TABLESPACE pg_default;

create index IF not exists expenses_created_at_idx on public.expenses using btree (created_at) TABLESPACE pg_default;

create index IF not exists expenses_group_id_idx on public.expenses using btree (group_id) TABLESPACE pg_default;

create index IF not exists expenses_paid_by_idx on public.expenses using btree (paid_by) TABLESPACE pg_default;

create trigger trigger_create_expense_shares
after INSERT on expenses for EACH row
execute FUNCTION create_expense_shares ();