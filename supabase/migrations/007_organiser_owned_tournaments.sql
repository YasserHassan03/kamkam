-- =====================================================================
-- HARD RESET: organiser-owned tournaments (no separate organisations)
-- Run this in Supabase SQL Editor to reset the database
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1) Drop triggers & functions & tables (app only)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_tournaments_updated_at') THEN
    DROP TRIGGER update_tournaments_updated_at ON tournaments;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_teams_updated_at') THEN
    DROP TRIGGER update_teams_updated_at ON teams;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_players_updated_at') THEN
    DROP TRIGGER update_players_updated_at ON players;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_matches_updated_at') THEN
    DROP TRIGGER update_matches_updated_at ON matches;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_standings_updated_at') THEN
    DROP TRIGGER update_standings_updated_at ON standings;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'create_standings_on_team_insert') THEN
    DROP TRIGGER create_standings_on_team_insert ON teams;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') THEN
    DROP TRIGGER on_auth_user_created ON auth.users;
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
    DROP FUNCTION update_updated_at_column() CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'initialize_team_standings') THEN
    DROP FUNCTION initialize_team_standings() CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_match_result') THEN
    DROP FUNCTION update_match_result(UUID, INTEGER, INTEGER) CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'generate_round_robin_fixtures') THEN
    DROP FUNCTION generate_round_robin_fixtures(UUID, DATE, INTEGER) CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'generate_tournament_fixtures') THEN
    DROP FUNCTION generate_tournament_fixtures(UUID, DATE, INTEGER) CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_new_user') THEN
    DROP FUNCTION handle_new_user() CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'approve_user') THEN
    DROP FUNCTION approve_user(UUID, VARCHAR) CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'reject_user') THEN
    DROP FUNCTION reject_user(UUID, TEXT) CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_my_approval_status') THEN
    DROP FUNCTION get_my_approval_status() CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_pending_users') THEN
    DROP FUNCTION get_pending_users() CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_all_users') THEN
    DROP FUNCTION get_all_users() CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'is_admin') THEN
    DROP FUNCTION is_admin(UUID) CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_user_role') THEN
    DROP FUNCTION get_user_role(UUID) CASCADE;
  END IF;
END;
$$;

DROP TABLE IF EXISTS standings CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS players CASCADE;
DROP TABLE IF EXISTS teams CASCADE;
DROP TABLE IF EXISTS tournaments CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- 2) Core tables

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

CREATE TABLE tournaments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  short_name VARCHAR(10),
  logo_url TEXT,
  primary_color VARCHAR(7),
  secondary_color VARCHAR(7),
  group_number INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (tournament_id, name)
);

CREATE TABLE players (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  jersey_number INTEGER,
  position VARCHAR(50),
  is_captain BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  home_team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  away_team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  matchday INTEGER,
  kickoff_time TIMESTAMPTZ,
  venue VARCHAR(255),
  status VARCHAR(20) NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','in_progress','finished','postponed','cancelled')),
  home_goals INTEGER,
  away_goals INTEGER,
  previous_home_goals INTEGER,
  previous_away_goals INTEGER,
  notes TEXT,
  round_number INTEGER,
  next_match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
  home_seed INTEGER,
  away_seed INTEGER,
  home_qualifier TEXT,
  away_qualifier TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT different_teams CHECK (home_team_id <> away_team_id)
);

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
  form VARCHAR(10),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (tournament_id, team_id)
);

-- 3) Indexes

CREATE INDEX idx_user_profiles_role ON user_profiles(role);
CREATE INDEX idx_user_profiles_email ON user_profiles(email);

CREATE INDEX idx_tournaments_owner ON tournaments(owner_id);
CREATE INDEX idx_tournaments_status ON tournaments(status);
CREATE INDEX idx_tournaments_visibility ON tournaments(visibility);
CREATE INDEX idx_tournaments_season ON tournaments(season_year);

CREATE INDEX idx_teams_tournament ON teams(tournament_id);
CREATE INDEX idx_players_team ON players(team_id);

