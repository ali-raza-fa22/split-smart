-- Fix infinite recursion in group_members policies
-- The issue is that policies are referencing the same table they're protecting

-- Drop all existing problematic policies
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;
DROP POLICY IF EXISTS "Group creators can add members" ON public.group_members;
DROP POLICY IF EXISTS "Group admins can add members" ON public.group_members;
DROP POLICY IF EXISTS "Group members can view group members" ON public.group_members;

-- Create simple, non-recursive policies for group_members
CREATE POLICY "Anyone can view group members" ON public.group_members FOR SELECT USING (true);

CREATE POLICY "Group creators can add members" ON public.group_members FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = group_members.group_id AND created_by = auth.uid()
  )
);

CREATE POLICY "Group admins can remove members" ON public.group_members FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = group_members.group_id AND created_by = auth.uid()
  )
  AND user_id != auth.uid() -- Prevent admin from removing themselves
);

CREATE POLICY "Group admins can update member roles" ON public.group_members FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = group_members.group_id AND created_by = auth.uid()
  )
);

-- Also fix the groups policies to avoid recursion
DROP POLICY IF EXISTS "Users can view groups they are members of" ON public.groups;
DROP POLICY IF EXISTS "Users can view their groups" ON public.groups;

CREATE POLICY "Users can view groups they created" ON public.groups FOR SELECT USING (
  created_by = auth.uid()
);

CREATE POLICY "Users can view groups they are members of" ON public.groups FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = groups.id AND user_id = auth.uid()
  )
);

-- Fix group_messages policies to avoid recursion
DROP POLICY IF EXISTS "Group members can view messages" ON public.group_messages;
DROP POLICY IF EXISTS "Group members can send messages" ON public.group_messages;

CREATE POLICY "Group members can view messages" ON public.group_messages FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = group_messages.group_id AND user_id = auth.uid()
  )
);

CREATE POLICY "Group members can send messages" ON public.group_messages FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = group_messages.group_id AND user_id = auth.uid()
  )
  AND sender_id = auth.uid()
); 