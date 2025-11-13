create table public.messages (
  id uuid not null default gen_random_uuid (),
  sender_id uuid not null,
  receiver_id uuid not null,
  content text not null,
  is_read boolean null default false,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  is_deleted boolean null default false,
  status text null default 'sent'::text,
  deleted_for_users uuid[] null default '{}'::uuid[],
  constraint messages_pkey primary key (id),
  constraint messages_receiver_id_fkey foreign KEY (receiver_id) references auth.users (id) on delete CASCADE,
  constraint messages_sender_id_fkey foreign KEY (sender_id) references auth.users (id) on delete CASCADE,
  constraint messages_status_check check (
    (
      status = any (
        array['sent'::text, 'delivered'::text, 'read'::text]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_messages_created_at_deleted on public.messages using btree (created_at desc, is_deleted) TABLESPACE pg_default
where
  (
    (is_deleted = false)
    or (is_deleted is null)
  );

create index IF not exists idx_messages_deleted_for_users on public.messages using gin (deleted_for_users) TABLESPACE pg_default
where
  (array_length(deleted_for_users, 1) > 0);

create index IF not exists idx_messages_sender_receiver_deleted on public.messages using btree (sender_id, receiver_id, is_deleted) TABLESPACE pg_default
where
  (
    (is_deleted = false)
    or (is_deleted is null)
  );

create index IF not exists messages_created_at_idx on public.messages using btree (created_at) TABLESPACE pg_default;

create index IF not exists messages_receiver_id_idx on public.messages using btree (receiver_id) TABLESPACE pg_default;

create index IF not exists messages_sender_id_idx on public.messages using btree (sender_id) TABLESPACE pg_default;

create trigger update_messages_updated_at BEFORE
update on messages for EACH row
execute FUNCTION update_updated_at_column ();