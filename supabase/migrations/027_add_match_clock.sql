-- Add clock columns to matches table
ALTER TABLE matches 
ADD COLUMN IF NOT EXISTS is_clock_running BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS clock_start_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS accumulated_seconds INTEGER DEFAULT 0;

-- Function to handle automatic clock stopping when match ends
CREATE OR REPLACE FUNCTION handle_match_clock_on_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- If match status changes to 'finished', stop the clock
    IF NEW.status = 'finished' AND OLD.status != 'finished' THEN
        NEW.is_clock_running := false;
        
        -- Calculate final accumulated time if it was running
        IF OLD.is_clock_running AND OLD.clock_start_time IS NOT NULL THEN
            NEW.accumulated_seconds := OLD.accumulated_seconds + floor(extract(epoch from (now() - OLD.clock_start_time)))::INTEGER;
        END IF;
        
        NEW.clock_start_time := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to stop clock on finish
DROP TRIGGER IF EXISTS tr_stop_clock_on_finish ON matches;
CREATE TRIGGER tr_stop_clock_on_finish
BEFORE UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION handle_match_clock_on_status_change();

-- Enable realtime for the new columns
-- (Assuming realtime is already enabled for the matches table, 
--  adding new columns usually just works, but let's be explicit if needed)
COMMENT ON COLUMN matches.is_clock_running IS 'Whether the match stopwatch is currently active';
COMMENT ON COLUMN matches.clock_start_time IS 'The last time the stopwatch was started or resumed';
COMMENT ON COLUMN matches.accumulated_seconds IS 'Total seconds elapsed before the last pause or reset';