CREATE INDEX idx_matches_tournament ON matches(tournament_id);
CREATE INDEX idx_matches_home_team ON matches(home_team_id);
CREATE INDEX idx_matches_away_team ON matches(away_team_id);
CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_matches_kickoff ON matches(kickoff_time);
CREATE INDEX idx_matches_round_number ON matches(round_number);
CREATE INDEX idx_matches_next_match ON matches(next_match_id);

CREATE INDEX idx_standings_tournament ON standings(tournament_id);
CREATE INDEX idx_standings_team ON standings(team_id);
CREATE INDEX idx_standings_points
  ON standings(tournament_id, points DESC, goal_difference DESC, goals_for DESC);

-- 4) RLS

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE standings ENABLE ROW LEVEL SECURITY;

-- User profiles
CREATE POLICY "Users can read own profile" ON user_profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Users can insert own profile" ON user_profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update own profile" ON user_profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- tournaments: public read, owners manage
CREATE POLICY "Public tournaments are readable" ON tournaments
  FOR SELECT USING (
    visibility = 'public' AND status <> 'draft'
  );

CREATE POLICY "Owner can manage own tournaments" ON tournaments
  FOR ALL USING (owner_id = auth.uid());

-- teams
CREATE POLICY "Public teams readable" ON teams
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM tournaments t
      WHERE t.id = teams.tournament_id
        AND t.visibility = 'public'
        AND t.status <> 'draft'
    )
  );

CREATE POLICY "Owner manages teams" ON teams
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM tournaments t
      WHERE t.id = teams.tournament_id
        AND t.owner_id = auth.uid()
    )
  );

-- players
CREATE POLICY "Public players readable" ON players
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM teams tm
      JOIN tournaments t ON t.id = tm.tournament_id
      WHERE tm.id = players.team_id
        AND t.visibility = 'public'
        AND t.status <> 'draft'
    )
  );

CREATE POLICY "Owner manages players" ON players
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM teams tm
      JOIN tournaments t ON t.id = tm.tournament_id
      WHERE tm.id = players.team_id
        AND t.owner_id = auth.uid()
    )
  );

-- matches
CREATE POLICY "Public matches readable" ON matches
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM tournaments t
      WHERE t.id = matches.tournament_id
        AND t.visibility = 'public'
        AND t.status <> 'draft'
    )
  );

CREATE POLICY "Owner manages matches" ON matches
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM tournaments t
      WHERE t.id = matches.tournament_id
        AND t.owner_id = auth.uid()
    )
  );

-- standings
CREATE POLICY "Public standings readable" ON standings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM tournaments t
      WHERE t.id = standings.tournament_id
        AND t.visibility = 'public'
        AND t.status <> 'draft'
    )
  );

CREATE POLICY "Owner manages standings" ON standings
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM tournaments t
      WHERE t.id = standings.tournament_id
        AND t.owner_id = auth.uid()
    )
  );

-- 5) Timestamps & standings init

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

-- 6) Match result update function (transactional standings update)

CREATE OR REPLACE FUNCTION update_match_result(
  p_match_id   UUID,
  p_home_goals INTEGER,
  p_away_goals INTEGER
)
RETURNS JSONB AS $$
DECLARE
  v_match          RECORD;
  v_tournament_id  UUID;
  v_home_team_id   UUID;
  v_away_team_id   UUID;
  v_old_home_goals INTEGER;
  v_old_away_goals INTEGER;
  v_old_status     VARCHAR(20);
  v_rules          JSONB;
  v_points_win     INTEGER;
  v_points_draw    INTEGER;
  v_points_loss    INTEGER;
  v_prev_winner    UUID;
  v_winner         UUID;
  v_next_match_id  UUID;
  v_next_home      UUID;
  v_next_away      UUID;
