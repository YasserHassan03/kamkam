-- ============================================================================
-- Fix Draft Tournament Visibility
-- ============================================================================
-- Ensure draft tournaments are only visible to the organization owner
-- ============================================================================

-- Drop the existing public tournaments policy
DROP POLICY IF EXISTS "Public tournaments are viewable by everyone" ON tournaments;

-- Create updated policy that excludes draft tournaments from public view
CREATE POLICY "Public tournaments are viewable by everyone" ON tournaments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM organisations o 
            WHERE o.id = tournaments.org_id 
            AND o.visibility = 'public'
        )
        AND tournaments.status != 'draft' -- Draft tournaments not visible publicly
    );

-- The "Owners can view their tournament" policy remains unchanged
-- This allows owners to see all their tournaments including drafts

-- ============================================================================
-- DONE! Draft tournaments are now only visible to their creators
-- ============================================================================
