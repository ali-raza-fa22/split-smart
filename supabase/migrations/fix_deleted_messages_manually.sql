-- Fix deleted messages filter - Run this in Supabase SQL Editor

-- Drop and recreate the function to ensure it's properly updated
DROP FUNCTION IF EXISTS get_user_chats_with_last_message(uuid);

CREATE OR REPLACE FUNCTION get_user_chats_with_last_message(current_user_id uuid)
RETURNS TABLE (
    id uuid,
    username text,
    display_name text,
    last_message_content text,
    last_message_created_at timestamp with time zone,
    last_message_sender_id uuid,
    last_message_sender_display_name text
) AS $$
BEGIN
    RETURN QUERY
    WITH last_messages AS (
        SELECT
            CASE
                WHEN sender_id = current_user_id THEN receiver_id
                ELSE sender_id
            END AS other_user_id,
            content,
            created_at,
            sender_id,
            ROW_NUMBER() OVER (
                PARTITION BY
                    CASE
                        WHEN sender_id = current_user_id THEN receiver_id
                        ELSE sender_id
                    END
                ORDER BY created_at DESC
            ) AS rn
        FROM messages
        WHERE (sender_id = current_user_id OR receiver_id = current_user_id)
        AND (is_deleted IS NULL OR is_deleted = false)  -- Explicitly filter out deleted messages
    )
    SELECT
        p.id,
        p.username,
        p.display_name,
        lm.content AS last_message_content,
        lm.created_at AS last_message_created_at,
        lm.sender_id AS last_message_sender_id,
        sender_profile.display_name AS last_message_sender_display_name
    FROM profiles p
    LEFT JOIN last_messages lm ON p.id = lm.other_user_id AND lm.rn = 1
    LEFT JOIN profiles sender_profile ON lm.sender_id = sender_profile.id
    WHERE p.id != current_user_id
    ORDER BY lm.created_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- Add a comment to document the function
COMMENT ON FUNCTION get_user_chats_with_last_message(uuid) IS 'Get all users with their last non-deleted message for chat list display';

-- Also ensure the messages table has proper indexing for performance
CREATE INDEX IF NOT EXISTS idx_messages_sender_receiver_deleted 
ON messages(sender_id, receiver_id, is_deleted) 
WHERE is_deleted = false OR is_deleted IS NULL;

CREATE INDEX IF NOT EXISTS idx_messages_created_at_deleted 
ON messages(created_at DESC, is_deleted) 
WHERE is_deleted = false OR is_deleted IS NULL;

-- Test the function to make sure it works
-- SELECT * FROM get_user_chats_with_last_message('your-user-id-here'); 