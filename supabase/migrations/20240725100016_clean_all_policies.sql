-- Clean all existing policies and create fresh ones
-- This migration drops ALL policies and recreates them with unique names

-- Drop ALL existing policies for all tables
-- Profiles policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;

-- Groups policies
DROP POLICY IF EXISTS "Users can view groups they are members of" ON public.groups;
DROP POLICY IF EXISTS "Users can create groups" ON public.groups;
DROP POLICY IF EXISTS "Users can view their groups" ON public.groups;
DROP POLICY IF EXISTS "Users can view groups they created" ON public.groups;
DROP POLICY IF EXISTS "Group admins can update groups" ON public.groups;

-- Group members policies
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;
DROP POLICY IF EXISTS "Group creators can add members" ON public.group_members;
DROP POLICY IF EXISTS "Group admins can add members" ON public.group_members;
DROP POLICY IF EXISTS "Group admins can remove members" ON public.group_members;
DROP POLICY IF EXISTS "Group admins can update member roles" ON public.group_members;
DROP POLICY IF EXISTS "Anyone can view group members" ON public.group_members;
DROP POLICY IF EXISTS "Group members can view group members" ON public.group_members;
DROP POLICY IF EXISTS "Users can add members to their groups" ON public.group_members;

-- Group messages policies
DROP POLICY IF EXISTS "Group members can view messages" ON public.group_messages;
DROP POLICY IF EXISTS "Group members can send messages" ON public.group_messages;
DROP POLICY IF EXISTS "Users can view group messages" ON public.group_messages;
DROP POLICY IF EXISTS "Users can send messages to their groups" ON public.group_messages;
DROP POLICY IF EXISTS "Message sender can update their messages" ON public.group_messages;
DROP POLICY IF EXISTS "Message sender can delete their messages" ON public.group_messages;

-- Messages policies (for direct messages)
DROP POLICY IF EXISTS "Users can view their messages" ON public.messages;
DROP POLICY IF EXISTS "Users can send messages" ON public.messages;

-- Now create fresh policies with unique names

-- Profiles policies
CREATE POLICY "profiles_select_policy" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_policy" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update_policy" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Groups policies
CREATE POLICY "groups_select_created_policy" ON public.groups FOR SELECT USING (created_by = auth.uid());
CREATE POLICY "groups_select_member_policy" ON public.groups FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = groups.id AND user_id = auth.uid()
  )
);
CREATE POLICY "groups_insert_policy" ON public.groups FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Group members policies
CREATE POLICY "group_members_select_policy" ON public.group_members FOR SELECT USING (true);
CREATE POLICY "group_members_insert_policy" ON public.group_members FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = group_members.group_id AND created_by = auth.uid()
  )
);
CREATE POLICY "group_members_delete_policy" ON public.group_members FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = group_members.group_id AND created_by = auth.uid()
  )
  AND user_id != auth.uid()
);
CREATE POLICY "group_members_update_policy" ON public.group_members FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = group_members.group_id AND created_by = auth.uid()
  )
);

-- Group messages policies
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
CREATE POLICY "group_messages_update_policy" ON public.group_messages FOR UPDATE USING (sender_id = auth.uid());
CREATE POLICY "group_messages_delete_policy" ON public.group_messages FOR DELETE USING (sender_id = auth.uid());

-- Messages policies (for direct messages)
CREATE POLICY "messages_select_policy" ON public.messages FOR SELECT USING (
  sender_id = auth.uid() OR receiver_id = auth.uid()
);
CREATE POLICY "messages_insert_policy" ON public.messages FOR INSERT WITH CHECK (sender_id = auth.uid());
CREATE POLICY "messages_update_policy" ON public.messages FOR UPDATE USING (sender_id = auth.uid());
CREATE POLICY "messages_delete_policy" ON public.messages FOR DELETE USING (sender_id = auth.uid()); 