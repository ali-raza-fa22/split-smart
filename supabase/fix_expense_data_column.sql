-- Quick fix for missing expense_data column
-- Run this in your Supabase SQL Editor

-- Add the expense_data column to group_messages table (if it doesn't exist)
ALTER TABLE public.group_messages 
ADD COLUMN IF NOT EXISTS expense_data jsonb;

-- Create index for better performance (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'group_messages_expense_data_idx'
    ) THEN
        CREATE INDEX group_messages_expense_data_idx 
        ON public.group_messages USING GIN (expense_data);
    END IF;
END $$;

-- Verify the column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'group_messages' 
AND column_name = 'expense_data';

-- Check if index exists
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'group_messages' 
AND indexname = 'group_messages_expense_data_idx';

-- Test result
SELECT 'expense_data column and index check completed' as result; 