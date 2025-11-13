create table public.group_messages (
  id uuid not null default gen_random_uuid (),
  group_id uuid not null,
  sender_id uuid not null,
  content text not null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  category text null default 'general'::text,
  expense_data jsonb null,
  payment_data jsonb null,
  is_deleted boolean null default false,
  deleted_for_users uuid[] null default '{}'::uuid[],
  constraint group_messages_pkey primary key (id),
  constraint group_messages_group_id_fkey foreign KEY (group_id) references groups (id) on delete CASCADE,
  constraint group_messages_sender_id_fkey foreign KEY (sender_id) references auth.users (id) on delete CASCADE,
  constraint group_messages_category_check check (
    (
      category = any (
        array[
          'general'::text,
          'expense'::text,
          'payment'::text,
          'reminder'::text,
          'info'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists group_messages_category_idx on public.group_messages using btree (category) TABLESPACE pg_default;

create index IF not exists group_messages_created_at_idx on public.group_messages using btree (created_at) TABLESPACE pg_default;

create index IF not exists group_messages_expense_data_idx on public.group_messages using gin (expense_data) TABLESPACE pg_default;

create index IF not exists group_messages_group_id_idx on public.group_messages using btree (group_id) TABLESPACE pg_default;

create index IF not exists group_messages_payment_data_idx on public.group_messages using gin (payment_data) TABLESPACE pg_default;

create index IF not exists idx_group_messages_deleted_for_users on public.group_messages using gin (deleted_for_users) TABLESPACE pg_default
where
  (array_length(deleted_for_users, 1) > 0);