-- Add message category to group_messages table
alter table public.group_messages 
add column category text default 'general' check (category in ('general', 'expense', 'payment', 'reminder', 'info'));

-- Create index for category queries
create index group_messages_category_idx on public.group_messages(category); 