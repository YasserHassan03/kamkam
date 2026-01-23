-- =====================================================================
-- COMPLETE DATABASE RESET
-- =====================================================================
-- This script will DELETE EVERYTHING and recreate the database from scratch
-- Run this in Supabase SQL Editor after logging out
-- =====================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================================
-- STEP 1: DROP ALL TRIGGERS (excluding system triggers)
-- =====================================================================
-- Drop specific app triggers explicitly (with error handling for missing tables)
DO $$
BEGIN
  -- Drop triggers on tables that might not exist yet
  DROP TRIGGER IF EXISTS update_organisations_updated_at ON organisations CASCADE;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_tournaments_updated_at ON tournaments CASCADE;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_teams_updated_at ON teams CASCADE;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_players_updated_at ON players CASCADE;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_matches_updated_at ON matches CASCADE;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_standings_updated_at ON standings CASCADE;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS create_standings_on_team_insert ON teams CASCADE;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- This one is on auth.users which always exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;

-- Drop any other custom triggers (excluding system triggers like RI_ConstraintTrigger_*)
-- Only try to drop triggers if the tables exist
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT tgname, tgrelid::regclass as table_name
    FROM pg_trigger
    WHERE tgname NOT LIKE 'pg_%'
      AND tgname NOT LIKE 'RI_ConstraintTrigger_%'
      AND tgname NOT LIKE 'RI_KeyTrigger_%'
      AND tgisinternal = false
      AND EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = tgrelid::regclass::text
      )
      AND (tgrelid::regclass::text LIKE '%user_profiles%' 
           OR tgrelid::regclass::text LIKE '%organisations%'
           OR tgrelid::regclass::text LIKE '%tournaments%'
           OR tgrelid::regclass::text LIKE '%groups%'
           OR tgrelid::regclass::text LIKE '%teams%'
           OR tgrelid::regclass::text LIKE '%players%'
           OR tgrelid::regclass::text LIKE '%matches%'
           OR tgrelid::regclass::text LIKE '%standings%')
  ) LOOP
    BEGIN
      EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s CASCADE', r.tgname, r.table_name);
    EXCEPTION
      WHEN OTHERS THEN
        -- Ignore errors
        NULL;
    END;
  END LOOP;
END;
$$;

