-- Disposable PostgreSQL harness. Never run against a shared database.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END;
$$;

CREATE SCHEMA auth;
CREATE SCHEMA private;

CREATE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
CREATE FUNCTION auth.jwt()
RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object(
    'role', COALESCE(current_setting('request.jwt.claim.role', true), '')
  )
$$;

CREATE TABLE private.domain_security_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domain text NOT NULL,
  event text NOT NULL,
  actor_user_id uuid,
  object_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE public.profile_wrapper_effects (
  command text NOT NULL,
  user_id uuid NOT NULL,
  payload text
);

CREATE FUNCTION public.get_or_create_driver(p_user_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$
  SELECT jsonb_build_object('success', true, 'user_id', p_user_id)
$$;
CREATE FUNCTION public.save_driver_profile(
  p_user_id uuid, p_full_name text DEFAULT NULL,
  p_profile_photo_url text DEFAULT NULL, p_bio text DEFAULT NULL,
  p_gender text DEFAULT NULL, p_locale text DEFAULT NULL
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$
  SELECT jsonb_build_object('success', true, 'user_id', p_user_id)
$$;
CREATE FUNCTION public.save_driver_preferences(
  p_user_id uuid, p_pickup_distance_km integer DEFAULT NULL,
  p_payment_methods text[] DEFAULT NULL,
  p_auto_accept_enabled boolean DEFAULT NULL,
  p_auto_accept_min_fare numeric DEFAULT NULL,
  p_radar_enabled boolean DEFAULT NULL, p_is_electric boolean DEFAULT NULL,
  p_is_pet_friendly boolean DEFAULT NULL,
  p_is_wheelchair_accessible boolean DEFAULT NULL,
  p_is_female_driver boolean DEFAULT NULL
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$
  SELECT jsonb_build_object('success', true, 'user_id', p_user_id)
$$;
CREATE FUNCTION public.save_vehicle_info(
  p_user_id uuid, p_vehicle_plate text, p_vehicle_plate_entered text,
  p_rdw_voertuigsoort text DEFAULT NULL, p_rdw_merk text DEFAULT NULL,
  p_rdw_handelsbenaming text DEFAULT NULL, p_rdw_eerste_kleur text DEFAULT NULL,
  p_rdw_tweede_kleur text DEFAULT NULL,
  p_rdw_datum_eerste_toelating text DEFAULT NULL,
  p_rdw_aantal_zitplaatsen text DEFAULT NULL,
  p_rdw_inrichting text DEFAULT NULL,
  p_rdw_massa_ledig_voertuig text DEFAULT NULL,
  p_rdw_wam_verzekerd text DEFAULT NULL,
  p_rdw_apk_vervaldatum text DEFAULT NULL,
  p_vehicle_verification_status text DEFAULT 'unverified',
  p_vehicle_type text DEFAULT 'sedan', p_vehicle_year text DEFAULT NULL,
  p_vehicle_colour text DEFAULT NULL, p_passenger_seats text DEFAULT NULL,
  p_is_wheelchair_accessible boolean DEFAULT false,
  p_is_electric boolean DEFAULT false, p_is_pet_friendly boolean DEFAULT false,
  p_is_female_driver boolean DEFAULT false
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$
  SELECT jsonb_build_object('success', true, 'user_id', p_user_id)
$$;
CREATE FUNCTION public.verify_vehicle_and_unlock(uuid, text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{"success":true}'::jsonb $$;
CREATE FUNCTION public.mark_welcome_modal_seen(uuid, boolean DEFAULT false)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{"success":true}'::jsonb $$;
CREATE FUNCTION public.update_profile_completion(uuid, text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{"success":true}'::jsonb $$;
CREATE FUNCTION public.upsert_push_token(p_user_id uuid, p_token text, p_platform text DEFAULT NULL)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  INSERT INTO public.profile_wrapper_effects(command,user_id,payload)
  VALUES ('upsert_push_token',p_user_id,p_token)
$$;
CREATE FUNCTION public.refresh_driver_badge(uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$ SELECT true $$;

CREATE FUNCTION public.setup_review_driver_profile(uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.mark_idle_drivers_offline() RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.recompute_driver_compliance(uuid) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.recalculate_driver_rating(uuid) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.recalculate_rider_credibility(text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_ride_audit_append(uuid,text,uuid,jsonb,text,text,uuid) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_driver_ride_lifecycle_mark_on_ride(uuid) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_driver_ride_lifecycle_release_driver(uuid) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_driver_shift_handover_consume_step_up(uuid,uuid) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$ SELECT false $$;
CREATE FUNCTION public.fn_driver_shift_handover_finalize(uuid,text,text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_driver_shift_handover_notify(uuid,text,text,text,jsonb) RETURNS uuid LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::uuid $$;
CREATE FUNCTION public.fn_driver_shift_handover_notify_ops(text,text,jsonb) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_driver_shift_handover_queue_email(uuid,text,text,jsonb) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_ensure_driver_business_account(uuid) RETURNS uuid LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::uuid $$;
CREATE FUNCTION public.fn_ensure_ride_rider_identity_for_notify(uuid) RETURNS uuid LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::uuid $$;
CREATE FUNCTION public.fn_generate_power_cards(uuid) RETURNS integer LANGUAGE sql SECURITY DEFINER AS $$ SELECT 0 $$;
CREATE FUNCTION public.fn_soft_reserve_ride(uuid,uuid) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$ SELECT false $$;
CREATE FUNCTION public.fn_start_radar_session(uuid,uuid) RETURNS uuid LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::uuid $$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  TO PUBLIC, anon, authenticated, service_role;

\ir ../migrations/20260714075308_driver_profile_actor_and_internal_helper_boundary.sql
\ir driver_profile_actor_and_internal_helper_boundary_test.sql

SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000201',
  false
);
SET ROLE authenticated;
SELECT public.save_driver_profile(
  '00000000-0000-0000-0000-000000000201', 'Own Driver'
);
SELECT public.save_driver_profile(
  '00000000-0000-0000-0000-000000000202', 'Other Driver'
);
SELECT public.upsert_push_token(
  '00000000-0000-0000-0000-000000000201', 'own-token'
);
RESET ROLE;

DO $$
DECLARE
  v_denied jsonb;
BEGIN
  v_denied := public.save_driver_profile(
    '00000000-0000-0000-0000-000000000202', 'Other Driver'
  );
  -- The postgres assertion call is a distinct, intentionally unauthorized
  -- actor; validate the authenticated denial through the persisted audit too.
  IF NOT EXISTS (
    SELECT 1 FROM private.domain_security_events
    WHERE domain = 'driver_profile'
      AND event = 'actor_mismatch'
      AND actor_user_id = '00000000-0000-0000-0000-000000000201'
      AND object_id = '00000000-0000-0000-0000-000000000202'
  ) THEN
    RAISE EXCEPTION 'cross-user Driver profile denial was not audited';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.profile_wrapper_effects
    WHERE command = 'upsert_push_token'
      AND user_id = '00000000-0000-0000-0000-000000000201'
      AND payload = 'own-token'
  ) THEN
    RAISE EXCEPTION 'valid Driver wrapper did not preserve implementation';
  END IF;
END;
$$;

SELECT 'driver_profile_actor_behavior_passed' AS result;
