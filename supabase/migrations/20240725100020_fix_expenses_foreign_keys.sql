-- Fix expenses table foreign key relationships
-- Drop existing tables and recreate with correct foreign keys

-- Drop existing tables
DROP TABLE IF EXISTS public.expense_shares CASCADE;
DROP TABLE IF EXISTS public.expenses CASCADE;

-- Create expenses table with correct foreign key to auth.users
CREATE TABLE public.expenses (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id uuid REFERENCES public.groups(id) ON DELETE CASCADE NOT NULL,
  title text NOT NULL,
  description text,
  total_amount decimal(10,2) NOT NULL CHECK (total_amount > 0),
  paid_by uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create expense_shares table with correct foreign key to auth.users
CREATE TABLE public.expense_shares (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  expense_id uuid REFERENCES public.expenses(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount_owed decimal(10,2) NOT NULL CHECK (amount_owed >= 0),
  is_paid boolean DEFAULT false,
  paid_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(expense_id, user_id)
);

-- Enable Row Level Security
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_shares ENABLE ROW LEVEL SECURITY;

-- Create policies for expenses
CREATE POLICY "Users can view expenses in their groups"
  ON public.expenses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_id = expenses.group_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create expenses in their groups"
  ON public.expenses FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_id = expenses.group_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update expenses they created"
  ON public.expenses FOR UPDATE
  USING (created_by = auth.uid());

-- Create policies for expense_shares
CREATE POLICY "Users can view expense shares in their groups"
  ON public.expense_shares FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.expenses e
      JOIN public.group_members gm ON e.group_id = gm.group_id
      WHERE e.id = expense_shares.expense_id
      AND gm.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own expense shares"
  ON public.expense_shares FOR UPDATE
  USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX expenses_group_id_idx ON public.expenses(group_id);
CREATE INDEX expenses_paid_by_idx ON public.expenses(paid_by);
CREATE INDEX expenses_created_at_idx ON public.expenses(created_at);
CREATE INDEX expense_shares_expense_id_idx ON public.expense_shares(expense_id);
CREATE INDEX expense_shares_user_id_idx ON public.expense_shares(user_id);

-- Create function to automatically create expense shares when an expense is created
CREATE OR REPLACE FUNCTION create_expense_shares()
RETURNS trigger AS $$
BEGIN
  -- Insert expense shares for all group members
  INSERT INTO public.expense_shares (expense_id, user_id, amount_owed)
  SELECT 
    NEW.id,
    gm.user_id,
    NEW.total_amount / COUNT(*) OVER (PARTITION BY gm.group_id)
  FROM public.group_members gm
  WHERE gm.group_id = NEW.group_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create expense shares
CREATE TRIGGER trigger_create_expense_shares
  AFTER INSERT ON public.expenses
  FOR EACH ROW
  EXECUTE FUNCTION create_expense_shares();

-- Enable realtime for new tables
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.expenses;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.expense_shares;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$; 