BEGIN
  SELECT * INTO v_match FROM matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Match not found');
  END IF;

  v_tournament_id  := v_match.tournament_id;
  v_home_team_id   := v_match.home_team_id;
  v_away_team_id   := v_match.away_team_id;
  v_old_home_goals := v_match.home_goals;
  v_old_away_goals := v_match.away_goals;
  v_old_status     := v_match.status;
  v_next_match_id  := v_match.next_match_id;

  SELECT rules_json INTO v_rules FROM tournaments WHERE id = v_tournament_id;
  v_points_win  := COALESCE((v_rules->>'points_for_win')::INTEGER, 3);
  v_points_draw := COALESCE((v_rules->>'points_for_draw')::INTEGER, 1);
  v_points_loss := COALESCE((v_rules->>'points_for_loss')::INTEGER, 0);

  -- Reverse old result if match was finished
  IF v_old_status = 'finished'
     AND v_old_home_goals IS NOT NULL
     AND v_old_away_goals IS NOT NULL THEN

    IF v_old_home_goals > v_old_away_goals THEN
      v_prev_winner := v_home_team_id;
    ELSIF v_old_home_goals < v_old_away_goals THEN
      v_prev_winner := v_away_team_id;
    ELSE
      v_prev_winner := NULL;
    END IF;

    UPDATE standings SET
      played        = played - 1,
      won           = won - CASE WHEN v_old_home_goals > v_old_away_goals THEN 1 ELSE 0 END,
      drawn         = drawn - CASE WHEN v_old_home_goals = v_old_away_goals THEN 1 ELSE 0 END,
      lost          = lost - CASE WHEN v_old_home_goals < v_old_away_goals THEN 1 ELSE 0 END,
      goals_for     = goals_for - v_old_home_goals,
      goals_against = goals_against - v_old_away_goals,
      points        = points - CASE
        WHEN v_old_home_goals > v_old_away_goals THEN v_points_win
        WHEN v_old_home_goals = v_old_away_goals THEN v_points_draw
        ELSE v_points_loss
      END
    WHERE tournament_id = v_tournament_id AND team_id = v_home_team_id;

    UPDATE standings SET
      played        = played - 1,
      won           = won - CASE WHEN v_old_away_goals > v_old_home_goals THEN 1 ELSE 0 END,
      drawn         = drawn - CASE WHEN v_old_away_goals = v_old_home_goals THEN 1 ELSE 0 END,
      lost          = lost - CASE WHEN v_old_away_goals < v_old_home_goals THEN 1 ELSE 0 END,
      goals_for     = goals_for - v_old_away_goals,
      goals_against = goals_against - v_old_home_goals,
      points        = points - CASE
        WHEN v_old_away_goals > v_old_home_goals THEN v_points_win
        WHEN v_old_away_goals = v_old_home_goals THEN v_points_draw
        ELSE v_points_loss
      END
    WHERE tournament_id = v_tournament_id AND team_id = v_away_team_id;

    -- undo knockout propagation
    IF v_prev_winner IS NOT NULL AND v_next_match_id IS NOT NULL THEN
      SELECT home_team_id, away_team_id
      INTO v_next_home, v_next_away
      FROM matches WHERE id = v_next_match_id;

      IF v_next_home = v_prev_winner THEN
        UPDATE matches SET home_team_id = NULL WHERE id = v_next_match_id;
      ELSIF v_next_away = v_prev_winner THEN
        UPDATE matches SET away_team_id = NULL WHERE id = v_next_match_id;
      END IF;
    END IF;
  END IF;

  -- Apply new result
  UPDATE matches SET
    home_goals         = p_home_goals,
    away_goals         = p_away_goals,
    previous_home_goals = v_old_home_goals,
    previous_away_goals = v_old_away_goals,
    status             = 'finished'
  WHERE id = p_match_id;

  UPDATE standings SET
    played        = played + 1,
    won           = won + CASE WHEN p_home_goals > p_away_goals THEN 1 ELSE 0 END,
    drawn         = drawn + CASE WHEN p_home_goals = p_away_goals THEN 1 ELSE 0 END,
    lost          = lost + CASE WHEN p_home_goals < p_away_goals THEN 1 ELSE 0 END,
    goals_for     = goals_for + p_home_goals,
    goals_against = goals_against + p_away_goals,
    points        = points + CASE
      WHEN p_home_goals > p_away_goals THEN v_points_win
      WHEN p_home_goals = p_away_goals THEN v_points_draw
      ELSE v_points_loss
    END
  WHERE tournament_id = v_tournament_id AND team_id = v_home_team_id;

  UPDATE standings SET
    played        = played + 1,
    won           = won + CASE WHEN p_away_goals > p_home_goals THEN 1 ELSE 0 END,
    drawn         = drawn + CASE WHEN p_away_goals = p_home_goals THEN 1 ELSE 0 END,
    lost          = lost + CASE WHEN p_away_goals < p_home_goals THEN 1 ELSE 0 END,
    goals_for     = goals_for + p_away_goals,
    goals_against = goals_against + p_home_goals,
    points        = points + CASE
      WHEN p_away_goals > p_home_goals THEN v_points_win
      WHEN p_away_goals = p_home_goals THEN v_points_draw
      ELSE v_points_loss
    END
  WHERE tournament_id = v_tournament_id AND team_id = v_away_team_id;

  -- knockout winner propagation
  IF p_home_goals > p_away_goals THEN
    v_winner := v_home_team_id;
  ELSIF p_home_goals < p_away_goals THEN
    v_winner := v_away_team_id;
  ELSE
    v_winner := NULL;
  END IF;

  IF v_winner IS NOT NULL AND v_next_match_id IS NOT NULL THEN
    SELECT home_team_id, away_team_id
    INTO v_next_home, v_next_away
    FROM matches WHERE id = v_next_match_id;

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

