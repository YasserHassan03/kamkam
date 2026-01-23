-- Quick fix for anonymous user permissions
-- Run this in Supabase SQL Editor if you already ran the migration
-- This allows anonymous (not logged in) users to view public tournaments

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO anon;

-- Grant SELECT permissions on public tables
GRANT SELECT ON organisations TO anon;
GRANT SELECT ON tournaments TO anon;
GRANT SELECT ON groups TO anon;
GRANT SELECT ON teams TO anon;
GRANT SELECT ON players TO anon;
GRANT SELECT ON matches TO anon;
GRANT SELECT ON standings TO anon;

-- Verify permissions
SELECT 
  grantee, 
  table_name, 
  privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'anon'
  AND table_schema = 'public'
ORDER BY table_name, privilege_type;
