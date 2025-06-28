-- Create balance system tables
-- This migration adds user balance management with titles and loan tracking

-- Create user_balances table to track current balance for each user
CREATE TABLE public.user_balances (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  current_balance decimal(10,2) DEFAULT 0.00 NOT NULL,
  total_added decimal(10,2) DEFAULT 0.00 NOT NULL,
  total_spent decimal(10,2) DEFAULT 0.00 NOT NULL,
  total_loans decimal(10,2) DEFAULT 0.00 NOT NULL,
  total_repaid decimal(10,2) DEFAULT 0.00 NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id)
);

-- Create balance_transactions table to track all balance changes
CREATE TABLE public.balance_transactions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  transaction_type text NOT NULL CHECK (transaction_type IN ('add', 'spend', 'loan', 'repay')),
  amount decimal(10,2) NOT NULL CHECK (amount > 0),
  title text NOT NULL,
  description text,
  expense_share_id uuid REFERENCES public.expense_shares(id) ON DELETE SET NULL,
  group_id uuid REFERENCES public.groups(id) ON DELETE SET NULL,
  balance_before decimal(10,2) NOT NULL,
  balance_after decimal(10,2) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create default balance titles table
CREATE TABLE public.default_balance_titles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL UNIQUE,
  category text NOT NULL CHECK (category IN ('income', 'expense', 'other')),
  icon text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Insert default balance titles
INSERT INTO public.default_balance_titles (title, category, icon) VALUES
  ('Salary', 'income', 'work'),
  ('Freelance', 'income', 'computer'),
  ('Investment', 'income', 'trending_up'),
  ('Gift', 'income', 'card_giftcard'),
  ('Refund', 'income', 'money_off'),
  ('Food & Dining', 'expense', 'restaurant'),
  ('Transportation', 'expense', 'directions_car'),
  ('Shopping', 'expense', 'shopping_cart'),
  ('Entertainment', 'expense', 'movie'),
  ('Bills', 'expense', 'receipt'),
  ('Healthcare', 'expense', 'local_hospital'),
  ('Education', 'expense', 'school'),
  ('Travel', 'expense', 'flight'),
  ('Other', 'other', 'more_horiz');

-- Enable Row Level Security
ALTER TABLE public.user_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balance_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.default_balance_titles ENABLE ROW LEVEL SECURITY;

-- Create policies for user_balances
CREATE POLICY "Users can view their own balance"
  ON public.user_balances FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their own balance"
  ON public.user_balances FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own balance"
  ON public.user_balances FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Create policies for balance_transactions
CREATE POLICY "Users can view their own transactions"
  ON public.balance_transactions FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own transactions"
  ON public.balance_transactions FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Create policies for default_balance_titles (read-only for all users)
CREATE POLICY "All users can view default balance titles"
  ON public.default_balance_titles FOR SELECT
  USING (true);

-- Create indexes
CREATE INDEX user_balances_user_id_idx ON public.user_balances(user_id);
CREATE INDEX balance_transactions_user_id_idx ON public.balance_transactions(user_id);
CREATE INDEX balance_transactions_type_idx ON public.balance_transactions(transaction_type);
CREATE INDEX balance_transactions_created_at_idx ON public.balance_transactions(created_at);
CREATE INDEX balance_transactions_expense_share_id_idx ON public.balance_transactions(expense_share_id);
CREATE INDEX balance_transactions_group_id_idx ON public.balance_transactions(group_id);

-- Create function to automatically create user balance when user is created
CREATE OR REPLACE FUNCTION create_user_balance()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_balances (user_id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create user balance
CREATE TRIGGER trigger_create_user_balance
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_balance();

-- Create function to update user balance when transaction is added
CREATE OR REPLACE FUNCTION update_user_balance_on_transaction()
RETURNS trigger AS $$
DECLARE
  current_balance decimal(10,2);
  new_balance decimal(10,2);
  total_added decimal(10,2);
  total_spent decimal(10,2);
  total_loans decimal(10,2);
  total_repaid decimal(10,2);
BEGIN
  -- Get current balance
  SELECT user_balances.current_balance, user_balances.total_added, user_balances.total_spent, user_balances.total_loans, user_balances.total_repaid
  INTO current_balance, total_added, total_spent, total_loans, total_repaid
  FROM public.user_balances
  WHERE user_id = NEW.user_id;

  -- Calculate new balance based on transaction type
  CASE NEW.transaction_type
    WHEN 'add' THEN
      new_balance := current_balance + NEW.amount;
      total_added := total_added + NEW.amount;
    WHEN 'spend' THEN
      new_balance := current_balance - NEW.amount;
      total_spent := total_spent + NEW.amount;
    WHEN 'loan' THEN
      new_balance := current_balance - NEW.amount;
      total_loans := total_loans + NEW.amount;
    WHEN 'repay' THEN
      new_balance := current_balance + NEW.amount;
      total_repaid := total_repaid + NEW.amount;
  END CASE;

  -- Update user balance
  UPDATE public.user_balances
  SET 
    current_balance = new_balance,
    total_added = total_added,
    total_spent = total_spent,
    total_loans = total_loans,
    total_repaid = total_repaid,
    updated_at = NOW()
  WHERE user_id = NEW.user_id;

  -- Set balance_before and balance_after in the transaction
  NEW.balance_before := current_balance;
  NEW.balance_after := new_balance;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically update user balance
CREATE TRIGGER trigger_update_user_balance_on_transaction
  BEFORE INSERT ON public.balance_transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_balance_on_transaction();

-- Enable realtime for new tables
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.user_balances;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.balance_transactions;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.default_balance_titles;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$; 