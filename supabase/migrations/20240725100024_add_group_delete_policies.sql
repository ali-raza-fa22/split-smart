-- Add RLS policies for group deletion
-- This migration adds policies that allow group admins to delete groups and related data

-- Enable RLS on all tables if not already enabled
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_shares ENABLE ROW LEVEL SECURITY;

-- Policy for deleting groups (admin only)
CREATE POLICY "Admins can delete groups" ON groups
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = groups.id
            AND group_members.user_id = auth.uid()
            AND group_members.is_admin = true
        )
    );

-- Policy for deleting group members (admin only)
CREATE POLICY "Admins can delete group members" ON group_members
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = group_members.group_id
            AND gm.user_id = auth.uid()
            AND gm.is_admin = true
        )
    );

-- Policy for deleting group messages (admin only)
CREATE POLICY "Admins can delete group messages" ON group_messages
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = group_messages.group_id
            AND group_members.user_id = auth.uid()
            AND group_members.is_admin = true
        )
    );

-- Policy for deleting expenses (admin only)
CREATE POLICY "Admins can delete expenses" ON expenses
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = expenses.group_id
            AND group_members.user_id = auth.uid()
            AND group_members.is_admin = true
        )
    );

-- Policy for deleting expense shares (admin only)
CREATE POLICY "Admins can delete expense shares" ON expense_shares
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            JOIN expenses e ON e.id = expense_shares.expense_id
            WHERE gm.group_id = e.group_id
            AND gm.user_id = auth.uid()
            AND gm.is_admin = true
        )
    ); 