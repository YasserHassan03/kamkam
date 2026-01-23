-- ============================================================================
-- KAM KAM - Ramadan Football Tournament Management System
-- Supabase/PostgreSQL Database Schema
-- ============================================================================
-- This migration creates the complete database schema for the tournament
-- management system including tables, indexes, RLS policies, and functions.
-- ============================================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TABLES
-- ============================================================================

-- Organisations: Top-level entity representing tournament organisers
CREATE TABLE IF NOT EXISTS organisations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_email VARCHAR(255) NOT NULL,
    description TEXT,
    logo_url TEXT,
    visibility VARCHAR(20) NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'private', 'invite')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tournaments: Competition events under an organisation
CREATE TABLE IF NOT EXISTS tournaments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    season_year INTEGER NOT NULL,
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'completed', 'cancelled')),
    -- Rules JSON structure:
    -- {
    --   "type": "league" | "knockout" | "group_knockout",
    --   "points_for_win": 3,
    --   "points_for_draw": 1,
    --   "points_for_loss": 0,
    --   "rounds": 1 | 2,  -- single or double round-robin
    --   "tiebreak_order": ["points", "goal_difference", "goals_for", "head_to_head"],
    --   "match_duration_minutes": 90,
    --   "extra_time_allowed": false
    -- }
    rules_json JSONB NOT NULL DEFAULT '{
        "type": "league",
        "points_for_win": 3,
        "points_for_draw": 1,
        "points_for_loss": 0,
        "rounds": 1,
        "tiebreak_order": ["points", "goal_difference", "goals_for", "head_to_head"]
    }'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Teams: Participating teams in a tournament
CREATE TABLE IF NOT EXISTS teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    short_name VARCHAR(10),
    logo_url TEXT,
    primary_color VARCHAR(7), -- Hex color code
    secondary_color VARCHAR(7),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(tournament_id, name)
);

-- Players: Optional player roster for teams
CREATE TABLE IF NOT EXISTS players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    jersey_number INTEGER,
    position VARCHAR(50),
    is_captain BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Matches: Individual fixtures/games
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    home_team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    away_team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    matchday INTEGER, -- Round number for league format
    kickoff_time TIMESTAMP WITH TIME ZONE,
    venue VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'finished', 'postponed', 'cancelled')),
    home_goals INTEGER,
    away_goals INTEGER,
    -- For tracking result changes and proper standings updates
    previous_home_goals INTEGER,
    previous_away_goals INTEGER,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT different_teams CHECK (home_team_id != away_team_id)
);

-- Standings: Materialized league table for fast reads
-- Updated transactionally when match results are entered
CREATE TABLE IF NOT EXISTS standings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    played INTEGER NOT NULL DEFAULT 0,
    won INTEGER NOT NULL DEFAULT 0,
    drawn INTEGER NOT NULL DEFAULT 0,
    lost INTEGER NOT NULL DEFAULT 0,
    goals_for INTEGER NOT NULL DEFAULT 0,
    goals_against INTEGER NOT NULL DEFAULT 0,
    goal_difference INTEGER GENERATED ALWAYS AS (goals_for - goals_against) STORED,
    points INTEGER NOT NULL DEFAULT 0,
    form VARCHAR(10), -- Last 5 results: W/D/L e.g., "WWDLW"
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(tournament_id, team_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Organisations
CREATE INDEX IF NOT EXISTS idx_organisations_owner ON organisations(owner_id);
CREATE INDEX IF NOT EXISTS idx_organisations_visibility ON organisations(visibility);

-- Tournaments
CREATE INDEX IF NOT EXISTS idx_tournaments_org ON tournaments(org_id);
CREATE INDEX IF NOT EXISTS idx_tournaments_status ON tournaments(status);
CREATE INDEX IF NOT EXISTS idx_tournaments_season ON tournaments(season_year);

-- Teams
CREATE INDEX IF NOT EXISTS idx_teams_tournament ON teams(tournament_id);

-- Players
CREATE INDEX IF NOT EXISTS idx_players_team ON players(team_id);

-- Matches
CREATE INDEX IF NOT EXISTS idx_matches_tournament ON matches(tournament_id);
CREATE INDEX IF NOT EXISTS idx_matches_home_team ON matches(home_team_id);
CREATE INDEX IF NOT EXISTS idx_matches_away_team ON matches(away_team_id);
CREATE INDEX IF NOT EXISTS idx_matches_status ON matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_kickoff ON matches(kickoff_time);

-- Standings
CREATE INDEX IF NOT EXISTS idx_standings_tournament ON standings(tournament_id);
CREATE INDEX IF NOT EXISTS idx_standings_team ON standings(team_id);
CREATE INDEX IF NOT EXISTS idx_standings_points ON standings(tournament_id, points DESC, goal_difference DESC, goals_for DESC);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE standings ENABLE ROW LEVEL SECURITY;

-- Organisations policies
CREATE POLICY "Public organisations are viewable by everyone" ON organisations
    FOR SELECT USING (visibility = 'public');

CREATE POLICY "Owners can view their own organisations" ON organisations
    FOR SELECT USING (auth.uid() = owner_id);

CREATE POLICY "Owners can insert their own organisations" ON organisations
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners can update their own organisations" ON organisations
    FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Owners can delete their own organisations" ON organisations
    FOR DELETE USING (auth.uid() = owner_id);

-- Tournaments policies
CREATE POLICY "Public tournaments are viewable by everyone" ON tournaments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM organisations o 
            WHERE o.id = tournaments.org_id 
            AND o.visibility = 'public'
        )
    );

