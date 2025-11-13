create table public.group_message_deliveries (
  id uuid not null default gen_random_uuid (),
  message_id uuid not null,
  receiver_id uuid not null,
  status text not null default 'sent'::text,
  delivered_at timestamp with time zone null,
  read_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  constraint group_message_deliveries_pkey primary key (id),
  constraint group_message_deliveries_message_id_receiver_id_key unique (message_id, receiver_id),
  constraint group_message_deliveries_message_id_fkey foreign KEY (message_id) references group_messages (id) on delete CASCADE,
  constraint group_message_deliveries_receiver_id_fkey foreign KEY (receiver_id) references profiles (id) on delete CASCADE,
  constraint group_message_deliveries_status_check check (
    (
      status = any (
        array['sent'::text, 'delivered'::text, 'read'::text]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_group_message_deliveries_message_id on public.group_message_deliveries using btree (message_id) TABLESPACE pg_default;

create index IF not exists idx_group_message_deliveries_receiver_id on public.group_message_deliveries using btree (receiver_id) TABLESPACE pg_default;

create index IF not exists idx_group_message_deliveries_status on public.group_message_deliveries using btree (status) TABLESPACE pg_default;