# Database Setup Instructions

## ⚠️ IMPORTANT: Database Not Set Up

The errors you're seeing (`Could not find the table 'public.tournaments'`, etc.) mean the database tables haven't been created yet. You need to run the migration SQL file in Supabase first.

## Quick Setup

Follow these steps to set up your database:

### Step 1: Open Supabase SQL Editor

1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your project
3. Click on **SQL Editor** in the left sidebar

### Step 2: Run the Migration

1. Click **New Query** or open a new SQL editor tab
2. Copy the **entire contents** of the file: `supabase/migrations/009_complete_reset.sql`
3. Paste it into the SQL editor
4. Click **Run** (or press Cmd/Ctrl + Enter)

### Step 3: Verify Setup

After running the migration, you should see:
- ✅ All tables created (user_profiles, organisations, tournaments, teams, matches, standings, groups, players)
- ✅ All functions created (update_match_result, generate_tournament_fixtures, etc.)
- ✅ All RLS policies enabled
- ✅ All triggers set up

### Step 4: Verify Setup (Optional)

Run the verification query in `supabase/verify_setup.sql` to confirm all tables and functions were created successfully.

### Step 5: Test the App

1. **Stop and restart your Flutter app completely** (hot restart won't be enough)
2. The first user you sign up will automatically become an **admin**
3. All subsequent users will be **pending** until approved by an admin

**Note:** If you already created an account (like `admin@kamkam.com`) before running the migration:

1. Run the migration first (Step 2 above)
2. Then run `supabase/fix_existing_user.sql` in the SQL Editor (update the email in that file to match your account)
3. This will create the user profile and make them admin if they're the first user

Alternatively, you can:
- Delete the user from Supabase Auth (Authentication → Users) and create a new one after running the migration

## Important Notes

⚠️ **This migration will DELETE all existing data** if you run it on a database that already has tables. It's designed to reset everything.

✅ **Safe for fresh databases** - If your database is empty, this will create everything from scratch.

## Troubleshooting

### If you get permission errors:
- Make sure you're logged in as the project owner or have admin access
- Check that your Supabase project is active

### If tables still don't appear:
- Refresh the Supabase dashboard
- Check the SQL Editor for any error messages
- Make sure you ran the entire migration file (all 1290 lines)

### If the app still shows errors after running migration:
- Do a **full app restart** (not just hot reload)
- Clear app cache if needed
- Verify the migration completed successfully in Supabase

## What Gets Created

- **Tables**: user_profiles, organisations, tournaments, groups, teams, players, matches, standings
- **Functions**: update_match_result, generate_tournament_fixtures, approve_user, etc.
- **Triggers**: Auto-create user profiles, update timestamps, initialize standings
- **RLS Policies**: Row-level security for all tables
- **Indexes**: Performance indexes on key columns

## First User = Admin

The first user to sign up after running this migration will automatically have the `admin` role. This user can:
- Approve/reject other organisers
- Access user management
- Create organisations and tournaments
