create table public.groups (
  id uuid not null default gen_random_uuid (),
  name text not null,
  created_by uuid not null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint groups_pkey primary key (id),
  constraint groups_created_by_fkey foreign KEY (created_by) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;