-- Diagnostic script to check why sign-up isn't creating profiles
-- Run this in Supabase SQL Editor

-- 1. Check if trigger exists and is enabled
SELECT 
  'Trigger Status' as check_type,
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation,
  CASE WHEN trigger_name IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM information_schema.triggers
WHERE trigger_schema = 'auth'
  AND trigger_name = 'on_auth_user_created';

-- 2. Check if function exists
SELECT 
  'Function Status' as check_type,
  routine_name,
  routine_type,
  security_type,
  CASE WHEN routine_name IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'handle_new_user';

-- 3. Check recent auth.users vs user_profiles
SELECT 
  'User Profile Status' as check_type,
  COUNT(DISTINCT au.id) as total_auth_users,
  COUNT(DISTINCT up.id) as total_profiles,
  COUNT(DISTINCT au.id) - COUNT(DISTINCT up.id) as missing_profiles,
  CASE 
    WHEN COUNT(DISTINCT au.id) = COUNT(DISTINCT up.id) THEN '✅ ALL HAVE PROFILES'
    ELSE '❌ SOME USERS MISSING PROFILES'
  END as status
FROM auth.users au
LEFT JOIN user_profiles up ON up.id = au.id;

-- 4. Show users without profiles (the problem)
SELECT 
  'Users Without Profiles' as check_type,
  au.id,
  au.email,
  au.created_at as auth_created_at,
  au.email_confirmed_at,
  '❌ NO PROFILE' as status
FROM auth.users au
LEFT JOIN user_profiles up ON up.id = au.id
WHERE up.id IS NULL
ORDER BY au.created_at DESC
LIMIT 10;

-- 5. Check RLS policies on user_profiles
SELECT 
  'RLS Policy' as check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  CASE WHEN tablename = 'user_profiles' THEN '✅ HAS POLICIES' ELSE 'N/A' END as status
FROM pg_policies
WHERE tablename = 'user_profiles';

-- 6. Test: Try to manually create a profile for a test user (if needed)
-- Uncomment and replace USER_ID with an actual user ID:
/*
INSERT INTO user_profiles (id, email, display_name, role)
SELECT 
  id,
  email,
  split_part(email, '@', 1),
  CASE WHEN (SELECT COUNT(*) FROM user_profiles) = 0 THEN 'admin' ELSE 'pending' END
FROM auth.users
WHERE id = 'USER_ID_HERE'
  AND NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.users.id)
ON CONFLICT (id) DO NOTHING;
*/
