-- ============================================================================
-- Fix Orphaned Tournaments
-- ============================================================================
-- This script helps identify and clean up tournaments/organisations 
-- that are orphaned (owner_id doesn't exist in user_profiles)
-- ============================================================================

-- Function to find and optionally delete orphaned tournaments
CREATE OR REPLACE FUNCTION find_orphaned_data()
RETURNS TABLE (
    type TEXT,
    id UUID,
    name TEXT,
    owner_id UUID,
    owner_email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Find orphaned organisations
    RETURN QUERY
    SELECT 
        'organisation'::TEXT as type,
        o.id,
        o.name,
        o.owner_id,
        o.owner_email
    FROM organisations o
    WHERE NOT EXISTS (
        SELECT 1 FROM user_profiles up WHERE up.id = o.owner_id
    );
    
    -- Find orphaned tournaments
    RETURN QUERY
    SELECT 
        'tournament'::TEXT as type,
        t.id,
        t.name,
        t.owner_id,
        t.owner_email
    FROM tournaments t
    WHERE NOT EXISTS (
        SELECT 1 FROM user_profiles up WHERE up.id = t.owner_id
    );
END;
$$;

-- Function to delete orphaned tournaments and their data
CREATE OR REPLACE FUNCTION cleanup_orphaned_tournaments()
RETURNS TABLE (
    deleted_type TEXT,
    deleted_id UUID,
    deleted_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    orphaned_tournament RECORD;
    tournament_ids UUID[];
BEGIN
    -- Get all orphaned tournament IDs
    SELECT ARRAY_AGG(id) INTO tournament_ids
    FROM tournaments
    WHERE NOT EXISTS (
        SELECT 1 FROM user_profiles up WHERE up.id = tournaments.owner_id
    );
    
    -- If no orphaned tournaments, return
    IF tournament_ids IS NULL OR array_length(tournament_ids, 1) = 0 THEN
        RETURN;
    END IF;
    
    -- Delete related data
    DELETE FROM standings WHERE tournament_id = ANY(tournament_ids);
    DELETE FROM matches WHERE tournament_id = ANY(tournament_ids);
    DELETE FROM players WHERE team_id IN (SELECT id FROM teams WHERE tournament_id = ANY(tournament_ids));
    DELETE FROM teams WHERE tournament_id = ANY(tournament_ids);
    DELETE FROM groups WHERE tournament_id = ANY(tournament_ids);
    
    -- Delete orphaned tournaments and return info
    RETURN QUERY
    WITH deleted AS (
        DELETE FROM tournaments
        WHERE id = ANY(tournament_ids)
        RETURNING id, name
    )
    SELECT 'tournament'::TEXT, d.id, d.name::TEXT
    FROM deleted d;
    
    -- Also delete orphaned organisations
    RETURN QUERY
    WITH deleted AS (
        DELETE FROM organisations
        WHERE NOT EXISTS (
            SELECT 1 FROM user_profiles up WHERE up.id = organisations.owner_id
        )
        RETURNING id, name
    )
    SELECT 'organisation'::TEXT, d.id, d.name::TEXT
    FROM deleted d;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION find_orphaned_data() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_orphaned_tournaments() TO authenticated;

-- ============================================================================
-- USAGE:
-- ============================================================================
-- 1. To find orphaned data:
--    SELECT * FROM find_orphaned_data();
--
-- 2. To clean up orphaned tournaments and organisations:
--    SELECT * FROM cleanup_orphaned_tournaments();
--
-- 3. After cleanup, you can manually delete the auth.users record via:
--    - Supabase Dashboard > Authentication > Users
--    - Or Supabase Admin API
-- ============================================================================