-- 7) Fixture generation functions (reuse from migration 006)

-- Legacy league-only generator
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
  SELECT rules_json INTO v_rules FROM tournaments WHERE id = p_tournament_id;
  v_num_rounds := COALESCE((v_rules->>'rounds')::INTEGER, 1);

  SELECT ARRAY_AGG(id ORDER BY created_at) INTO v_teams
  FROM teams WHERE tournament_id = p_tournament_id;

  v_team_count := array_length(v_teams, 1);
  IF v_team_count IS NULL OR v_team_count < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Need at least 2 teams');
  END IF;

  IF v_team_count % 2 = 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Odd number of teams not supported yet');
  END IF;

  DELETE FROM matches WHERE tournament_id = p_tournament_id;

  v_rounds   := v_team_count - 1;
  v_matchday := COALESCE(p_start_date, CURRENT_DATE);

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
          v_temp      := v_home_team;
          v_home_team := v_away_team;
          v_away_team := v_temp;
        END IF;

        INSERT INTO matches (
          tournament_id, home_team_id, away_team_id,
          matchday, kickoff_time, status
        ) VALUES (
          p_tournament_id, v_home_team, v_away_team,
          round + 1 + ((r - 1) * v_rounds),
          v_matchday + (round * p_days_between_matchdays)
            + ((r - 1) * v_rounds * p_days_between_matchdays),
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

-- Format-aware fixture generator (league/knockout/group+knockout)
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
  SELECT rules_json, format, group_count, qualifiers_per_group
  INTO v_rules, v_type, v_group_count, v_qualifiers
  FROM tournaments WHERE id = p_tournament_id;

  v_type := COALESCE(v_rules->>'type', v_type, 'league');
  v_num_rounds := COALESCE((v_rules->>'rounds')::INTEGER, 1);

  SELECT ARRAY_AGG(id ORDER BY created_at) INTO v_teams
  FROM teams WHERE tournament_id = p_tournament_id;
  v_team_count := COALESCE(array_length(v_teams, 1), 0);

  IF v_team_count < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Need at least 2 teams');
  END IF;

  DELETE FROM matches WHERE tournament_id = p_tournament_id;

  v_matchday := COALESCE(p_start_date, CURRENT_DATE);

  CASE v_type
    WHEN 'league' THEN
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
              v_temp      := v_home_team;
              v_home_team := v_away_team;
              v_away_team := v_temp;
            END IF;

            INSERT INTO matches (
              tournament_id, home_team_id, away_team_id,
              matchday, kickoff_time, status, notes, round_number
            ) VALUES (
              p_tournament_id, v_home_team, v_away_team,
              round + 1 + ((r - 1) * v_rounds),
              v_matchday + (round * p_days_between_matchdays)
                + ((r - 1) * v_rounds * p_days_between_matchdays),
              'scheduled', 'League Match',
              round + 1 + ((r - 1) * v_rounds)
            ) RETURNING id INTO v_inserted_id;

            v_match_count := v_match_count + 1;
          END LOOP;
        END LOOP;
      END LOOP;

    WHEN 'knockout' THEN
      IF v_team_count NOT IN (2,4,8,16,32) THEN
        RETURN jsonb_build_object('success', false, 'error',
          'Knockout format requires 2,4,8,16 or 32 teams');
      END IF;

      v_rounds_needed := 0;
      v_tmp := v_team_count;
      WHILE v_tmp > 1 LOOP
        v_tmp := v_tmp / 2;
        v_rounds_needed := v_rounds_needed + 1;
      END LOOP;

      CREATE TEMP TABLE tmp_gen_matches(
        id UUID PRIMARY KEY,
        round_num INT,
        idx INT
      ) ON COMMIT DROP;

      -- Round 1
      FOR match IN 1..(v_team_count / 2) LOOP
        INSERT INTO matches (
          tournament_id, home_team_id, away_team_id, kickoff_time, status, round_number
        ) VALUES (
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

      -- Placeholder rounds
      FOR r IN 2..v_rounds_needed LOOP
        FOR match IN 1..(v_team_count / (2 ^ r)) LOOP
          INSERT INTO matches (
            tournament_id, kickoff_time, status, round_number
          ) VALUES (
            p_tournament_id,
            v_matchday + ((r - 1) * p_days_between_matchdays),
            'scheduled',
            r
          ) RETURNING id INTO v_inserted_id;

          INSERT INTO tmp_gen_matches VALUES (v_inserted_id, r, match);
          v_match_count := v_match_count + 1;
        END LOOP;
      END LOOP;

      -- Link next_match_id
      FOR rec IN SELECT id, round_num, idx FROM tmp_gen_matches WHERE round_num < v_rounds_needed LOOP
        SELECT id INTO v_parent_id
        FROM tmp_gen_matches
        WHERE round_num = rec.round_num + 1
          AND idx = ((rec.idx + 1) / 2);
        UPDATE matches SET next_match_id = v_parent_id WHERE id = rec.id;
      END LOOP;

    WHEN 'group_knockout' THEN
      v_group_count := COALESCE(v_group_count, (v_rules->>'group_count')::INTEGER);
      v_qualifiers  := COALESCE(v_qualifiers,  (v_rules->>'qualifiers_per_group')::INTEGER);

      IF v_group_count IS NULL OR v_qualifiers IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error',
          'Group count and qualifiers per group must be specified');
      END IF;

      IF v_team_count < (v_group_count * 2) THEN
        RETURN jsonb_build_object('success', false, 'error',
          'Not enough teams for the requested number of groups');
      END IF;

      v_teams_per_group := v_team_count / v_group_count;
      IF v_teams_per_group * v_group_count <> v_team_count THEN
        RETURN jsonb_build_object('success', false, 'error',
          'Teams must divide evenly into groups');
      END IF;

      -- Assign teams to groups + generate round-robin per group
      FOR v_group_num IN 1..v_group_count LOOP
        v_group_teams := v_teams[( (v_group_num - 1) * v_teams_per_group + 1 )
                            : (v_group_num * v_teams_per_group)];

        UPDATE teams
        SET group_number = v_group_num
        WHERE id = ANY(v_group_teams);

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
              'scheduled',
              'Group ' || chr(64 + v_group_num) || ' - Matchday ' || (round + 1),
              round + 1
            ) RETURNING id INTO v_inserted_id;

            v_match_count := v_match_count + 1;
          END LOOP;
        END LOOP;
      END LOOP;

      -- knockout placeholders based on total qualifiers
      v_total_qualifiers := v_group_count * v_qualifiers;
      IF v_total_qualifiers NOT IN (2,4,8,16,32) THEN
        RETURN jsonb_build_object('success', false, 'error',
          'Total qualifiers must be 2,4,8,16 or 32');
      END IF;

      v_rounds_needed := 0;
      v_tmp := v_total_qualifiers;
      WHILE v_tmp > 1 LOOP
        v_tmp := v_tmp / 2;
        v_rounds_needed := v_rounds_needed + 1;
      END LOOP;

      CREATE TEMP TABLE tmp_ko_matches(
        id UUID PRIMARY KEY,
        round_num INT,
        idx INT
      ) ON COMMIT DROP;

      -- First playoff round placeholders
      FOR match IN 1..(v_total_qualifiers / 2) LOOP
        INSERT INTO matches (
          tournament_id, kickoff_time, status, round_number, home_qualifier, away_qualifier
        ) VALUES (
          p_tournament_id,
          v_matchday + (v_rounds_needed * p_days_between_matchdays),
          'scheduled',
          100,
          'QUAL',
          'QUAL'
        ) RETURNING id INTO v_inserted_id;

        INSERT INTO tmp_ko_matches VALUES (v_inserted_id, 1, match);
        v_match_count := v_match_count + 1;
      END LOOP;

      -- Subsequent playoff rounds
      FOR r IN 2..v_rounds_needed LOOP
        FOR match IN 1..(v_total_qualifiers / (2 ^ r)) LOOP
          INSERT INTO matches (
            tournament_id, kickoff_time, status, round_number
          ) VALUES (
            p_tournament_id,
            v_matchday + ((v_rounds_needed + r - 1) * p_days_between_matchdays),
            'scheduled',
            100 + r
          ) RETURNING id INTO v_inserted_id;

          INSERT INTO tmp_ko_matches VALUES (v_inserted_id, r, match);
          v_match_count := v_match_count + 1;
        END LOOP;
      END LOOP;

      -- Link next_match_id for knockout placeholders
      FOR rec IN SELECT id, round_num, idx FROM tmp_ko_matches WHERE round_num < v_rounds_needed LOOP
        SELECT id INTO v_parent_id
        FROM tmp_ko_matches
        WHERE round_num = rec.round_num + 1
          AND idx = ((rec.idx + 1) / 2);
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

