-- Create a view that joins profiles with auth.users to get emails
-- This is an alternative approach to the function
create or replace view user_profiles_with_emails as
select 
  p.id,
  p.username,
  p.display_name,
  p.avatar_url,
  p.created_at,
  p.updated_at,
  au.email
from public.profiles p
left join auth.users au on p.id = au.id;

-- Grant select permission to authenticated users
grant select on user_profiles_with_emails to authenticated; 