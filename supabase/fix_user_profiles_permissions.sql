-- ============================================================================
-- Fix user_profiles Permissions
-- ============================================================================
-- This script ensures proper permissions and RLS policies for user_profiles
-- Run this if you're getting "permission denied for table user_profiles" errors
-- ============================================================================

-- Ensure RLS is enabled
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Grant basic permissions to authenticated and anon roles
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;

-- Grant SELECT, INSERT, UPDATE on user_profiles
GRANT SELECT, INSERT, UPDATE ON user_profiles TO authenticated;
GRANT SELECT ON user_profiles TO anon; -- Anon might need to read for signup checks

-- Ensure the policies exist (drop and recreate to be safe)
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;

-- Recreate policies
CREATE POLICY "Users can view their own profile"
  ON user_profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON user_profiles FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid() AND up.role = 'admin'
    )
  );

-- Allow anon to read user_profiles for checking if email exists (for signup)
-- This is needed during registration before the user is authenticated
CREATE POLICY "Anon can check if profile exists"
  ON user_profiles FOR SELECT
  TO anon
  USING (true); -- Allow anon to read (needed for signup flow)

CREATE POLICY "Users can create their own profile"
  ON user_profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Also allow anon to insert (needed for signup via trigger)
CREATE POLICY "Anon can create profile via trigger"
  ON user_profiles FOR INSERT
  TO anon
  WITH CHECK (true); -- Trigger will handle the actual user_id

CREATE POLICY "Users can update their own profile"
  ON user_profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- Verify permissions
-- ============================================================================
-- After running, you can verify with:
-- SELECT * FROM user_profiles LIMIT 1; (as authenticated user)
-- ============================================================================
