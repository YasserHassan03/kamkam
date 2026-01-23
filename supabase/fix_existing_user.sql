-- If you created a user account BEFORE running the migration,
-- that user won't have a profile. Run this to create it manually.

-- Replace 'admin@kamkam.com' with your actual email
-- This will make the first user in user_profiles an admin

INSERT INTO public.user_profiles (id, email, display_name, role)
SELECT 
  au.id,
  au.email,
  COALESCE(au.raw_user_meta_data->>'display_name', split_part(au.email, '@', 1)) as display_name,
  CASE 
    WHEN (SELECT COUNT(*) FROM public.user_profiles) = 0 THEN 'admin'
    ELSE 'pending'
  END as role
FROM auth.users au
WHERE au.email = 'admin@kamkam.com'  -- Change this to your email
  AND NOT EXISTS (
    SELECT 1 FROM public.user_profiles up WHERE up.id = au.id
  )
ON CONFLICT (id) DO UPDATE
SET role = CASE 
  WHEN (SELECT COUNT(*) FROM public.user_profiles WHERE role = 'admin') = 0 THEN 'admin'
  ELSE user_profiles.role
END;

-- Verify the user was created
SELECT id, email, role, created_at 
FROM public.user_profiles 
WHERE email = 'admin@kamkam.com';  -- Change this to your email
