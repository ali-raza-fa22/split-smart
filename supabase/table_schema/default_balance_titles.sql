create table public.default_balance_titles (
  id uuid not null default gen_random_uuid (),
  title text not null,
  category text not null,
  icon text null,
  is_active boolean null default true,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint default_balance_titles_pkey primary key (id),
  constraint default_balance_titles_title_key unique (title),
  constraint default_balance_titles_category_check check (
    (
      category = any (
        array['income'::text, 'expense'::text, 'other'::text]
      )
    )
  )
) TABLESPACE pg_default;