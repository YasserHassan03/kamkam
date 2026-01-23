-- =====================================================================
-- KAM KAM - Ramadan Football Tournament Management System
-- Complete Database Setup Script
-- =====================================================================
-- This script creates all necessary tables, functions, triggers, and
-- Row Level Security (RLS) policies for your tournament management app.
--
-- Run this script in your Supabase SQL Editor to set up the database.
-- =====================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================================
-- TABLES
-- =====================================================================

-- User Profiles (with approval system)
-- First user to sign up automatically becomes admin
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL,
  display_name VARCHAR(255),
  role VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (role IN ('pending','organiser','admin','rejected')),
  rejection_reason TEXT,
  approved_by UUID REFERENCES auth.users(id),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_profiles_email ON user_profiles(email);
CREATE INDEX idx_user_profiles_role ON user_profiles(role);

-- Organisations
-- Top-level entity representing tournament organizers
CREATE TABLE organisations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_email VARCHAR(255) NOT NULL,
  description TEXT,
  logo_url TEXT,
  visibility VARCHAR(20) NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public','private','invite')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_organisations_owner_id ON organisations(owner_id);
CREATE INDEX idx_organisations_visibility ON organisations(visibility);

-- Tournaments
-- Top-level entity representing a competition event
CREATE TABLE tournaments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_email VARCHAR(255),
  name VARCHAR(255) NOT NULL,
  season_year INTEGER NOT NULL,
  start_date DATE,
  end_date DATE,
  status VARCHAR(20) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','active','completed','cancelled')),
  visibility VARCHAR(20) NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public','private','invite')),
  format VARCHAR(32) NOT NULL DEFAULT 'league'
    CHECK (format IN ('league','knockout','group_knockout')),
  group_count INTEGER,
  qualifiers_per_group INTEGER,
  -- Tournament rules stored as JSON
  rules_json JSONB NOT NULL DEFAULT '{
    "type": "league",
    "points_for_win": 3,
    "points_for_draw": 1,
    "points_for_loss": 0,
    "rounds": 1,
    "tiebreak_order": ["points","goal_difference","goals_for","head_to_head"]
  }'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tournaments_owner_id ON tournaments(owner_id);
CREATE INDEX idx_tournaments_visibility ON tournaments(visibility);
CREATE INDEX idx_tournaments_status ON tournaments(status);
CREATE INDEX idx_tournaments_format ON tournaments(format);

-- Teams
-- Participating teams in a tournament
CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  short_name VARCHAR(50),
  logo_url TEXT,
  primary_color VARCHAR(7), -- Hex color code
  secondary_color VARCHAR(7),
  group_number INTEGER, -- For group stage tournaments
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tournament_id, name)
);

CREATE INDEX idx_teams_tournament_id ON teams(tournament_id);

-- Players (optional roster feature)
CREATE TABLE players (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  jersey_number INTEGER,
  position VARCHAR(50), -- goalkeeper, defender, midfielder, forward
  is_captain BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_players_team_id ON players(team_id);

-- Matches
-- Individual fixtures/games between teams
CREATE TABLE matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  home_team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  away_team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  matchday INTEGER, -- Round number for league format
  kickoff_time TIMESTAMPTZ,
  venue VARCHAR(255),
  status VARCHAR(20) NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','in_progress','finished','postponed','cancelled')),
  home_goals INTEGER,
  away_goals INTEGER,
  -- For tracking result changes (enables proper standings updates)
  previous_home_goals INTEGER,
  previous_away_goals INTEGER,
  -- Bracket/Knockout specific fields
  round_number INTEGER,
  next_match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
  home_seed INTEGER,
  away_seed INTEGER,
  home_qualifier TEXT, -- e.g., "Group A Winner"
  away_qualifier TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (home_team_id != away_team_id)
);

CREATE INDEX idx_matches_tournament_id ON matches(tournament_id);
CREATE INDEX idx_matches_home_team_id ON matches(home_team_id);
CREATE INDEX idx_matches_away_team_id ON matches(away_team_id);
CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_matches_kickoff_time ON matches(kickoff_time);
CREATE INDEX idx_matches_round_number ON matches(round_number);
CREATE INDEX idx_matches_next_match ON matches(next_match_id);

-- Standings
-- Materialized league table for fast reads
-- Updated transactionally when match results are entered
CREATE TABLE standings (
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
  form VARCHAR(10), -- Last 5 results: "WWDLW"
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tournament_id, team_id)
);

CREATE INDEX idx_standings_tournament_id ON standings(tournament_id);
CREATE INDEX idx_standings_team_id ON standings(team_id);
CREATE INDEX idx_standings_points ON standings(tournament_id, points DESC, goal_difference DESC, goals_for DESC);

