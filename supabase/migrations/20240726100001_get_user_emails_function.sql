-- Create a function to get user emails from auth.users table
-- This function can be called from the client side to get emails for user IDs
create or replace function get_user_emails(user_ids uuid[])
returns table(user_id uuid, email text) as $$
begin
  return query
  select au.id, au.email
  from auth.users au
  where au.id = any(user_ids);
end;
$$ language plpgsql security definer;

-- Grant execute permission to authenticated users
grant execute on function get_user_emails(uuid[]) to authenticated; 