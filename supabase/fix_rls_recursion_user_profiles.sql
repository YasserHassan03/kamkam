-- ============================================================================
-- Fix RLS Recursion in user_profiles
-- ============================================================================
-- The "Admins can view all profiles" policy causes infinite recursion
-- because it queries user_profiles to check if user is admin, which
-- triggers the same policy check again.
-- 
-- Solution: Use the is_admin() SECURITY DEFINER function that bypasses RLS
-- ============================================================================

-- Ensure the is_admin function exists (it should from 009_complete_reset.sql)
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

-- Drop the problematic policy
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;

-- Recreate it using the is_admin() function (which bypasses RLS)
CREATE POLICY "Admins can view all profiles"
  ON user_profiles FOR SELECT
  TO authenticated
  USING (is_admin(auth.uid()));

-- ============================================================================
-- Verify the fix
-- ============================================================================
-- After running, try logging in again. The recursion error should be gone.
-- ============================================================================
