-- Migration: Ensure player goals column and defaults
-- This ensures manual goal overrides work reliably

-- 1. Ensure goals column exists with correct default
ALTER TABLE players ADD COLUMN IF NOT EXISTS goals INTEGER DEFAULT 0;

-- 2. Initialize NULL goals to 0 for consistency
UPDATE players SET goals = 0 WHERE goals IS NULL;

-- 3. Add a check constraint to prevent negative goals (optional but recommended)
ALTER TABLE players DROP CONSTRAINT IF EXISTS check_positive_goals;
ALTER TABLE players ADD CONSTRAINT check_positive_goals CHECK (goals >= 0);
