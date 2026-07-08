-- ============================================================
-- Enhance rider_favorite_drivers for CTO Favorite Driver System
-- Adds: source_ride_request_id, rating_id, is_active, removed_at
-- Changes unique constraint to partial (active only)
-- Updates fn_rider_can_add_favorite to count active only
-- ============================================================

-- 1. Add new columns
ALTER TABLE public.rider_favorite_drivers
  ADD COLUMN IF NOT EXISTS source_ride_request_id uuid REFERENCES public.ride_requests(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS rating_id uuid REFERENCES public.ride_ratings(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS removed_at timestamptz;

-- 2. Backfill existing rows as active
UPDATE public.rider_favorite_drivers SET is_active = true WHERE is_active IS NULL;

-- 3. Drop old unique constraint and replace with partial unique (active only)
ALTER TABLE public.rider_favorite_drivers
  DROP CONSTRAINT IF EXISTS rider_favorite_drivers_rider_identity_id_driver_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS rider_favorite_drivers_active_unique
  ON public.rider_favorite_drivers (rider_identity_id, driver_id)
  WHERE is_active = true;

-- 4. Update fn_rider_can_add_favorite to count only active favorites
CREATE OR REPLACE FUNCTION public.fn_rider_can_add_favorite(p_rider_identity_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT COUNT(*) < 10
  FROM public.rider_favorite_drivers
  WHERE rider_identity_id = p_rider_identity_id
    AND is_active = true;
$function$;