-- =====================================================================
-- STEP 2: DROP ALL FUNCTIONS
-- =====================================================================
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS initialize_team_standings() CASCADE;
DROP FUNCTION IF EXISTS update_match_result(UUID, INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS generate_round_robin_fixtures(UUID, DATE, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS generate_knockout_fixtures(UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS generate_tournament_fixtures(UUID, DATE, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS approve_user(UUID, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS reject_user(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_my_approval_status() CASCADE;
DROP FUNCTION IF EXISTS get_pending_users() CASCADE;
DROP FUNCTION IF EXISTS get_all_users() CASCADE;
DROP FUNCTION IF EXISTS is_admin(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_user_role(UUID) CASCADE;
DROP FUNCTION IF EXISTS create_profile_for_current_user() CASCADE;
DROP FUNCTION IF EXISTS create_profile_for_user_by_email(TEXT) CASCADE;

-- =====================================================================
-- STEP 3: DROP ALL TABLES (in correct order due to foreign keys)
-- =====================================================================
DROP TABLE IF EXISTS standings CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS players CASCADE;
DROP TABLE IF EXISTS teams CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP TABLE IF EXISTS tournaments CASCADE;
DROP TABLE IF EXISTS organisations CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- =====================================================================
-- STEP 4: RECREATE TABLES
-- =====================================================================

-- User Profiles
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

CREATE INDEX idx_tournaments_org_id ON tournaments(org_id);
CREATE INDEX idx_tournaments_owner_id ON tournaments(owner_id);
CREATE INDEX idx_tournaments_visibility ON tournaments(visibility);
CREATE INDEX idx_tournaments_status ON tournaments(status);
CREATE INDEX idx_tournaments_format ON tournaments(format);

-- Groups (for group stage tournaments)
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL, -- e.g., "Group A", "Group B"
  group_number INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tournament_id, name),
  UNIQUE(tournament_id, group_number)
);

CREATE INDEX idx_groups_tournament_id ON groups(tournament_id);

-- Teams
CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
  name VARCHAR(255) NOT NULL,
  short_name VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tournament_id, name)
);

CREATE INDEX idx_teams_tournament_id ON teams(tournament_id);
CREATE INDEX idx_teams_group_id ON teams(group_id);

-- Players (optional)
CREATE TABLE players (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  contact_info JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_players_team_id ON players(team_id);

-- Matches
CREATE TABLE matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  group_id UUID REFERENCES groups(id) ON DELETE SET NULL, -- For group stage matches
  round_number INTEGER, -- For knockout rounds (1=final, 2=semi, etc.)
  phase VARCHAR(20) NOT NULL DEFAULT 'group'
    CHECK (phase IN ('group','knockout')),
  home_team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  away_team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  matchday INTEGER, -- Round number for league format
  kickoff_time TIMESTAMPTZ,
  venue VARCHAR(255),
  status VARCHAR(20) NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','in_progress','finished','cancelled','postponed')),
  home_goals INTEGER,
  away_goals INTEGER,
  next_match_id UUID REFERENCES matches(id) ON DELETE SET NULL, -- For knockout progression
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (home_team_id IS NULL OR away_team_id IS NULL OR home_team_id != away_team_id)
);

CREATE INDEX idx_matches_tournament_id ON matches(tournament_id);
CREATE INDEX idx_matches_group_id ON matches(group_id);
CREATE INDEX idx_matches_phase ON matches(phase);
CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_matches_home_team_id ON matches(home_team_id);
CREATE INDEX idx_matches_away_team_id ON matches(away_team_id);
CREATE INDEX idx_matches_kickoff_time ON matches(kickoff_time);
CREATE INDEX idx_matches_round_number ON matches(round_number);
CREATE INDEX idx_matches_next_match ON matches(next_match_id);
CREATE INDEX idx_matches_matchday ON matches(matchday);

-- Standings (materialized for league/group stages)
CREATE TABLE standings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  group_id UUID, -- NULL for pure league, set for group stages
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  played INTEGER NOT NULL DEFAULT 0,
  won INTEGER NOT NULL DEFAULT 0,
  drawn INTEGER NOT NULL DEFAULT 0,
  lost INTEGER NOT NULL DEFAULT 0,
  goals_for INTEGER NOT NULL DEFAULT 0,
  goals_against INTEGER NOT NULL DEFAULT 0,
  goal_difference INTEGER NOT NULL DEFAULT 0,
  points INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_standings_unique ON standings(tournament_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::UUID), team_id);
CREATE INDEX idx_standings_tournament_id ON standings(tournament_id);
CREATE INDEX idx_standings_group_id ON standings(group_id);
CREATE INDEX idx_standings_team_id ON standings(team_id);
CREATE INDEX idx_standings_points ON standings(tournament_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::UUID), points DESC);

-- =====================================================================
-- STEP 5: HELPER FUNCTIONS (needed for RLS policies)
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
-- STEP 6: ROW LEVEL SECURITY (RLS)
-- =====================================================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
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
    visibility = 'public' 
    OR owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM organisations o
      WHERE o.id = tournaments.org_id
      AND (o.visibility = 'public' OR o.owner_id = auth.uid())
    )
  );

CREATE POLICY "Owners can manage their tournaments"
  ON tournaments FOR ALL
  USING (
    owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM organisations o
      WHERE o.id = tournaments.org_id
      AND o.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM organisations o
      WHERE o.id = tournaments.org_id
      AND o.owner_id = auth.uid()
    )
  );

