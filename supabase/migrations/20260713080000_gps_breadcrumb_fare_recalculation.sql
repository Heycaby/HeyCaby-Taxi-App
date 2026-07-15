-- GPS breadcrumb recording + actual distance calculation + traffic overtime fare rule.
--
-- Fare model (Uber/Bolt-class):
--   1. Quoted fare is fixed — if the trip is faster, rider pays the quoted amount.
--   2. If the trip takes longer than estimated_duration_min + grace, traffic overtime kicks in.
--   3. Traffic overtime rate = 50% of the driver's registered waiting_rate per minute.
--   4. Pickup waiting fee (driver waits for rider) remains at full waiting_rate — unchanged.
--
-- Example:
--   Quoted fare: €30 (10km, 20min estimate)
--   Driver waiting rate: €1.00/min
--   Grace: 5 minutes
--   Actual trip: 40 minutes
--   Overtime: 40 - 20 - 5 = 15 minutes
--   Overtime rate: €1.00 × 50% = €0.50/min
--   Overtime fee: 15 × €0.50 = €7.50
--   Final fare: €30 + €7.50 = €37.50

-- ---------------------------------------------------------------------------
-- 1) GPS breadcrumb table — records driver location during in_progress rides.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ride_gps_track (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ride_request_id uuid NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  heading double precision,
  speed_mps double precision,
  accuracy_m double precision,
  recorded_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ride_gps_track_ride
  ON public.ride_gps_track(ride_request_id, recorded_at);

CREATE INDEX IF NOT EXISTS idx_ride_gps_track_driver
  ON public.ride_gps_track(driver_id, recorded_at);

-- RLS: drivers can insert their own GPS points; riders can read points for their ride.
ALTER TABLE public.ride_gps_track ENABLE ROW LEVEL SECURITY;

CREATE POLICY ride_gps_track_driver_insert
  ON public.ride_gps_track FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id IN (
      SELECT d.id FROM public.drivers d
      WHERE d.user_id = auth.uid()
    )
  );

CREATE POLICY ride_gps_track_driver_select
  ON public.ride_gps_track FOR SELECT
  TO authenticated
  USING (
    driver_id IN (
      SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
    )
    OR ride_request_id IN (
      SELECT rr.id FROM public.ride_requests rr
      WHERE rr.rider_id = auth.uid()
         OR rr.rider_identity_id IN (
           SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
         )
    )
  );

-- ---------------------------------------------------------------------------
-- 2) New columns on ride_requests for actual trip metrics + overtime.
-- ---------------------------------------------------------------------------
ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS actual_distance_km numeric,
  ADD COLUMN IF NOT EXISTS actual_duration_min numeric,
  ADD COLUMN IF NOT EXISTS traffic_overtime_minutes integer,
  ADD COLUMN IF NOT EXISTS traffic_overtime_fee_cents integer,
  ADD COLUMN IF NOT EXISTS traffic_grace_minutes integer NOT NULL DEFAULT 5;

COMMENT ON COLUMN public.ride_requests.actual_distance_km IS
  'Sum of haversine distance between GPS breadcrumbs during in_progress. NULL until trip completes.';
COMMENT ON COLUMN public.ride_requests.actual_duration_min IS
  'Actual trip duration in minutes (completed_at - started_at). NULL until trip completes.';
COMMENT ON COLUMN public.ride_requests.traffic_overtime_minutes IS
  'Minutes beyond estimated_duration_min + traffic_grace_minutes. 0 if trip was within estimate.';
COMMENT ON COLUMN public.ride_requests.traffic_overtime_fee_cents IS
  'Overtime fee in cents = overtime_minutes × (waiting_rate × 0.5). 0 if no overtime.';
COMMENT ON COLUMN public.ride_requests.traffic_grace_minutes IS
  'Grace period before traffic overtime kicks in. Default 5 minutes. Configurable per ride.';

