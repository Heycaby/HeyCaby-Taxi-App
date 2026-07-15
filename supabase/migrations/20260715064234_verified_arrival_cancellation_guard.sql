-- A server-verified arrival cannot be erased by an old or modified Rider
-- client. The request becomes a reviewable case; no automatic refund occurs.

CREATE OR REPLACE FUNCTION public.request_rider_cancellation(
  p_ride_id uuid, p_rider_token text DEFAULT NULL, p_reason text DEFAULT NULL,
  p_idempotency_key uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ride_requests%ROWTYPE; v public.ride_verification_state; case_id uuid;
DECLARE case_kind text;
BEGIN
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id FOR UPDATE;
  IF r.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','ride_not_found'); END IF;
  IF NOT private.fn_ride_rider_authorized(r,p_rider_token) THEN RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  IF NOT private.fn_ride_is_payment_protected(p_ride_id) THEN
    RETURN public.fn_rider_cancel_open_ride(p_ride_id,p_rider_token,p_reason)::jsonb;
  END IF;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=p_ride_id;
  IF r.status='in_progress' OR COALESCE(v.boarding_verified,false) OR COALESCE(v.arrival_verified,false) THEN
    case_kind := CASE WHEN r.status='in_progress' OR COALESCE(v.boarding_verified,false)
      THEN 'end_trip_early' ELSE 'payment_dispute' END;
    INSERT INTO public.ride_protection_cases(ride_id,case_type,opened_by_type,opened_by,reason)
    VALUES(p_ride_id,case_kind,'rider',auth.uid(),COALESCE(NULLIF(btrim(p_reason),''),
      CASE WHEN case_kind='end_trip_early' THEN 'Rider requested an early trip end'
           ELSE 'Rider requested cancellation after verified driver arrival' END))
    RETURNING id INTO case_id;
    PERFORM public.fn_ride_audit_append(p_ride_id,'cancellation.converted_to_case',auth.uid(),
      jsonb_build_object('case_id',case_id,'case_type',case_kind,'status',r.status,
        'arrival_verified',COALESCE(v.arrival_verified,false),'boarding_verified',COALESCE(v.boarding_verified,false)),
      'rider','rpc',p_ride_id);
    RETURN jsonb_build_object('ok',true,'status','support_review','case_id',case_id,
      'normal_cancellation_disabled',true,'automatic_refund',false);
  END IF;
  RETURN public.fn_rider_cancel_open_ride(p_ride_id,p_rider_token,p_reason)::jsonb;
END; $$;

CREATE OR REPLACE FUNCTION private.trg_enforce_protected_ride_transition()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v public.ride_verification_state; protected boolean;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
  protected := private.fn_ride_is_payment_protected(NEW.id);
  IF NOT protected THEN RETURN NEW; END IF;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=NEW.id;
  IF NEW.status='driver_arrived' AND private.fn_ride_verification_flag('ride_arrival_verification_enabled')
     AND NOT COALESCE(v.arrival_verified,false) THEN RAISE EXCEPTION 'arrival_verification_required' USING ERRCODE='P0001'; END IF;
  IF NEW.status='in_progress' AND private.fn_ride_verification_flag('boarding_pin_enabled')
     AND (NOT COALESCE(v.arrival_verified,false) OR NOT COALESCE(v.boarding_verified,false)) THEN
    RAISE EXCEPTION 'boarding_verification_required' USING ERRCODE='P0001';
  END IF;
  IF NEW.status='completed' AND private.fn_ride_verification_flag('verified_completion_enabled')
     AND (NOT COALESCE(v.completion_verified,false) OR COALESCE(v.risk_status,'blocked')<>'clear') THEN
    RAISE EXCEPTION 'completion_verification_required' USING ERRCODE='P0001';
  END IF;
  IF NEW.status='cancelled'
     AND private.fn_ride_verification_flag('ride_arrival_verification_enabled')
     AND (OLD.status='in_progress' OR COALESCE(v.arrival_verified,false)) THEN
    RAISE EXCEPTION 'verified_ride_requires_case_review' USING ERRCODE='P0001';
  END IF;
  RETURN NEW;
END; $$;

REVOKE ALL ON FUNCTION public.request_rider_cancellation(uuid,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_rider_cancellation(uuid,text,text,uuid) TO anon,authenticated,service_role;
REVOKE ALL ON FUNCTION private.trg_enforce_protected_ride_transition() FROM PUBLIC,anon,authenticated;
