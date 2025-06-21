ALTER TABLE public.group_members
ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;

UPDATE public.group_members gm
SET is_admin = TRUE
FROM public.groups g
WHERE gm.group_id = g.id AND gm.user_id = g.created_by;

ALTER TABLE public.group_members
ALTER COLUMN is_admin SET NOT NULL; 