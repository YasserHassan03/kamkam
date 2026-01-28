-- Harden RPC permissions and RLS to ensure only tournament owners or admins can modify data

-- 1) Update update_match_result with permission check
CREATE OR REPLACE FUNCTION update_match_result(
  p_match_id UUID,
  p_home_goals INTEGER,
  p_away_goals INTEGER
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match RECORD;
  v_tournament_format VARCHAR;
  v_old_home_goals INTEGER;
  v_old_away_goals INTEGER;
  v_old_status VARCHAR(20);
  v_prev_winner UUID;
  v_winner_id UUID;
  v_loser_id UUID;
  v_is_draw BOOLEAN;
  v_points_for_win INTEGER;
  v_points_for_draw INTEGER;
  v_points_for_loss INTEGER;
  v_next_match_id UUID;
  v_next_home UUID;
  v_next_away UUID;
BEGIN
  -- Get match details and tournament owner
  SELECT m.*, t.format, t.rules_json, t.owner_id
  INTO v_match
  FROM matches m
  JOIN tournaments t ON t.id = m.tournament_id
  WHERE m.id = p_match_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Match not found');
  END IF;

  -- PERMISSION CHECK: Only owner or admin
  IF v_match.owner_id != auth.uid() AND NOT is_admin(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Permission denied');
  END IF;

  v_old_home_goals := v_match.home_goals;
  v_old_away_goals := v_match.away_goals;
  v_old_status := v_match.status;
  v_next_match_id := v_match.next_match_id;

  -- Get points from rules
  v_points_for_win := COALESCE((v_match.rules_json->>'points_for_win')::INTEGER, 3);
  v_points_for_draw := COALESCE((v_match.rules_json->>'points_for_draw')::INTEGER, 1);
  v_points_for_loss := COALESCE((v_match.rules_json->>'points_for_loss')::INTEGER, 0);

  -- If match was previously finished, reverse the old result first
  IF v_old_status = 'finished' AND v_old_home_goals IS NOT NULL AND v_old_away_goals IS NOT NULL THEN
    -- Determine previous winner
    IF v_old_home_goals > v_old_away_goals THEN
      v_prev_winner := v_match.home_team_id;
    ELSIF v_old_home_goals < v_old_away_goals THEN
      v_prev_winner := v_match.away_team_id;
    ELSE
      v_prev_winner := NULL;
    END IF;

    -- Reverse home team stats
    UPDATE standings SET
      played = played - 1,
      won = won - CASE WHEN v_old_home_goals > v_old_away_goals THEN 1 ELSE 0 END,
      drawn = drawn - CASE WHEN v_old_home_goals = v_old_away_goals THEN 1 ELSE 0 END,
      lost = lost - CASE WHEN v_old_home_goals < v_old_away_goals THEN 1 ELSE 0 END,
      goals_for = goals_for - v_old_home_goals,
      goals_against = goals_against - v_old_away_goals,
      goal_difference = goals_for - v_old_home_goals - (goals_against - v_old_away_goals),
      points = points - CASE
        WHEN v_old_home_goals > v_old_away_goals THEN v_points_for_win
        WHEN v_old_home_goals = v_old_away_goals THEN v_points_for_draw
        ELSE v_points_for_loss
      END,
      updated_at = NOW()
    WHERE tournament_id = v_match.tournament_id
      AND COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::UUID) = COALESCE(v_match.group_id, '00000000-0000-0000-0000-000000000000'::UUID)
      AND team_id = v_match.home_team_id;

    -- Reverse away team stats
    UPDATE standings SET
      played = played - 1,
      won = won - CASE WHEN v_old_away_goals > v_old_home_goals THEN 1 ELSE 0 END,
      drawn = drawn - CASE WHEN v_old_away_goals = v_old_home_goals THEN 1 ELSE 0 END,
      lost = lost - CASE WHEN v_old_away_goals < v_old_home_goals THEN 1 ELSE 0 END,
      goals_for = goals_for - v_old_away_goals,
      goals_against = goals_against - v_old_home_goals,
      goal_difference = goals_for - v_old_away_goals - (goals_against - v_old_home_goals),
      points = points - CASE
        WHEN v_old_away_goals > v_old_home_goals THEN v_points_for_win
        WHEN v_old_away_goals = v_old_home_goals THEN v_points_for_draw
        ELSE v_points_for_loss
      END,
      updated_at = NOW()
    WHERE tournament_id = v_match.tournament_id
      AND COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::UUID) = COALESCE(v_match.group_id, '00000000-0000-0000-0000-000000000000'::UUID)
      AND team_id = v_match.away_team_id;

    -- Undo propagation to next match
    IF v_prev_winner IS NOT NULL AND v_next_match_id IS NOT NULL THEN
      SELECT home_team_id, away_team_id INTO v_next_home, v_next_away FROM matches WHERE id = v_next_match_id;
      IF v_next_home = v_prev_winner THEN
        UPDATE matches SET home_team_id = NULL WHERE id = v_next_match_id;
      ELSIF v_next_away = v_prev_winner THEN
        UPDATE matches SET away_team_id = NULL WHERE id = v_next_match_id;
      END IF;
    END IF;
  END IF;

  -- Update the match with new result
  UPDATE matches
  SET home_goals = p_home_goals,
      away_goals = p_away_goals,
      status = 'finished',
      updated_at = NOW()
  WHERE id = p_match_id;

  -- Determine winner/loser/draw for new result
  IF p_home_goals > p_away_goals THEN
    v_winner_id := v_match.home_team_id;
    v_loser_id := v_match.away_team_id;
    v_is_draw := false;
  ELSIF p_away_goals > p_home_goals THEN
    v_winner_id := v_match.away_team_id;
    v_loser_id := v_match.home_team_id;
    v_is_draw := false;
  ELSE
    v_is_draw := true;
  END IF;

  -- Update standings for league/group stages
  IF v_match.format IN ('league', 'group_knockout') AND (v_match.phase = 'group' OR v_match.phase IS NULL) THEN
    -- Update home team standings
    UPDATE standings
    SET played = played + 1,
        won = won + CASE WHEN p_home_goals > p_away_goals THEN 1 ELSE 0 END,
        drawn = drawn + CASE WHEN p_home_goals = p_away_goals THEN 1 ELSE 0 END,
        lost = lost + CASE WHEN p_home_goals < p_away_goals THEN 1 ELSE 0 END,
        goals_for = goals_for + p_home_goals,
        goals_against = goals_against + p_away_goals,
        goal_difference = (goals_for + p_home_goals) - (goals_against + p_away_goals),
        points = points + CASE
          WHEN p_home_goals > p_away_goals THEN v_points_for_win
          WHEN p_home_goals = p_away_goals THEN v_points_for_draw
          ELSE v_points_for_loss
        END,
        updated_at = NOW()
    WHERE tournament_id = v_match.tournament_id
      AND COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::UUID) = COALESCE(v_match.group_id, '00000000-0000-0000-0000-000000000000'::UUID)
      AND team_id = v_match.home_team_id;

    -- Update away team standings
    UPDATE standings
    SET played = played + 1,
        won = won + CASE WHEN p_away_goals > p_home_goals THEN 1 ELSE 0 END,
        drawn = drawn + CASE WHEN p_away_goals = p_home_goals THEN 1 ELSE 0 END,
        lost = lost + CASE WHEN p_away_goals < p_home_goals THEN 1 ELSE 0 END,
        goals_for = goals_for + p_away_goals,
        goals_against = goals_against + p_home_goals,
        goal_difference = (goals_for + p_away_goals) - (goals_against + p_home_goals),
        points = points + CASE
          WHEN p_away_goals > p_home_goals THEN v_points_for_win
          WHEN p_away_goals = p_home_goals THEN v_points_for_draw
          ELSE v_points_for_loss
        END,
        updated_at = NOW()
    WHERE tournament_id = v_match.tournament_id
      AND COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::UUID) = COALESCE(v_match.group_id, '00000000-0000-0000-0000-000000000000'::UUID)
      AND team_id = v_match.away_team_id;
  END IF;

  -- Handle knockout progression
  IF v_match.format IN ('knockout', 'group_knockout') AND v_match.phase = 'knockout' AND NOT v_is_draw AND v_next_match_id IS NOT NULL THEN
    -- Assign winner to next match
    SELECT home_team_id, away_team_id INTO v_next_home, v_next_away FROM matches WHERE id = v_next_match_id;
    IF v_next_home IS NULL THEN
      UPDATE matches SET home_team_id = v_winner_id WHERE id = v_next_match_id;
    ELSIF v_next_away IS NULL THEN
      UPDATE matches SET away_team_id = v_winner_id WHERE id = v_next_match_id;
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;

