-- ============================================================================
-- Fix Fixture Generation Logic: Proper Matchdays and Bracket Pairings
-- ============================================================================

-- 1. Fix Round Robin Fixtures to use proper Matchdays
-- This ensures that each team plays exactly once per matchday.
CREATE OR REPLACE FUNCTION generate_round_robin_fixtures(
  p_tournament_id UUID,
  p_start_date DATE,
  p_rounds INTEGER DEFAULT 1,
  p_group_id UUID DEFAULT NULL
)
RETURNS TABLE (
  home_team_id UUID,
  away_team_id UUID,
  matchday INTEGER,
  kickoff_time TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_teams UUID[];
  v_team_count INTEGER;
  v_rounds_per_cycle INTEGER;
  v_total_matchdays INTEGER;
  v_rotated_teams UUID[];
  v_match_date DATE;
  v_matchday INTEGER;
  v_cycle INTEGER;
BEGIN
  -- Get teams for this specific group or tournament
  SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams
  FROM teams
  WHERE tournament_id = p_tournament_id
    AND (p_group_id IS NULL OR group_id = p_group_id);

  v_team_count := array_length(v_teams, 1);
  IF v_team_count IS NULL OR v_team_count < 2 THEN
    RETURN;
  END IF;

  -- Add a dummy team (NULL) if odd number of teams to handle byes
  IF v_team_count % 2 = 1 THEN
    v_teams := v_teams || NULL::UUID;
    v_team_count := v_team_count + 1;
  END IF;

  v_rounds_per_cycle := v_team_count - 1;
  v_match_date := COALESCE(p_start_date, CURRENT_DATE);

  FOR v_cycle IN 1..p_rounds LOOP
    FOR v_matchday IN 1..v_rounds_per_cycle LOOP
      -- Rotate teams using the circle method
      v_rotated_teams := ARRAY[v_teams[1]];
      FOR i IN 1..(v_team_count - 1) LOOP
        v_rotated_teams := v_rotated_teams || v_teams[((v_matchday - 2 + i) % (v_team_count - 1)) + 2];
      END LOOP;

      -- Pair teams
      FOR i IN 1..(v_team_count / 2) LOOP
        home_team_id := v_rotated_teams[i];
        away_team_id := v_rotated_teams[v_team_count - i + 1];

        -- Skip matches with the dummy team (byes)
        IF home_team_id IS NOT NULL AND away_team_id IS NOT NULL THEN
          -- Flip home/away for even cycles
          IF v_cycle % 2 = 0 THEN
            DECLARE tmp UUID := home_team_id; BEGIN home_team_id := away_team_id; away_team_id := tmp; END;
          END IF;

          matchday := (v_cycle - 1) * v_rounds_per_cycle + v_matchday;
          kickoff_time := (v_match_date + ((matchday - 1) * INTERVAL '1 day'))::TIMESTAMPTZ;
          RETURN NEXT;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;
END;
$$;

-- 2. Update generate_tournament_fixtures to use the fixed round-robin logic
CREATE OR REPLACE FUNCTION generate_tournament_fixtures(
  p_tournament_id UUID,
  p_start_date DATE DEFAULT NULL,
  p_days_between_matchdays INTEGER DEFAULT 7
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type VARCHAR;
  v_group_count INTEGER;
  v_match_count INTEGER := 0;
  v_teams UUID[];
  v_group_rec RECORD;
  v_match_date DATE;
  v_rules JSONB;
  v_rounds INTEGER;
  v_delta INTEGER;
BEGIN
  SELECT format, group_count, rules_json INTO v_type, v_group_count, v_rules
  FROM tournaments WHERE id = p_tournament_id;
  
  IF v_type IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tournament not found');
  END IF;

  -- 1. Clear existing matches
  DELETE FROM matches WHERE tournament_id = p_tournament_id;

  -- 2. Clear existing groups (ensures parity if group count changed)
  DELETE FROM groups WHERE tournament_id = p_tournament_id;

  -- 3. Reset standings for this tournament
  UPDATE standings SET
    played = 0,
    won = 0,
    drawn = 0,
    lost = 0,
    goals_for = 0,
    goals_against = 0,
    goal_difference = 0,
    points = 0,
    group_id = NULL,
    updated_at = NOW()
  WHERE tournament_id = p_tournament_id;

  -- 4. Reset player goals for all teams in this tournament
  UPDATE players SET goals = 0
  WHERE team_id IN (SELECT id FROM teams WHERE tournament_id = p_tournament_id);

  -- Update tournament timestamp
  UPDATE tournaments SET updated_at = NOW() WHERE id = p_tournament_id;

  v_match_date := COALESCE(p_start_date, CURRENT_DATE);

  IF v_type = 'league' THEN
    v_rounds := COALESCE((v_rules->>'rounds')::INTEGER, 1);
    
    INSERT INTO matches (tournament_id, home_team_id, away_team_id, matchday, kickoff_time, status, phase)
    SELECT p_tournament_id, m.home_team_id, m.away_team_id, m.matchday, m.kickoff_time, 'scheduled', 'group'
    FROM generate_round_robin_fixtures(p_tournament_id, v_match_date, v_rounds) m;
    
    GET DIAGNOSTICS v_match_count = ROW_COUNT;
    RETURN jsonb_build_object('success', true, 'matches_created', v_match_count);

  ELSIF v_type = 'group_knockout' THEN
    -- Setup groups
    IF v_group_count IS NULL OR v_group_count < 2 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Group knockout requires at least 2 groups');
    END IF;

    -- Create groups
    INSERT INTO groups (tournament_id, name, group_number)
    SELECT 
      p_tournament_id,
      'Group ' || CHR(64 + group_num),
      group_num
    FROM generate_series(1, v_group_count) group_num
    ON CONFLICT (tournament_id, group_number) DO NOTHING;

    -- Assign teams to groups if they aren't assigned
    SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams FROM teams WHERE tournament_id = p_tournament_id;
    FOR i IN 1..array_length(v_teams, 1) LOOP
      DECLARE
        v_g_id UUID;
      BEGIN
        SELECT id INTO v_g_id FROM groups WHERE tournament_id = p_tournament_id AND group_number = ((i - 1) % v_group_count) + 1;
        IF v_g_id IS NOT NULL THEN
          UPDATE teams SET group_id = v_g_id WHERE id = v_teams[i];
        END IF;
      END;
    END LOOP;

    -- Generate Group Stage Fixtures
    FOR v_group_rec IN SELECT id FROM groups WHERE tournament_id = p_tournament_id ORDER BY group_number LOOP
      INSERT INTO matches (tournament_id, group_id, home_team_id, away_team_id, matchday, kickoff_time, status, phase)
      SELECT p_tournament_id, v_group_rec.id, m.home_team_id, m.away_team_id, m.matchday, m.kickoff_time, 'scheduled', 'group'
      FROM generate_round_robin_fixtures(p_tournament_id, v_match_date, 1, v_group_rec.id) m;
      
      GET DIAGNOSTICS v_delta = ROW_COUNT;
      v_match_count := v_match_count + v_delta;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'matches_created', v_match_count);

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Unsupported tournament type for this generator');
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 3. Fix Knockout pairing logic for group_knockout
CREATE OR REPLACE FUNCTION generate_group_knockout_knockouts(
  p_tournament_id UUID
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_count INTEGER;
  v_qualifiers INTEGER;
  v_total_qualifiers INTEGER;
  v_match_date DATE;
  v_rounds_needed INTEGER := 0;
  v_round INTEGER;
  v_match_in_round INTEGER;
  v_matches_per_round INTEGER;
  v_match_id UUID;
  v_match_count INTEGER := 0;
  
  -- Match pairing variables
  v_home UUID;
  v_away UUID;
  v_half_matches INTEGER;
BEGIN
  SELECT group_count, qualifiers_per_group
  INTO v_group_count, v_qualifiers
  FROM tournaments WHERE id = p_tournament_id;

  v_total_qualifiers := v_group_count * v_qualifiers;
  
  -- Validate power of 2
  IF v_total_qualifiers NOT IN (2, 4, 8, 16, 32) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Total qualifiers (' || v_total_qualifiers || ') must be a power of 2 (2, 4, 8, 16, 32). Please adjust group count or qualifiers per group.');
  END IF;

  v_rounds_needed := ceil(log(2, v_total_qualifiers))::INTEGER;

  v_match_date := COALESCE(
    (SELECT (MAX(kickoff_time))::date FROM matches WHERE tournament_id = p_tournament_id AND phase = 'group'),
    CURRENT_DATE
  ) + 1;

  -- Create temp tables for tracking
  CREATE TEMP TABLE tmp_qualifiers (
    group_num INTEGER,
    pos INTEGER,
    team_id UUID
  ) ON COMMIT DROP;

  INSERT INTO tmp_qualifiers (group_num, pos, team_id)
  SELECT g.group_number, ranked.pos, ranked.team_id
  FROM (
    SELECT t.group_id, s.team_id, row_number() OVER (PARTITION BY t.group_id ORDER BY s.points DESC, s.goal_difference DESC, s.goals_for DESC) as pos
    FROM standings s JOIN teams t ON t.id = s.team_id
    WHERE s.tournament_id = p_tournament_id
  ) ranked JOIN groups g ON g.id = ranked.group_id
  WHERE ranked.pos <= v_qualifiers;

  CREATE TEMP TABLE tmp_ko_matches (
    id UUID PRIMARY KEY,
    round_num INTEGER,
    idx INTEGER
  ) ON COMMIT DROP;

  -- FIRST KNOCKOUT ROUND (Round v_rounds_needed)
  -- Generalized Pairing Strategy:
  -- Split teams into two halves to ensure group-mates (Winner & Runner-up) are on opposite sides.
  -- Half 1: Winners of Odd Groups vs Runners-up of Even Groups
  -- Half 2: Winners of Even Groups vs Runners-up of Odd Groups
  
  v_half_matches := v_total_qualifiers / 4; -- Number of matches per half per qualifier level
  -- Note: This works best for 2 qualifiers per group. 
  -- If qualifiers > 2, we just pair them sequentially for now while maintaining the split.

  FOR v_match_in_round IN 1..(v_total_qualifiers / 2) LOOP
    -- Logic for pairing:
    -- If we have 4 groups, 2 qualifiers each = 4 QF matches.
    -- Match 1: G1-P1 vs G2-P2
    -- Match 2: G3-P1 vs G4-P2
    -- Match 3: G2-P1 vs G1-P2
    -- Match 4: G4-P1 vs G3-P2
    
    DECLARE
      v_g1 INTEGER;
      v_g2 INTEGER;
      v_p1 INTEGER;
      v_p2 INTEGER;
      v_is_second_half BOOLEAN;
    BEGIN
      v_is_second_half := v_match_in_round > (v_total_qualifiers / 4);
      
      IF NOT v_is_second_half THEN
        -- First Half
        v_g1 := (v_match_in_round * 2) - 1;
        v_g2 := v_match_in_round * 2;
        v_p1 := 1;
        v_p2 := 2;
      ELSE
        -- Second Half
        v_g1 := ((v_match_in_round - (v_total_qualifiers / 4)) * 2);
        v_g2 := ((v_match_in_round - (v_total_qualifiers / 4)) * 2) - 1;
        v_p1 := 1;
        v_p2 := 2;
      END IF;

      SELECT team_id INTO v_home FROM tmp_qualifiers WHERE group_num = v_g1 AND pos = v_p1;
      SELECT team_id INTO v_away FROM tmp_qualifiers WHERE group_num = v_g2 AND pos = v_p2;

      -- Fallback if not exactly 2 qualifiers or odd group counts
      IF v_home IS NULL OR v_away IS NULL THEN
         -- Simple sequential fallback if the complex logic doesn't find a pair
         SELECT team_id INTO v_home FROM tmp_qualifiers OFFSET (v_match_in_round * 2 - 2) LIMIT 1;
         SELECT team_id INTO v_away FROM tmp_qualifiers OFFSET (v_match_in_round * 2 - 1) LIMIT 1;
      END IF;

      INSERT INTO matches (tournament_id, phase, round_number, home_team_id, away_team_id, kickoff_time, status)
      VALUES (p_tournament_id, 'knockout', v_rounds_needed, v_home, v_away, v_match_date, 'scheduled') RETURNING id INTO v_match_id;
      
      INSERT INTO tmp_ko_matches VALUES (v_match_id, v_rounds_needed, v_match_in_round);
      v_match_count := v_match_count + 1;
    END;
  END LOOP;

  -- SUBSEQUENT RECURSIVE ROUNDS
  FOR v_round IN REVERSE (v_rounds_needed - 1)..1 LOOP
    v_matches_per_round := power(2, v_round - 1)::INTEGER;
    FOR v_match_in_round IN 1..v_matches_per_round LOOP
      INSERT INTO matches (tournament_id, phase, round_number, home_team_id, away_team_id, kickoff_time, status)
      VALUES (p_tournament_id, 'knockout', v_round, NULL, NULL, v_match_date + ((v_rounds_needed - v_round) * INTERVAL '1 day'), 'scheduled') RETURNING id INTO v_match_id;
      INSERT INTO tmp_ko_matches VALUES (v_match_id, v_round, v_match_in_round);
      v_match_count := v_match_count + 1;
    END LOOP;
  END LOOP;

  -- Link logic
  UPDATE matches m
  SET next_match_id = pm.id
  FROM tmp_ko_matches rm JOIN tmp_ko_matches pm ON pm.round_num = rm.round_num - 1 AND pm.idx = ((rm.idx + 1) / 2)
  WHERE rm.round_num > 1 AND m.id = rm.id;

  RETURN jsonb_build_object('success', true, 'matches_created', v_match_count);
END;
$$ LANGUAGE plpgsql;
