-- =====================================================================
-- Fix Profile Creation - Manual Profile Creation Helper
-- =====================================================================
-- If the trigger didn't fire, use this to manually create profiles
-- =====================================================================

-- 1) Check if trigger exists and is enabled
SELECT 
  tgname as trigger_name,
  tgenabled as enabled,
  pg_get_triggerdef(oid) as definition
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

-- 2) Function to manually create profile for a user (run this for your user)
-- Replace 'YOUR_USER_ID_HERE' with your actual auth.users.id
-- Or use this to create profile for the currently authenticated user:

CREATE OR REPLACE FUNCTION create_profile_for_current_user()
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_email TEXT;
  v_user_count INT;
  v_new_role VARCHAR(20);
  v_profile_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Check if profile already exists
  IF EXISTS (SELECT 1 FROM user_profiles WHERE id = v_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile already exists');
  END IF;

  -- Get user email from auth.users
  SELECT email INTO v_user_email
  FROM auth.users
  WHERE id = v_user_id;

  IF v_user_email IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found in auth.users');
  END IF;

  -- Determine role: first user = admin, others = pending
  SELECT COUNT(*) INTO v_user_count FROM user_profiles;
  
  IF v_user_count = 0 THEN
    v_new_role := 'admin';
  ELSE
    v_new_role := 'pending';
  END IF;

  -- Create profile
  INSERT INTO user_profiles (id, email, display_name, role)
  VALUES (
    v_user_id,
    v_user_email,
    split_part(v_user_email, '@', 1),
    v_new_role
  )
  RETURNING id INTO v_profile_id;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', v_user_email,
    'role', v_new_role,
    'message', 'Profile created successfully'
  );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION create_profile_for_current_user TO authenticated;

-- 3) Alternative: Create profile for a specific user by email (admin only)
CREATE OR REPLACE FUNCTION create_profile_for_user_by_email(p_email TEXT)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_count INT;
  v_new_role VARCHAR(20);
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only admins can create profiles for other users');
  END IF;

  -- Find user by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = p_email;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found with email: ' || p_email);
  END IF;

  -- Check if profile already exists
  IF EXISTS (SELECT 1 FROM user_profiles WHERE id = v_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile already exists for this user');
  END IF;

  -- Determine role
  SELECT COUNT(*) INTO v_user_count FROM user_profiles;
  IF v_user_count = 0 THEN
    v_new_role := 'admin';
  ELSE
    v_new_role := 'pending';
  END IF;

  INSERT INTO user_profiles (id, email, display_name, role)
  VALUES (
    v_user_id,
    p_email,
    split_part(p_email, '@', 1),
    v_new_role
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', p_email,
    'role', v_new_role
  );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION create_profile_for_user_by_email TO authenticated;

-- 4) Recreate trigger to ensure it's set up correctly
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_count INT;
  new_role VARCHAR(20);
BEGIN
  -- Count existing profiles (SECURITY DEFINER bypasses RLS)
  SELECT COUNT(*) INTO user_count FROM public.user_profiles;

  -- First user becomes admin, others are pending
  IF user_count = 0 THEN
    new_role := 'admin';
  ELSE
    new_role := 'pending';
  END IF;

  -- Insert profile
  INSERT INTO public.user_profiles (id, email, display_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    new_role
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the user creation
    RAISE WARNING 'Failed to create user profile for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW 
  EXECUTE FUNCTION handle_new_user();

-- =====================================================================
-- TO FIX YOUR CURRENT USER:
-- =====================================================================
-- Option 1: If you're logged in, run this in Supabase SQL Editor:
-- SELECT create_profile_for_current_user();
--
-- Option 2: If you know your email, and you're an admin, run:
-- SELECT create_profile_for_user_by_email('your-email@example.com');
--
-- Option 3: Manual insert (replace with your actual user ID and email):
-- INSERT INTO user_profiles (id, email, display_name, role)
-- SELECT 
--   id,
--   email,
--   split_part(email, '@', 1) as display_name,
--   CASE WHEN (SELECT COUNT(*) FROM user_profiles) = 0 THEN 'admin' ELSE 'pending' END as role
-- FROM auth.users
-- WHERE email = 'your-email@example.com'
-- ON CONFLICT (id) DO NOTHING;
-- =====================================================================
