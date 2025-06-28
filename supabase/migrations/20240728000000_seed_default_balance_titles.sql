-- Seed default balance titles
-- First, delete all existing titles
DELETE FROM default_balance_titles;

-- Insert new default balance titles for income
INSERT INTO default_balance_titles (title, icon, category, is_active, created_at) VALUES
('Salary', 'work', 'income', true, NOW()),
('Freelance', 'computer', 'income', true, NOW()),
('Investment Returns', 'trending_up', 'income', true, NOW()),
('Gift', 'card_giftcard', 'income', true, NOW()),
('Refund', 'money_off', 'income', true, NOW()),
('Bonus', 'work', 'income', true, NOW()),
('Commission', 'trending_up', 'income', true, NOW()),
('Rental Income', 'home', 'income', true, NOW()),
('Side Business', 'business', 'income', true, NOW());
