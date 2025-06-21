-- Create expenses table
create table public.expenses (
  id uuid default gen_random_uuid() primary key,
  group_id uuid references public.groups(id) on delete cascade not null,
  title text not null,
  description text,
  total_amount decimal(10,2) not null check (total_amount > 0),
  paid_by uuid references auth.users(id) not null,
  created_by uuid references auth.users(id) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create expense_shares table to track how much each member owes
create table public.expense_shares (
  id uuid default gen_random_uuid() primary key,
  expense_id uuid references public.expenses(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  amount_owed decimal(10,2) not null check (amount_owed >= 0),
  is_paid boolean default false,
  paid_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(expense_id, user_id)
);

-- Enable RLS
alter table public.expenses enable row level security;
alter table public.expense_shares enable row level security;

-- Create policies for expenses
create policy "Users can view expenses in their groups"
  on public.expenses for select
  using (
    exists (
      select 1 from public.group_members
      where group_id = expenses.group_id
      and user_id = auth.uid()
    )
  );

create policy "Users can create expenses in their groups"
  on public.expenses for insert
  with check (
    exists (
      select 1 from public.group_members
      where group_id = expenses.group_id
      and user_id = auth.uid()
    )
  );

create policy "Users can update expenses they created"
  on public.expenses for update
  using (created_by = auth.uid());

-- Create policies for expense_shares
create policy "Users can view expense shares in their groups"
  on public.expense_shares for select
  using (
    exists (
      select 1 from public.expenses e
      join public.group_members gm on e.group_id = gm.group_id
      where e.id = expense_shares.expense_id
      and gm.user_id = auth.uid()
    )
  );

create policy "Users can update their own expense shares"
  on public.expense_shares for update
  using (user_id = auth.uid());

-- Create indexes
create index expenses_group_id_idx on public.expenses(group_id);
create index expenses_paid_by_idx on public.expenses(paid_by);
create index expenses_created_at_idx on public.expenses(created_at);
create index expense_shares_expense_id_idx on public.expense_shares(expense_id);
create index expense_shares_user_id_idx on public.expense_shares(user_id);

-- Create function to automatically create expense shares when an expense is created
create or replace function create_expense_shares()
returns trigger as $$
begin
  -- Insert expense shares for all group members
  insert into public.expense_shares (expense_id, user_id, amount_owed)
  select 
    new.id,
    gm.user_id,
    new.total_amount / count(*) over (partition by gm.group_id)
  from public.group_members gm
  where gm.group_id = new.group_id;
  
  return new;
end;
$$ language plpgsql security definer;

-- Create trigger to automatically create expense shares
create trigger trigger_create_expense_shares
  after insert on public.expenses
  for each row
  execute function create_expense_shares(); 