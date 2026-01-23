-- ============================================================================
-- Cleanup Orphaned Data - Run this in Supabase SQL Editor
-- ============================================================================
-- This script will find and delete all tournaments/organisations 
-- that belong to users who no longer exist in user_profiles
-- ============================================================================

-- Step 1: Check what orphaned data exists (optional - just to see what will be deleted)
SELECT * FROM find_orphaned_data();

-- Step 2: Clean up orphaned tournaments and organisations
-- This will delete all orphaned data and return what was deleted
SELECT * FROM cleanup_orphaned_tournaments();

-- ============================================================================
-- After running, you should see output like:
-- deleted_type  | deleted_id | deleted_name
-- tournament    | uuid-here  | Tournament Name
-- organisation  | uuid-here  | Organisation Name
-- ============================================================================
