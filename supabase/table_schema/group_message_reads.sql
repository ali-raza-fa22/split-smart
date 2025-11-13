create table public.group_message_reads (
  id uuid not null default gen_random_uuid (),
  message_id uuid not null,
  user_id uuid not null,
  read_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint group_message_reads_pkey primary key (id),
  constraint group_message_reads_message_id_user_id_key unique (message_id, user_id),
  constraint group_message_reads_message_id_fkey foreign KEY (message_id) references group_messages (id) on delete CASCADE,
  constraint group_message_reads_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_group_message_reads_message_id on public.group_message_reads using btree (message_id) TABLESPACE pg_default;

create index IF not exists idx_group_message_reads_user_id on public.group_message_reads using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_group_message_reads_user_message on public.group_message_reads using btree (user_id, message_id) TABLESPACE pg_default;