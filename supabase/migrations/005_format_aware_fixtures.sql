-- ============================================================================
-- Format-Aware Fixture Generation
-- ============================================================================
-- Generate fixtures based on tournament type (league, knockout, group_knockout)
-- ============================================================================

-- Create a unified fixture generation function that respects tournament format
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
BEGIN
    -- Get tournament rules and type
    SELECT rules_json INTO v_rules FROM tournaments WHERE id = p_tournament_id;
    v_type := COALESCE(v_rules->>'type', 'league');
    v_num_rounds := COALESCE((v_rules->>'rounds')::INTEGER, 1);
    
    -- Get all teams for this tournament
    SELECT ARRAY_AGG(id ORDER BY created_at) INTO v_teams
    FROM teams WHERE tournament_id = p_tournament_id;
    
    v_team_count := array_length(v_teams, 1);
    
    IF v_team_count IS NULL OR v_team_count < 2 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Need at least 2 teams');
    END IF;
    
    -- Delete existing fixtures
    DELETE FROM matches WHERE tournament_id = p_tournament_id;
    
    v_matchday := COALESCE(p_start_date, CURRENT_DATE);
    
    -- Handle different tournament types
    CASE v_type
        WHEN 'league' THEN
            -- Standard round-robin (same as before)
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
                            matchday, kickoff_time, status, notes
                        ) VALUES (
                            p_tournament_id, v_home_team, v_away_team,
                            round + 1 + ((r - 1) * v_rounds),
                            v_matchday + (round * p_days_between_matchdays) + ((r - 1) * v_rounds * p_days_between_matchdays),
                            'scheduled',
                            'League Match'
                        );
                        
                        v_match_count := v_match_count + 1;
                    END LOOP;
                END LOOP;
            END LOOP;
            
        WHEN 'knockout' THEN
            -- Single elimination bracket
            -- Number of teams must be power of 2 (2, 4, 8, 16, etc.)
            IF v_team_count NOT IN (2, 4, 8, 16, 32) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Knockout format requires 2, 4, 8, 16, or 32 teams');
            END IF;
            
            -- Generate first round matches
            FOR match IN 1..(v_team_count / 2) LOOP
                INSERT INTO matches (
                    tournament_id, home_team_id, away_team_id, 
                    matchday, kickoff_time, status, notes
                ) VALUES (
                    p_tournament_id, 
                    v_teams[(match * 2) - 1], 
                    v_teams[match * 2],
                    1,
                    v_matchday,
                    'scheduled',
                    'Round 1 - Match ' || match
                );
                v_match_count := v_match_count + 1;
            END LOOP;
            
            -- Note: Subsequent rounds will be generated after results are entered
            -- For now, just create placeholder text
            
        WHEN 'group_knockout' THEN
            -- Group stage + knockout
            -- Split teams into groups (default: 2 groups)
            IF v_team_count < 4 THEN
                RETURN jsonb_build_object('success', false, 'error', 'Group + Knockout requires at least 4 teams');
            END IF;
            
            -- Determine number of groups (2 or 4 groups depending on team count)
            IF v_team_count >= 8 THEN
                v_group_count := 4;
            ELSE
                v_group_count := 2;
            END IF;
            
            v_teams_per_group := v_team_count / v_group_count;
            
            -- Generate group stage matches
            FOR v_group_num IN 1..v_group_count LOOP
                -- Get teams for this group
                v_group_teams := v_teams[((v_group_num - 1) * v_teams_per_group + 1):(v_group_num * v_teams_per_group)];
                
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
                            matchday, kickoff_time, status, notes
                        ) VALUES (
                            p_tournament_id, v_home_team, v_away_team,
                            round + 1,
                            v_matchday + (round * p_days_between_matchdays),
                            'scheduled',
                            'Group ' || chr(64 + v_group_num) || ' - Matchday ' || (round + 1)
                        );
                        
                        v_match_count := v_match_count + 1;
                    END LOOP;
                END LOOP;
            END LOOP;
            
            -- Knockout stage matches will be generated after group stage completes
            
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_tournament_fixtures TO authenticated;

-- ============================================================================
-- DONE! Fixture generation now respects tournament format
-- ============================================================================
