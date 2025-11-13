create table public.invitations (
  id uuid not null default gen_random_uuid (),
  inviter_id uuid not null,
  invitee_email text not null,
  invitation_type text not null,
  group_id uuid null,
  status text not null default 'pending'::text,
  token text not null,
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone null default now(),
  accepted_at timestamp with time zone null,
  accepted_by uuid null,
  constraint invitations_pkey primary key (id),
  constraint invitations_token_key unique (token),
  constraint invitations_accepted_by_fkey foreign KEY (accepted_by) references auth.users (id) on delete set null,
  constraint invitations_inviter_id_fkey foreign KEY (inviter_id) references auth.users (id) on delete CASCADE,
  constraint invitations_group_id_fkey foreign KEY (group_id) references groups (id) on delete CASCADE,
  constraint invitations_status_check check (
    (
      status = any (
        array[
          'pending'::text,
          'accepted'::text,
          'declined'::text,
          'expired'::text
        ]
      )
    )
  ),
  constraint invitations_invitation_type_check check (
    (
      invitation_type = any (
        array['direct_chat'::text, 'group_invitation'::text]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_invitations_email on public.invitations using btree (invitee_email) TABLESPACE pg_default;

create index IF not exists idx_invitations_expires_at on public.invitations using btree (expires_at) TABLESPACE pg_default;

create index IF not exists idx_invitations_status on public.invitations using btree (status) TABLESPACE pg_default;

create index IF not exists idx_invitations_token on public.invitations using btree (token) TABLESPACE pg_default;