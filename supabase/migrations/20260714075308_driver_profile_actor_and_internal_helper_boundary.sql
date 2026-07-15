-- Preserve released Driver profile RPC signatures while making the actor
-- binding canonical. Existing implementation bodies move to the unexposed
-- private schema; public wrappers accept only the authenticated user's id (or
-- a signed service-role request for operational compatibility).

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.fn_driver_user_actor_authorized(
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, auth
AS $$
  SELECT p_user_id IS NOT NULL
    AND (
      p_user_id = auth.uid()
      OR COALESCE(auth.jwt() ->> 'role', '') = 'service_role'
    );
$$;

REVOKE ALL ON FUNCTION private.fn_driver_user_actor_authorized(uuid)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.fn_log_driver_profile_actor_denied(
  p_command text,
  p_requested_user_id uuid
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = private, pg_catalog
AS $$
  INSERT INTO private.domain_security_events(
    domain, event, actor_user_id, object_id, metadata
  ) VALUES (
    'driver_profile',
    'actor_mismatch',
    auth.uid(),
    p_requested_user_id,
    jsonb_build_object(
      'command', p_command,
      'jwt_role', COALESCE(auth.jwt() ->> 'role', '')
    )
  );
$$;

REVOKE ALL ON FUNCTION private.fn_log_driver_profile_actor_denied(text, uuid)
  FROM PUBLIC, anon, authenticated, service_role;

ALTER FUNCTION public.get_or_create_driver(uuid) SET SCHEMA private;
ALTER FUNCTION public.save_driver_profile(
  uuid, text, text, text, text, text
) SET SCHEMA private;
ALTER FUNCTION public.save_driver_preferences(
  uuid, integer, text[], boolean, numeric, boolean,
  boolean, boolean, boolean, boolean
) SET SCHEMA private;
ALTER FUNCTION public.save_vehicle_info(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  text, text, text, text, text, text, text, boolean, boolean, boolean, boolean
) SET SCHEMA private;
ALTER FUNCTION public.verify_vehicle_and_unlock(uuid, text) SET SCHEMA private;
ALTER FUNCTION public.mark_welcome_modal_seen(uuid, boolean) SET SCHEMA private;
ALTER FUNCTION public.update_profile_completion(uuid, text) SET SCHEMA private;
ALTER FUNCTION public.upsert_push_token(uuid, text, text) SET SCHEMA private;
ALTER FUNCTION public.refresh_driver_badge(uuid) SET SCHEMA private;

CREATE FUNCTION public.get_or_create_driver(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_catalog
AS $$
BEGIN
  IF NOT private.fn_driver_user_actor_authorized(p_user_id) THEN
    PERFORM private.fn_log_driver_profile_actor_denied(
      'get_or_create_driver', p_user_id
    );
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;
  RETURN private.get_or_create_driver(p_user_id);
END;
$$;

CREATE FUNCTION public.save_driver_profile(
  p_user_id uuid,
  p_full_name text DEFAULT NULL,
  p_profile_photo_url text DEFAULT NULL,
  p_bio text DEFAULT NULL,
  p_gender text DEFAULT NULL,
  p_locale text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_catalog
AS $$
BEGIN
  IF NOT private.fn_driver_user_actor_authorized(p_user_id) THEN
    PERFORM private.fn_log_driver_profile_actor_denied(
      'save_driver_profile', p_user_id
    );
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;
  RETURN private.save_driver_profile(
    p_user_id, p_full_name, p_profile_photo_url, p_bio, p_gender, p_locale
  );
END;
$$;

CREATE FUNCTION public.save_driver_preferences(
  p_user_id uuid,
  p_pickup_distance_km integer DEFAULT NULL,
  p_payment_methods text[] DEFAULT NULL,
  p_auto_accept_enabled boolean DEFAULT NULL,
  p_auto_accept_min_fare numeric DEFAULT NULL,
  p_radar_enabled boolean DEFAULT NULL,
  p_is_electric boolean DEFAULT NULL,
  p_is_pet_friendly boolean DEFAULT NULL,
  p_is_wheelchair_accessible boolean DEFAULT NULL,
  p_is_female_driver boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_catalog
AS $$
BEGIN
  IF NOT private.fn_driver_user_actor_authorized(p_user_id) THEN
    PERFORM private.fn_log_driver_profile_actor_denied(
      'save_driver_preferences', p_user_id
    );
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;
  RETURN private.save_driver_preferences(
    p_user_id, p_pickup_distance_km, p_payment_methods,
    p_auto_accept_enabled, p_auto_accept_min_fare, p_radar_enabled,
    p_is_electric, p_is_pet_friendly, p_is_wheelchair_accessible,
    p_is_female_driver
  );
END;
$$;

CREATE FUNCTION public.save_vehicle_info(
  p_user_id uuid,
  p_vehicle_plate text,
  p_vehicle_plate_entered text,
  p_rdw_voertuigsoort text DEFAULT NULL,
  p_rdw_merk text DEFAULT NULL,
  p_rdw_handelsbenaming text DEFAULT NULL,
  p_rdw_eerste_kleur text DEFAULT NULL,
  p_rdw_tweede_kleur text DEFAULT NULL,
  p_rdw_datum_eerste_toelating text DEFAULT NULL,
  p_rdw_aantal_zitplaatsen text DEFAULT NULL,
  p_rdw_inrichting text DEFAULT NULL,
  p_rdw_massa_ledig_voertuig text DEFAULT NULL,
  p_rdw_wam_verzekerd text DEFAULT NULL,
  p_rdw_apk_vervaldatum text DEFAULT NULL,
  p_vehicle_verification_status text DEFAULT 'unverified',
  p_vehicle_type text DEFAULT 'sedan',
  p_vehicle_year text DEFAULT NULL,
  p_vehicle_colour text DEFAULT NULL,
  p_passenger_seats text DEFAULT NULL,
  p_is_wheelchair_accessible boolean DEFAULT false,
  p_is_electric boolean DEFAULT false,
  p_is_pet_friendly boolean DEFAULT false,
  p_is_female_driver boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_catalog
AS $$
BEGIN
  IF NOT private.fn_driver_user_actor_authorized(p_user_id) THEN
    PERFORM private.fn_log_driver_profile_actor_denied(
      'save_vehicle_info', p_user_id
    );
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;
  RETURN private.save_vehicle_info(
    p_user_id, p_vehicle_plate, p_vehicle_plate_entered,
    p_rdw_voertuigsoort, p_rdw_merk, p_rdw_handelsbenaming,
    p_rdw_eerste_kleur, p_rdw_tweede_kleur, p_rdw_datum_eerste_toelating,
    p_rdw_aantal_zitplaatsen, p_rdw_inrichting,
    p_rdw_massa_ledig_voertuig, p_rdw_wam_verzekerd,
    p_rdw_apk_vervaldatum, p_vehicle_verification_status, p_vehicle_type,
    p_vehicle_year, p_vehicle_colour, p_passenger_seats,
    p_is_wheelchair_accessible, p_is_electric, p_is_pet_friendly,
    p_is_female_driver
  );
END;
$$;

CREATE FUNCTION public.verify_vehicle_and_unlock(
  p_user_id uuid,
  p_kenteken text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_catalog
AS $$
BEGIN
  IF NOT private.fn_driver_user_actor_authorized(p_user_id) THEN
    PERFORM private.fn_log_driver_profile_actor_denied(
      'verify_vehicle_and_unlock', p_user_id
    );
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;
  RETURN private.verify_vehicle_and_unlock(p_user_id, p_kenteken);
END;
$$;

CREATE FUNCTION public.mark_welcome_modal_seen(
  p_user_id uuid,
  p_skipped boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_catalog
AS $$
BEGIN
  IF NOT private.fn_driver_user_actor_authorized(p_user_id) THEN
    PERFORM private.fn_log_driver_profile_actor_denied(
      'mark_welcome_modal_seen', p_user_id
    );
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;
  RETURN private.mark_welcome_modal_seen(p_user_id, p_skipped);
END;
$$;

CREATE FUNCTION public.update_profile_completion(
  p_user_id uuid,
  p_section text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_catalog
AS $$
BEGIN
  IF NOT private.fn_driver_user_actor_authorized(p_user_id) THEN
    PERFORM private.fn_log_driver_profile_actor_denied(
      'update_profile_completion', p_user_id
    );
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;
  RETURN private.update_profile_completion(p_user_id, p_section);
END;
$$;

CREATE FUNCTION public.upsert_push_token(
  p_user_id uuid,
  p_token text,
  p_platform text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_catalog
AS $$
BEGIN
  IF NOT private.fn_driver_user_actor_authorized(p_user_id) THEN
    PERFORM private.fn_log_driver_profile_actor_denied(
      'upsert_push_token', p_user_id
    );
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'not_authorized';
  END IF;
  PERFORM private.upsert_push_token(p_user_id, p_token, p_platform);
END;
$$;

CREATE FUNCTION public.refresh_driver_badge(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, pg_catalog
AS $$
BEGIN
  IF NOT private.fn_driver_user_actor_authorized(p_user_id) THEN
    PERFORM private.fn_log_driver_profile_actor_denied(
      'refresh_driver_badge', p_user_id
    );
    RETURN false;
  END IF;
  RETURN private.refresh_driver_badge(p_user_id);
END;
$$;

REVOKE ALL ON FUNCTION private.get_or_create_driver(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.save_driver_profile(
  uuid, text, text, text, text, text
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.save_driver_preferences(
  uuid, integer, text[], boolean, numeric, boolean,
  boolean, boolean, boolean, boolean
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.save_vehicle_info(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  text, text, text, text, text, text, text, boolean, boolean, boolean, boolean
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.verify_vehicle_and_unlock(uuid, text)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.mark_welcome_modal_seen(uuid, boolean)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.update_profile_completion(uuid, text)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.upsert_push_token(uuid, text, text)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.refresh_driver_badge(uuid)
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.get_or_create_driver(uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_driver_profile(
  uuid, text, text, text, text, text
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_driver_preferences(
  uuid, integer, text[], boolean, numeric, boolean,
  boolean, boolean, boolean, boolean
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_vehicle_info(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  text, text, text, text, text, text, text, boolean, boolean, boolean, boolean
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_vehicle_and_unlock(uuid, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_welcome_modal_seen(uuid, boolean)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_profile_completion(uuid, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_push_token(uuid, text, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refresh_driver_badge(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_or_create_driver(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_driver_profile(
  uuid, text, text, text, text, text
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_driver_preferences(
  uuid, integer, text[], boolean, numeric, boolean,
  boolean, boolean, boolean, boolean
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_vehicle_info(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  text, text, text, text, text, text, text, boolean, boolean, boolean, boolean
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.verify_vehicle_and_unlock(uuid, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_welcome_modal_seen(uuid, boolean)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_profile_completion(uuid, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.upsert_push_token(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.refresh_driver_badge(uuid)
  FROM PUBLIC, anon;

-- These are implementation helpers or service Edge commands. SQL callers run
-- in their owning definer context; scan-radar, driver-agent, and Apple review
-- use the service role. No Flutter caller exists for these signatures.

REVOKE ALL ON FUNCTION public.setup_review_driver_profile(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_idle_drivers_offline()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.recompute_driver_compliance(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.recalculate_driver_rating(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.recalculate_rider_credibility(text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_ride_audit_append(
  uuid, text, uuid, jsonb, text, text, uuid
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_ride_lifecycle_mark_on_ride(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_ride_lifecycle_release_driver(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_consume_step_up(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_finalize(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_notify(
  uuid, text, text, text, jsonb
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_notify_ops(
  text, text, jsonb
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_queue_email(
  uuid, text, text, jsonb
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_ensure_driver_business_account(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_ensure_ride_rider_identity_for_notify(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_generate_power_cards(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_soft_reserve_ride(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_start_radar_session(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.setup_review_driver_profile(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_idle_drivers_offline()
  TO service_role;
GRANT EXECUTE ON FUNCTION public.recompute_driver_compliance(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.recalculate_driver_rating(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.recalculate_rider_credibility(text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_ride_audit_append(
  uuid, text, uuid, jsonb, text, text, uuid
) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_lifecycle_mark_on_ride(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_lifecycle_release_driver(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_consume_step_up(uuid, uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_finalize(uuid, text, text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_notify(
  uuid, text, text, text, jsonb
) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_notify_ops(
  text, text, jsonb
) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_queue_email(
  uuid, text, text, jsonb
) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_ensure_driver_business_account(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_ensure_ride_rider_identity_for_notify(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_generate_power_cards(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_soft_reserve_ride(uuid, uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_start_radar_session(uuid, uuid)
  TO service_role;
