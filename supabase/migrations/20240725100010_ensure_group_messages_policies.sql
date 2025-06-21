-- Ensure group_messages has proper RLS policies for sending and viewing messages
-- Drop any existing policies to avoid conflicts
drop policy if exists "Users can view group messages" on public.group_messages;
drop policy if exists "Users can send messages to their groups" on public.group_messages;
drop policy if exists "Group members can view messages" on public.group_messages;
drop policy if exists "Group members can send messages" on public.group_messages;

-- Create robust policies for group messages
create policy "Group members can view messages"
  on public.group_messages for select
  using (
    exists (
      select 1 from public.group_members
      where group_id = group_messages.group_id
      and user_id = auth.uid()
    )
  );

create policy "Group members can send messages"
  on public.group_messages for insert
  with check (
    -- User must be a member of the group
    exists (
      select 1 from public.group_members
      where group_id = group_messages.group_id
      and user_id = auth.uid()
    )
    and
    -- Sender must be the authenticated user
    sender_id = auth.uid()
  );

-- Add update policy for message editing (optional - for future features)
create policy "Message sender can update their messages"
  on public.group_messages for update
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

-- Add delete policy for message deletion (optional - for future features)
create policy "Message sender can delete their messages"
  on public.group_messages for delete
  using (sender_id = auth.uid()); 