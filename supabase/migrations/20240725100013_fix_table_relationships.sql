-- Fix table relationships to resolve "could not find relation" error
-- This migration ensures proper foreign key relationships and table structure

-- First, let's check and fix the group_members table structure
-- The issue is likely that user_id references auth.users but we're trying to join with profiles

-- Drop existing foreign key constraints if they exist
ALTER TABLE IF EXISTS public.group_members 
DROP CONSTRAINT IF EXISTS group_members_user_id_fkey;

ALTER TABLE IF EXISTS public.group_messages 
DROP CONSTRAINT IF EXISTS group_messages_sender_id_fkey;

ALTER TABLE IF EXISTS public.messages 
DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;

ALTER TABLE IF EXISTS public.messages 
DROP CONSTRAINT IF EXISTS messages_receiver_id_fkey;

ALTER TABLE IF EXISTS public.groups 
DROP CONSTRAINT IF EXISTS groups_created_by_fkey;

-- Now add the correct foreign key constraints
-- Since profiles.id = auth.users.id, we can reference either one
-- But for Supabase joins to work properly, we need to reference auth.users

ALTER TABLE public.group_members 
ADD CONSTRAINT group_members_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.group_messages 
ADD CONSTRAINT group_messages_sender_id_fkey 
FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.messages 
ADD CONSTRAINT messages_sender_id_fkey 
FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.messages 
ADD CONSTRAINT messages_receiver_id_fkey 
FOREIGN KEY (receiver_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.groups 
ADD CONSTRAINT groups_created_by_fkey 
FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Create a view to help with joins between group_members and profiles
CREATE OR REPLACE VIEW public.group_members_with_profiles AS
SELECT 
    gm.*,
    p.username,
    p.display_name,
    p.avatar_url
FROM public.group_members gm
LEFT JOIN public.profiles p ON gm.user_id = p.id;

-- Create a view to help with joins between group_messages and profiles
CREATE OR REPLACE VIEW public.group_messages_with_profiles AS
SELECT 
    gmsg.*,
    p.username,
    p.display_name,
    p.avatar_url
FROM public.group_messages gmsg
LEFT JOIN public.profiles p ON gmsg.sender_id = p.id; 