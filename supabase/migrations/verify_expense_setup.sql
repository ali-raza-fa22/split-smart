-- Verify expense setup
-- Run this to check if everything is working correctly

-- Check if expenses table exists
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'expenses') 
        THEN 'expenses table exists' 
        ELSE 'expenses table missing' 
    END as expenses_table_status;

-- Check if expense_shares table exists
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'expense_shares') 
        THEN 'expense_shares table exists' 
        ELSE 'expense_shares table missing' 
    END as expense_shares_table_status;

-- Check if expense_data column exists in group_messages
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'group_messages' AND column_name = 'expense_data'
        ) 
        THEN 'expense_data column exists' 
        ELSE 'expense_data column missing' 
    END as expense_data_column_status;

-- Check if expense_data index exists
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE tablename = 'group_messages' AND indexname = 'group_messages_expense_data_idx'
        ) 
        THEN 'expense_data index exists' 
        ELSE 'expense_data index missing' 
    END as expense_data_index_status;

-- Check if trigger exists
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.triggers 
            WHERE trigger_name = 'trigger_create_expense_shares'
        ) 
        THEN 'expense shares trigger exists' 
        ELSE 'expense shares trigger missing' 
    END as trigger_status;

-- Check RLS policies for expenses
SELECT 
    policyname,
    CASE 
        WHEN cmd = 'r' THEN 'SELECT'
        WHEN cmd = 'a' THEN 'INSERT'
        WHEN cmd = 'w' THEN 'UPDATE'
        WHEN cmd = 'd' THEN 'DELETE'
        ELSE cmd::text
    END as operation
FROM pg_policies 
WHERE tablename = 'expenses'
ORDER BY policyname;

-- Check RLS policies for expense_shares
SELECT 
    policyname,
    CASE 
        WHEN cmd = 'r' THEN 'SELECT'
        WHEN cmd = 'a' THEN 'INSERT'
        WHEN cmd = 'w' THEN 'UPDATE'
        WHEN cmd = 'd' THEN 'DELETE'
        ELSE cmd::text
    END as operation
FROM pg_policies 
WHERE tablename = 'expense_shares'
ORDER BY policyname;

-- Simple test to check if we can query the expenses table
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM public.expenses LIMIT 1) 
        THEN 'expenses table is accessible' 
        ELSE 'expenses table is empty or not accessible' 
    END as expenses_access_status;

-- Check if we have any groups and users for testing
SELECT 
    (SELECT COUNT(*) FROM public.groups) as groups_count,
    (SELECT COUNT(*) FROM auth.users) as users_count; 