CREATE POLICY "Owners can view their tournament" ON tournaments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM organisations o 
            WHERE o.id = tournaments.org_id 
            AND o.owner_id = auth.uid()
        )
    );

CREATE POLICY "Owners can manage their tournaments" ON tournaments
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM organisations o 
            WHERE o.id = tournaments.org_id 
            AND o.owner_id = auth.uid()
        )
    );

-- Teams policies (similar pattern)
CREATE POLICY "Public teams are viewable by everyone" ON teams
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM tournaments t
            JOIN organisations o ON o.id = t.org_id
            WHERE t.id = teams.tournament_id
            AND o.visibility = 'public'
        )
    );

CREATE POLICY "Owners can manage their teams" ON teams
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM tournaments t
            JOIN organisations o ON o.id = t.org_id
            WHERE t.id = teams.tournament_id
            AND o.owner_id = auth.uid()
        )
    );

-- Players policies
CREATE POLICY "Public players are viewable by everyone" ON players
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM teams tm
            JOIN tournaments t ON t.id = tm.tournament_id
            JOIN organisations o ON o.id = t.org_id
            WHERE tm.id = players.team_id
            AND o.visibility = 'public'
        )
    );

CREATE POLICY "Owners can manage their players" ON players
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM teams tm
            JOIN tournaments t ON t.id = tm.tournament_id
            JOIN organisations o ON o.id = t.org_id
            WHERE tm.id = players.team_id
            AND o.owner_id = auth.uid()
        )
    );

-- Matches policies
CREATE POLICY "Public matches are viewable by everyone" ON matches
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM tournaments t
            JOIN organisations o ON o.id = t.org_id
            WHERE t.id = matches.tournament_id
            AND o.visibility = 'public'
        )
    );

CREATE POLICY "Owners can manage their matches" ON matches
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM tournaments t
            JOIN organisations o ON o.id = t.org_id
            WHERE t.id = matches.tournament_id
            AND o.owner_id = auth.uid()
        )
    );

-- Standings policies
CREATE POLICY "Public standings are viewable by everyone" ON standings
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM tournaments t
            JOIN organisations o ON o.id = t.org_id
            WHERE t.id = standings.tournament_id
            AND o.visibility = 'public'
        )
    );

CREATE POLICY "Owners can manage their standings" ON standings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM tournaments t
            JOIN organisations o ON o.id = t.org_id
            WHERE t.id = standings.tournament_id
            AND o.owner_id = auth.uid()
        )
    );

-- ============================================================================
-- FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update timestamps automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply timestamp triggers to all tables
CREATE TRIGGER update_organisations_updated_at
    BEFORE UPDATE ON organisations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tournaments_updated_at
    BEFORE UPDATE ON tournaments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_teams_updated_at
    BEFORE UPDATE ON teams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_players_updated_at
    BEFORE UPDATE ON players
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_matches_updated_at
    BEFORE UPDATE ON matches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_standings_updated_at
    BEFORE UPDATE ON standings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STANDINGS UPDATE RPC FUNCTION
-- This function handles match result entry/update with transactional standings update
-- ============================================================================

