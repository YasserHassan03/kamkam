-- ============================================================================
-- Generate knockout stage for group_knockout tournaments
-- ============================================================================
-- After all group matches are finished, this RPC creates the knockout bracket
-- based on group standings (top N qualifiers per group).
--
-- The app currently generates ONLY the group stage fixtures for group_knockout.
-- Without this function, the Knockouts/Draw tab remains empty even after the
-- group stage is completed.

CREATE OR REPLACE FUNCTION generate_group_knockout_knockouts(
  p_tournament_id UUID
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_owner_id UUID;
  v_format VARCHAR;
  v_group_count INTEGER;
  v_qualifiers INTEGER;
  v_total_qualifiers INTEGER;
  v_tmp INTEGER;
  v_rounds_needed INTEGER := 0;
  v_match_date DATE;
  v_match_count INTEGER := 0;

  v_group_a INTEGER;
  v_group_b INTEGER;
  v_pos INTEGER;
  v_home UUID;
  v_away UUID;
  v_match_id UUID;

  v_round INTEGER;
  v_matches_per_round INTEGER;
  v_match_in_round INTEGER;
BEGIN
  v_user_id := auth.uid();

  SELECT owner_id, format, group_count, qualifiers_per_group
  INTO v_owner_id, v_format, v_group_count, v_qualifiers
  FROM tournaments
  WHERE id = p_tournament_id;

  IF v_format IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tournament not found');
  END IF;

  IF NOT (is_admin(v_user_id) OR v_owner_id = v_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;

  IF v_format <> 'group_knockout' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tournament is not group_knockout');
  END IF;

  IF v_group_count IS NULL OR v_group_count < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'group_count must be at least 2');
  END IF;

  IF v_qualifiers IS NULL OR v_qualifiers < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'qualifiers_per_group must be at least 1');
  END IF;

  -- Ensure group fixtures exist and are complete
  IF NOT EXISTS (
    SELECT 1 FROM matches
    WHERE tournament_id = p_tournament_id
      AND phase = 'group'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'No group fixtures found');
  END IF;

  IF EXISTS (
    SELECT 1 FROM matches
    WHERE tournament_id = p_tournament_id
      AND phase = 'group'
      AND status <> 'finished'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group stage not finished');
  END IF;

  -- Do not regenerate if knockouts already exist
  IF EXISTS (
    SELECT 1 FROM matches
    WHERE tournament_id = p_tournament_id
      AND phase = 'knockout'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Knockout stage already generated');
  END IF;

  v_total_qualifiers := v_group_count * v_qualifiers;
  IF v_total_qualifiers NOT IN (2,4,8,16,32) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Total qualifiers must be 2,4,8,16 or 32'
    );
  END IF;

  -- Calculate number of knockout rounds needed
  v_tmp := v_total_qualifiers;
  WHILE v_tmp > 1 LOOP
    v_tmp := v_tmp / 2;
    v_rounds_needed := v_rounds_needed + 1;
  END LOOP;

  -- Start knockout stage the day after the last group match (fallback: tomorrow)
  v_match_date :=
    COALESCE(
      (SELECT (MAX(kickoff_time))::date FROM matches WHERE tournament_id = p_tournament_id AND phase = 'group'),
      CURRENT_DATE
    ) + 1;

  -- Collect qualifiers from standings (ranked within each group)
  CREATE TEMP TABLE tmp_qualifiers (
    group_number INTEGER NOT NULL,
    pos INTEGER NOT NULL,
    team_id UUID NOT NULL
  ) ON COMMIT DROP;

  INSERT INTO tmp_qualifiers (group_number, pos, team_id)
  SELECT
    g.group_number,
    ranked.pos,
    ranked.team_id
  FROM (
    SELECT
      t.group_id,
      s.team_id,
      row_number() OVER (
        PARTITION BY t.group_id
        ORDER BY s.points DESC, s.goal_difference DESC, s.goals_for DESC, t.name ASC
      ) AS pos
    FROM standings s
    JOIN teams t ON t.id = s.team_id
    WHERE s.tournament_id = p_tournament_id
      AND t.group_id IS NOT NULL
  ) ranked
  JOIN groups g ON g.id = ranked.group_id
  WHERE ranked.pos <= v_qualifiers;

  IF (SELECT COUNT(*) FROM tmp_qualifiers) <> v_total_qualifiers THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not enough qualified teams found');
  END IF;

  -- Track created knockout matches to link next_match_id deterministically.
  CREATE TEMP TABLE tmp_ko_matches(
    id UUID PRIMARY KEY,
    round_num INTEGER NOT NULL,
    idx INTEGER NOT NULL
  ) ON COMMIT DROP;

  -- First knockout round uses round_number = v_rounds_needed (matches have teams)
  v_match_in_round := 1;
  FOR v_group_a IN 1..v_group_count BY 2 LOOP
    v_group_b := v_group_a + 1;

    FOR v_pos IN 1..v_qualifiers LOOP
      SELECT team_id INTO v_home
      FROM tmp_qualifiers
      WHERE group_number = v_group_a AND pos = v_pos;

      SELECT team_id INTO v_away
      FROM tmp_qualifiers
      WHERE group_number = v_group_b AND pos = (v_qualifiers - v_pos + 1);

      INSERT INTO matches (
        tournament_id, phase, round_number, home_team_id, away_team_id, kickoff_time, status
      ) VALUES (
        p_tournament_id,
        'knockout',
        v_rounds_needed,
        v_home,
        v_away,
        (v_match_date + ((v_rounds_needed - 1) * INTERVAL '1 day'))::timestamptz,
        'scheduled'
      ) RETURNING id INTO v_match_id;

      INSERT INTO tmp_ko_matches VALUES (v_match_id, v_rounds_needed, v_match_in_round);
      v_match_in_round := v_match_in_round + 1;
      v_match_count := v_match_count + 1;
    END LOOP;
  END LOOP;

  -- Create empty matches for later rounds (v_rounds_needed-1 down to 1)
  FOR v_round IN REVERSE (v_rounds_needed - 1)..1 LOOP
    v_matches_per_round := power(2, v_round - 1)::INTEGER;
    FOR v_match_in_round IN 1..v_matches_per_round LOOP
      INSERT INTO matches (
        tournament_id, phase, round_number, home_team_id, away_team_id, kickoff_time, status
      ) VALUES (
        p_tournament_id,
        'knockout',
        v_round,
        NULL,
        NULL,
        (v_match_date + ((v_round - 1) * INTERVAL '1 day'))::timestamptz,
        'scheduled'
      ) RETURNING id INTO v_match_id;

      INSERT INTO tmp_ko_matches VALUES (v_match_id, v_round, v_match_in_round);
      v_match_count := v_match_count + 1;
    END LOOP;
  END LOOP;

  -- Link next_match_id for bracket progression (round N links to round N-1)
  FOR v_round IN REVERSE v_rounds_needed..2 LOOP
    UPDATE matches m
    SET next_match_id = pm.id
    FROM tmp_ko_matches rm
    JOIN tmp_ko_matches pm
      ON pm.round_num = rm.round_num - 1
     AND pm.idx = ((rm.idx + 1) / 2)
    WHERE rm.round_num = v_round
      AND m.id = rm.id;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'matches_created', v_match_count,
    'rounds', v_rounds_needed
  );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION generate_group_knockout_knockouts(UUID) TO authenticated;

