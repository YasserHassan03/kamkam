-- ============================================================================
-- Admin Tournament Controls
-- ============================================================================
-- Add hidden_by_admin field to tournaments and update RLS policies
-- Add delete user functionality
-- ============================================================================

-- Add hidden_by_admin field to tournaments table
ALTER TABLE tournaments 
ADD COLUMN IF NOT EXISTS hidden_by_admin BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_tournaments_hidden_by_admin ON tournaments(hidden_by_admin);

-- Update RLS policy to hide tournaments that are hidden by admin from public view
-- Drop existing public tournaments policy
DROP POLICY IF EXISTS "Public tournaments are viewable by everyone" ON tournaments;

-- Create updated policy that excludes hidden_by_admin tournaments
CREATE POLICY "Public tournaments are viewable by everyone" ON tournaments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM organisations o 
            WHERE o.id = tournaments.org_id 
            AND o.visibility = 'public'
        )
        AND tournaments.status != 'draft' -- Draft tournaments not visible publicly
        AND tournaments.hidden_by_admin = FALSE -- Admin-hidden tournaments not visible publicly
    );

-- Admins can always see all tournaments (including hidden ones)
-- This policy should already exist, but we ensure it allows viewing hidden tournaments
DROP POLICY IF EXISTS "Admins can view all tournaments" ON tournaments;

CREATE POLICY "Admins can view all tournaments" ON tournaments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid()
            AND up.role = 'admin'
        )
    );

-- Admins can update hidden_by_admin field
DROP POLICY IF EXISTS "Admins can hide/show tournaments" ON tournaments;
CREATE POLICY "Admins can hide/show tournaments" ON tournaments
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid()
            AND up.role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid()
            AND up.role = 'admin'
        )
    );

-- ============================================================================
-- Delete User Functionality
-- ============================================================================
-- Function to delete a user and all their data (admin only)
-- This manually deletes all related data since we can't delete from auth.users directly
CREATE OR REPLACE FUNCTION delete_user(user_id_to_delete UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID;
    is_admin BOOLEAN;
    org_ids UUID[];
    tournament_ids UUID[];
BEGIN
    -- Get current user
    current_user_id := auth.uid();
    
    -- Check if current user is admin using helper function (bypasses RLS)
    SELECT is_admin(current_user_id) INTO is_admin;
    
    IF NOT is_admin THEN
        RAISE EXCEPTION 'Only admins can delete users';
    END IF;
    
    -- Prevent self-deletion
    IF current_user_id = user_id_to_delete THEN
        RAISE EXCEPTION 'Admins cannot delete their own account';
    END IF;
    
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = user_id_to_delete) THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Step 1: Get all organisations owned by this user
    SELECT ARRAY_AGG(id) INTO org_ids
    FROM organisations
    WHERE owner_id = user_id_to_delete;
    
    -- Step 2: Get ALL tournament IDs that need to be deleted
    -- This includes:
    -- - Tournaments directly owned by the user (owner_id = user_id_to_delete)
    -- - Tournaments in organisations owned by the user (org_id IN org_ids)
    SELECT ARRAY_AGG(DISTINCT id) INTO tournament_ids
    FROM tournaments
    WHERE owner_id = user_id_to_delete
       OR (org_ids IS NOT NULL AND array_length(org_ids, 1) > 0 AND org_id = ANY(org_ids));
    
    -- Step 3: Delete all related data for these tournaments (in correct order)
    IF tournament_ids IS NOT NULL AND array_length(tournament_ids, 1) > 0 THEN
        -- Delete standings
        DELETE FROM standings WHERE tournament_id = ANY(tournament_ids);
        
        -- Delete matches
        DELETE FROM matches WHERE tournament_id = ANY(tournament_ids);
        
        -- Delete players (via teams)
        DELETE FROM players 
        WHERE team_id IN (SELECT id FROM teams WHERE tournament_id = ANY(tournament_ids));
        
        -- Delete teams
        DELETE FROM teams WHERE tournament_id = ANY(tournament_ids);
        
        -- Delete groups
        DELETE FROM groups WHERE tournament_id = ANY(tournament_ids);
    END IF;
    
    -- Step 4: Delete ALL tournaments associated with this user
    -- Delete tournaments directly owned by user (explicit, catches all)
    DELETE FROM tournaments WHERE owner_id = user_id_to_delete;
    
    -- Delete tournaments in user's organisations (explicit, catches all)
    IF org_ids IS NOT NULL AND array_length(org_ids, 1) > 0 THEN
        DELETE FROM tournaments WHERE org_id = ANY(org_ids);
    END IF;
    
    -- Step 5: Delete organisations (will cascade via FK, but we've already deleted tournaments)
    IF org_ids IS NOT NULL AND array_length(org_ids, 1) > 0 THEN
        DELETE FROM organisations WHERE id = ANY(org_ids);
    END IF;
    
    -- Final cleanup: delete any remaining organisations owned by user
    DELETE FROM organisations WHERE owner_id = user_id_to_delete;
    
    -- Step 6: Delete user profile
    DELETE FROM user_profiles WHERE id = user_id_to_delete;
    
    -- Note: The auth.users record will remain but will be orphaned
    -- You can delete it manually via Supabase Dashboard > Authentication > Users
    -- or use Supabase Admin API: DELETE /auth/v1/admin/users/{user_id}
    
END;
$$;

-- Grant execute permission to authenticated users (RLS will enforce admin check)
GRANT EXECUTE ON FUNCTION delete_user(UUID) TO authenticated;

-- ============================================================================
-- DONE! Admin can now:
-- 1. Hide tournaments from public view (overriding organiser settings)
-- 2. Delete users from the system
-- ============================================================================
