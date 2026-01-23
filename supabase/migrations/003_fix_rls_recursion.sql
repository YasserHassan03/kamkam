-- ============================================================================
-- KAM KAM - User Approval System (FIXED - No Recursion)
-- ============================================================================
-- Run this ENTIRE script in Supabase SQL Editor to fix the recursion issue
-- ============================================================================

-- 1. Drop ALL existing policies first (clean slate)
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own display name" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON user_profiles;
DROP POLICY IF EXISTS "Allow all for service role" ON user_profiles;
DROP POLICY IF EXISTS "Enable read access for users" ON user_profiles;
DROP POLICY IF EXISTS "Enable insert for users" ON user_profiles;
DROP POLICY IF EXISTS "Enable update for users" ON user_profiles;

-- 2. Create a SECURITY DEFINER function to check admin status (bypasses RLS)
CREATE OR REPLACE FUNCTION is_admin(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = check_user_id AND role = 'admin'
  );
$$;

-- 3. Create a SECURITY DEFINER function to get user role (bypasses RLS)
CREATE OR REPLACE FUNCTION get_user_role(check_user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT role FROM user_profiles WHERE id = check_user_id;
$$;

-- 4. Simple RLS policies that DON'T cause recursion
-- Users can always read their own profile
CREATE POLICY "Users can read own profile" ON user_profiles
    FOR SELECT TO authenticated
    USING (id = auth.uid());

-- Admins can read all profiles (uses function to avoid recursion)
CREATE POLICY "Admins can read all profiles" ON user_profiles
    FOR SELECT TO authenticated
    USING (is_admin(auth.uid()));

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT TO authenticated
    WITH CHECK (id = auth.uid());

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Admins can update any profile (uses function to avoid recursion)
CREATE POLICY "Admins can update all profiles" ON user_profiles
    FOR UPDATE TO authenticated
    USING (is_admin(auth.uid()));

-- 5. Update the trigger function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_count INT;
    new_role VARCHAR(20);
BEGIN
    -- Count existing users (SECURITY DEFINER bypasses RLS)
    SELECT COUNT(*) INTO user_count FROM public.user_profiles;
    
    -- First user becomes admin, others are pending
    IF user_count = 0 THEN
        new_role := 'admin';
    ELSE
        new_role := 'pending';
    END IF;
    
    INSERT INTO public.user_profiles (id, email, display_name, role)
    VALUES (
        NEW.id, 
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
        new_role
    )
    ON CONFLICT (id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 7. Update approval functions to use SECURITY DEFINER
CREATE OR REPLACE FUNCTION approve_user(p_user_id UUID, p_role VARCHAR(20) DEFAULT 'organiser')
RETURNS JSONB 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    v_admin_id := auth.uid();
    
    -- Check admin using direct query (SECURITY DEFINER bypasses RLS)
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = v_admin_id AND role = 'admin') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only admins can approve users');
    END IF;
    
    UPDATE user_profiles SET
        role = p_role,
        approved_by = v_admin_id,
        approved_at = NOW(),
        rejection_reason = NULL,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'new_role', p_role);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION reject_user(p_user_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS JSONB 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    v_admin_id := auth.uid();
    
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = v_admin_id AND role = 'admin') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only admins can reject users');
    END IF;
    
    UPDATE user_profiles SET
        role = 'rejected',
        rejection_reason = p_reason,
        approved_by = v_admin_id,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_user_id;
    
    RETURN jsonb_build_object('success', true, 'user_id', p_user_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_pending_users()
RETURNS SETOF user_profiles 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Check admin status directly (SECURITY DEFINER bypasses RLS)
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'Only admins can view pending users';
    END IF;
    
    RETURN QUERY SELECT * FROM user_profiles WHERE role = 'pending' ORDER BY created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- 8. Create function to get all users (for admin)
CREATE OR REPLACE FUNCTION get_all_users()
RETURNS SETOF user_profiles 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'Only admins can view all users';
    END IF;
    
    RETURN QUERY SELECT * FROM user_profiles ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 9. Grant execute permissions
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION approve_user TO authenticated;
GRANT EXECUTE ON FUNCTION reject_user TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_users TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_users TO authenticated;

-- ============================================================================
-- DONE! The recursion issue is now fixed.
-- If you already have users, make yourself admin:
-- UPDATE user_profiles SET role = 'admin' WHERE email = 'YOUR_EMAIL_HERE';
-- ============================================================================
