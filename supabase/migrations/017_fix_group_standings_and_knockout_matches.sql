-- ============================================================================
-- Fix group standings - only add trigger, keep existing fixture generation logic
-- ============================================================================

-- Update standings to set group_id when teams are assigned to groups
-- This fixes the issue where standings are created before teams get group_id
CREATE OR REPLACE FUNCTION update_standings_group_id()
RETURNS TRIGGER AS $$
BEGIN
  -- When a team's group_id is updated, update the corresponding standing
  IF NEW.group_id IS DISTINCT FROM OLD.group_id THEN
    UPDATE standings
    SET group_id = NEW.group_id
    WHERE tournament_id = NEW.tournament_id
      AND team_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS update_standings_on_team_group_update ON teams;
CREATE TRIGGER update_standings_on_team_group_update
  AFTER UPDATE OF group_id ON teams
  FOR EACH ROW
  WHEN (NEW.group_id IS DISTINCT FROM OLD.group_id)
  EXECUTE FUNCTION update_standings_group_id();
