-- ============================================================================
-- Test Delete User Function
-- ============================================================================
-- Run this to verify delete_user is working correctly
-- Replace 'USER_EMAIL_HERE' with the email of a user you want to test with
-- ============================================================================

-- First, check what tournaments exist for a user
-- Replace 'USER_EMAIL_HERE' with actual email
SELECT 
    t.id,
    t.name,
    t.owner_id,
    t.org_id,
    o.name as org_name
FROM tournaments t
LEFT JOIN organisations o ON o.id = t.org_id
WHERE t.owner_id IN (
    SELECT id FROM auth.users WHERE email = 'USER_EMAIL_HERE'
)
OR t.org_id IN (
    SELECT id FROM organisations 
    WHERE owner_id IN (SELECT id FROM auth.users WHERE email = 'USER_EMAIL_HERE')
);

-- Then after running delete_user, check again - should return no rows
-- SELECT * FROM tournaments WHERE owner_id = 'USER_ID_HERE';

-- ============================================================================
-- To test the function:
-- 1. Get the user ID: SELECT id FROM auth.users WHERE email = 'test@example.com';
-- 2. Check tournaments before: Run the query above
-- 3. Call delete_user: SELECT delete_user('USER_ID_HERE');
-- 4. Check tournaments after: Should be empty
-- ============================================================================
