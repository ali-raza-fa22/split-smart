-- Add insert policy for groups table
create policy "Users can create groups"
  on public.groups for insert
  with check (auth.uid() = created_by); 