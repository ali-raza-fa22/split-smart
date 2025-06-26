-- Add group_message_reads table for scalable per-user read tracking
CREATE TABLE IF NOT EXISTS public.group_message_reads (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id uuid REFERENCES public.group_messages(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  read_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(message_id, user_id)
);

-- Indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_group_message_reads_message_id ON public.group_message_reads(message_id);
CREATE INDEX IF NOT EXISTS idx_group_message_reads_user_id ON public.group_message_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_group_message_reads_user_message ON public.group_message_reads(user_id, message_id);

-- Policy: Only group members can insert/select their own reads
CREATE POLICY group_message_reads_select_policy ON public.group_message_reads FOR SELECT USING (
  user_id = auth.uid()
);
CREATE POLICY group_message_reads_insert_policy ON public.group_message_reads FOR INSERT WITH CHECK (
  user_id = auth.uid()
);
-- (Optional) Allow deletion of read receipts by the user
CREATE POLICY group_message_reads_delete_policy ON public.group_message_reads FOR DELETE USING (
  user_id = auth.uid()
); 