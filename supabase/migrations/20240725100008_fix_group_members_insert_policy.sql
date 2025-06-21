-- Fix group_members insert policy to allow group creation
drop policy if exists "Group admins can add members" on public.group_members;

-- Create a simple insert policy that allows group creators to add members
create policy "Group creators can add members"
  on public.group_members for insert
  with check (
    exists (
      select 1 from public.groups
      where id = group_members.group_id
      and created_by = auth.uid()
    )
  ); 