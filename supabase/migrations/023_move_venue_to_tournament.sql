-- ============================================================================
-- Move venue from matches to tournaments
-- ============================================================================
-- Changes:
-- - Drop venue column from matches table
-- - Add venue column to tournaments table
--
-- This migration is idempotent and safe to run multiple times.

-- Drop venue from matches (if exists)
ALTER TABLE public.matches DROP COLUMN IF EXISTS venue;

-- Add venue to tournaments (nullable text)
ALTER TABLE public.tournaments
  ADD COLUMN IF NOT EXISTS venue TEXT;

