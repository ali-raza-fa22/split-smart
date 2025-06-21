-- Create groups table
create table public.groups (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  created_by uuid references auth.users(id) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create group_members table
create table public.group_members (
  id uuid default gen_random_uuid() primary key,
  group_id uuid references public.groups(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(group_id, user_id)
);

-- Create group_messages table
create table public.group_messages (
  id uuid default gen_random_uuid() primary key,
  group_id uuid references public.groups(id) on delete cascade not null,
  sender_id uuid references auth.users(id) not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_messages enable row level security;

-- Create policies for groups
create policy "Users can view their groups"
  on public.groups for select
  using (
    exists (
      select 1 from public.group_members
      where group_id = groups.id
      and user_id = auth.uid()
    )
  );

create policy "Users can create groups"
  on public.groups for insert
  with check (auth.uid() = created_by);

-- Create policies for group_members
create policy "Users can view group members"
  on public.group_members for select
  using (
    exists (
      select 1 from public.group_members
      where group_id = group_members.group_id
      and user_id = auth.uid()
    )
  );

create policy "Users can add members to their groups"
  on public.group_members for insert
  with check (
    exists (
      select 1 from public.groups
      where id = group_members.group_id
      and created_by = auth.uid()
    )
  );

-- Create policies for group_messages
create policy "Users can view group messages"
  on public.group_messages for select
  using (
    exists (
      select 1 from public.group_members
      where group_id = group_messages.group_id
      and user_id = auth.uid()
    )
  );

create policy "Users can send messages to their groups"
  on public.group_messages for insert
  with check (
    exists (
      select 1 from public.group_members
      where group_id = group_messages.group_id
      and user_id = auth.uid()
    )
  );

-- Create indexes
create index group_members_group_id_idx on public.group_members(group_id);
create index group_members_user_id_idx on public.group_members(user_id);
create index group_messages_group_id_idx on public.group_messages(group_id);
create index group_messages_created_at_idx on public.group_messages(created_at);