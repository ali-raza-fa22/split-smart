create view public.group_messages_with_profiles as
select
  gmsg.id,
  gmsg.group_id,
  gmsg.sender_id,
  gmsg.content,
  gmsg.created_at,
  p.username,
  p.display_name,
  p.avatar_url
from
  group_messages gmsg
  left join profiles p on gmsg.sender_id = p.id;