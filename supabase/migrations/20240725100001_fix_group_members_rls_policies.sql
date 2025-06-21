-- Drop existing problematic policies
drop policy if exists "Users can view group members" on public.group_members;
drop policy if exists "Users can add members to their groups" on public.group_members;

-- Create simplified policies that avoid recursion
create policy "Users can view group members"
  on public.group_members for select
  using (
    exists (
      select 1 from public.groups
      where id = group_members.group_id
      and created_by = auth.uid()
    )
    or
    user_id = auth.uid()
  );

create policy "Group admins can add members"
  on public.group_members for insert
  with check (
    exists (
      select 1 from public.groups
      where id = group_members.group_id
      and created_by = auth.uid()
    )
  );

create policy "Group admins can remove members"
  on public.group_members for delete
  using (
    exists (
      select 1 from public.groups
      where id = group_members.group_id
      and created_by = auth.uid()
    )
    and user_id != auth.uid() -- Prevent admin from removing themselves
  );

-- Add update policy for admin role
create policy "Group admins can update member roles"
  on public.group_members for update
  using (
    exists (
      select 1 from public.groups
      where id = group_members.group_id
      and created_by = auth.uid()
    )
  ); 