-- ============================================================================
-- Fix existing standings that have NULL group_id
-- This updates standings to match their team's group_id
-- ============================================================================

-- Update standings to set group_id from the team's group_id
UPDATE standings s
SET group_id = t.group_id
FROM teams t
WHERE s.team_id = t.id
  AND s.tournament_id = t.tournament_id
  AND t.group_id IS NOT NULL
  AND s.group_id IS NULL;
