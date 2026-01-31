-- ============================================================================
-- General Security Hardening
-- ============================================================================
-- 1. Administrative Cooldown (Rate Limiting)
-- 2. Hardened is_admin check (using Auth Metadata)
-- ============================================================================

-- Create a table to log admin actions for rate limiting
CREATE TABLE IF NOT EXISTS admin_action_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES auth.users(id),
    action_name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for quick cooldown checks
CREATE INDEX IF NOT EXISTS idx_admin_action_logs_cooldown 
ON admin_action_logs(admin_id, action_name, created_at DESC);

-- Enable RLS on audit table (Admins only)
ALTER TABLE admin_action_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can view admin action logs" ON admin_action_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() AND up.role = 'admin'
        )
    );

-- HARDENED is_admin function
-- Checks both user_profiles table and Supabase Auth app_metadata
CREATE OR REPLACE FUNCTION is_admin(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile_role VARCHAR;
    v_auth_role VARCHAR;
BEGIN
    -- Check user_profiles table
    SELECT role INTO v_profile_role 
    FROM public.user_profiles 
    WHERE id = check_user_id;

    -- Check Supabase Auth app_metadata (much harder to spoof)
    -- This requires a slightly complex query since we're in SECURITY DEFINER
    -- and accessing auth.users directly.
    SELECT (raw_app_meta_data->>'role') INTO v_auth_role
    FROM auth.users
    WHERE id = check_user_id;

    RETURN (v_profile_role = 'admin' OR v_auth_role = 'admin');
END;
$$;

-- RATE LIMITING helper function
CREATE OR REPLACE FUNCTION check_admin_cooldown(
    p_admin_id UUID,
    p_action VARCHAR,
    p_seconds INTEGER DEFAULT 5
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM admin_action_logs
        WHERE admin_id = p_admin_id
          AND action_name = p_action
          AND created_at > NOW() - (p_seconds || ' seconds')::INTERVAL
    ) THEN
        RAISE EXCEPTION 'Action cooldown in progress. Please wait % seconds.', p_seconds;
    END IF;

    -- Log the action
    INSERT INTO admin_action_logs (admin_id, action_name)
    VALUES (p_admin_id, p_action);
END;
$$;

-- UPDATE delete_user with rate limiting
-- We wrap the existing logic or redefine it with the cooldown check
CREATE OR REPLACE FUNCTION delete_user(user_id_to_delete UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID;
    is_admin_check BOOLEAN;
    org_ids UUID[];
    tournament_ids UUID[];
BEGIN
    -- Get current user
    current_user_id := auth.uid();
    
    -- HARDENED ADMIN CHECK
    SELECT is_admin(current_user_id) INTO is_admin_check;
    
    IF NOT is_admin_check THEN
        RAISE EXCEPTION 'Only admins can delete users';
    END IF;

    -- RATE LIMITING (5 seconds)
    PERFORM check_admin_cooldown(current_user_id, 'delete_user', 5);
    
    -- Prevent self-deletion
    IF current_user_id = user_id_to_delete THEN
        RAISE EXCEPTION 'Admins cannot delete their own account';
    END IF;
    
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = user_id_to_delete) THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- [Existing Deletion Logic remains the same as migration 011]
    -- Step 1: Get all organisations owned by this user
    SELECT ARRAY_AGG(id) INTO org_ids
    FROM organisations
    WHERE owner_id = user_id_to_delete;
    
    -- Step 2: Get ALL tournament IDs that need to be deleted
    SELECT ARRAY_AGG(DISTINCT id) INTO tournament_ids
    FROM tournaments
    WHERE owner_id = user_id_to_delete
       OR (org_ids IS NOT NULL AND array_length(org_ids, 1) > 0 AND org_id = ANY(org_ids));
    
    -- Step 3: Delete related data
    IF tournament_ids IS NOT NULL AND array_length(tournament_ids, 1) > 0 THEN
        DELETE FROM standings WHERE tournament_id = ANY(tournament_ids);
        DELETE FROM matches WHERE tournament_id = ANY(tournament_ids);
        DELETE FROM players WHERE team_id IN (SELECT id FROM teams WHERE tournament_id = ANY(tournament_ids));
        DELETE FROM teams WHERE tournament_id = ANY(tournament_ids);
        DELETE FROM groups WHERE tournament_id = ANY(tournament_ids);
    END IF;
    
    DELETE FROM tournaments WHERE owner_id = user_id_to_delete;
    IF org_ids IS NOT NULL AND array_length(org_ids, 1) > 0 THEN
        DELETE FROM tournaments WHERE org_id = ANY(org_ids);
        DELETE FROM organisations WHERE id = ANY(org_ids);
    END IF;
    DELETE FROM organisations WHERE owner_id = user_id_to_delete;
    DELETE FROM user_profiles WHERE id = user_id_to_delete;
END;
$$;

-- UPDATE generate_tournament_fixtures with cooldown
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
  v_admin_id UUID;
BEGIN
  -- Get current user
  v_admin_id := auth.uid();

  -- RATE LIMITING (5 seconds)
  PERFORM check_admin_cooldown(v_admin_id, 'generate_fixtures', 5);

  SELECT format, group_count, rules_json INTO v_type, v_group_count, v_rules
  FROM tournaments WHERE id = p_tournament_id;
  
  IF v_type IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tournament not found');
  END IF;

  -- [Remainder of original logic from 026]
  DELETE FROM matches WHERE tournament_id = p_tournament_id;
  DELETE FROM groups WHERE tournament_id = p_tournament_id;
  UPDATE standings SET played = 0, won = 0, drawn = 0, lost = 0, goals_for = 0, goals_against = 0, goal_difference = 0, points = 0, group_id = NULL, updated_at = NOW() WHERE tournament_id = p_tournament_id;
  UPDATE players SET goals = 0 WHERE team_id IN (SELECT id FROM teams WHERE tournament_id = p_tournament_id);
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
    IF v_group_count IS NULL OR v_group_count < 2 THEN RETURN jsonb_build_object('success', false, 'error', 'Group knockout requires at least 2 groups'); END IF;
    INSERT INTO groups (tournament_id, name, group_number) SELECT p_tournament_id, 'Group ' || CHR(64 + group_num), group_num FROM generate_series(1, v_group_count) group_num ON CONFLICT (tournament_id, group_number) DO NOTHING;
    SELECT ARRAY_AGG(id ORDER BY name) INTO v_teams FROM teams WHERE tournament_id = p_tournament_id;
    FOR i IN 1..array_length(v_teams, 1) LOOP
      DECLARE v_g_id UUID; BEGIN SELECT id INTO v_g_id FROM groups WHERE tournament_id = p_tournament_id AND group_number = ((i - 1) % v_group_count) + 1; IF v_g_id IS NOT NULL THEN UPDATE teams SET group_id = v_g_id WHERE id = v_teams[i]; END IF; END;
    END LOOP;
    FOR v_group_rec IN SELECT id FROM groups WHERE tournament_id = p_tournament_id ORDER BY group_number LOOP
      INSERT INTO matches (tournament_id, group_id, home_team_id, away_team_id, matchday, kickoff_time, status, phase)
      SELECT p_tournament_id, v_group_rec.id, m.home_team_id, m.away_team_id, m.matchday, m.kickoff_time, 'scheduled', 'group'
      FROM generate_round_robin_fixtures(p_tournament_id, v_match_date, 1, v_group_rec.id) m;
      GET DIAGNOSTICS v_delta = ROW_COUNT; v_match_count := v_match_count + v_delta;
    END LOOP;
    RETURN jsonb_build_object('success', true, 'matches_created', v_match_count);
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Unsupported tournament type for this generator');
  END IF;
END;
$$;