-- 8) User approval system

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

CREATE OR REPLACE FUNCTION get_user_role(check_user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE AS $$
  SELECT role FROM user_profiles WHERE id = check_user_id;
$$;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_count INT;
  new_role VARCHAR(20);
BEGIN
  SELECT COUNT(*) INTO user_count FROM public.user_profiles;

  IF user_count = 0 THEN
    new_role := 'admin';
  ELSE
    new_role := 'pending';
  END IF;

  INSERT INTO public.user_profiles (id, email, display_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    new_role
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

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
    rejection_reason = NULL,
    updated_at    = NOW()
  WHERE id = p_user_id;

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'new_role', p_role);
END;
$$ LANGUAGE plpgsql;

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
    approved_at     = NOW(),
    updated_at      = NOW()
  WHERE id = p_user_id;

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_my_approval_status()
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile RECORD;
BEGIN
  SELECT * INTO v_profile FROM user_profiles WHERE id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'status',         v_profile.role,
    'display_name',   v_profile.display_name,
    'rejection_reason', v_profile.rejection_reason,
    'approved_at',    v_profile.approved_at
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_pending_users()
RETURNS SETOF user_profiles
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can view pending users';
  END IF;

  RETURN QUERY
  SELECT * FROM user_profiles
  WHERE role = 'pending'
  ORDER BY created_at ASC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_all_users()
RETURNS SETOF user_profiles
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can view all users';
  END IF;

  RETURN QUERY
  SELECT * FROM user_profiles
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Admin read/update policies using helper
CREATE POLICY "Admins can read all profiles" ON user_profiles
  FOR SELECT TO authenticated
  USING (is_admin(auth.uid()));

CREATE POLICY "Admins can update all profiles" ON user_profiles
  FOR UPDATE TO authenticated
  USING (is_admin(auth.uid()));

-- 9) Grant execute permissions

GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION approve_user TO authenticated;
GRANT EXECUTE ON FUNCTION reject_user TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_approval_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_users TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_users TO authenticated;
GRANT EXECUTE ON FUNCTION update_match_result TO authenticated;
GRANT EXECUTE ON FUNCTION generate_round_robin_fixtures TO authenticated;
GRANT EXECUTE ON FUNCTION generate_tournament_fixtures TO authenticated;

-- =====================================================================
-- DONE: Database reset complete. Organiser-owned tournaments model.
-- First user to sign up will automatically become admin.
-- =====================================================================
