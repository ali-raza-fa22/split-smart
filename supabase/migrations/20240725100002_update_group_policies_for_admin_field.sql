-- Drop existing policies that need updating
drop policy if exists "Users can view group members" on public.group_members;
drop policy if exists "Group admins can add members" on public.group_members;
drop policy if exists "Group admins can remove members" on public.group_members;
drop policy if exists "Group admins can update member roles" on public.group_members;

-- Create updated policies using the is_admin field
create policy "Users can view group members"
  on public.group_members for select
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = group_members.group_id
      and gm.user_id = auth.uid()
    )
  );

create policy "Group admins can add members"
  on public.group_members for insert
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = group_members.group_id
      and gm.user_id = auth.uid()
      and gm.is_admin = true
    )
  );

create policy "Group admins can remove members"
  on public.group_members for delete
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = group_members.group_id
      and gm.user_id = auth.uid()
      and gm.is_admin = true
    )
    and user_id != auth.uid() -- Prevent admin from removing themselves
  );

create policy "Group admins can update member roles"
  on public.group_members for update
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = group_members.group_id
      and gm.user_id = auth.uid()
      and gm.is_admin = true
    )
  );

-- Add policy for group updates (renaming)
drop policy if exists "Users can update their groups" on public.groups;
create policy "Group admins can update groups"
  on public.groups for update
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = groups.id
      and gm.user_id = auth.uid()
      and gm.is_admin = true
    )
  ); 