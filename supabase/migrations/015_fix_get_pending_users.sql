-- ============================================================================
-- Fix get_pending_users Function
-- ============================================================================
-- The function should use is_admin() helper to avoid RLS recursion issues
-- ============================================================================

-- Drop and recreate the function using is_admin() helper
DROP FUNCTION IF EXISTS get_pending_users() CASCADE;

CREATE OR REPLACE FUNCTION get_pending_users()
RETURNS TABLE (
  id UUID,
  email VARCHAR,
  display_name VARCHAR,
  role VARCHAR,
  rejection_reason TEXT,
  approved_by UUID,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Use is_admin() helper function which bypasses RLS
  IF NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Only admins can view pending users';
  END IF;

  RETURN QUERY
  SELECT 
    up.id, 
    up.email, 
    up.display_name, 
    up.role, 
    up.rejection_reason,
    up.approved_by,
    up.approved_at,
    up.created_at
  FROM user_profiles up
  WHERE up.role = 'pending'
  ORDER BY up.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_pending_users() TO authenticated;

-- ============================================================================
-- DONE! The function now uses is_admin() which bypasses RLS
-- This should fix the issue where pending users aren't showing up
-- ============================================================================
