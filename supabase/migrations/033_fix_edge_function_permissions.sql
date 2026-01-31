-- ============================================================================
-- Fix Permissions for Edge Functions and Service Role
-- ============================================================================

-- Grant usage on the public schema
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Grant all permissions on the notification tables to ensure the service_role can bypass RLS
GRANT ALL ON TABLE public.user_devices TO service_role, postgres;
GRANT ALL ON TABLE public.user_subscriptions TO service_role, postgres;

-- Also ensure anon and authenticated can perform their basic duties
GRANT ALL ON TABLE public.user_devices TO anon, authenticated;
GRANT ALL ON TABLE public.user_subscriptions TO anon, authenticated;

-- Explicitly allow the service role to bypass RLS (this is usually default, but good to be sure)
ALTER TABLE public.user_devices FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions FORCE ROW LEVEL SECURITY;

-- Re-verify RLS is enabled but policies are open for our use case
DROP POLICY IF EXISTS "Subscriptions access policy" ON user_subscriptions;
CREATE POLICY "Subscriptions access policy" ON user_subscriptions
    FOR ALL
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Devices access policy" ON user_devices;
CREATE POLICY "Devices access policy" ON user_devices
    FOR ALL
    USING (true)
    WITH CHECK (true);
