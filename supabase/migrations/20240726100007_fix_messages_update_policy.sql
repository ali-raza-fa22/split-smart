-- Fix messages update policy to allow users to update messages they received
-- This is needed for marking messages as read

-- Drop the existing restrictive policy
DROP POLICY IF EXISTS "messages_update_policy" ON public.messages;

-- Create a new policy that allows users to update messages they sent OR received
CREATE POLICY "messages_update_policy" ON public.messages FOR UPDATE USING (
  sender_id = auth.uid() OR receiver_id = auth.uid()
); 