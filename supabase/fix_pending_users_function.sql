-- Quick fix for get_pending_users function
-- Run this if you already ran the migration and pending users aren't showing correctly

-- Drop the existing function first (it has a different return type)
DROP FUNCTION IF EXISTS get_pending_users() CASCADE;

-- Recreate with all required fields
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
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles up
    WHERE up.id = auth.uid() AND up.role = 'admin'
  ) THEN
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

-- Note: To verify it works, you need to be logged in as an admin in your app
-- and check the "Pending" tab in User Management screen