CREATE OR REPLACE FUNCTION update_match_result(
    p_match_id UUID,
    p_home_goals INTEGER,
    p_away_goals INTEGER
)
RETURNS JSONB AS $$
DECLARE
    v_match RECORD;
    v_tournament_id UUID;
    v_home_team_id UUID;
    v_away_team_id UUID;
    v_old_home_goals INTEGER;
    v_old_away_goals INTEGER;
    v_old_status VARCHAR(20);
    v_rules JSONB;
    v_points_win INTEGER;
    v_points_draw INTEGER;
    v_points_loss INTEGER;
    v_prev_winner UUID;
    v_winner UUID;
    v_next_match_id UUID;
    v_next_home UUID;
    v_next_away UUID;
BEGIN
    -- Get the match details
    SELECT * INTO v_match FROM matches WHERE id = p_match_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;
    
    v_tournament_id := v_match.tournament_id;
    v_home_team_id := v_match.home_team_id;
    v_away_team_id := v_match.away_team_id;
    v_old_home_goals := v_match.home_goals;
    v_old_away_goals := v_match.away_goals;
    v_old_status := v_match.status;
    v_next_match_id := v_match.next_match_id;

    -- Get tournament rules for points
    SELECT rules_json INTO v_rules FROM tournaments WHERE id = v_tournament_id;
    v_points_win := COALESCE((v_rules->>'points_for_win')::INTEGER, 3);
    v_points_draw := COALESCE((v_rules->>'points_for_draw')::INTEGER, 1);
    v_points_loss := COALESCE((v_rules->>'points_for_loss')::INTEGER, 0);
    
    -- If match was previously finished, reverse the old result first and undo propagation
    IF v_old_status = 'finished' AND v_old_home_goals IS NOT NULL AND v_old_away_goals IS NOT NULL THEN
        -- Determine previous winner (if any)
        IF v_old_home_goals > v_old_away_goals THEN
            v_prev_winner := v_home_team_id;
        ELSIF v_old_home_goals < v_old_away_goals THEN
            v_prev_winner := v_away_team_id;
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
            points = points - CASE 
                WHEN v_old_home_goals > v_old_away_goals THEN v_points_win
                WHEN v_old_home_goals = v_old_away_goals THEN v_points_draw
                ELSE v_points_loss
            END
        WHERE tournament_id = v_tournament_id AND team_id = v_home_team_id;
        
        -- Reverse away team stats
        UPDATE standings SET
            played = played - 1,
            won = won - CASE WHEN v_old_away_goals > v_old_home_goals THEN 1 ELSE 0 END,
            drawn = drawn - CASE WHEN v_old_away_goals = v_old_home_goals THEN 1 ELSE 0 END,
            lost = lost - CASE WHEN v_old_away_goals < v_old_home_goals THEN 1 ELSE 0 END,
            goals_for = goals_for - v_old_away_goals,
            goals_against = goals_against - v_old_home_goals,
            points = points - CASE 
                WHEN v_old_away_goals > v_old_home_goals THEN v_points_win
                WHEN v_old_away_goals = v_old_home_goals THEN v_points_draw
                ELSE v_points_loss
            END
        WHERE tournament_id = v_tournament_id AND team_id = v_away_team_id;

        -- Undo propagation to next match if previous winner advanced
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
    UPDATE matches SET
        home_goals = p_home_goals,
        away_goals = p_away_goals,
        previous_home_goals = v_old_home_goals,
        previous_away_goals = v_old_away_goals,
        status = 'finished'
    WHERE id = p_match_id;
    
    -- Apply new result to home team standings
    UPDATE standings SET
        played = played + 1,
        won = won + CASE WHEN p_home_goals > p_away_goals THEN 1 ELSE 0 END,
        drawn = drawn + CASE WHEN p_home_goals = p_away_goals THEN 1 ELSE 0 END,
        lost = lost + CASE WHEN p_home_goals < p_away_goals THEN 1 ELSE 0 END,
        goals_for = goals_for + p_home_goals,
        goals_against = goals_against + p_away_goals,
        points = points + CASE 
            WHEN p_home_goals > p_away_goals THEN v_points_win
            WHEN p_home_goals = p_away_goals THEN v_points_draw
            ELSE v_points_loss
        END
    WHERE tournament_id = v_tournament_id AND team_id = v_home_team_id;
    
    -- Apply new result to away team standings
    UPDATE standings SET
        played = played + 1,
        won = won + CASE WHEN p_away_goals > p_home_goals THEN 1 ELSE 0 END,
        drawn = drawn + CASE WHEN p_away_goals = p_home_goals THEN 1 ELSE 0 END,
        lost = lost + CASE WHEN p_away_goals < p_home_goals THEN 1 ELSE 0 END,
        goals_for = goals_for + p_away_goals,
        goals_against = goals_against + p_home_goals,
        points = points + CASE 
            WHEN p_away_goals > p_home_goals THEN v_points_win
            WHEN p_away_goals = p_home_goals THEN v_points_draw
            ELSE v_points_loss
        END
    WHERE tournament_id = v_tournament_id AND team_id = v_away_team_id;

    -- Determine winner and propagate to next match if applicable
    IF p_home_goals > p_away_goals THEN
        v_winner := v_home_team_id;
    ELSIF p_home_goals < p_away_goals THEN
        v_winner := v_away_team_id;
    ELSE
        v_winner := NULL; -- Draws have no automatic propagation for knockout
    END IF;

    IF v_winner IS NOT NULL AND v_next_match_id IS NOT NULL THEN
        SELECT home_team_id, away_team_id INTO v_next_home, v_next_away FROM matches WHERE id = v_next_match_id;
        IF v_next_home IS NULL THEN
            UPDATE matches SET home_team_id = v_winner WHERE id = v_next_match_id;
        ELSIF v_next_away IS NULL THEN
            UPDATE matches SET away_team_id = v_winner WHERE id = v_next_match_id;
        END IF;
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'match_id', p_match_id,
        'home_goals', p_home_goals,
        'away_goals', p_away_goals
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to initialize standings when a team is added
CREATE OR REPLACE FUNCTION initialize_team_standings()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO standings (tournament_id, team_id)
    VALUES (NEW.tournament_id, NEW.id)
    ON CONFLICT (tournament_id, team_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_standings_on_team_insert
    AFTER INSERT ON teams
    FOR EACH ROW EXECUTE FUNCTION initialize_team_standings();

-- Function to generate round-robin fixtures
CREATE OR REPLACE FUNCTION generate_round_robin_fixtures(
    p_tournament_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_days_between_matchdays INTEGER DEFAULT 7
)
RETURNS JSONB AS $$
DECLARE
    v_teams UUID[];
    v_team_count INTEGER;
    v_rounds INTEGER;
    v_match_count INTEGER := 0;
    v_home_team UUID;
    v_away_team UUID;
    v_round INTEGER;
    v_match INTEGER;
    v_temp UUID;
    v_matchday DATE;
    v_rules JSONB;
    v_num_rounds INTEGER;
BEGIN
    -- Get tournament rules
    SELECT rules_json INTO v_rules FROM tournaments WHERE id = p_tournament_id;
    v_num_rounds := COALESCE((v_rules->>'rounds')::INTEGER, 1);
    
    -- Get all teams for this tournament
    SELECT ARRAY_AGG(id ORDER BY created_at) INTO v_teams
    FROM teams WHERE tournament_id = p_tournament_id;
    
    v_team_count := array_length(v_teams, 1);
    
    IF v_team_count IS NULL OR v_team_count < 2 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Need at least 2 teams');
    END IF;
    
    -- If odd number of teams, add a "bye" (NULL won't work, so we handle it differently)
    -- For simplicity, we require even number of teams
    IF v_team_count % 2 = 1 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Odd number of teams not supported yet');
    END IF;
    
    -- Delete existing fixtures
    DELETE FROM matches WHERE tournament_id = p_tournament_id;
    
    v_rounds := v_team_count - 1;
    v_matchday := COALESCE(p_start_date, CURRENT_DATE);
    
    -- Generate fixtures using round-robin algorithm
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
                
                -- Alternate home/away for second round
                IF r = 2 THEN
                    v_temp := v_home_team;
                    v_home_team := v_away_team;
                    v_away_team := v_temp;
                END IF;
                
                INSERT INTO matches (
                    tournament_id, home_team_id, away_team_id, 
                    matchday, kickoff_time, status
                ) VALUES (
                    p_tournament_id, v_home_team, v_away_team,
                    round + 1 + ((r - 1) * v_rounds),
                    v_matchday + (round * p_days_between_matchdays) + ((r - 1) * v_rounds * p_days_between_matchdays),
                    'scheduled'
                );
                
                v_match_count := v_match_count + 1;
            END LOOP;
        END LOOP;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true, 
        'matches_created', v_match_count,
        'rounds', v_num_rounds,
        'matchdays', v_rounds * v_num_rounds
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on RPC functions
GRANT EXECUTE ON FUNCTION update_match_result TO authenticated;
GRANT EXECUTE ON FUNCTION generate_round_robin_fixtures TO authenticated;
