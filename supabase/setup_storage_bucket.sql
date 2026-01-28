-- ============================================
-- Supabase Storage Bucket Setup for Logos
-- ============================================
-- Run this in your Supabase SQL Editor to create
-- the storage bucket and configure permissions.
-- ============================================

-- Step 1: Create the storage bucket
-- Note: This needs to be done via Supabase Dashboard or API
-- Go to Storage > Create new bucket > Name: "logos" > Public: ON

-- Step 2: Set up RLS policies for the bucket
-- These policies allow:
-- - Anyone can VIEW logos (public read)
-- - Authenticated users can UPLOAD logos
-- - Authenticated users can UPDATE their own logos
-- - Authenticated users can DELETE their own logos

-- Allow public read access to all logos
CREATE POLICY "Public can view logos"
ON storage.objects FOR SELECT
USING (bucket_id = 'logos');

-- Allow authenticated users to upload logos
CREATE POLICY "Authenticated users can upload logos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'logos');

-- Allow authenticated users to update logos
CREATE POLICY "Authenticated users can update logos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'logos');

-- Allow authenticated users to delete logos
CREATE POLICY "Authenticated users can delete logos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'logos');

-- ============================================
-- IMPORTANT: Manual Step Required
-- ============================================
-- 1. Go to your Supabase Dashboard
-- 2. Navigate to Storage
-- 3. Click "Create new bucket"
-- 4. Name: logos
-- 5. Toggle "Public bucket" to ON
-- 6. Click "Create bucket"
-- 7. Then run the SQL above to set up policies
-- ============================================
