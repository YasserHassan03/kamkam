-- Migration: Add match_events table for live match goal tracking
-- Run this in your Supabase SQL Editor

-- Create match_events table
CREATE TABLE IF NOT EXISTS match_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('goal', 'own_goal', 'penalty')),
  player_name TEXT,
  minute INT CHECK (minute >= 0 AND minute <= 150),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_match_events_match_id ON match_events(match_id);
CREATE INDEX IF NOT EXISTS idx_match_events_team_id ON match_events(team_id);

-- Enable Row Level Security
ALTER TABLE match_events ENABLE ROW LEVEL SECURITY;

-- Public read access
CREATE POLICY "Public can view match events"
ON match_events FOR SELECT
TO public
USING (true);

-- Authenticated users can manage match events
CREATE POLICY "Authenticated users can insert match events"
ON match_events FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Authenticated users can update match events"
ON match_events FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Authenticated users can delete match events"
ON match_events FOR DELETE
TO authenticated
USING (true);

-- Enable realtime for match_events
ALTER PUBLICATION supabase_realtime ADD TABLE match_events;
