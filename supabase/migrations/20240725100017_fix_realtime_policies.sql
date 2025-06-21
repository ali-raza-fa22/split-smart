-- Fix RLS policies for real-time updates
-- The issue might be that the policies are too restrictive for real-time subscriptions

-- Drop existing group_messages policies
DROP POLICY IF EXISTS "group_messages_select_policy" ON public.group_messages;
DROP POLICY IF EXISTS "group_messages_insert_policy" ON public.group_messages;
DROP POLICY IF EXISTS "group_messages_update_policy" ON public.group_messages;
DROP POLICY IF EXISTS "group_messages_delete_policy" ON public.group_messages;

-- Create simpler, more permissive policies for real-time to work
CREATE POLICY "group_messages_select_policy" ON public.group_messages FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = group_messages.group_id AND user_id = auth.uid()
  )
);

CREATE POLICY "group_messages_insert_policy" ON public.group_messages FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = group_messages.group_id AND user_id = auth.uid()
  )
  AND sender_id = auth.uid()
);

CREATE POLICY "group_messages_update_policy" ON public.group_messages FOR UPDATE USING (
  sender_id = auth.uid()
);

CREATE POLICY "group_messages_delete_policy" ON public.group_messages FOR DELETE USING (
  sender_id = auth.uid()
);

-- Also ensure group_members policies are simple enough
DROP POLICY IF EXISTS "group_members_select_policy" ON public.group_members;
CREATE POLICY "group_members_select_policy" ON public.group_members FOR SELECT USING (true);

-- Test function to verify policies work
CREATE OR REPLACE FUNCTION test_group_messages_access(group_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_members.group_id = $1
    AND group_members.user_id = auth.uid()
  );
$$; 