-- ============================================
-- Add Sponsor Logo URL to Tournaments
-- ============================================
-- Run this in Supabase SQL Editor to add
-- the sponsor_logo_url column to tournaments.
-- ============================================

ALTER TABLE tournaments 
ADD COLUMN IF NOT EXISTS sponsor_logo_url TEXT;

-- Add a comment for documentation
COMMENT ON COLUMN tournaments.sponsor_logo_url IS 'URL to sponsor logo image stored in Supabase Storage';
