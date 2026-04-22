-- Cascading driver matching: invites table, seed/expand batches, atomic accept.
-- Deploy to Supabase; enable Realtime for public.ride_request_invites if drivers should get instant UI.
-- Harden fn_seed / expand with rider identity checks when your auth model allows it.

-- ---------------------------------------------------------------------------
-- Columns (idempotent)
-- ---------------------------------------------------------------------------
ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS vehicle_category text NOT NULL DEFAULT 'standard';

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS accepts_pets boolean NOT NULL DEFAULT false;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS pet_friendly boolean NOT NULL DEFAULT false;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS vehicle_category text;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS booking_mode text;

COMMENT ON COLUMN public.drivers.vehicle_category IS 'standard|comfort|taxibus|wheelchair — rider supply + matching';
COMMENT ON COLUMN public.drivers.accepts_pets IS 'If true, driver may receive pet_friendly ride invites';

-- ---------------------------------------------------------------------------
-- Invites
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ride_request_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id uuid NOT NULL REFERENCES public.ride_requests (id) ON DELETE CASCADE,
  driver_id uuid NOT NULL REFERENCES public.drivers (id) ON DELETE CASCADE,
  batch_no int NOT NULL DEFAULT 1,
  invited_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'expired', 'accepted', 'superseded')),
  UNIQUE (ride_request_id, driver_id)
);

CREATE INDEX IF NOT EXISTS idx_ride_request_invites_ride
  ON public.ride_request_invites (ride_request_id);

CREATE INDEX IF NOT EXISTS idx_ride_request_invites_driver_pending
  ON public.ride_request_invites (driver_id)
  WHERE status = 'pending';

ALTER TABLE public.ride_request_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ride_request_invites_driver_select ON public.ride_request_invites;
CREATE POLICY ride_request_invites_driver_select
  ON public.ride_request_invites
  FOR SELECT
  TO authenticated
  USING (
    driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Seed / expand next batch (closest eligible drivers first)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_seed_ride_matching_batch (
  p_ride_request_id uuid,
  p_batch_size int DEFAULT 4,
  p_window_seconds int DEFAULT 30
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride record;
  v_pickup geography;
  v_next_batch int;
  v_inserted int;
BEGIN
  UPDATE public.ride_request_invites i
  SET status = 'expired'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.status = 'pending'
    AND i.expires_at <= now();

  SELECT r INTO v_ride FROM public.ride_requests r WHERE r.id = p_ride_request_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status IS DISTINCT FROM 'pending' THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_pending');
  END IF;

  v_pickup := v_ride.pickup_coords;
  IF v_pickup IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'no_pickup');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.status = 'pending'
      AND i.expires_at > now()
  ) THEN
    RETURN json_build_object('ok', true, 'skipped', true, 'reason', 'active_invites');
  END IF;

  SELECT COALESCE(MAX(i.batch_no), 0) + 1 INTO v_next_batch
  FROM public.ride_request_invites i
  WHERE i.ride_request_id = p_ride_request_id;

  IF v_next_batch > 20 THEN
    RETURN json_build_object('ok', false, 'error', 'max_batches');
  END IF;

  INSERT INTO public.ride_request_invites (
    ride_request_id, driver_id, batch_no, expires_at, status
  )
  SELECT
    p_ride_request_id,
    dl.driver_id,
    v_next_batch,
    now() + make_interval(secs => p_window_seconds),
    'pending'
  FROM public.driver_locations dl
  INNER JOIN public.drivers d ON d.id = dl.driver_id
  WHERE d.status = 'available'
    AND dl.updated_at > now() - interval '3 minutes'
    AND dl.latitude IS NOT NULL
    AND dl.longitude IS NOT NULL
    AND (
      v_ride.vehicle_category IS NULL
      OR trim(both from v_ride.vehicle_category::text) = ''
      OR lower(trim(both from d.vehicle_category::text)) = lower(trim(both from v_ride.vehicle_category::text))
    )
    AND (
      NOT COALESCE(v_ride.pet_friendly, false)
      OR COALESCE(d.accepts_pets, false)
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.ride_request_invites x
      WHERE x.ride_request_id = p_ride_request_id
        AND x.driver_id = dl.driver_id
    )
  ORDER BY ST_Distance(
    ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
    v_pickup
  ) ASC NULLS LAST
  LIMIT p_batch_size;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN json_build_object(
    'ok', true,
    'batch', v_next_batch,
    'invited', v_inserted
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Atomic accept (first valid invite wins)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_driver_accept_ride_invite (p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = v_driver_id
      AND i.status = 'pending'
      AND i.expires_at > now()
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'no_valid_invite');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'assigned',
    driver_id = v_driver_id,
    updated_at = now()
  WHERE rr.id = p_ride_request_id
    AND rr.status = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'race_lost');
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'superseded'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id <> v_driver_id
    AND i.status = 'pending';

  UPDATE public.ride_request_invites i
  SET status = 'accepted'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id = v_driver_id
    AND i.status = 'pending';

  RETURN json_build_object('ok', true);
END;
$$;

-- ---------------------------------------------------------------------------
-- Trigger: first batch right after rider inserts a pending request
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_ride_request_after_insert_matching ()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'pending' THEN
    BEGIN
      PERFORM public.fn_seed_ride_matching_batch(NEW.id, 4, 30);
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'fn_seed_ride_matching_batch skipped: %', SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ride_request_start_matching ON public.ride_requests;
CREATE TRIGGER ride_request_start_matching
AFTER INSERT ON public.ride_requests
FOR EACH ROW
EXECUTE PROCEDURE public.trg_ride_request_after_insert_matching ();

GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch (uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_accept_ride_invite (uuid) TO authenticated;
