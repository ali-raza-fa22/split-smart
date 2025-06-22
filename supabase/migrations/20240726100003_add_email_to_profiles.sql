-- Add email column to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

-- Create a function to update existing profiles with emails from auth.users
CREATE OR REPLACE FUNCTION update_profiles_with_emails()
RETURNS void AS $$
BEGIN
  UPDATE public.profiles 
  SET email = au.email
  FROM auth.users au
  WHERE profiles.id = au.id 
  AND profiles.email IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the function to populate emails
SELECT update_profiles_with_emails();

-- Create a trigger to automatically update email when a new user is created
CREATE OR REPLACE FUNCTION handle_new_user_with_email()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name, email)
  VALUES (new.id, new.email, new.email, new.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the old trigger and create the new one
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user_with_email(); 