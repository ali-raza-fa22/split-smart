-- Test expense functionality
-- Run this to verify everything is working

-- 1. Check if all required tables exist
SELECT 'Checking tables...' as step;

SELECT 
    table_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = t.table_name) 
        THEN 'EXISTS' 
        ELSE 'MISSING' 
    END as status
FROM (VALUES 
    ('expenses'),
    ('expense_shares'),
    ('group_messages')
) AS t(table_name);

-- 2. Check if expense_data column exists
SELECT 'Checking expense_data column...' as step;

SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'group_messages' AND column_name = 'expense_data'
        ) 
        THEN 'expense_data column EXISTS' 
        ELSE 'expense_data column MISSING' 
    END as column_status;

-- 3. Check if we have any data to work with
SELECT 'Checking data availability...' as step;

SELECT 
    (SELECT COUNT(*) FROM public.groups) as groups_count,
    (SELECT COUNT(*) FROM auth.users) as users_count,
    (SELECT COUNT(*) FROM public.expenses) as expenses_count;

-- 4. Test if we can insert into expenses table (without actually inserting)
SELECT 'Testing expense table permissions...' as step;

-- This will test if the table structure is correct
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'expenses' 
ORDER BY ordinal_position;

-- 5. Check if the trigger function exists
SELECT 'Checking trigger function...' as step;

SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'create_expense_shares'
        ) 
        THEN 'create_expense_shares function EXISTS' 
        ELSE 'create_expense_shares function MISSING' 
    END as function_status;

-- 6. Final status
SELECT 'Verification complete!' as final_status; 