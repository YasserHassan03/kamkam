-- ============================================================================
-- Add bracket and group support
-- ============================================================================

-- Add competition format and group settings to tournaments
ALTER TABLE tournaments
  ADD COLUMN IF NOT EXISTS format VARCHAR(32) NOT NULL DEFAULT 'league' CHECK (format IN ('league','knockout','group_knockout')),
  ADD COLUMN IF NOT EXISTS group_count INTEGER,
  ADD COLUMN IF NOT EXISTS qualifiers_per_group INTEGER;

-- Add group number to teams
ALTER TABLE teams
  ADD COLUMN IF NOT EXISTS group_number INTEGER;

-- Extend matches to support knockout/bracket metadata and qualifiers
ALTER TABLE matches
  ADD COLUMN IF NOT EXISTS round_number INTEGER,
  ADD COLUMN IF NOT EXISTS next_match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS home_seed INTEGER,
  ADD COLUMN IF NOT EXISTS away_seed INTEGER,
  ADD COLUMN IF NOT EXISTS home_qualifier TEXT,
  ADD COLUMN IF NOT EXISTS away_qualifier TEXT;

-- Indexes for bracket navigation
CREATE INDEX IF NOT EXISTS idx_matches_round_number ON matches(round_number);
CREATE INDEX IF NOT EXISTS idx_matches_next_match ON matches(next_match_id);

-- ==========================================================================
-- Refactor the fixture generator to produce proper knockout brackets and
-- group + knockout placeholders. This replaces the generate_tournament_fixtures
-- function with an updated implementation that fills round_number, next_match_id
-- and qualifier placeholders where needed.
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_tournament_fixtures(
    p_tournament_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_days_between_matchdays INTEGER DEFAULT 7
)
RETURNS JSONB AS $$
DECLARE
    v_rules JSONB;
    v_type TEXT;
    v_teams UUID[];
    v_team_count INTEGER;
    v_match_count INTEGER := 0;
    v_rounds INTEGER;
    v_num_rounds INTEGER;
    v_home_team UUID;
    v_away_team UUID;
    v_round INTEGER;
    v_match INTEGER;
    v_temp UUID;
    v_matchday DATE;
    v_group_count INTEGER;
    v_teams_per_group INTEGER;
    v_group_num INTEGER;
    v_group_teams UUID[];
    v_qualifiers INTEGER;
    v_total_qualifiers INTEGER;
    v_rounds_needed INTEGER;
    v_tmp INTEGER;
    v_inserted_id UUID;
    v_parent_id UUID;
    rec RECORD;
    rec_ko RECORD;

