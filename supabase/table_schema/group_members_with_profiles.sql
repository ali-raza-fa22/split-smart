create view public.group_members_with_profiles as
select
  gm.id,
  gm.group_id,
  gm.user_id,
  gm.created_at,
  gm.is_admin,
  p.username,
  p.display_name,
  p.avatar_url
from
  group_members gm
  left join profiles p on gm.user_id = p.id;