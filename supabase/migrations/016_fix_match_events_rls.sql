-- Migration: Fix match_events RLS and ensure robust permissions for all match-related tables

-- 0) Fix underlying table permissions (GRANTs)
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

-- Ensure match_events specifically has correct ownership and grants
ALTER TABLE IF EXISTS public.match_events OWNER TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.match_events TO postgres, authenticated, service_role;
GRANT SELECT ON public.match_events TO anon;

-- 1) match_events hardening
-- Drop ALL potential existing policies
DROP POLICY IF EXISTS "Public can view match events" ON public.match_events;
DROP POLICY IF EXISTS "Authenticated users can insert match events" ON public.match_events;
DROP POLICY IF EXISTS "Authenticated users can update match events" ON public.match_events;
DROP POLICY IF EXISTS "Authenticated users can delete match events" ON public.match_events;
DROP POLICY IF EXISTS "Tournament owners can manage match events" ON public.match_events;
DROP POLICY IF EXISTS "Tournament owners and admins can manage match events" ON public.match_events;
DROP POLICY IF EXISTS "Owners and admins can manage match events" ON public.match_events;

ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;

-- Public can view all match events
CREATE POLICY "Public can view match events"
  ON public.match_events FOR SELECT
  TO public
  USING (true);

-- Owners and admins can manage match events
CREATE POLICY "Owners and admins can manage match events"
  ON public.match_events FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.matches m
      JOIN public.tournaments t ON t.id = m.tournament_id
      WHERE m.id = public.match_events.match_id
        AND (t.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.matches m
      JOIN public.tournaments t ON t.id = m.tournament_id
      WHERE m.id = public.match_events.match_id
        AND (t.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  );


-- 2) matches hardening
DROP POLICY IF EXISTS "Anyone can view matches in public tournaments" ON public.matches;
DROP POLICY IF EXISTS "Tournament owners can manage matches" ON public.matches;
DROP POLICY IF EXISTS "Tournament owners and admins can manage matches" ON public.matches;
DROP POLICY IF EXISTS "Anyone can view matches" ON public.matches;
DROP POLICY IF EXISTS "Owners and admins can manage matches" ON public.matches;

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

-- Public can view matches
CREATE POLICY "Anyone can view matches"
  ON public.matches FOR SELECT
  TO public
  USING (true);

-- Owners and admins can manage matches
CREATE POLICY "Owners and admins can manage matches"
  ON public.matches FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.tournaments t
      WHERE t.id = public.matches.tournament_id
      AND (t.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tournaments t
      WHERE t.id = public.matches.tournament_id
      AND (t.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  );


-- 3) tournaments hardening
DROP POLICY IF EXISTS "Anyone can view public tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "Tournament owners can manage their tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "Owners and admins can manage their tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "Owners can manage their tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "Anyone can view tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "Owners and admins can manage tournaments" ON public.tournaments;

ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;

-- Public can view tournaments
CREATE POLICY "Anyone can view tournaments"
  ON public.tournaments FOR SELECT
  TO public
  USING (true);

-- Owners and admins can manage tournaments
CREATE POLICY "Owners and admins can manage tournaments"
  ON public.tournaments FOR ALL
  TO authenticated
  USING (
    owner_id = auth.uid()
    OR is_admin(auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.organisations o
      WHERE o.id = public.tournaments.org_id
      AND (o.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  )
  WITH CHECK (
    owner_id = auth.uid()
    OR is_admin(auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.organisations o
      WHERE o.id = public.tournaments.org_id
      AND (o.owner_id = auth.uid() OR is_admin(auth.uid()))
    )
  );

-- 4) teams/players as well to be safe
DROP POLICY IF EXISTS "Anyone can view teams in public tournaments" ON public.teams;
DROP POLICY IF EXISTS "Tournament owners can manage teams" ON public.teams;
DROP POLICY IF EXISTS "Tournament owners and admins can manage teams" ON public.teams;
DROP POLICY IF EXISTS "Anyone can view teams" ON public.teams;
DROP POLICY IF EXISTS "Owners and admins can manage teams" ON public.teams;

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view teams" ON public.teams FOR SELECT TO public USING (true);
CREATE POLICY "Owners and admins can manage teams" ON public.teams FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.tournaments t WHERE t.id = public.teams.tournament_id AND (t.owner_id = auth.uid() OR is_admin(auth.uid()))));

DROP POLICY IF EXISTS "Anyone can view players in public tournaments" ON public.players;
DROP POLICY IF EXISTS "Tournament owners can manage players" ON public.players;
DROP POLICY IF EXISTS "Tournament owners and admins can manage players" ON public.players;
DROP POLICY IF EXISTS "Anyone can view players" ON public.players;
DROP POLICY IF EXISTS "Owners and admins can manage players" ON public.players;

ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view players" ON public.players FOR SELECT TO public USING (true);
CREATE POLICY "Owners and admins can manage players" ON public.players FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.teams teams JOIN public.tournaments t ON t.id = teams.tournament_id WHERE teams.id = public.players.team_id AND (t.owner_id = auth.uid() OR is_admin(auth.uid()))));

-- 5) Standings
DROP POLICY IF EXISTS "Anyone can view standings in public tournaments" ON public.standings;
DROP POLICY IF EXISTS "Tournament owners can manage standings" ON standings;
DROP POLICY IF EXISTS "Anyone can view standings" ON public.standings;
DROP POLICY IF EXISTS "Owners and admins can manage standings" ON public.standings;

ALTER TABLE public.standings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view standings" ON public.standings FOR SELECT TO public USING (true);
CREATE POLICY "Owners and admins can manage standings" ON public.standings FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.tournaments t WHERE t.id = public.standings.tournament_id AND (t.owner_id = auth.uid() OR is_admin(auth.uid()))));
