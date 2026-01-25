-- ============================================================================
-- Players cleanup + stats
-- ============================================================================
-- Changes requested:
-- - Remove position/captain feature (frontend no longer uses them)
-- - Drop legacy contact_info column (if present)
-- - Use player_number (nullable) instead of jersey_number
-- - Add goals column (nullable)
--
-- This migration is written to be idempotent and safe across environments.

-- Drop legacy columns if they exist
ALTER TABLE public.players DROP COLUMN IF EXISTS contact_info;
ALTER TABLE public.players DROP COLUMN IF EXISTS position;
ALTER TABLE public.players DROP COLUMN IF EXISTS is_captain;

-- Rename jersey_number -> player_number if needed (preserves existing data)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'players'
      AND column_name = 'jersey_number'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'players'
      AND column_name = 'player_number'
  ) THEN
    ALTER TABLE public.players RENAME COLUMN jersey_number TO player_number;
  END IF;
END $$;

-- Ensure player_number exists (nullable by default)
ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS player_number INTEGER;

-- If both jersey_number and player_number exist (mixed schemas), migrate values then drop jersey_number
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'players'
      AND column_name = 'jersey_number'
  ) AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'players'
      AND column_name = 'player_number'
  ) THEN
    EXECUTE 'UPDATE public.players SET player_number = COALESCE(player_number, jersey_number) WHERE player_number IS NULL';
    ALTER TABLE public.players DROP COLUMN jersey_number;
  END IF;
END $$;

-- Add goals column (nullable by default)
ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS goals INTEGER;

-- Helpful index for sorting/filtering within a team
DROP INDEX IF EXISTS public.idx_players_team_jersey_number;
CREATE INDEX IF NOT EXISTS idx_players_team_player_number
  ON public.players (team_id, player_number);

