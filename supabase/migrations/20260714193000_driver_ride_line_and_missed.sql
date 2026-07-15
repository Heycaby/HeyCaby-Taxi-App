-- Driver ride line: missed opportunity ledger + generalized next-ride queue RPC.

CREATE TABLE IF NOT EXISTS public.driver_missed_opportunities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  ride_request_id uuid REFERENCES public.ride_requests(id) ON DELETE SET NULL,
  pickup_zone_name text,
  destination_zone_name text,
  offered_fare numeric,
  missed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS driver_missed_opportunities_driver_missed_at_idx
  ON public.driver_missed_opportunities (driver_id, missed_at DESC);

ALTER TABLE public.driver_missed_opportunities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_missed_opportunities_select_own
  ON public.driver_missed_opportunities;
CREATE POLICY driver_missed_opportunities_select_own
  ON public.driver_missed_opportunities
  FOR SELECT
  TO authenticated
  USING (
    driver_id IN (
      SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
    )
  );

CREATE OR REPLACE FUNCTION public.fn_driver_record_missed_opportunity(
  p_ride_request_id uuid,
  p_pickup_zone_name text DEFAULT NULL,
  p_destination_zone_name text DEFAULT NULL,
  p_offered_fare numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'driver_not_found');
  END IF;

  IF p_ride_request_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.driver_missed_opportunities m
    WHERE m.driver_id = v_driver_id
      AND m.ride_request_id = p_ride_request_id
      AND m.missed_at >= now() - interval '6 hours'
  ) THEN
    RETURN jsonb_build_object('ok', true, 'deduped', true);
  END IF;

  INSERT INTO public.driver_missed_opportunities (
    driver_id,
    ride_request_id,
    pickup_zone_name,
    destination_zone_name,
    offered_fare
  ) VALUES (
    v_driver_id,
    p_ride_request_id,
    nullif(trim(p_pickup_zone_name), ''),
    nullif(trim(p_destination_zone_name), ''),
    p_offered_fare
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_missed_opportunities_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_count int;
  v_total numeric;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'count_today', 0, 'fare_total_today', 0);
  END IF;

  SELECT count(*)::int, coalesce(sum(m.offered_fare), 0)
  INTO v_count, v_total
  FROM public.driver_missed_opportunities m
  WHERE m.driver_id = v_driver_id
    AND m.missed_at >= date_trunc('day', now());

  RETURN jsonb_build_object(
    'ok', true,
    'count_today', v_count,
    'fare_total_today', v_total
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_missed_opportunities_list(
  p_limit int DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_items jsonb;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'items', '[]'::jsonb);
  END IF;

  SELECT coalesce(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.missed_at DESC), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      m.id,
      m.ride_request_id,
      m.pickup_zone_name,
      m.destination_zone_name,
      m.offered_fare,
      m.missed_at
    FROM public.driver_missed_opportunities m
    WHERE m.driver_id = v_driver_id
    ORDER BY m.missed_at DESC
    LIMIT greatest(1, least(p_limit, 100))
  ) t;

  RETURN jsonb_build_object('ok', true, 'items', v_items);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_next_ride_queue(
  p_active_ride_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_row public.ride_requests%ROWTYPE;
  v_pickup_zone text;
  v_dest_zone text;
  v_fare numeric;
  v_pickup_min int;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('has_queued', false, 'reason', 'not_a_driver');
  END IF;

  SELECT rr.* INTO v_row
  FROM public.ride_requests rr
  WHERE rr.driver_id = v_driver_id
    AND rr.status IN ('accepted', 'assigned', 'driver_en_route')
    AND (
      COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) = true
      OR COALESCE((rr.dispatch_state->>'reserved_for_next_ride')::boolean, false) = true
      OR nullif(rr.dispatch_state->>'queued_after_ride_id', '') IS NOT NULL
    )
    AND (p_active_ride_id IS NULL OR rr.id::text IS DISTINCT FROM p_active_ride_id::text)
  ORDER BY rr.accepted_at ASC NULLS LAST, rr.created_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('has_queued', false);
  END IF;

  SELECT bz1.name_display, bz2.name_display
  INTO v_pickup_zone, v_dest_zone
  FROM public.ride_requests rr
  LEFT JOIN public.bubble_zones bz1 ON bz1.id = rr.pickup_zone_id
  LEFT JOIN public.bubble_zones bz2 ON bz2.id = rr.destination_zone_id
  WHERE rr.id = v_row.id;

  v_fare := coalesce(
    v_row.offered_fare,
    v_row.marketplace_offered_fare,
    v_row.estimated_fare,
    v_row.quoted_fare
  );
  v_pickup_min := COALESCE(
    (v_row.dispatch_state->>'estimated_pickup_minutes')::int, 15
  );

  RETURN jsonb_build_object(
    'has_queued', true,
    'ride_id', v_row.id,
    'status', v_row.status,
    'booking_mode', v_row.booking_mode,
    'pickup_address', v_row.pickup_address,
    'destination_address', v_row.destination_address,
    'pickup_zone_name', v_pickup_zone,
    'destination_zone_name', v_dest_zone,
    'offered_fare', v_fare,
    'queued_after_ride_id', v_row.dispatch_state->>'queued_after_ride_id',
    'estimated_pickup_minutes', v_pickup_min,
    'pickup_available_min', GREATEST(v_pickup_min - 3, 1),
    'pickup_available_max', v_pickup_min + 5
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_driver_record_missed_opportunity(uuid, text, text, numeric)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_missed_opportunities_summary()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_missed_opportunities_list(int)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_next_ride_queue(uuid)
  TO authenticated, service_role;
