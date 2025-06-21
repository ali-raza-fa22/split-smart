-- Enable real-time for group_messages table
-- This ensures that real-time subscriptions work properly

-- Enable real-time replication for the group_messages table
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_messages;

-- Also ensure the table has the proper structure for real-time
-- Add a trigger to ensure updated_at is set on changes
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at column if it doesn't exist
ALTER TABLE public.group_messages ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT timezone('utc'::text, now());

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS update_group_messages_updated_at ON public.group_messages;
CREATE TRIGGER update_group_messages_updated_at
    BEFORE UPDATE ON public.group_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column(); 