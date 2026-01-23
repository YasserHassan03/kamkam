-- ============================================================================
-- Optimize Fixture Generation
-- ============================================================================
-- Replace individual INSERTs with batch operations for better performance
-- ============================================================================

-- Optimized round-robin fixture generation using proper round-robin algorithm
-- Each matchday, all teams play once (proper league structure)
CREATE OR REPLACE FUNCTION generate_round_robin_fixtures(
  p_tournament_id UUID,
  p_start_date DATE,
  p_rounds INTEGER DEFAULT 1
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teams UUID[];
  v_team_count INTEGER;
  v_match_count INTEGER := 0;
  v_match_date DATE;
  v_matchday INTEGER;
  v_rounds_per_season INTEGER;
  v_round INTEGER;
  v_round_offset INTEGER;
  v_home_idx INTEGER;
  v_away_idx INTEGER;
  v_home_team UUID;
  v_away_team UUID;
  v_kickoff TIMESTAMPTZ;
  v_rotated_teams UUID[];
  i INTEGER;
BEGIN
  -- Get teams
  SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams
  FROM teams
  WHERE tournament_id = p_tournament_id;

  IF v_teams IS NULL OR array_length(v_teams, 1) < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Need at least 2 teams');
  END IF;

  v_team_count := array_length(v_teams, 1);
  
  -- Require even number of teams for round-robin
  IF v_team_count % 2 = 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Round-robin requires even number of teams');
  END IF;

  v_match_date := COALESCE(p_start_date, CURRENT_DATE);
  v_rounds_per_season := v_team_count - 1; -- Number of matchdays in one complete round

  -- Create temporary table to batch inserts
  CREATE TEMP TABLE IF NOT EXISTS temp_matches (
    tournament_id UUID,
    phase VARCHAR,
    matchday INTEGER,
    home_team_id UUID,
    away_team_id UUID,
    kickoff_time TIMESTAMPTZ,
    status VARCHAR
  ) ON COMMIT DROP;

  -- Generate fixtures using round-robin algorithm
  -- Standard algorithm: Fix team 1, rotate others around
  FOR v_round IN 1..p_rounds LOOP
    v_round_offset := (v_round - 1) * v_rounds_per_season;
    
    -- For each matchday in the round
    FOR v_matchday IN 1..v_rounds_per_season LOOP
      -- Create rotated array for this matchday
      -- Team 1 stays fixed, others rotate
      v_rotated_teams := ARRAY[v_teams[1]]; -- Start with team 1
      
      -- Rotate: for matchday N, start from position (N-1) and wrap around
      FOR i IN 1..(v_team_count - 1) LOOP
        v_rotated_teams := v_rotated_teams || v_teams[((v_matchday - 2 + i) % (v_team_count - 1)) + 2];
      END LOOP;
      
      -- Generate matches for this matchday
      -- Pair up: (1 vs N), (2 vs N-1), (3 vs N-2), ...
      FOR i IN 1..(v_team_count / 2) LOOP
        v_home_idx := i;
        v_away_idx := v_team_count - i + 1;
        
        -- Determine home/away based on round
        IF v_round = 1 THEN
          -- First round: first team in pair is home
          v_home_team := v_rotated_teams[v_home_idx];
          v_away_team := v_rotated_teams[v_away_idx];
        ELSE
          -- Second round and beyond: swap home/away for return fixtures
          v_home_team := v_rotated_teams[v_away_idx];
          v_away_team := v_rotated_teams[v_home_idx];
        END IF;
        
        v_kickoff := (v_match_date + ((v_matchday - 1 + v_round_offset) * INTERVAL '1 day'))::TIMESTAMPTZ;
        
        INSERT INTO temp_matches VALUES (
          p_tournament_id, 'group', v_matchday + v_round_offset, v_home_team, v_away_team, v_kickoff, 'scheduled'
        );
        v_match_count := v_match_count + 1;
      END LOOP;
    END LOOP;
  END LOOP;

  -- Batch insert all matches at once
  INSERT INTO matches (tournament_id, phase, matchday, home_team_id, away_team_id, kickoff_time, status)
  SELECT tournament_id, phase, matchday, home_team_id, away_team_id, kickoff_time, status
  FROM temp_matches
  ORDER BY matchday, home_team_id;

  DROP TABLE IF EXISTS temp_matches;

  RETURN jsonb_build_object('success', true, 'matches_created', v_match_count);
END;
$$ LANGUAGE plpgsql;

-- Optimized knockout fixture generation using temporary table
CREATE OR REPLACE FUNCTION generate_knockout_fixtures(
  p_tournament_id UUID,
  p_start_date DATE
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_team_count INTEGER;
  v_match_count INTEGER := 0;
  v_rounds_needed INTEGER;
  v_teams UUID[];
  v_match_date DATE;
  v_kickoff TIMESTAMPTZ;
  v_match_id UUID;
  v_next_match_id UUID;
  v_round INTEGER;
  v_match_in_round INTEGER;
  v_matches_per_round INTEGER;
  v_first_round_matches UUID[];
  v_match_idx INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_team_count FROM teams WHERE tournament_id = p_tournament_id;

  IF v_team_count < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Need at least 2 teams');
  END IF;

  -- Calculate rounds needed
  v_rounds_needed := ceil(log(2, v_team_count))::INTEGER;
  
  -- Get teams sorted
  SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams
  FROM teams WHERE tournament_id = p_tournament_id;
  
  v_match_date := COALESCE(p_start_date, CURRENT_DATE);
  
  -- Create temporary table for batch inserts
  CREATE TEMP TABLE IF NOT EXISTS temp_knockout_matches (
    tournament_id UUID,
    phase VARCHAR,
    round_number INTEGER,
    home_team_id UUID,
    away_team_id UUID,
    kickoff_time TIMESTAMPTZ,
    status VARCHAR
  ) ON COMMIT DROP;
  
  -- Step 1: Create all matches for all rounds
  -- First round matches with teams
  FOR v_match_in_round IN 1..power(2, v_rounds_needed - 1)::INTEGER LOOP
    v_kickoff := (v_match_date + ((v_rounds_needed - 1) * INTERVAL '1 day'))::TIMESTAMPTZ;
    INSERT INTO temp_knockout_matches VALUES (
      p_tournament_id,
      'knockout',
      v_rounds_needed,
      v_teams[(v_match_in_round * 2 - 1)],
      CASE WHEN (v_match_in_round * 2) <= array_length(v_teams, 1) THEN v_teams[v_match_in_round * 2] ELSE NULL END,
      v_kickoff,
      'scheduled'
    );
    v_match_count := v_match_count + 1;
  END LOOP;
  
  -- Create empty matches for later rounds
  FOR v_round IN REVERSE (v_rounds_needed - 1)..1 LOOP
    v_matches_per_round := power(2, v_round - 1)::INTEGER;
    v_kickoff := (v_match_date + ((v_round - 1) * INTERVAL '1 day'))::TIMESTAMPTZ;
    
    FOR v_match_in_round IN 1..v_matches_per_round LOOP
      INSERT INTO temp_knockout_matches VALUES (
        p_tournament_id, 'knockout', v_round, NULL, NULL, v_kickoff, 'scheduled'
      );
      v_match_count := v_match_count + 1;
    END LOOP;
  END LOOP;
  
  -- Batch insert all matches
  INSERT INTO matches (tournament_id, phase, round_number, home_team_id, away_team_id, kickoff_time, status)
  SELECT tournament_id, phase, round_number, home_team_id, away_team_id, kickoff_time, status
  FROM temp_knockout_matches;
  
  DROP TABLE IF EXISTS temp_knockout_matches;
  
  -- Step 2: Link matches (batch update where possible)
  -- Get all first round matches
  SELECT ARRAY_AGG(id ORDER BY id) INTO v_first_round_matches
  FROM matches
  WHERE tournament_id = p_tournament_id
    AND phase = 'knockout'
    AND round_number = v_rounds_needed;
  
  -- Link matches from round N to round N-1 (optimized with batch updates)
  FOR v_round IN REVERSE v_rounds_needed..2 LOOP
    -- Use a more efficient approach: update all matches in a round at once
    WITH round_matches AS (
      SELECT id, row_number() OVER (ORDER BY id) as match_idx
      FROM matches
      WHERE tournament_id = p_tournament_id
        AND phase = 'knockout'
        AND round_number = v_round
    ),
    parent_matches AS (
      SELECT id, row_number() OVER (ORDER BY id) as parent_idx
      FROM matches
      WHERE tournament_id = p_tournament_id
        AND phase = 'knockout'
        AND round_number = v_round - 1
    )
    UPDATE matches m
    SET next_match_id = pm.id
    FROM round_matches rm
    JOIN parent_matches pm ON pm.parent_idx = ((rm.match_idx - 1) / 2) + 1
    WHERE m.id = rm.id;
  END LOOP;
  
  RETURN jsonb_build_object('success', true, 'matches_created', v_match_count);
END;
$$ LANGUAGE plpgsql;

-- Drop the old function first to avoid parameter name conflicts
-- The original function had p_rounds as the third parameter, but frontend uses p_days_between_matchdays
-- Drop with CASCADE to handle any dependencies
DROP FUNCTION IF EXISTS generate_tournament_fixtures(UUID, DATE, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS generate_tournament_fixtures(UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS generate_tournament_fixtures(UUID) CASCADE;

-- Optimized format-aware fixture generation
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
  v_qualifiers_per_group INTEGER;
  v_team_count INTEGER;
  v_match_count INTEGER := 0;
  v_teams UUID[];
  v_group_id UUID;
  v_group_rec RECORD;
  v_teams_in_group UUID[];
  v_match_date DATE;
  v_kickoff TIMESTAMPTZ;
  i INTEGER;
  j INTEGER;
  r INTEGER;
  v_round INTEGER;
  v_result JSONB;
BEGIN
  SELECT format, group_count, qualifiers_per_group INTO v_type, v_group_count, v_qualifiers_per_group
  FROM tournaments WHERE id = p_tournament_id;
  
  IF v_type IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tournament not found');
  END IF;

  SELECT COUNT(*) INTO v_team_count FROM teams WHERE tournament_id = p_tournament_id;

  IF v_team_count < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Need at least 2 teams');
  END IF;

  -- Clear existing matches
  DELETE FROM matches WHERE tournament_id = p_tournament_id;

  v_match_date := COALESCE(p_start_date, CURRENT_DATE);

  IF v_type = 'league' THEN
    -- Get rounds from rules
    SELECT COALESCE((rules_json->>'rounds')::INTEGER, 1) INTO r FROM tournaments WHERE id = p_tournament_id;
    RETURN generate_round_robin_fixtures(p_tournament_id, v_match_date, r);
  
  ELSIF v_type = 'knockout' THEN
    RETURN generate_knockout_fixtures(p_tournament_id, v_match_date);
  
  ELSIF v_type = 'group_knockout' THEN
    -- Step 1: Create groups
    IF v_group_count IS NULL OR v_group_count < 2 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Group knockout requires at least 2 groups');
    END IF;
    
    -- Create groups (batch insert)
    INSERT INTO groups (tournament_id, name, group_number)
    SELECT 
      p_tournament_id,
      'Group ' || CHR(64 + group_num),
      group_num
    FROM generate_series(1, v_group_count) group_num
    ON CONFLICT (tournament_id, group_number) DO NOTHING;
    
    -- Step 2: Assign teams to groups
    SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams
    FROM teams WHERE tournament_id = p_tournament_id;
    
    -- Assign teams to groups (round-robin distribution)
    FOR i IN 1..array_length(v_teams, 1) LOOP
      v_group_id := (
        SELECT id FROM groups 
        WHERE tournament_id = p_tournament_id 
        AND group_number = ((i - 1) % v_group_count) + 1
        LIMIT 1
      );
      UPDATE teams SET group_id = v_group_id WHERE id = v_teams[i];
    END LOOP;
    
    -- Step 3: Generate group stage fixtures (optimized with temp table)
    CREATE TEMP TABLE IF NOT EXISTS temp_group_matches (
      tournament_id UUID,
      phase VARCHAR,
      group_id UUID,
      home_team_id UUID,
      away_team_id UUID,
      kickoff_time TIMESTAMPTZ,
      status VARCHAR
    ) ON COMMIT DROP;

    FOR v_group_rec IN SELECT id, name, group_number FROM groups WHERE tournament_id = p_tournament_id ORDER BY group_number LOOP
      SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams_in_group
      FROM teams WHERE tournament_id = p_tournament_id AND group_id = v_group_rec.id;
      
      IF v_teams_in_group IS NOT NULL AND array_length(v_teams_in_group, 1) >= 2 THEN
        -- Generate round-robin within group
        FOR i IN 1..array_length(v_teams_in_group, 1) LOOP
          FOR j IN (i+1)..array_length(v_teams_in_group, 1) LOOP
            v_kickoff := (v_match_date + (v_match_count * INTERVAL '1 day'))::TIMESTAMPTZ;
            
            INSERT INTO temp_group_matches VALUES (
              p_tournament_id, 'group', v_group_rec.id, v_teams_in_group[i], v_teams_in_group[j], v_kickoff, 'scheduled'
            );
            
            v_match_count := v_match_count + 1;
          END LOOP;
        END LOOP;
      END IF;
    END LOOP;

    -- Batch insert all group matches at once
    INSERT INTO matches (tournament_id, phase, group_id, home_team_id, away_team_id, kickoff_time, status)
    SELECT tournament_id, phase, group_id, home_team_id, away_team_id, kickoff_time, status
    FROM temp_group_matches;

    DROP TABLE IF EXISTS temp_group_matches;
    
    RETURN jsonb_build_object(
      'success', true, 
      'matches_created', v_match_count,
      'message', 'Group stage fixtures created. Knockout stage will be generated after group stage completion.'
    );
  
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Unsupported tournament type: ' || v_type);
  END IF;
END;
$$ LANGUAGE plpgsql;
