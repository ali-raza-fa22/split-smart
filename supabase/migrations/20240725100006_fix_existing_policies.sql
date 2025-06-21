-- Drop existing policies that might conflict
drop policy if exists "Users can create groups" on public.groups;
drop policy if exists "Users can view their groups" on public.groups;
drop policy if exists "Group admins can update groups" on public.groups;

-- Recreate all groups policies properly
create policy "Users can create groups"
  on public.groups for insert
  with check (auth.uid() = created_by);

create policy "Users can view their groups"
  on public.groups for select
  using (
    exists (
      select 1 from public.group_members
      where group_id = groups.id
      and user_id = auth.uid()
    )
  );

create policy "Group admins can update groups"
  on public.groups for update
  using (is_group_admin(id)); 