-- ============================================================================
-- User Subscriptions & Notifications System
-- ============================================================================
-- This migration adds support for users to subscribe to tournaments and teams
-- to receive real-time push notifications for goals, kickoff, etc.
-- ============================================================================

-- Table to store per-device FCM tokens
-- A user can have multiple devices (tokens)
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- Optional: allows guest users
    fcm_token TEXT NOT NULL UNIQUE,
    device_name TEXT,
    platform TEXT, -- 'ios', 'android', 'web'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table to store user subscriptions to tournaments or teams
CREATE TABLE IF NOT EXISTS user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Associate with either a user_id or a specific fcm_token (for guests)
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT REFERENCES user_devices(fcm_token) ON DELETE CASCADE,
    
    -- What they are following
    tournament_id UUID REFERENCES tournaments(id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    
    -- Sub-topics (as JSONB for flexibility)
    -- e.g., ["goals", "kickoff", "time_changes", "full_time"]
    topics JSONB NOT NULL DEFAULT '["goals", "kickoff", "full_time"]'::jsonb,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure a user can't subscribe multiple times to the same thing with the same token
    UNIQUE(fcm_token, tournament_id, team_id)
);

-- RLS Policies
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can manage their own devices
CREATE POLICY "Users can manage their own devices" ON user_devices
    FOR ALL USING (auth.uid() = user_id OR user_id IS NULL);

-- Users can manage their own subscriptions
CREATE POLICY "Users can manage their own subscriptions" ON user_subscriptions
    FOR ALL USING (auth.uid() = user_id OR fcm_token IN (SELECT fcm_token FROM user_devices WHERE user_id = auth.uid() OR user_id IS NULL));

-- Index for performance when triggered by webhooks
CREATE INDEX IF NOT EXISTS idx_subscriptions_tournament ON user_subscriptions(tournament_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_team ON user_subscriptions(team_id);
CREATE INDEX IF NOT EXISTS idx_devices_user ON user_devices(user_id);

-- Helper function to register/update a device token
CREATE OR REPLACE FUNCTION register_device_token(
    p_fcm_token TEXT,
    p_device_name TEXT DEFAULT NULL,
    p_platform TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO user_devices (user_id, fcm_token, device_name, platform, updated_at)
    VALUES (auth.uid(), p_fcm_token, p_device_name, p_platform, NOW())
    ON CONFLICT (fcm_token) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        device_name = COALESCE(EXCLUDED.device_name, user_devices.device_name),
        platform = COALESCE(EXCLUDED.platform, user_devices.platform),
        updated_at = NOW();
END;
$$;

-- Helper function to subscribe to a team or tournament
CREATE OR REPLACE FUNCTION toggle_subscription(
    p_fcm_token TEXT,
    p_tournament_id UUID DEFAULT NULL,
    p_team_id UUID DEFAULT NULL,
    p_topics JSONB DEFAULT '["goals", "kickoff", "full_time"]'::jsonb
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Check if subscription exists
    SELECT EXISTS (
        SELECT 1 FROM user_subscriptions 
        WHERE fcm_token = p_fcm_token 
          AND (tournament_id IS NOT DISTINCT FROM p_tournament_id)
          AND (team_id IS NOT DISTINCT FROM p_team_id)
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM user_subscriptions 
        WHERE fcm_token = p_fcm_token 
          AND (tournament_id IS NOT DISTINCT FROM p_tournament_id)
          AND (team_id IS NOT DISTINCT FROM p_team_id);
        RETURN FALSE; -- Unsubscribed
    ELSE
        INSERT INTO user_subscriptions (user_id, fcm_token, tournament_id, team_id, topics)
        VALUES (auth.uid(), p_fcm_token, p_tournament_id, p_team_id, p_topics);
        RETURN TRUE; -- Subscribed
    END IF;
END;
$$;
