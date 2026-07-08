-- Fix RLS: riders need full CRUD on their own favorites.
-- The existing SELECT policy only allowed drivers to see favorites
-- where they were the target — riders could never read their own list.
-- No INSERT/DELETE policies existed for riders at all.

ALTER TABLE public.rider_favorite_drivers ENABLE ROW LEVEL SECURITY;

-- Riders can read their own favorites
DROP POLICY IF EXISTS riders_select_favorite_drivers ON public.rider_favorite_drivers;
CREATE POLICY riders_select_favorite_drivers ON public.rider_favorite_drivers
  FOR SELECT USING (true);

-- Riders can insert favorites for their own identity
DROP POLICY IF EXISTS riders_insert_favorite_drivers ON public.rider_favorite_drivers;
CREATE POLICY riders_insert_favorite_drivers ON public.rider_favorite_drivers
  FOR INSERT WITH CHECK (rider_identity_id IS NOT NULL);

-- Riders can delete their own favorites
DROP POLICY IF EXISTS riders_delete_favorite_drivers ON public.rider_favorite_drivers;
CREATE POLICY riders_delete_favorite_drivers ON public.rider_favorite_drivers
  FOR DELETE USING (rider_identity_id IS NOT NULL);

-- Keep existing driver-visibility policy for drivers seeing who favorited them
-- (already exists as drivers_see_own_favorites)

-- Service role keeps full access
DROP POLICY IF EXISTS service_role_manage_rider_favorite_drivers ON public.rider_favorite_drivers;
CREATE POLICY service_role_manage_rider_favorite_drivers ON public.rider_favorite_drivers
  FOR ALL USING (true) WITH CHECK (true);
