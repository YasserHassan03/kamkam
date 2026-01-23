-- ============================================================================
-- Unique Tournament Names per Organisation
-- ============================================================================
-- Prevent multiple tournaments from the same organiser (organisation) 
-- from having the same name
-- ============================================================================

-- Add unique constraint on (org_id, name) combination
-- This ensures each organisation can only have one tournament with a given name
CREATE UNIQUE INDEX IF NOT EXISTS idx_tournaments_org_name_unique 
ON tournaments(org_id, LOWER(TRIM(name)));

-- ============================================================================
-- DONE! Now each organisation can only have one tournament with each name
-- (case-insensitive, trimmed)
-- ============================================================================
