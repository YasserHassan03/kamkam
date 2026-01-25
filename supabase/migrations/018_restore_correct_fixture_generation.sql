-- ============================================================================
-- Restore correct fixture generation logic from migration 016
-- This restores the working knockout and group_knockout logic
-- ============================================================================

-- Restore the correct generate_tournament_fixtures function
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
