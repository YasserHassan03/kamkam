-- ============================================================================
-- KAM KAM - User Approval System
-- ============================================================================
-- This migration adds a user profiles table with approval workflow
-- Only approved users can create organisations
-- ============================================================================

-- User profiles table for approval status and roles
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    role VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (role IN ('pending', 'organiser', 'admin', 'rejected')),
    -- pending = just signed up, awaiting approval
    -- organiser = approved to create tournaments
    -- admin = can approve other users
    -- rejected = explicitly denied access
    rejection_reason TEXT,
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Everyone can read their own profile
CREATE POLICY "Users can view own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

-- Admins can view all profiles
CREATE POLICY "Admins can view all profiles" ON user_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() AND up.role = 'admin'
        )
    );

-- Users can update their own display_name only
CREATE POLICY "Users can update own display name" ON user_profiles
    FOR UPDATE USING (auth.uid() = id)
    WITH CHECK (
        auth.uid() = id AND
        -- Can only change display_name, not role or approval status
        role = (SELECT role FROM user_profiles WHERE id = auth.uid())
    );

-- Admins can update any profile (for approvals)
CREATE POLICY "Admins can update any profile" ON user_profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() AND up.role = 'admin'
        )
    );

-- Function to auto-create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_profiles (id, email, display_name, role)
    VALUES (
        NEW.id, 
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
        'pending'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Update organisations RLS to require approved status
DROP POLICY IF EXISTS "Owners can insert their own organisations" ON organisations;
CREATE POLICY "Approved users can create organisations" ON organisations
    FOR INSERT WITH CHECK (
        auth.uid() = owner_id AND
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() 
            AND up.role IN ('organiser', 'admin')
        )
    );

-- Function to approve a user
CREATE OR REPLACE FUNCTION approve_user(
    p_user_id UUID,
    p_role VARCHAR(20) DEFAULT 'organiser'
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID;
    v_user_email VARCHAR(255);
BEGIN
    v_admin_id := auth.uid();
    
    -- Check if caller is admin
    IF NOT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = v_admin_id AND role = 'admin'
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only admins can approve users');
    END IF;
    
    -- Check if target user exists
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not found');
    END IF;
    
    -- Update the user's role
    UPDATE user_profiles SET
        role = p_role,
        approved_by = v_admin_id,
        approved_at = NOW(),
        rejection_reason = NULL,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    SELECT email INTO v_user_email FROM user_profiles WHERE id = p_user_id;
    
    RETURN jsonb_build_object(
        'success', true, 
        'user_id', p_user_id,
        'email', v_user_email,
        'new_role', p_role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reject a user
CREATE OR REPLACE FUNCTION reject_user(
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    v_admin_id := auth.uid();
    
    -- Check if caller is admin
    IF NOT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = v_admin_id AND role = 'admin'
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only admins can reject users');
    END IF;
    
    UPDATE user_profiles SET
        role = 'rejected',
        rejection_reason = p_reason,
        approved_by = v_admin_id,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_user_id;
    
    RETURN jsonb_build_object('success', true, 'user_id', p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's approval status
CREATE OR REPLACE FUNCTION get_my_approval_status()
RETURNS JSONB AS $$
DECLARE
    v_profile RECORD;
BEGIN
    SELECT * INTO v_profile FROM user_profiles WHERE id = auth.uid();
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'not_found');
    END IF;
    
    RETURN jsonb_build_object(
        'status', v_profile.role,
        'display_name', v_profile.display_name,
        'rejection_reason', v_profile.rejection_reason,
        'approved_at', v_profile.approved_at
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending users (for admin)
CREATE OR REPLACE FUNCTION get_pending_users()
RETURNS SETOF user_profiles AS $$
BEGIN
    -- Check if caller is admin
    IF NOT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Only admins can view pending users';
    END IF;
    
    RETURN QUERY 
    SELECT * FROM user_profiles 
    WHERE role = 'pending' 
    ORDER BY created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION approve_user TO authenticated;
GRANT EXECUTE ON FUNCTION reject_user TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_approval_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_users TO authenticated;

-- ============================================================================
-- IMPORTANT: Create your first admin user manually!
-- ============================================================================
-- After running this migration, you need to manually promote your user to admin.
-- 
-- 1. First, sign up in the app
-- 2. Go to Supabase Dashboard → Table Editor → user_profiles
-- 3. Find your row and change 'role' from 'pending' to 'admin'
-- 
-- Or run this SQL (replace with your actual user ID):
-- UPDATE user_profiles SET role = 'admin' WHERE email = 'your-email@example.com';
-- ============================================================================
