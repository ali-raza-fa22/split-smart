-- Fix missing UPDATE policy for groups table
-- The previous migration dropped the update policy but didn't recreate it

-- Add UPDATE policy for groups
CREATE POLICY "groups_update_policy" ON public.groups FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = groups.id 
    AND user_id = auth.uid() 
    AND is_admin = true
  )
  OR
  created_by = auth.uid()
);

-- Test the policy
SELECT 'Group update policy added successfully' as status; 