-- Fix ambiguous column reference in balance function
-- This migration updates the update_user_balance_on_transaction function

-- Drop the existing function and trigger
DROP TRIGGER IF EXISTS trigger_update_user_balance_on_transaction ON public.balance_transactions;
DROP FUNCTION IF EXISTS update_user_balance_on_transaction();

-- Recreate the function with completely unambiguous column references
CREATE OR REPLACE FUNCTION update_user_balance_on_transaction()
RETURNS trigger AS $$
DECLARE
  user_balance_record RECORD;
  new_balance decimal(10,2);
BEGIN
  -- Get current balance using a more explicit approach
  SELECT 
    ub.current_balance,
    ub.total_added,
    ub.total_spent,
    ub.total_loans,
    ub.total_repaid
  INTO user_balance_record
  FROM public.user_balances ub
  WHERE ub.user_id = NEW.user_id;

  -- Calculate new balance based on transaction type
  CASE NEW.transaction_type
    WHEN 'add' THEN
      new_balance := user_balance_record.current_balance + NEW.amount;
      UPDATE public.user_balances
      SET 
        current_balance = new_balance,
        total_added = user_balance_record.total_added + NEW.amount,
        updated_at = NOW()
      WHERE user_id = NEW.user_id;
    WHEN 'spend' THEN
      new_balance := user_balance_record.current_balance - NEW.amount;
      UPDATE public.user_balances
      SET 
        current_balance = new_balance,
        total_spent = user_balance_record.total_spent + NEW.amount,
        updated_at = NOW()
      WHERE user_id = NEW.user_id;
    WHEN 'loan' THEN
      new_balance := user_balance_record.current_balance - NEW.amount;
      UPDATE public.user_balances
      SET 
        current_balance = new_balance,
        total_loans = user_balance_record.total_loans + NEW.amount,
        updated_at = NOW()
      WHERE user_id = NEW.user_id;
    WHEN 'repay' THEN
      new_balance := user_balance_record.current_balance + NEW.amount;
      UPDATE public.user_balances
      SET 
        current_balance = new_balance,
        total_repaid = user_balance_record.total_repaid + NEW.amount,
        updated_at = NOW()
      WHERE user_id = NEW.user_id;
  END CASE;

  -- Set balance_before and balance_after in the transaction
  NEW.balance_before := user_balance_record.current_balance;
  NEW.balance_after := new_balance;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
CREATE TRIGGER trigger_update_user_balance_on_transaction
  BEFORE INSERT ON public.balance_transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_balance_on_transaction(); 