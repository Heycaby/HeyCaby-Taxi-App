CREATE TABLE IF NOT EXISTS public.saved_trips (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_identity_id uuid NOT NULL,
  label       text NOT NULL DEFAULT '',
  pickup_address      text NOT NULL,
  pickup_latitude     double precision NOT NULL,
  pickup_longitude    double precision NOT NULL,
  destination_address text NOT NULL,
  destination_latitude  double precision NOT NULL,
  destination_longitude double precision NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  used_at     timestamptz
);

ALTER TABLE public.saved_trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS riders_select_saved_trips ON public.saved_trips;
CREATE POLICY riders_select_saved_trips ON public.saved_trips
  FOR SELECT USING (true);

DROP POLICY IF EXISTS riders_insert_saved_trips ON public.saved_trips;
CREATE POLICY riders_insert_saved_trips ON public.saved_trips
  FOR INSERT WITH CHECK (rider_identity_id IS NOT NULL);

DROP POLICY IF EXISTS riders_update_saved_trips ON public.saved_trips;
CREATE POLICY riders_update_saved_trips ON public.saved_trips
  FOR UPDATE USING (rider_identity_id IS NOT NULL)
  WITH CHECK (rider_identity_id IS NOT NULL);

DROP POLICY IF EXISTS riders_delete_saved_trips ON public.saved_trips;
CREATE POLICY riders_delete_saved_trips ON public.saved_trips
  FOR DELETE USING (rider_identity_id IS NOT NULL);

DROP POLICY IF EXISTS service_role_manage_saved_trips ON public.saved_trips;
CREATE POLICY service_role_manage_saved_trips ON public.saved_trips
  FOR ALL USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS saved_trips_rider_identity_id_idx
  ON public.saved_trips (rider_identity_id);
