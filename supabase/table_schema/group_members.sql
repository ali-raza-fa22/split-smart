create table public.group_members (
  id uuid not null default gen_random_uuid (),
  group_id uuid not null,
  user_id uuid not null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  is_admin boolean not null default false,
  constraint group_members_pkey primary key (id),
  constraint group_members_group_id_user_id_key unique (group_id, user_id),
  constraint group_members_group_id_fkey foreign KEY (group_id) references groups (id) on delete CASCADE,
  constraint group_members_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists group_members_group_id_idx on public.group_members using btree (group_id) TABLESPACE pg_default;

create index IF not exists group_members_user_id_idx on public.group_members using btree (user_id) TABLESPACE pg_default;