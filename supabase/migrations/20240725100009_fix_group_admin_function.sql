-- Update the is_group_admin function to also check if user is group creator
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
  )
  or
  exists (
    select 1 from public.groups
    where id = $1
    and created_by = auth.uid()
  );
$$; 