BEGIN
    -- Read rules and explicit tournament format override
    SELECT rules_json, format, group_count, qualifiers_per_group
    INTO v_rules, v_type, v_group_count, v_qualifiers
    FROM tournaments WHERE id = p_tournament_id;

    v_type := COALESCE(v_rules->>'type', v_type);
    v_type := COALESCE(v_type, 'league');
    v_num_rounds := COALESCE((v_rules->>'rounds')::INTEGER, 1);

    -- Get all teams for this tournament
    SELECT ARRAY_AGG(id ORDER BY created_at) INTO v_teams
    FROM teams WHERE tournament_id = p_tournament_id;
    v_team_count := COALESCE(array_length(v_teams, 1), 0);

    IF v_team_count < 2 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Need at least 2 teams');
    END IF;

    -- Delete existing fixtures for tournament
    DELETE FROM matches WHERE tournament_id = p_tournament_id;

    v_matchday := COALESCE(p_start_date, CURRENT_DATE);

    CASE v_type

        WHEN 'league' THEN
            -- Existing round-robin logic (unchanged, but uses round_number for clarity)
            IF v_team_count % 2 = 1 THEN
                RETURN jsonb_build_object('success', false, 'error', 'League format requires even number of teams');
            END IF;

            v_rounds := v_team_count - 1;

            FOR r IN 1..v_num_rounds LOOP
                FOR round IN 0..(v_rounds - 1) LOOP
                    FOR match IN 0..((v_team_count / 2) - 1) LOOP
                        IF match = 0 THEN
                            v_home_team := v_teams[1];
                            v_away_team := v_teams[v_team_count - round];
                        ELSE
                            v_home_team := v_teams[((round + match - 1) % (v_team_count - 1)) + 2];
                            v_away_team := v_teams[((round + v_team_count - match - 2) % (v_team_count - 1)) + 2];
                        END IF;

                        IF r = 2 THEN
                            v_temp := v_home_team;
                            v_home_team := v_away_team;
                            v_away_team := v_temp;
                        END IF;

                        INSERT INTO matches (
                            tournament_id, home_team_id, away_team_id,
                            matchday, kickoff_time, status, notes, round_number
                        ) VALUES (
                            p_tournament_id, v_home_team, v_away_team,
                            round + 1 + ((r - 1) * v_rounds),
                            v_matchday + (round * p_days_between_matchdays) + ((r - 1) * v_rounds * p_days_between_matchdays),
                            'scheduled', 'League Match', round + 1 + ((r - 1) * v_rounds)
                        ) RETURNING id INTO v_inserted_id;

                        v_match_count := v_match_count + 1;
                    END LOOP;
                END LOOP;
            END LOOP;

        WHEN 'knockout' THEN
            -- Pure knockout: require power of two for simplicity
            IF v_team_count NOT IN (2,4,8,16,32) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Knockout format requires 2,4,8,16 or 32 teams');
            END IF;

            -- Compute number of rounds (log2)
            v_rounds_needed := 0;
            v_tmp := v_team_count;
            WHILE v_tmp > 1 LOOP
                v_tmp := v_tmp / 2;
                v_rounds_needed := v_rounds_needed + 1;
            END LOOP;

            -- Temporary table to track inserted match ids and indices
            CREATE TEMP TABLE tmp_gen_matches(id UUID PRIMARY KEY, round_num INT, idx INT) ON COMMIT DROP;

            -- Round 1: insert actual pairings
            FOR match IN 1..(v_team_count / 2) LOOP
                INSERT INTO matches (tournament_id, home_team_id, away_team_id, kickoff_time, status, round_number)
                VALUES (
                    p_tournament_id,
                    v_teams[(match * 2) - 1],
                    v_teams[match * 2],
                    v_matchday,
                    'scheduled',
                    1
                ) RETURNING id INTO v_inserted_id;

                INSERT INTO tmp_gen_matches VALUES (v_inserted_id, 1, match);
                v_match_count := v_match_count + 1;
            END LOOP;

            -- Insert placeholder matches for subsequent rounds
            FOR r IN 2..v_rounds_needed LOOP
                FOR match IN 1..(v_team_count / (2 ^ r)) LOOP
                    INSERT INTO matches (tournament_id, kickoff_time, status, round_number)
                    VALUES (p_tournament_id, v_matchday + ((r - 1) * p_days_between_matchdays), 'scheduled', r)
                    RETURNING id INTO v_inserted_id;

                    INSERT INTO tmp_gen_matches VALUES (v_inserted_id, r, match);
                    v_match_count := v_match_count + 1;
                END LOOP;
            END LOOP;

            -- Link next_match_id relations
            FOR rec IN SELECT id, round_num, idx FROM tmp_gen_matches WHERE round_num < v_rounds_needed LOOP
                SELECT id INTO v_parent_id FROM tmp_gen_matches WHERE round_num = rec.round_num + 1 AND idx = ((rec.idx + 1) / 2);
                UPDATE matches SET next_match_id = v_parent_id WHERE id = rec.id;
            END LOOP;

        WHEN 'group_knockout' THEN
            -- Group stage + knockout
            -- Determine groups & qualifiers from rules or tournament columns
            v_group_count := COALESCE(v_group_count, (v_rules->>'group_count')::INTEGER);
            v_qualifiers := COALESCE(v_qualifiers, (v_rules->>'qualifiers_per_group')::INTEGER);

            IF v_group_count IS NULL OR v_qualifiers IS NULL THEN
                RETURN jsonb_build_object('success', false, 'error', 'Group count and qualifiers per group must be specified in tournament rules or columns');
            END IF;

            IF v_team_count < (v_group_count * 2) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Not enough teams for the requested number of groups');
            END IF;

            v_teams_per_group := v_team_count / v_group_count;
            IF v_teams_per_group * v_group_count <> v_team_count THEN
                RETURN jsonb_build_object('success', false, 'error', 'Teams must divide evenly into groups');
            END IF;

            -- Assign teams to groups (sequential assignment)
            FOR v_group_num IN 1..v_group_count LOOP
                v_group_teams := v_teams[((v_group_num - 1) * v_teams_per_group + 1):(v_group_num * v_teams_per_group)];

                -- Update teams with group_number
                UPDATE teams SET group_number = v_group_num WHERE id = ANY(v_group_teams);

                -- Generate round-robin within group
                FOR round IN 0..(v_teams_per_group - 2) LOOP
                    FOR match IN 0..((v_teams_per_group / 2) - 1) LOOP
                        IF match = 0 THEN
                            v_home_team := v_group_teams[1];
                            v_away_team := v_group_teams[v_teams_per_group - round];
                        ELSE
                            v_home_team := v_group_teams[((round + match - 1) % (v_teams_per_group - 1)) + 2];
                            v_away_team := v_group_teams[((round + v_teams_per_group - match - 2) % (v_teams_per_group - 1)) + 2];
                        END IF;

                        INSERT INTO matches (
                            tournament_id, home_team_id, away_team_id,
                            matchday, kickoff_time, status, notes, round_number
                        ) VALUES (
                            p_tournament_id, v_home_team, v_away_team,
                            round + 1,
                            v_matchday + (round * p_days_between_matchdays),
                            'scheduled', 'Group ' || chr(64 + v_group_num) || ' - Matchday ' || (round + 1),
                            round + 1
                        ) RETURNING id INTO v_inserted_id;

                        v_match_count := v_match_count + 1;
                    END LOOP;
                END LOOP;
            END LOOP;

            -- Knockout placeholders: create bracket for total qualifiers
            v_total_qualifiers := v_group_count * v_qualifiers;
            IF v_total_qualifiers NOT IN (2,4,8,16,32) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Total qualifiers must be 2,4,8,16 or 32');
            END IF;

            -- Compute rounds needed for knockout stage
            v_rounds_needed := 0;
            v_tmp := v_total_qualifiers;
            WHILE v_tmp > 1 LOOP
                v_tmp := v_tmp / 2;
                v_rounds_needed := v_rounds_needed + 1;
            END LOOP;

            -- Create temp table for knockout placeholders
            CREATE TEMP TABLE tmp_ko_matches(id UUID PRIMARY KEY, round_num INT, idx INT) ON COMMIT DROP;

            -- Create first round placeholders and set qualifiers (e.g., 'G1:1')
            FOR match IN 1..(v_total_qualifiers / 2) LOOP
                -- Compute group/position for home and away qualifiers in a simple seeded order
                -- Example pairing: (G1:1 vs G2:qualifiers), (G3:1 vs G4:qualifiers) etc. Simpler mapping used here.
                INSERT INTO matches (tournament_id, kickoff_time, status, round_number, home_qualifier, away_qualifier)
                VALUES (
                    p_tournament_id,
                    v_matchday + (v_rounds_needed * p_days_between_matchdays),
                    'scheduled',
                    100, -- placeholder round offset for knockout stage (100+ means playoff)
                    'QUAL',
                    'QUAL'
                ) RETURNING id INTO v_inserted_id;

                INSERT INTO tmp_ko_matches VALUES (v_inserted_id, 1, match);
                v_match_count := v_match_count + 1;
            END LOOP;

            -- Insert subsequent knockout rounds as placeholders
            FOR r IN 2..v_rounds_needed LOOP
                FOR match IN 1..(v_total_qualifiers / (2 ^ r)) LOOP
                    INSERT INTO matches (tournament_id, kickoff_time, status, round_number)
                    VALUES (p_tournament_id, v_matchday + ((v_rounds_needed + r - 1) * p_days_between_matchdays), 'scheduled', 100 + r)
                    RETURNING id INTO v_inserted_id;

                    INSERT INTO tmp_ko_matches VALUES (v_inserted_id, r, match);
                    v_match_count := v_match_count + 1;
                END LOOP;
            END LOOP;

            -- Link next_match_id relations for placeholders
            FOR rec IN SELECT id, round_num, idx FROM tmp_ko_matches WHERE round_num < v_rounds_needed LOOP
                SELECT id INTO v_parent_id FROM tmp_ko_matches WHERE round_num = rec.round_num + 1 AND idx = ((rec.idx + 1) / 2);
                UPDATE matches SET next_match_id = v_parent_id WHERE id = rec.id;
            END LOOP;

        ELSE
            RETURN jsonb_build_object('success', false, 'error', 'Unknown tournament type: ' || v_type);
    END CASE;

    RETURN jsonb_build_object(
        'success', true,
        'matches_created', v_match_count,
        'tournament_type', v_type,
        'team_count', v_team_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION generate_tournament_fixtures TO authenticated;

-- =========================================================================
-- DONE - added bracket/group support
-- =========================================================================
