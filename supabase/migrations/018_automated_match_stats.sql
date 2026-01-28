-- Migration: Automate match stats and fix score sync
-- Adds player_id to match_events and sets up triggers for scores and goal counts

-- 1. Add player_id to match_events
ALTER TABLE match_events ADD COLUMN IF NOT EXISTS player_id UUID REFERENCES players(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_match_events_player_id ON match_events(player_id);

-- 2. Function to update match scores based on events
CREATE OR REPLACE FUNCTION update_match_score_from_events()
RETURNS TRIGGER AS $$
DECLARE
    h_score INT := 0;
    a_score INT := 0;
    m_id UUID;
BEGIN
    -- Get the match ID from OLD or NEW
    IF TG_OP = 'DELETE' THEN
        m_id := OLD.match_id;
    ELSE
        m_id := NEW.match_id;
    END IF;

    -- Calculate total scores for this match
    -- Goal/Penalty for home team OR Own Goal by away team = Home score
    SELECT 
        COUNT(*) FILTER (
            WHERE (team_id = m.home_team_id AND event_type IN ('goal', 'penalty'))
               OR (team_id = m.away_team_id AND event_type = 'own_goal')
        ),
        COUNT(*) FILTER (
            WHERE (team_id = m.away_team_id AND event_type IN ('goal', 'penalty'))
               OR (team_id = m.home_team_id AND event_type = 'own_goal')
        )
    INTO h_score, a_score
    FROM match_events e
    JOIN matches m ON m.id = e.match_id
    WHERE e.match_id = m_id;

    -- Update the match record
    UPDATE matches 
    SET home_goals = h_score, 
        away_goals = a_score,
        updated_at = NOW()
    WHERE id = m_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 3. Trigger for match score updates
DROP TRIGGER IF EXISTS trg_update_match_score ON match_events;
CREATE TRIGGER trg_update_match_score
AFTER INSERT OR UPDATE OR DELETE ON match_events
FOR EACH ROW
EXECUTE FUNCTION update_match_score_from_events();

-- 4. Function to update player goal tallies
CREATE OR REPLACE FUNCTION update_player_goal_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle Increments
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.player_id IS NOT NULL AND NEW.event_type IN ('goal', 'penalty') THEN
        -- If update and player changed, decrement old player first
        IF TG_OP = 'UPDATE' AND OLD.player_id IS NOT NULL AND OLD.player_id != NEW.player_id THEN
            UPDATE players SET goals = GREATEST(0, goals - 1) WHERE id = OLD.player_id;
        END IF;
        
        -- If update and event type changed away from goal, decrement
        IF TG_OP = 'UPDATE' AND OLD.event_type IN ('goal', 'penalty') AND NEW.event_type = 'own_goal' THEN
             UPDATE players SET goals = GREATEST(0, goals - 1) WHERE id = NEW.player_id;
        -- Normal increment
        ELSEIF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND (OLD.player_id IS NULL OR OLD.player_id != NEW.player_id OR OLD.event_type = 'own_goal')) THEN
            UPDATE players SET goals = COALESCE(goals, 0) + 1 WHERE id = NEW.player_id;
        END IF;
    END IF;

    -- Handle Decrements
    IF TG_OP = 'DELETE' AND OLD.player_id IS NOT NULL AND OLD.event_type IN ('goal', 'penalty') THEN
        UPDATE players SET goals = GREATEST(0, goals - 1) WHERE id = OLD.player_id;
    END IF;

    -- Handle Update where player/type removed/changed
    IF TG_OP = 'UPDATE' AND OLD.player_id IS NOT NULL AND (NEW.player_id IS NULL OR NEW.event_type = 'own_goal') AND OLD.event_type IN ('goal', 'penalty') THEN
        UPDATE players SET goals = GREATEST(0, goals - 1) WHERE id = OLD.player_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger for player goal updates
DROP TRIGGER IF EXISTS trg_update_player_goals ON match_events;
CREATE TRIGGER trg_update_player_goals
AFTER INSERT OR UPDATE OR DELETE ON match_events
FOR EACH ROW
EXECUTE FUNCTION update_player_goal_count();