-- ---------------------------------------------------------------------------
-- 3) Function: calculate actual distance from GPS breadcrumbs.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_calculate_actual_trip_distance(
  p_ride_request_id uuid
) RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH points AS (
    SELECT
      latitude,
      longitude,
      recorded_at,
      LAG(latitude) OVER (ORDER BY recorded_at) AS prev_lat,
      LAG(longitude) OVER (ORDER BY recorded_at) AS prev_lng
    FROM public.ride_gps_track
    WHERE ride_request_id = p_ride_request_id
    ORDER BY recorded_at
  ),
  segments AS (
    SELECT
      ST_Distance(
        ST_SetSRID(ST_MakePoint(prev_lng, prev_lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
      ) / 1000.0 AS segment_km
    FROM points
    WHERE prev_lat IS NOT NULL
      -- Reject GPS noise: skip segments > 5km (likely GPS jump/teleport)
      AND ST_Distance(
        ST_SetSRID(ST_MakePoint(prev_lng, prev_lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
      ) / 1000.0 < 5.0
  )
  SELECT jsonb_build_object(
    'actual_distance_km', COALESCE(round(sum(segment_km)::numeric, 2), 0),
    'point_count', count(*)
  )
  FROM segments;
$$;

REVOKE ALL ON FUNCTION public.fn_calculate_actual_trip_distance(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_calculate_actual_trip_distance(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4) Function: recalculate fare with traffic overtime rule.
--    Called by fn_driver_ride_complete after setting status = 'completed'.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_recalculate_ride_fare(
  p_ride_request_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_actual_distance_km numeric;
  v_actual_duration_min numeric;
  v_estimated_duration_min numeric;
  v_grace_minutes integer;
  v_overtime_minutes integer;
  v_waiting_rate numeric;
  v_overtime_rate numeric;
  v_overtime_fee_cents integer;
  v_base_fare numeric;
  v_final_fare numeric;
  v_distance_result jsonb;
BEGIN
  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  -- Calculate actual distance from GPS breadcrumbs.
  v_distance_result := public.fn_calculate_actual_trip_distance(p_ride_request_id);
  v_actual_distance_km := COALESCE(
    (v_distance_result->>'actual_distance_km')::numeric,
    v_ride.estimated_distance_km,
    0
  );

  -- Calculate actual duration from timestamps.
  IF v_ride.started_at IS NOT NULL AND v_ride.completed_at IS NOT NULL THEN
    v_actual_duration_min := round(
      extract(epoch from (v_ride.completed_at - v_ride.started_at)) / 60.0
    )::numeric;
  ELSE
    v_actual_duration_min := v_ride.estimated_duration_min;
  END IF;

  -- Grace period (default 5 minutes, configurable per ride).
  v_grace_minutes := COALESCE(v_ride.traffic_grace_minutes, 5);

  -- Estimated duration (fallback to 0 if missing).
  v_estimated_duration_min := COALESCE(v_ride.estimated_duration_min, 0);

  -- Calculate traffic overtime.
  v_overtime_minutes := GREATEST(
    0,
    CEIL(v_actual_duration_min - v_estimated_duration_min - v_grace_minutes)::int
  );

  -- Driver's waiting rate from ride snapshot (set when driver arrived).
  v_waiting_rate := COALESCE(v_ride.waiting_rate_per_minute, 0);

  -- Traffic overtime rate = 50% of waiting rate.
  v_overtime_rate := v_waiting_rate * 0.5;

  -- Overtime fee in cents.
  v_overtime_fee_cents := round(v_overtime_minutes * v_overtime_rate * 100)::int;

  -- Base fare: the quoted/offered fare (fixed — rider pays this regardless).
  v_base_fare := COALESCE(
    v_ride.quoted_fare,
    v_ride.offered_fare,
    v_ride.marketplace_offered_fare,
    v_ride.estimated_fare,
    v_ride.estimated_price,
    0
  );

  -- Final fare = base + traffic overtime fee.
  -- Pickup waiting fee is added separately at receipt time (already in waiting_fee_cents).
  v_final_fare := v_base_fare + (v_overtime_fee_cents / 100.0);

  -- Update ride with actual metrics + recalculated fare.
  UPDATE public.ride_requests rr
  SET
    actual_distance_km = v_actual_distance_km,
    actual_duration_min = v_actual_duration_min,
    traffic_overtime_minutes = v_overtime_minutes,
    traffic_overtime_fee_cents = v_overtime_fee_cents,
    final_fare = v_final_fare
  WHERE rr.id = p_ride_request_id;

  RETURN jsonb_build_object(
    'ok', true,
    'actual_distance_km', v_actual_distance_km,
    'actual_duration_min', v_actual_duration_min,
    'estimated_duration_min', v_estimated_duration_min,
    'overtime_minutes', v_overtime_minutes,
    'overtime_rate_per_min', v_overtime_rate,
    'overtime_fee_cents', v_overtime_fee_cents,
    'base_fare', v_base_fare,
    'final_fare', v_final_fare
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_recalculate_ride_fare(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_recalculate_ride_fare(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 5) Patch fn_driver_ride_complete to call fare recalculation after completion.
--    We use a trigger approach to avoid modifying the existing function body
--    (which may be updated by future migrations). The trigger fires AFTER
--    the status changes to 'completed' and calls fn_recalculate_ride_fare.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_recalculate_fare_on_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status <> 'completed' AND NEW.status = 'completed' THEN
    -- Recalculate fare with actual distance + traffic overtime.
    PERFORM public.fn_recalculate_ride_fare(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_recalculate_fare_on_complete() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_fare_recalculation ON public.ride_requests;
CREATE TRIGGER trg_fare_recalculation
  AFTER UPDATE OF status ON public.ride_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_recalculate_fare_on_complete();

-- ---------------------------------------------------------------------------
-- 6) Function: batch insert GPS breadcrumbs (called by driver app).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_insert_ride_gps_batch(
  p_ride_request_id uuid,
  p_points jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_point jsonb;
BEGIN
  -- Resolve driver from the ride request.
  SELECT driver_id INTO v_driver_id
  FROM public.ride_requests
  WHERE id = p_ride_request_id;

  IF v_driver_id IS NULL THEN RETURN; END IF;

  -- Verify caller is the driver assigned to this ride.
  IF NOT EXISTS (
    SELECT 1 FROM public.drivers d
    WHERE d.id = v_driver_id AND d.user_id = auth.uid()
  ) THEN RETURN; END IF;

  -- Only record GPS during in_progress.
  IF NOT EXISTS (
    SELECT 1 FROM public.ride_requests
    WHERE id = p_ride_request_id AND status = 'in_progress'
  ) THEN RETURN; END IF;

  FOR v_point IN SELECT jsonb_array_elements(p_points)
  LOOP
    INSERT INTO public.ride_gps_track (
      ride_request_id,
      driver_id,
      latitude,
      longitude,
      heading,
      speed_mps,
      accuracy_m,
      recorded_at
    ) VALUES (
      p_ride_request_id,
      v_driver_id,
      (v_point->>'lat')::double precision,
      (v_point->>'lng')::double precision,
      NULLIF(v_point->>'heading', '')::double precision,
      NULLIF(v_point->>'speed', '')::double precision,
      NULLIF(v_point->>'accuracy', '')::double precision,
      (v_point->>'recorded_at')::timestamptz
    );
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_insert_ride_gps_batch(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_insert_ride_gps_batch(uuid, jsonb) TO authenticated;

-- ---------------------------------------------------------------------------
-- 7) Function: get fare breakdown for rider receipt.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_ride_fare_breakdown(
  p_ride_request_id uuid
) RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'quoted_fare', COALESCE(rr.quoted_fare, rr.offered_fare, rr.marketplace_offered_fare, rr.estimated_fare, 0),
    'final_fare', COALESCE(rr.final_fare, rr.quoted_fare, rr.offered_fare, rr.marketplace_offered_fare, rr.estimated_fare, 0),
    'estimated_distance_km', COALESCE(rr.estimated_distance_km, 0),
    'actual_distance_km', COALESCE(rr.actual_distance_km, 0),
    'estimated_duration_min', COALESCE(rr.estimated_duration_min, 0),
    'actual_duration_min', COALESCE(rr.actual_duration_min, 0),
    'traffic_overtime_minutes', COALESCE(rr.traffic_overtime_minutes, 0),
    'traffic_overtime_fee_cents', COALESCE(rr.traffic_overtime_fee_cents, 0),
    'waiting_fee_cents', CASE WHEN COALESCE(rr.waiting_fee_waived, false) THEN 0 ELSE COALESCE(rr.waiting_fee_cents, 0) END,
    'waiting_rate_per_minute', COALESCE(rr.waiting_rate_per_minute, 0),
    'traffic_grace_minutes', COALESCE(rr.traffic_grace_minutes, 5),
    'tip_amount_eur', COALESCE(rr.tip_amount_eur, 0),
    'total_amount_eur', COALESCE(rr.total_amount_eur, 0)
  )
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;
$$;

REVOKE ALL ON FUNCTION public.fn_get_ride_fare_breakdown(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_get_ride_fare_breakdown(uuid) TO authenticated;