-- Groups Policies
CREATE POLICY "Anyone can view groups in public tournaments"
  ON groups FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = groups.tournament_id
      AND (tournaments.visibility = 'public' OR tournaments.owner_id = auth.uid())
    )
  );

CREATE POLICY "Tournament owners can manage groups"
  ON groups FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = groups.tournament_id
      AND tournaments.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM tournaments
      WHERE tournaments.id = groups.tournament_id
      AND tournaments.owner_id = auth.uid()
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
-- STEP 7: TRIGGERS AND FUNCTIONS
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
DECLARE
  v_tournament_format VARCHAR;
  v_group_id UUID;
BEGIN
  SELECT format INTO v_tournament_format
  FROM tournaments
  WHERE id = NEW.tournament_id;

  -- Only create standings for league or group_knockout formats
  IF v_tournament_format IN ('league', 'group_knockout') THEN
    -- Use team's group_id if it exists (for group_knockout), otherwise NULL (for league)
    v_group_id := NEW.group_id;
    
    INSERT INTO standings (tournament_id, group_id, team_id)
    VALUES (NEW.tournament_id, v_group_id, NEW.id)
    ON CONFLICT (tournament_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::UUID), team_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER create_standings_on_team_insert
  AFTER INSERT ON teams
  FOR EACH ROW EXECUTE FUNCTION initialize_team_standings();

-- Update match result and standings (with proper edit handling)
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
  -- Get match details
  SELECT m.*, t.format, t.rules_json
  INTO v_match
  FROM matches m
  JOIN tournaments t ON t.id = m.tournament_id
  WHERE m.id = p_match_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Match not found');
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
        goal_difference = goals_for + p_home_goals - (goals_against + p_away_goals),
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
        goal_difference = goals_for + p_away_goals - (goals_against + p_home_goals),
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

  RETURN jsonb_build_object(
    'success', true,
    'match_id', p_match_id,
    'home_goals', p_home_goals,
    'away_goals', p_away_goals
  );
END;
$$ LANGUAGE plpgsql;

-- Fixture generation functions
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
  i INTEGER;
  j INTEGER;
  r INTEGER;
  v_match_date DATE;
  v_kickoff TIMESTAMPTZ;
  v_matchday INTEGER;
BEGIN
  -- Get teams
  SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams
  FROM teams
  WHERE tournament_id = p_tournament_id;

  IF v_teams IS NULL OR array_length(v_teams, 1) < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Need at least 2 teams');
  END IF;

  v_team_count := array_length(v_teams, 1);
  v_match_date := COALESCE(p_start_date, CURRENT_DATE);

  -- Generate fixtures for each round
  v_matchday := 1;
  FOR r IN 1..p_rounds LOOP
    FOR i IN 1..v_team_count LOOP
      FOR j IN (i+1)..v_team_count LOOP
        v_kickoff := (v_match_date + ((v_match_count / 2) * INTERVAL '1 day'))::TIMESTAMPTZ;
        
        INSERT INTO matches (
          tournament_id, phase, matchday, home_team_id, away_team_id, kickoff_time, status
        ) VALUES (
          p_tournament_id, 'group', v_matchday, v_teams[i], v_teams[j], v_kickoff, 'scheduled'
        );
        
        v_match_count := v_match_count + 1;
        -- Alternate matchdays for better scheduling
        IF v_match_count % 2 = 0 THEN
          v_matchday := v_matchday + 1;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'matches_created', v_match_count);
