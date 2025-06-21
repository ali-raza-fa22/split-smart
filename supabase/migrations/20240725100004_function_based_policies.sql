-- Create helper function to check if user is admin of a group
create or replace function is_group_admin(group_id uuid)
returns boolean
language sql
security definer
as $$
  select exists (
    select 1 from public.group_members
    where group_members.group_id = $1
    and group_members.user_id = auth.uid()
    and group_members.is_admin = true
  );
$$;

-- Create helper function to check if user is member of a group
create or replace function is_group_member(group_id uuid)
returns boolean
language sql
security definer
as $$
  select exists (
    select 1 from public.group_members
    where group_members.group_id = $1
    and group_members.user_id = auth.uid()
  );
$$;

-- Drop all existing policies
drop policy if exists "Group members can view group members" on public.group_members;
drop policy if exists "Group admins can add members" on public.group_members;
drop policy if exists "Group admins can remove members" on public.group_members;
drop policy if exists "Group admins can update member roles" on public.group_members;
drop policy if exists "Group admins can update groups" on public.groups;

-- Create new policies using functions
create policy "Group members can view group members"
  on public.group_members for select
  using (is_group_member(group_id));

create policy "Group admins can add members"
  on public.group_members for insert
  with check (is_group_admin(group_id));

create policy "Group admins can remove members"
  on public.group_members for delete
  using (is_group_admin(group_id) and user_id != auth.uid());

create policy "Group admins can update member roles"
  on public.group_members for update
  using (is_group_admin(group_id));

create policy "Group admins can update groups"
  on public.groups for update
  using (is_group_admin(id)); 