create view public.user_profiles_with_emails as
select
  p.id,
  p.username,
  p.display_name,
  p.avatar_url,
  p.created_at,
  p.updated_at,
  au.email
from
  profiles p
  left join auth.users au on p.id = au.id;