END;
$$ LANGUAGE plpgsql;

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

  -- Calculate rounds needed (round of 16 = 4, round of 8 = 3, etc.)
  -- Round 1 = final, Round 2 = semi, Round 3 = quarter, etc.
  v_rounds_needed := ceil(log(2, v_team_count))::INTEGER;
  
  -- Get teams sorted
  SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams
  FROM teams WHERE tournament_id = p_tournament_id;
  
  v_match_date := COALESCE(p_start_date, CURRENT_DATE);
  
  -- Step 1: Create all matches for all rounds (top to bottom: final to first round)
  FOR v_round IN 1..v_rounds_needed LOOP
    v_matches_per_round := power(2, v_rounds_needed - v_round)::INTEGER;
    v_kickoff := (v_match_date + ((v_round - 1) * INTERVAL '1 day'))::TIMESTAMPTZ;
    
    FOR v_match_in_round IN 1..v_matches_per_round LOOP
      IF v_round = v_rounds_needed THEN
        -- First round (lowest round number): assign teams
        INSERT INTO matches (
          tournament_id, phase, round_number, home_team_id, away_team_id, kickoff_time, status
        ) VALUES (
          p_tournament_id, 
          'knockout', 
          v_rounds_needed, 
          v_teams[(v_match_in_round * 2 - 1)],
          CASE WHEN (v_match_in_round * 2) <= array_length(v_teams, 1) THEN v_teams[v_match_in_round * 2] ELSE NULL END,
          v_kickoff, 
          'scheduled'
        ) RETURNING id INTO v_match_id;
      ELSE
        -- Later rounds: create empty matches
        INSERT INTO matches (
          tournament_id, phase, round_number, home_team_id, away_team_id, kickoff_time, status
        ) VALUES (
          p_tournament_id, 'knockout', v_round, NULL, NULL, v_kickoff, 'scheduled'
        ) RETURNING id INTO v_match_id;
      END IF;
      
      v_match_count := v_match_count + 1;
    END LOOP;
  END LOOP;
  
  -- Step 2: Link matches (each match in round N links to a match in round N-1)
  -- Get all first round matches
  SELECT ARRAY_AGG(id ORDER BY id) INTO v_first_round_matches
  FROM matches
  WHERE tournament_id = p_tournament_id
    AND phase = 'knockout'
    AND round_number = v_rounds_needed;
  
  -- Link matches from round N to round N-1
  FOR v_round IN REVERSE v_rounds_needed..2 LOOP
    v_match_idx := 1;
    FOR v_match_id IN (
      SELECT id FROM matches
      WHERE tournament_id = p_tournament_id
        AND phase = 'knockout'
        AND round_number = v_round
      ORDER BY id
    ) LOOP
      -- Get the parent match in the previous round
      SELECT id INTO v_next_match_id
      FROM matches
      WHERE tournament_id = p_tournament_id
        AND phase = 'knockout'
        AND round_number = v_round - 1
        AND (SELECT COUNT(*) FROM matches WHERE next_match_id = id) < 2
      ORDER BY id
      LIMIT 1;
      
      IF v_next_match_id IS NOT NULL THEN
        UPDATE matches SET next_match_id = v_next_match_id WHERE id = v_match_id;
      END IF;
      
      v_match_idx := v_match_idx + 1;
    END LOOP;
  END LOOP;
  
  RETURN jsonb_build_object('success', true, 'matches_created', v_match_count);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_tournament_fixtures(
  p_tournament_id UUID,
  p_start_date DATE DEFAULT NULL,
  p_rounds INTEGER DEFAULT 1
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
    
    -- Create groups
    FOR i IN 1..v_group_count LOOP
      INSERT INTO groups (tournament_id, name, group_number)
      VALUES (p_tournament_id, 'Group ' || CHR(64 + i), i)
      ON CONFLICT (tournament_id, group_number) DO NOTHING;
    END LOOP;
    
    -- Step 2: Assign teams to groups (round-robin distribution)
    SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams
    FROM teams WHERE tournament_id = p_tournament_id;
    
    FOR i IN 1..array_length(v_teams, 1) LOOP
      v_group_id := (
        SELECT id FROM groups 
        WHERE tournament_id = p_tournament_id 
        AND group_number = ((i - 1) % v_group_count) + 1
        LIMIT 1
      );
      UPDATE teams SET group_id = v_group_id WHERE id = v_teams[i];
    END LOOP;
    
    -- Step 3: Generate group stage fixtures (round-robin within each group)
    FOR v_group_rec IN SELECT id, name, group_number FROM groups WHERE tournament_id = p_tournament_id ORDER BY group_number LOOP
      SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams_in_group
      FROM teams WHERE tournament_id = p_tournament_id AND group_id = v_group_rec.id;
      
      IF v_teams_in_group IS NOT NULL AND array_length(v_teams_in_group, 1) >= 2 THEN
        -- Generate round-robin within group
        FOR i IN 1..array_length(v_teams_in_group, 1) LOOP
          FOR j IN (i+1)..array_length(v_teams_in_group, 1) LOOP
            v_kickoff := (v_match_date + (v_match_count * INTERVAL '1 day'))::TIMESTAMPTZ;
            
            INSERT INTO matches (
              tournament_id, phase, group_id, home_team_id, away_team_id, kickoff_time, status
            ) VALUES (
              p_tournament_id, 'group', v_group_rec.id, v_teams_in_group[i], v_teams_in_group[j], v_kickoff, 'scheduled'
            );
            
            v_match_count := v_match_count + 1;
          END LOOP;
        END LOOP;
      END IF;
    END LOOP;
    
    -- Step 4: Knockout stage will be generated after group stage completes
    -- (This would be done manually or via a separate function after group stage results)
    
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
  -- Check if profile already exists (shouldn't happen, but be safe)
  IF EXISTS (SELECT 1 FROM public.user_profiles WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  -- Count existing profiles BEFORE inserting this one (SECURITY DEFINER bypasses RLS)
  -- This ensures atomic check: if count is 0, this user is definitely the first
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
    -- Log error but don't fail the user creation
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
  p_role    VARCHAR(20) DEFAULT 'organiser'
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
    role          = p_role,
    approved_by   = v_admin_id,
    approved_at   = NOW(),
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
  p_reason  TEXT DEFAULT NULL
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
    role            = 'rejected',
    rejection_reason = p_reason,
    approved_by     = v_admin_id,
    approved_at     = NOW()
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
  FROM user_profiles up
  WHERE up.id = auth.uid();

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
  rejection_reason TEXT,
  approved_by UUID,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles up
    WHERE up.id = auth.uid() AND up.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can view pending users';
  END IF;

  RETURN QUERY
  SELECT 
    up.id, 
    up.email, 
    up.display_name, 
    up.role, 
    up.rejection_reason,
    up.approved_by,
    up.approved_at,
    up.created_at
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
    SELECT 1 FROM user_profiles up
    WHERE up.id = auth.uid() AND up.role = 'admin'
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
-- STEP 8: GRANT PERMISSIONS
-- =====================================================================

-- Permissions for authenticated users (full access)
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON organisations TO authenticated;
GRANT ALL ON tournaments TO authenticated;
GRANT ALL ON groups TO authenticated;
GRANT ALL ON teams TO authenticated;
GRANT ALL ON players TO authenticated;
GRANT ALL ON matches TO authenticated;
GRANT ALL ON standings TO authenticated;

-- Permissions for anonymous users (read-only access to public data)
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON organisations TO anon;
GRANT SELECT ON tournaments TO anon;
GRANT SELECT ON groups TO anon;
GRANT SELECT ON teams TO anon;
GRANT SELECT ON players TO anon;
GRANT SELECT ON matches TO anon;
GRANT SELECT ON standings TO anon;

GRANT EXECUTE ON FUNCTION update_match_result(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_round_robin_fixtures(UUID, DATE, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_knockout_fixtures(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_tournament_fixtures(UUID, DATE, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_user(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_user(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_approval_status() TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_users() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_users() TO authenticated;

-- =====================================================================
-- RESET COMPLETE
-- =====================================================================
-- The database is now completely reset and ready.
-- The first user to sign up will automatically become an admin.
-- =====================================================================
