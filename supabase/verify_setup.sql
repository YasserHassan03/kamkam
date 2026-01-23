-- Quick verification query to check if all tables exist
-- Run this in Supabase SQL Editor to verify your database setup

SELECT 
  table_name,
  CASE 
    WHEN table_name IN ('user_profiles', 'organisations', 'tournaments', 'groups', 'teams', 'players', 'matches', 'standings') 
    THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('user_profiles', 'organisations', 'tournaments', 'groups', 'teams', 'players', 'matches', 'standings')
ORDER BY table_name;

-- Check if key functions exist
SELECT 
  routine_name as function_name,
  '✅ EXISTS' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'update_match_result',
    'generate_tournament_fixtures',
    'generate_round_robin_fixtures',
    'generate_knockout_fixtures',
    'approve_user',
    'reject_user',
    'get_my_approval_status',
    'get_pending_users',
    'get_all_users',
    'handle_new_user'
  )
ORDER BY routine_name;

-- Check if trigger exists
SELECT 
  trigger_name,
  event_object_table,
  '✅ EXISTS' as status
FROM information_schema.triggers
WHERE trigger_schema = 'auth'
  AND trigger_name = 'on_auth_user_created';