-- =====================================================================
-- HELPER FUNCTIONS (needed for RLS policies)
-- =====================================================================

-- Check if user is admin (SECURITY DEFINER bypasses RLS)
CREATE OR REPLACE FUNCTION is_admin(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = check_user_id AND role = 'admin'
  );
$$;

-- Get user role (SECURITY DEFINER bypasses RLS)
CREATE OR REPLACE FUNCTION get_user_role(check_user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE AS $$
  SELECT role FROM user_profiles WHERE id = check_user_id;
$$;

-- =====================================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE standings ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
CREATE POLICY "Users can view their own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON user_profiles FOR SELECT
  USING (is_admin(auth.uid()));

CREATE POLICY "Users can create their own profile"
  ON user_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Organisations Policies
CREATE POLICY "Public organisations are viewable by everyone"
  ON organisations FOR SELECT
  USING (visibility = 'public');

CREATE POLICY "Owners can view their own organisations"
  ON organisations FOR SELECT
  USING (auth.uid() = owner_id);

CREATE POLICY "Owners can create their own organisations"
  ON organisations FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners can update their own organisations"
  ON organisations FOR UPDATE
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners can delete their own organisations"
  ON organisations FOR DELETE
  USING (auth.uid() = owner_id);

-- Tournaments Policies
CREATE POLICY "Anyone can view public tournaments"
  ON tournaments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM organisations o
      WHERE o.id = tournaments.org_id
      AND (o.visibility = 'public' OR o.owner_id = auth.uid())
    )
  );

CREATE POLICY "Organisation owners can manage their tournaments"
  ON tournaments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM organisations o
      WHERE o.id = tournaments.org_id
      AND o.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organisations o
      WHERE o.id = tournaments.org_id
      AND o.owner_id = auth.uid()
    )
  );

-- Teams Policies
CREATE POLICY "Anyone can view teams in public tournaments"
  ON teams FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = teams.tournament_id
      AND (tournaments.visibility = 'public' OR tournaments.owner_id = auth.uid())
    )
  );

CREATE POLICY "Tournament owners can manage teams"
  ON teams FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = teams.tournament_id
      AND tournaments.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = teams.tournament_id
      AND tournaments.owner_id = auth.uid()
    )
  );

-- Players Policies
CREATE POLICY "Anyone can view players in public tournaments"
  ON players FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM teams
      JOIN tournaments ON tournaments.id = teams.tournament_id
      WHERE teams.id = players.team_id
      AND (tournaments.visibility = 'public' OR tournaments.owner_id = auth.uid())
    )
  );

CREATE POLICY "Tournament owners can manage players"
  ON players FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM teams
      JOIN tournaments ON tournaments.id = teams.tournament_id
      WHERE teams.id = players.team_id
      AND tournaments.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM teams
      JOIN tournaments ON tournaments.id = teams.tournament_id
      WHERE teams.id = players.team_id
      AND tournaments.owner_id = auth.uid()
    )
  );

-- Matches Policies
CREATE POLICY "Anyone can view matches in public tournaments"
  ON matches FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = matches.tournament_id
      AND (tournaments.visibility = 'public' OR tournaments.owner_id = auth.uid())
    )
  );

CREATE POLICY "Tournament owners can manage matches"
  ON matches FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = matches.tournament_id
      AND tournaments.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = matches.tournament_id
      AND tournaments.owner_id = auth.uid()
    )
  );

-- Standings Policies
CREATE POLICY "Anyone can view standings in public tournaments"
  ON standings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = standings.tournament_id
      AND (tournaments.visibility = 'public' OR tournaments.owner_id = auth.uid())
    )
  );

CREATE POLICY "Tournament owners can manage standings"
  ON standings FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = standings.tournament_id
      AND tournaments.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = standings.tournament_id
      AND tournaments.owner_id = auth.uid()
    )
  );

-- =====================================================================
-- TRIGGERS AND FUNCTIONS
-- =====================================================================

-- Generic updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
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

-- Initialize standings when team is added
CREATE OR REPLACE FUNCTION initialize_team_standings()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO standings (tournament_id, team_id)
  VALUES (NEW.tournament_id, NEW.id)
  ON CONFLICT (tournament_id, team_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER create_standings_on_team_insert
  AFTER INSERT ON teams
  FOR EACH ROW EXECUTE FUNCTION initialize_team_standings();

-- =====================================================================
-- MATCH RESULT UPDATE FUNCTION
-- Transactionally updates match result and standings
-- =====================================================================

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

  -- If match was previously finished, reverse the old result first
  IF v_old_status = 'finished' AND v_old_home_goals IS NOT NULL AND v_old_away_goals IS NOT NULL THEN
    -- Determine previous winner
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

  -- Determine winner and propagate to next match (knockout tournaments)
  IF p_home_goals > p_away_goals THEN
    v_winner := v_home_team_id;
  ELSIF p_home_goals < p_away_goals THEN
    v_winner := v_away_team_id;
  ELSE
    v_winner := NULL;
  END IF;

  -- Propagate winner to next round
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
$$ LANGUAGE plpgsql;

-- =====================================================================
-- FIXTURE GENERATION FUNCTIONS
-- =====================================================================

-- Generate round-robin fixtures (League format)
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

  IF v_team_count % 2 = 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'League format requires even number of teams');
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

