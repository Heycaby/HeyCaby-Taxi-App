-- Backend Flow Blueprint: Ride Swap / Ritwissel Contract (CTO launch rule)
-- Source: docs/HEYCABY_BACKEND_FLOW_BLUEPRINT.md
-- offer_ride_swap: launch-safe eligibility (scheduled + accepted only) + audit.
-- claim_ride_swap: lock ride row too, verify ride still owned/accepted/not
--   started, notify rider (new driver/vehicle/plate) + both drivers + audit.
-- cancel_ride_swap: audit trail.
-- All functions exist and are replaced in place; no new tables needed
-- (ride_swaps already exists with the full column set).

-- 1) Offer: launch rule = scheduled ride, status accepted, >15 min out
CREATE OR REPLACE FUNCTION public.offer_ride_swap(
  _driver_id uuid,
  _ride_id uuid,
  _reason text DEFAULT 'other'::text,
  _detail text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_ride ride_requests%ROWTYPE; v_urg text; v_exp timestamptz; v_mins numeric;
  v_sid uuid; v_plat float8; v_plng float8; v_dlat float8; v_dlng float8;
BEGIN
  SELECT * INTO v_ride FROM ride_requests WHERE id=_ride_id AND driver_id=_driver_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','not_your_ride'); END IF;

  -- CTO launch rule: only scheduled rides, only status accepted (no
  -- driver_arrived swaps at launch), ride not started/cancelled/completed.
  IF v_ride.status <> 'accepted' THEN
    RETURN jsonb_build_object('success',false,'error','wrong_status:'||v_ride.status); END IF;
  IF NOT COALESCE(v_ride.is_scheduled,false) OR v_ride.scheduled_pickup_at IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','not_scheduled'); END IF;
  IF EXISTS(SELECT 1 FROM ride_swaps WHERE ride_request_id=_ride_id AND status='open') THEN
    RETURN jsonb_build_object('success',false,'error','already_listed'); END IF;

  v_mins := EXTRACT(EPOCH FROM (v_ride.scheduled_pickup_at-now()))/60;
  IF v_mins > 240 THEN v_urg:='standard'; v_exp:=v_ride.scheduled_pickup_at-interval'45 min';
  ELSIF v_mins > 120 THEN v_urg:='moderate'; v_exp:=v_ride.scheduled_pickup_at-interval'30 min';
  ELSIF v_mins > 45 THEN v_urg:='urgent'; v_exp:=v_ride.scheduled_pickup_at-interval'20 min';
  ELSIF v_mins > 15 THEN v_urg:='emergency'; v_exp:=v_ride.scheduled_pickup_at-interval'10 min';
  ELSE RETURN jsonb_build_object('success',false,'error','too_late','mins',ROUND(v_mins)); END IF;

  SELECT ST_Y(pickup_coords::geometry),ST_X(pickup_coords::geometry),
         ST_Y(destination_coords::geometry),ST_X(destination_coords::geometry)
  INTO v_plat,v_plng,v_dlat,v_dlng FROM ride_requests WHERE id=_ride_id;

  INSERT INTO ride_swaps(
    ride_request_id,offering_driver_id,reason,reason_note,swap_reason_category,
    urgency,status,pickup_at,swap_expires_at,swap_listed_at,
    pickup_address,destination_address,pickup_lat,pickup_lng,destination_lat,destination_lng,
    estimated_distance_km,estimated_duration_min,ride_type,payment_methods
  ) VALUES(
    _ride_id,_driver_id,_reason,_detail,_reason,
    v_urg,'open',v_ride.scheduled_pickup_at,v_exp,now(),
    v_ride.pickup_address,v_ride.destination_address,
    v_plat,v_plng,v_dlat,v_dlng,
    v_ride.estimated_distance_km,v_ride.estimated_duration_min,
    v_ride.ride_type,v_ride.payment_methods
  ) RETURNING id INTO v_sid;

  UPDATE ride_requests SET swap_listed=true,swap_listed_at=now() WHERE id=_ride_id;

  PERFORM public.fn_ride_audit_append(
    _ride_id, 'swap.offered', _driver_id,
    jsonb_build_object('swap_id', v_sid, 'urgency', v_urg,
                       'expires_at', v_exp, 'reason', _reason),
    'driver', 'rpc', _ride_id
  );

  RETURN jsonb_build_object('success',true,'swap_id',v_sid,'urgency',v_urg,
    'expires_at',v_exp,'mins_until',ROUND(v_mins));
END; $$;

-- 2) Claim: atomic over swap + ride rows, full notification chain, audit
CREATE OR REPLACE FUNCTION public.claim_ride_swap(_claimer_id uuid, _swap_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_s ride_swaps%ROWTYPE;
  v_chk jsonb;
  v_d drivers%ROWTYPE;
  v_new drivers%ROWTYPE;
  v_ride ride_requests%ROWTYPE;
  v_rider_target text;
BEGIN
  SELECT * INTO v_s FROM ride_swaps WHERE id=_swap_id FOR UPDATE SKIP LOCKED;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','not_available'); END IF;
  IF v_s.status!='open' THEN RETURN jsonb_build_object('success',false,'error','swap_is_'||v_s.status); END IF;
  IF now()>v_s.swap_expires_at THEN
    UPDATE ride_swaps SET status='expired',updated_at=now() WHERE id=_swap_id;
    RETURN jsonb_build_object('success',false,'error','expired'); END IF;
  IF _claimer_id=v_s.offering_driver_id THEN RETURN jsonb_build_object('success',false,'error','own_swap'); END IF;

  SELECT * INTO v_new FROM drivers WHERE id=_claimer_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','not_a_driver'); END IF;
  IF v_new.compliance_status!='compliant' THEN RETURN jsonb_build_object('success',false,'error','not_compliant'); END IF;

  v_chk := can_driver_take_swap(_claimer_id,v_s.pickup_at,v_s.estimated_duration_min);
  IF NOT (v_chk->>'can_take')::boolean THEN RETURN v_chk||jsonb_build_object('success',false); END IF;

  -- Lock the ride row and verify swap is still valid against live ride state.
  SELECT * INTO v_ride FROM ride_requests WHERE id=v_s.ride_request_id FOR UPDATE;
  IF NOT FOUND THEN
    UPDATE ride_swaps SET status='cancelled',updated_at=now() WHERE id=_swap_id;
    RETURN jsonb_build_object('success',false,'error','ride_missing');
  END IF;
  IF v_ride.driver_id IS DISTINCT FROM v_s.offering_driver_id
     OR v_ride.status <> 'accepted'
     OR v_ride.started_at IS NOT NULL THEN
    UPDATE ride_swaps SET status='cancelled',updated_at=now() WHERE id=_swap_id;
    UPDATE ride_requests SET swap_listed=false WHERE id=v_s.ride_request_id;
    RETURN jsonb_build_object('success',false,'error','ride_no_longer_swappable');
  END IF;

  UPDATE ride_requests SET driver_id=_claimer_id,accepted_at=now(),updated_at=now(),
    swap_listed=false,swap_completed=true WHERE id=v_s.ride_request_id;

  UPDATE ride_swaps SET status='completed',accepting_driver_id=_claimer_id,
    claimed_by_driver_id=_claimer_id,claimed_at=now(),
    swap_accepted_at=now(),swap_completed_at=now(),rider_notified=true,updated_at=now()
  WHERE id=_swap_id;

  -- Keep chat context pointed at the new driver.
  UPDATE public.conversations
  SET driver_id = _claimer_id
  WHERE ride_request_id = v_s.ride_request_id;

  -- Rider trust rule: rider must know the new driver, vehicle, and plate.
  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'driver_changed',
    'Your driver has changed',
    'New driver: ' || COALESCE(v_new.full_name, 'HeyCaby driver')
      || CASE WHEN COALESCE(v_new.vehicle_make,'') <> ''
           THEN '. Vehicle: ' || COALESCE(v_new.vehicle_colour || ' ', '')
                || v_new.vehicle_make || ' ' || COALESCE(v_new.vehicle_model, '')
           ELSE '' END
      || CASE WHEN COALESCE(v_new.vehicle_plate,'') <> ''
           THEN '. Plate: ' || v_new.vehicle_plate ELSE '' END,
    jsonb_build_object(
      'type', 'driver_changed',
      'ride_request_id', v_s.ride_request_id,
      'swap_id', _swap_id,
      'driver_name', v_new.full_name,
      'vehicle_make', v_new.vehicle_make,
      'vehicle_model', v_new.vehicle_model,
      'vehicle_colour', v_new.vehicle_colour,
      'vehicle_plate', v_new.vehicle_plate
    ),
    'critical'
  );

  -- Original driver: ride swapped.
  SELECT * INTO v_d FROM drivers WHERE id=v_s.offering_driver_id;
  PERFORM public.fn_ride_event_notify(
    'driver', v_d.user_id::text, 'ride_swapped',
    'Ride swapped successfully',
    COALESCE(v_new.full_name, 'Another driver') || ' is now assigned to this ride.',
    jsonb_build_object(
      'type', 'ride_swapped',
      'ride_request_id', v_s.ride_request_id,
      'swap_id', _swap_id
    )
  );

  -- Claiming driver: ride claimed.
  PERFORM public.fn_ride_event_notify(
    'driver', v_new.user_id::text, 'ride_claimed',
    'Ride claimed',
    'It has been added to your scheduled rides.',
    jsonb_build_object(
      'type', 'ride_claimed',
      'ride_request_id', v_s.ride_request_id,
      'swap_id', _swap_id
    )
  );

  PERFORM public.fn_ride_audit_append(
    v_s.ride_request_id, 'swap.claimed', _claimer_id,
    jsonb_build_object(
      'swap_id', _swap_id,
      'previous_driver_id', v_s.offering_driver_id,
      'new_driver_id', _claimer_id
    ),
    'driver', 'rpc', v_s.ride_request_id
  );

  RETURN jsonb_build_object('success',true,'ride_request_id',v_s.ride_request_id,
    'pickup_address',v_s.pickup_address,'pickup_at',v_s.pickup_at,'km',v_s.estimated_distance_km);
END; $$;

-- 3) Cancel: audit trail
CREATE OR REPLACE FUNCTION public.cancel_ride_swap(_driver_id uuid, _swap_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_rid uuid;
BEGIN
  UPDATE ride_swaps SET status='cancelled',updated_at=now()
  WHERE id=_swap_id AND offering_driver_id=_driver_id AND status='open'
  RETURNING ride_request_id INTO v_rid;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','cannot_cancel'); END IF;
  UPDATE ride_requests SET swap_listed=false WHERE id=v_rid;

  PERFORM public.fn_ride_audit_append(
    v_rid, 'swap.cancelled', _driver_id,
    jsonb_build_object('swap_id', _swap_id),
    'driver', 'rpc', v_rid
  );

  RETURN jsonb_build_object('success',true);
END; $$;
