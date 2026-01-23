-- =====================================================================
-- Fix Admin Roles - Reset incorrectly assigned admin roles
-- =====================================================================
-- This script will:
-- 1. Find the first user (by created_at in auth.users or user_profiles)
-- 2. Set only that user as admin
-- 3. Set all other users to 'pending'
-- =====================================================================

-- Find the first user (by earliest created_at)
WITH first_user AS (
  SELECT 
    COALESCE(
      (SELECT id FROM user_profiles ORDER BY created_at ASC LIMIT 1),
      (SELECT id FROM auth.users ORDER BY created_at ASC LIMIT 1)
    ) AS first_user_id
)
-- Update all users: first user = admin, others = pending
UPDATE user_profiles
SET 
  role = CASE 
    WHEN id = (SELECT first_user_id FROM first_user) THEN 'admin'
    ELSE 'pending'
  END,
  updated_at = NOW()
WHERE role = 'admin' AND id != (SELECT first_user_id FROM first_user);

-- Verify: Show current admin count (should be 1)
SELECT 
  COUNT(*) FILTER (WHERE role = 'admin') as admin_count,
  COUNT(*) FILTER (WHERE role = 'pending') as pending_count,
  COUNT(*) FILTER (WHERE role = 'organiser') as organiser_count,
  COUNT(*) as total_users
FROM user_profiles;

-- Show who is currently admin
SELECT id, email, role, created_at
FROM user_profiles
WHERE role = 'admin'
ORDER BY created_at ASC;
