-- Migration: Enable realtime for matches table
-- Run this in your Supabase SQL Editor

ALTER PUBLICATION supabase_realtime ADD TABLE matches, match_events;
