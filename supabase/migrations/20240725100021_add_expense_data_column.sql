-- Add expense_data column to group_messages table
-- This column stores expense information when a message is of category 'expense'

-- Add the expense_data column
ALTER TABLE public.group_messages 
ADD COLUMN IF NOT EXISTS expense_data jsonb;

-- Create index for expense_data queries
CREATE INDEX IF NOT EXISTS group_messages_expense_data_idx ON public.group_messages USING GIN (expense_data);

-- Add comment to document the column
COMMENT ON COLUMN public.group_messages.expense_data IS 'JSON data containing expense information when message category is expense';

-- Test the column addition
SELECT 'expense_data column added successfully' as status; 