-- =====================================================================
-- USER MANAGEMENT FUNCTIONS
-- =====================================================================

-- Handle new user creation (FIRST USER = ADMIN)
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_count INT;
  new_role VARCHAR(20);
BEGIN
  -- Check if profile already exists
  IF EXISTS (SELECT 1 FROM public.user_profiles WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  -- Count existing profiles
  SELECT COUNT(*) INTO user_count FROM public.user_profiles;

  -- FIRST USER BECOMES ADMIN, ALL OTHERS ARE PENDING
  IF user_count = 0 THEN
    new_role := 'admin';
  ELSE
    new_role := 'pending';
  END IF;

  -- Insert profile
  INSERT INTO public.user_profiles (id, email, display_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    new_role
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to create user profile for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Approve user
CREATE OR REPLACE FUNCTION approve_user(
  p_user_id UUID,
  p_role VARCHAR(20) DEFAULT 'organiser'
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = v_admin_id AND role = 'admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only admins can approve users');
  END IF;

  UPDATE user_profiles SET
    role = p_role,
    approved_by = v_admin_id,
    approved_at = NOW(),
    rejection_reason = NULL
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'role', p_role);
END;
$$ LANGUAGE plpgsql;

-- Reject user
CREATE OR REPLACE FUNCTION reject_user(
  p_user_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = v_admin_id AND role = 'admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only admins can reject users');
  END IF;

  UPDATE user_profiles SET
    role = 'rejected',
    rejection_reason = p_reason,
    approved_by = v_admin_id,
    approved_at = NOW()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id);
END;
$$ LANGUAGE plpgsql;

-- Get my approval status
CREATE OR REPLACE FUNCTION get_my_approval_status()
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile RECORD;
BEGIN
  SELECT role, rejection_reason, approved_at
  INTO v_profile
  FROM user_profiles
  WHERE id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('role', 'none', 'exists', false);
  END IF;

  RETURN jsonb_build_object(
    'role', v_profile.role,
    'rejection_reason', v_profile.rejection_reason,
    'approved_at', v_profile.approved_at,
    'exists', true
  );
END;
$$ LANGUAGE plpgsql;

-- Get pending users (admin only)
CREATE OR REPLACE FUNCTION get_pending_users()
RETURNS TABLE (
  id UUID,
  email VARCHAR,
  display_name VARCHAR,
  role VARCHAR,
  created_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can view pending users';
  END IF;

  RETURN QUERY
  SELECT up.id, up.email, up.display_name, up.role, up.created_at
  FROM user_profiles up
  WHERE up.role = 'pending'
  ORDER BY up.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Get all users (admin only)
CREATE OR REPLACE FUNCTION get_all_users()
RETURNS TABLE (
  id UUID,
  email VARCHAR,
  display_name VARCHAR,
  role VARCHAR,
  created_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can view all users';
  END IF;

  RETURN QUERY
  SELECT up.id, up.email, up.display_name, up.role, up.created_at, up.approved_at
  FROM user_profiles up
  ORDER BY up.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- GRANT PERMISSIONS
-- =====================================================================

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON organisations TO authenticated;
GRANT ALL ON tournaments TO authenticated;
GRANT ALL ON teams TO authenticated;
GRANT ALL ON players TO authenticated;
GRANT ALL ON matches TO authenticated;
GRANT ALL ON standings TO authenticated;

GRANT EXECUTE ON FUNCTION update_match_result(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_round_robin_fixtures(UUID, DATE, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_user(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_user(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_approval_status() TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_users() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_users() TO authenticated;

-- =====================================================================
-- SETUP COMPLETE
-- =====================================================================
-- Your database is now ready for the Kam Kam tournament management app!
--
-- Key Features:
-- - User approval system (first user automatically becomes admin)
-- - Tournament management with league, knockout, and group+knockout formats
-- - Team and player management
-- - Match fixtures and results
-- - Automatic standings calculation
-- - Row Level Security for data protection
--
-- Next Steps:
-- 1. Sign up your first user (will automatically become admin)
-- 2. Create a tournament
-- 3. Add teams
-- 4. Generate fixtures
-- 5. Enter match results
-- =====================================================================
