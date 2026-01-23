-- Test script to verify the trigger is working
-- Run this in Supabase SQL Editor to check if the trigger exists and is enabled

-- 1. Check if trigger exists
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement,
  action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'auth'
  AND trigger_name = 'on_auth_user_created';

-- 2. Check if function exists
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'handle_new_user';

-- 3. Test the function manually (replace USER_ID with an actual user ID from auth.users)
-- SELECT handle_new_user(); -- This won't work directly, but you can check the function

-- 4. Check recent user profiles to see if trigger is creating them
SELECT 
  id,
  email,
  role,
  created_at
FROM user_profiles
ORDER BY created_at DESC
LIMIT 5;

-- 5. Check if there are users in auth.users without profiles
SELECT 
  au.id,
  au.email,
  au.created_at as auth_created_at,
  CASE WHEN up.id IS NULL THEN 'NO PROFILE' ELSE 'HAS PROFILE' END as profile_status
FROM auth.users au
LEFT JOIN user_profiles up ON up.id = au.id
ORDER BY au.created_at DESC
LIMIT 10;
