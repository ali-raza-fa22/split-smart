DROP FUNCTION IF EXISTS get_user_chats_with_last_message(uuid);

create or replace function get_user_chats_with_last_message(current_user_id uuid)
returns table (
    id uuid,
    username text,
    display_name text,
    last_message_content text,
    last_message_created_at timestamp with time zone,
    last_message_sender_id uuid,
    last_message_sender_display_name text
) as $$
begin
    return query
    with last_messages as (
        select
            case
                when sender_id = current_user_id then receiver_id
                else sender_id
            end as other_user_id,
            content,
            created_at,
            sender_id,
            row_number() over (
                partition by
                    case
                        when sender_id = current_user_id then receiver_id
                        else sender_id
                    end
                order by created_at desc
            ) as rn
        from messages
        where sender_id = current_user_id or receiver_id = current_user_id
    )
    select
        p.id,
        p.username,
        p.display_name,
        lm.content as last_message_content,
        lm.created_at as last_message_created_at,
        lm.sender_id as last_message_sender_id,
        sender_profile.display_name as last_message_sender_display_name
    from profiles p
    left join last_messages lm on p.id = lm.other_user_id
    left join profiles sender_profile on lm.sender_id = sender_profile.id
    where p.id <> current_user_id and (lm.rn = 1 or lm.rn is null)
    order by lm.created_at desc nulls last;
end;
$$ language plpgsql; 