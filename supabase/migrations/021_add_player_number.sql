-- ============================================================================
-- Add player number support
-- ============================================================================
-- The Flutter app already collects a player's "Jersey Number" (and position/captain),
-- but older databases may not have these columns on `players`.
--
-- This migration is idempotent and safe to run multiple times.

ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS jersey_number INTEGER;

ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS position VARCHAR(50);

ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS is_captain BOOLEAN DEFAULT FALSE;

-- Optional: index for sorting/filtering by number within a team
CREATE INDEX IF NOT EXISTS idx_players_team_jersey_number
  ON public.players (team_id, jersey_number);