-- 2) Update RLS policies to include is_admin check for management
-- Tournaments
DROP POLICY IF EXISTS "Owners can manage their tournaments" ON tournaments;
CREATE POLICY "Owners and admins can manage their tournaments"
  ON tournaments FOR ALL
  USING (
    owner_id = auth.uid()
    OR is_admin(auth.uid())
    OR EXISTS (
      SELECT 1 FROM organisations o
      WHERE o.id = tournaments.org_id
      AND (o.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  );

-- Matches
DROP POLICY IF EXISTS "Tournament owners can manage matches" ON matches;
CREATE POLICY "Tournament owners and admins can manage matches"
  ON matches FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = matches.tournament_id
      AND (tournaments.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  );

-- Teams
DROP POLICY IF EXISTS "Tournament owners can manage teams" ON teams;
CREATE POLICY "Tournament owners and admins can manage teams"
  ON teams FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = teams.tournament_id
      AND (tournaments.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  );

-- Players
DROP POLICY IF EXISTS "Tournament owners can manage players" ON players;
CREATE POLICY "Tournament owners and admins can manage players"
  ON players FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM teams
      JOIN tournaments ON tournaments.id = teams.tournament_id
      WHERE teams.id = players.team_id
      AND (tournaments.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  );

-- match_events
DROP POLICY IF EXISTS "Tournament owners can manage match events" ON match_events;
CREATE POLICY "Tournament owners and admins can manage match events"
ON match_events FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM matches m
    JOIN tournaments t ON t.id = m.tournament_id
    WHERE m.id = match_events.match_id
      AND (t.owner_id = auth.uid() OR is_admin(auth.uid()))
  )
);
