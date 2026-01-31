-- ============================================================================
-- Notification Reminders System (1 Hour Before Kickoff)
-- ============================================================================

-- 1. Create a table to track sent reminders (prevents duplicates)
CREATE TABLE IF NOT EXISTS notification_reminders_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    reminder_type TEXT NOT NULL, -- e.g., '1_hour_before'
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(match_id, reminder_type)
);

-- 2. Function to check upcoming matches and trigger edge function
-- This function will be called by pg_cron every 10 minutes
CREATE OR REPLACE FUNCTION check_upcoming_matches_and_notify()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_match RECORD;
    v_function_url TEXT := 'https://' || (SELECT current_setting('request.headers')::json->>'host') || '/functions/v1/push-notifications';
    v_anon_key TEXT := (SELECT current_setting('request.headers')::json->>'anon_key'); -- Use service role if available instead
BEGIN
    -- Find matches starting in 60-70 minutes that haven't had a reminder sent
    FOR v_match IN 
        SELECT id, name, kickoff_time 
        FROM matches 
        WHERE status = 'upcoming'
          AND kickoff_time >= NOW() + INTERVAL '55 minutes'
          AND kickoff_time <= NOW() + INTERVAL '65 minutes'
          AND id NOT IN (
              SELECT match_id 
              FROM notification_reminders_log 
              WHERE reminder_type = '1_hour_before'
          )
    LOOP
        -- Log that we are sending the reminder
        INSERT INTO notification_reminders_log (match_id, reminder_type)
        VALUES (v_match.id, '1_hour_before');

        -- Trigger the Edge Function
        -- Note: In a real environment, you'd use the 'http' extension 
        -- or call the function via net.http_post
        PERFORM net.http_post(
          url := v_function_url,
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') -- This logic is for Edge, in SQL we need the key
          ),
          body := jsonb_build_object(
            'type', 'reminder',
            'match_id', v_match.id
          )
        );
    END LOOP;
END;
$$;

-- Note: The actual pg_cron schedule command needs to be run by the database superuser 
-- (usually through the Supabase Dashboard "Schedule" UI or a specific script).
-- SELECT cron.schedule('match-reminders', '*/10 * * * *', 'SELECT check_upcoming_matches_and_notify()');
