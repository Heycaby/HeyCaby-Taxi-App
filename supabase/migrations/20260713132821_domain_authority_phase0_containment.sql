-- Production history 20260713132821: domain authority Phase 0 containment.
--
-- Goals:
--   * close confirmed privilege/identity bypasses without changing released RPC
--     signatures;
--   * make notifications and chat server-owned/immutable where appropriate;
--   * introduce the canonical, atomic marketplace command boundary;
--   * protect backend-owned driver and ride columns from direct Data API writes.
--
-- This migration intentionally retains compatibility wrappers. The old
-- implementations are moved to the unexposed `private` schema and can only be
-- reached after the public wrapper binds the caller to auth.uid().

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.domain_security_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domain text NOT NULL,
  event text NOT NULL,
  actor_user_id uuid,
  object_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

REVOKE ALL ON TABLE private.domain_security_events
  FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;
GRANT SELECT ON TABLE private.domain_security_events TO service_role;

CREATE OR REPLACE FUNCTION private.current_driver_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT d.id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION private.current_driver_id() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.rider_owns_ride(p_ride_request_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = p_ride_request_id
      AND (
        rr.rider_identity_id IN (
          SELECT ri.id
          FROM public.rider_identities ri
          WHERE ri.user_id = auth.uid()
        )
        OR rr.rider_token IN (
          SELECT rs.session_token
          FROM public.rider_sessions rs
          WHERE rs.user_id = auth.uid()
        )
        OR rr.rider_id = auth.uid()
      )
  );
$$;

REVOKE ALL ON FUNCTION private.rider_owns_ride(uuid)
  FROM PUBLIC, anon, authenticated;
-- RLS policies execute as the calling role. The helper is in an unexposed
-- schema and reveals only a boolean for the current auth.uid().
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.rider_owns_ride(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Destructive maintenance functions are never client APIs.
-- ---------------------------------------------------------------------------

DO $phase0$
BEGIN
  IF to_regprocedure('public.delete_all_auth_users()') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.delete_all_auth_users() '
      || 'FROM PUBLIC, anon, authenticated, service_role';
  END IF;

  IF to_regprocedure('public.cleanup_stale_driver_locations()') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.cleanup_stale_driver_locations() '
      || 'FROM PUBLIC, anon, authenticated, service_role';
  END IF;
END;
$phase0$;

-- ---------------------------------------------------------------------------
-- Auth-bind legacy ride swap RPCs while preserving released signatures.
-- ---------------------------------------------------------------------------

DO $phase0$
BEGIN
  IF to_regprocedure('public.can_driver_take_swap(uuid,timestamptz,numeric)') IS NOT NULL
     AND to_regprocedure('private.can_driver_take_swap(uuid,timestamptz,numeric)') IS NULL THEN
    ALTER FUNCTION public.can_driver_take_swap(uuid, timestamptz, numeric)
      SET SCHEMA private;
  END IF;

  IF to_regprocedure('private.can_driver_take_swap(uuid,timestamptz,numeric)') IS NOT NULL THEN
    EXECUTE $ddl$
      CREATE OR REPLACE FUNCTION public.can_driver_take_swap(
        _driver_id uuid,
        _pickup_at timestamptz,
        _est_duration numeric
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, private, pg_catalog
      AS $fn$
      DECLARE
        v_actor_driver_id uuid := private.current_driver_id();
      BEGIN
        IF v_actor_driver_id IS NULL OR v_actor_driver_id <> _driver_id THEN
          INSERT INTO private.domain_security_events(
            domain, event, actor_user_id, object_id, metadata
          ) VALUES (
            'ride_swap', 'identity_mismatch', auth.uid(), _driver_id,
            jsonb_build_object('operation', 'can_take')
          );
          RETURN jsonb_build_object('can_take', false, 'reason', 'not_authorized');
        END IF;
        RETURN private.can_driver_take_swap(
          v_actor_driver_id, _pickup_at, _est_duration
        );
      END;
      $fn$;
    $ddl$;
    REVOKE ALL ON FUNCTION public.can_driver_take_swap(uuid, timestamptz, numeric)
      FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.can_driver_take_swap(uuid, timestamptz, numeric)
      TO authenticated;
    REVOKE ALL ON FUNCTION private.can_driver_take_swap(uuid, timestamptz, numeric)
      FROM PUBLIC, anon, authenticated, service_role;
  END IF;
END;
$phase0$;

DO $phase0$
BEGIN
  IF to_regprocedure('public.offer_ride_swap(uuid,uuid,text,text)') IS NOT NULL
     AND to_regprocedure('private.offer_ride_swap(uuid,uuid,text,text)') IS NULL THEN
    ALTER FUNCTION public.offer_ride_swap(uuid, uuid, text, text)
      SET SCHEMA private;
  END IF;

  IF to_regprocedure('private.offer_ride_swap(uuid,uuid,text,text)') IS NOT NULL THEN
    EXECUTE $ddl$
      CREATE OR REPLACE FUNCTION public.offer_ride_swap(
        _driver_id uuid,
        _ride_id uuid,
        _reason text DEFAULT 'other',
        _detail text DEFAULT NULL
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, private, pg_catalog
      AS $fn$
      DECLARE
        v_actor_driver_id uuid := private.current_driver_id();
      BEGIN
        IF v_actor_driver_id IS NULL OR v_actor_driver_id <> _driver_id THEN
          INSERT INTO private.domain_security_events(
            domain, event, actor_user_id, object_id, metadata
          ) VALUES (
            'ride_swap', 'identity_mismatch', auth.uid(), _ride_id,
            jsonb_build_object('operation', 'offer', 'supplied_driver_id', _driver_id)
          );
          RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
        END IF;
        RETURN private.offer_ride_swap(
          v_actor_driver_id, _ride_id, _reason, _detail
        );
      END;
      $fn$;
    $ddl$;
    REVOKE ALL ON FUNCTION public.offer_ride_swap(uuid, uuid, text, text)
      FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.offer_ride_swap(uuid, uuid, text, text)
      TO authenticated;
    REVOKE ALL ON FUNCTION private.offer_ride_swap(uuid, uuid, text, text)
      FROM PUBLIC, anon, authenticated, service_role;
  END IF;
END;
$phase0$;

DO $phase0$
BEGIN
  IF to_regprocedure('public.claim_ride_swap(uuid,uuid)') IS NOT NULL
     AND to_regprocedure('private.claim_ride_swap(uuid,uuid)') IS NULL THEN
    ALTER FUNCTION public.claim_ride_swap(uuid, uuid) SET SCHEMA private;
  END IF;

  IF to_regprocedure('private.claim_ride_swap(uuid,uuid)') IS NOT NULL THEN
    EXECUTE $ddl$
      CREATE OR REPLACE FUNCTION public.claim_ride_swap(
        _claimer_id uuid,
        _swap_id uuid
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, private, pg_catalog
      AS $fn$
      DECLARE
        v_actor_driver_id uuid := private.current_driver_id();
      BEGIN
        IF v_actor_driver_id IS NULL OR v_actor_driver_id <> _claimer_id THEN
          INSERT INTO private.domain_security_events(
            domain, event, actor_user_id, object_id, metadata
          ) VALUES (
            'ride_swap', 'identity_mismatch', auth.uid(), _swap_id,
            jsonb_build_object('operation', 'claim', 'supplied_driver_id', _claimer_id)
          );
          RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
        END IF;
        RETURN private.claim_ride_swap(v_actor_driver_id, _swap_id);
      END;
      $fn$;
    $ddl$;
    REVOKE ALL ON FUNCTION public.claim_ride_swap(uuid, uuid)
      FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.claim_ride_swap(uuid, uuid)
      TO authenticated;
    REVOKE ALL ON FUNCTION private.claim_ride_swap(uuid, uuid)
      FROM PUBLIC, anon, authenticated, service_role;
  END IF;
END;
$phase0$;

DO $phase0$
BEGIN
  IF to_regprocedure('public.cancel_ride_swap(uuid,uuid)') IS NOT NULL
     AND to_regprocedure('private.cancel_ride_swap(uuid,uuid)') IS NULL THEN
    ALTER FUNCTION public.cancel_ride_swap(uuid, uuid) SET SCHEMA private;
  END IF;

  IF to_regprocedure('private.cancel_ride_swap(uuid,uuid)') IS NOT NULL THEN
    EXECUTE $ddl$
      CREATE OR REPLACE FUNCTION public.cancel_ride_swap(
        _driver_id uuid,
        _swap_id uuid
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, private, pg_catalog
      AS $fn$
      DECLARE
        v_actor_driver_id uuid := private.current_driver_id();
      BEGIN
        IF v_actor_driver_id IS NULL OR v_actor_driver_id <> _driver_id THEN
          INSERT INTO private.domain_security_events(
            domain, event, actor_user_id, object_id, metadata
          ) VALUES (
            'ride_swap', 'identity_mismatch', auth.uid(), _swap_id,
            jsonb_build_object('operation', 'cancel', 'supplied_driver_id', _driver_id)
          );
          RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
        END IF;
        RETURN private.cancel_ride_swap(v_actor_driver_id, _swap_id);
      END;
      $fn$;
    $ddl$;
    REVOKE ALL ON FUNCTION public.cancel_ride_swap(uuid, uuid)
      FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.cancel_ride_swap(uuid, uuid)
      TO authenticated;
    REVOKE ALL ON FUNCTION private.cancel_ride_swap(uuid, uuid)
      FROM PUBLIC, anon, authenticated, service_role;
  END IF;
END;
$phase0$;

DO $phase0$
BEGIN
  IF to_regprocedure('public.confirm_ride_swap(uuid,uuid)') IS NOT NULL
     AND to_regprocedure('private.confirm_ride_swap(uuid,uuid)') IS NULL THEN
    ALTER FUNCTION public.confirm_ride_swap(uuid, uuid) SET SCHEMA private;
  END IF;

  IF to_regprocedure('private.confirm_ride_swap(uuid,uuid)') IS NOT NULL THEN
    EXECUTE $ddl$
      CREATE OR REPLACE FUNCTION public.confirm_ride_swap(
        p_user_id uuid,
        p_swap_id uuid
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, private, pg_catalog
      AS $fn$
      BEGIN
        IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
          INSERT INTO private.domain_security_events(
            domain, event, actor_user_id, object_id, metadata
          ) VALUES (
            'ride_swap', 'identity_mismatch', auth.uid(), p_swap_id,
            jsonb_build_object('operation', 'confirm')
          );
          RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
        END IF;
        RETURN private.confirm_ride_swap(auth.uid(), p_swap_id);
      END;
      $fn$;
    $ddl$;
    REVOKE ALL ON FUNCTION public.confirm_ride_swap(uuid, uuid)
      FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.confirm_ride_swap(uuid, uuid)
      TO authenticated;
    REVOKE ALL ON FUNCTION private.confirm_ride_swap(uuid, uuid)
      FROM PUBLIC, anon, authenticated, service_role;
  END IF;
END;
$phase0$;

-- Community swap claim has the same caller-supplied-driver weakness.
DO $phase0$
BEGIN
  IF to_regprocedure('public.fn_claim_swap_ride(uuid,uuid)') IS NOT NULL
     AND to_regprocedure('private.fn_claim_swap_ride(uuid,uuid)') IS NULL THEN
    ALTER FUNCTION public.fn_claim_swap_ride(uuid, uuid) SET SCHEMA private;
  END IF;

  IF to_regprocedure('private.fn_claim_swap_ride(uuid,uuid)') IS NOT NULL THEN
    EXECUTE $ddl$
      CREATE OR REPLACE FUNCTION public.fn_claim_swap_ride(
        p_post_id uuid,
        p_claiming_driver_id uuid
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, private, pg_catalog
      AS $fn$
      DECLARE
        v_actor_driver_id uuid := private.current_driver_id();
      BEGIN
        IF v_actor_driver_id IS NULL OR v_actor_driver_id <> p_claiming_driver_id THEN
          INSERT INTO private.domain_security_events(
            domain, event, actor_user_id, object_id, metadata
          ) VALUES (
            'community_swap', 'identity_mismatch', auth.uid(), p_post_id,
            jsonb_build_object('operation', 'claim')
          );
          RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
        END IF;
        RETURN private.fn_claim_swap_ride(p_post_id, v_actor_driver_id);
      END;
      $fn$;
    $ddl$;
    REVOKE ALL ON FUNCTION public.fn_claim_swap_ride(uuid, uuid)
      FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.fn_claim_swap_ride(uuid, uuid)
      TO authenticated;
    REVOKE ALL ON FUNCTION private.fn_claim_swap_ride(uuid, uuid)
      FROM PUBLIC, anon, authenticated, service_role;
  END IF;

  -- Passenger-response confirmation is not called by Rider and cannot safely
  -- infer authority from its current signature. Keep it internal until it is
  -- replaced by an auth-bound Rider/Admin command.
  IF to_regprocedure('public.fn_confirm_swap_ride(uuid,text)') IS NOT NULL THEN
    REVOKE ALL ON FUNCTION public.fn_confirm_swap_ride(uuid, text)
      FROM PUBLIC, anon, authenticated;
    GRANT EXECUTE ON FUNCTION public.fn_confirm_swap_ride(uuid, text)
      TO service_role;
  END IF;
END;
$phase0$;

-- ---------------------------------------------------------------------------
-- Driver document submission compatibility wrapper.
-- ---------------------------------------------------------------------------

DO $phase0$
BEGIN
  IF to_regprocedure(
    'public.save_driver_document(uuid,text,text,text,text,text,text,text,text,text,text,text,text,text)'
  ) IS NOT NULL
  AND to_regprocedure(
    'private.save_driver_document(uuid,text,text,text,text,text,text,text,text,text,text,text,text,text)'
  ) IS NULL THEN
    ALTER FUNCTION public.save_driver_document(
      uuid, text, text, text, text, text, text, text,
      text, text, text, text, text, text
    ) SET SCHEMA private;
  END IF;

  IF to_regprocedure(
    'private.save_driver_document(uuid,text,text,text,text,text,text,text,text,text,text,text,text,text)'
  ) IS NOT NULL THEN
    EXECUTE $ddl$
      CREATE OR REPLACE FUNCTION public.save_driver_document(
        p_user_id uuid,
        p_document_type text,
        p_chauffeurspas_number text DEFAULT NULL,
        p_chauffeurspas_expiry text DEFAULT NULL,
        p_insurance_photo_url text DEFAULT NULL,
        p_insurance_provider text DEFAULT NULL,
        p_insurance_expiry text DEFAULT NULL,
        p_insurance_policy_nr text DEFAULT NULL,
        p_kvk_number text DEFAULT NULL,
        p_kvk_business_name text DEFAULT NULL,
        p_kvk_address text DEFAULT NULL,
        p_veriff_session_id text DEFAULT NULL,
        p_veriff_session_url text DEFAULT NULL,
        p_veriff_status text DEFAULT NULL
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, private, pg_catalog
      AS $fn$
      BEGIN
        IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
          INSERT INTO private.domain_security_events(
            domain, event, actor_user_id, object_id, metadata
          ) VALUES (
            'driver_readiness', 'document_identity_mismatch', auth.uid(), p_user_id,
            jsonb_build_object('document_type', p_document_type)
          );
          RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
        END IF;

        RETURN private.save_driver_document(
          auth.uid(), p_document_type, p_chauffeurspas_number,
          p_chauffeurspas_expiry, p_insurance_photo_url,
          p_insurance_provider, p_insurance_expiry,
          p_insurance_policy_nr, p_kvk_number, p_kvk_business_name,
          p_kvk_address, p_veriff_session_id, p_veriff_session_url,
          p_veriff_status
        );
      END;
      $fn$;
    $ddl$;

    REVOKE ALL ON FUNCTION public.save_driver_document(
      uuid, text, text, text, text, text, text, text,
      text, text, text, text, text, text
    ) FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.save_driver_document(
      uuid, text, text, text, text, text, text, text,
      text, text, text, text, text, text
    ) TO authenticated;
    REVOKE ALL ON FUNCTION private.save_driver_document(
      uuid, text, text, text, text, text, text, text,
      text, text, text, text, text, text
    ) FROM PUBLIC, anon, authenticated, service_role;
  END IF;
END;
$phase0$;

-- ---------------------------------------------------------------------------
-- Admin verification: app_metadata only, correct field assignment, audit.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_admin_set_manual_verifications(
  p_driver_id uuid,
  p_chauffeurspas_verified boolean DEFAULT NULL,
  p_kvk_verified boolean DEFAULT NULL,
  p_rijbewijs_verified boolean DEFAULT NULL,
  p_mark_fully_verified boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_role text;
  v_before jsonb;
  v_after jsonb;
BEGIN
  SELECT u.raw_app_meta_data->>'role'
  INTO v_role
  FROM auth.users u
  WHERE u.id = v_actor;

  IF v_actor IS NULL OR COALESCE(v_role, '') NOT IN ('admin', 'super_admin') THEN
    INSERT INTO private.domain_security_events(
      domain, event, actor_user_id, object_id, metadata
    ) VALUES (
      'driver_readiness', 'admin_verification_denied', v_actor, p_driver_id,
      jsonb_build_object('role', COALESCE(v_role, ''))
    );
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  SELECT jsonb_build_object(
    'chauffeurspas_verified', d.chauffeurspas_verified,
    'kvk_verified', d.kvk_verified,
    'rijbewijs_verified', d.rijbewijs_verified,
    'profile_status', d.profile_status,
    'compliance_status', d.compliance_status
  )
  INTO v_before
  FROM public.drivers d
  WHERE d.id = p_driver_id
  FOR UPDATE;

  IF v_before IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_not_found');
  END IF;

  UPDATE public.drivers d
  SET
    chauffeurspas_verified = COALESCE(
      p_chauffeurspas_verified, d.chauffeurspas_verified
    ),
    chauffeurspas_verified_at = CASE
      WHEN p_chauffeurspas_verified IS TRUE THEN timezone('utc', now())
      WHEN p_chauffeurspas_verified IS FALSE THEN NULL
      ELSE d.chauffeurspas_verified_at
    END,
    kvk_verified = COALESCE(p_kvk_verified, d.kvk_verified),
    kvk_verified_at = CASE
      WHEN p_kvk_verified IS TRUE THEN timezone('utc', now())
      WHEN p_kvk_verified IS FALSE THEN NULL
      ELSE d.kvk_verified_at
    END,
    kvk_manual_verified_at = CASE
      WHEN p_kvk_verified IS NOT NULL THEN timezone('utc', now())
      ELSE d.kvk_manual_verified_at
    END,
    kvk_manual_verified_by = CASE
      WHEN p_kvk_verified IS NOT NULL THEN v_actor
      ELSE d.kvk_manual_verified_by
    END,
    rijbewijs_verified = COALESCE(p_rijbewijs_verified, d.rijbewijs_verified),
    rijbewijs_verified_at = CASE
      WHEN p_rijbewijs_verified IS TRUE THEN timezone('utc', now())
      WHEN p_rijbewijs_verified IS FALSE THEN NULL
      ELSE d.rijbewijs_verified_at
    END,
    profile_status = CASE
      WHEN p_mark_fully_verified THEN 'verified'::public.profile_status
      ELSE d.profile_status
    END,
    compliance_status = CASE
      WHEN p_mark_fully_verified THEN 'compliant'
      ELSE d.compliance_status
    END,
    admin_approved_at = CASE
      WHEN p_mark_fully_verified THEN timezone('utc', now())
      ELSE d.admin_approved_at
    END,
    admin_approved_by = CASE
      WHEN p_mark_fully_verified THEN v_actor
      ELSE d.admin_approved_by
    END,
    congratulations_modal_shown = CASE
      WHEN p_mark_fully_verified THEN false
      ELSE d.congratulations_modal_shown
    END,
    updated_at = timezone('utc', now())
  WHERE d.id = p_driver_id;

  SELECT jsonb_build_object(
    'chauffeurspas_verified', d.chauffeurspas_verified,
    'kvk_verified', d.kvk_verified,
    'rijbewijs_verified', d.rijbewijs_verified,
    'profile_status', d.profile_status,
    'compliance_status', d.compliance_status
  )
  INTO v_after
  FROM public.drivers d
  WHERE d.id = p_driver_id;

  INSERT INTO private.domain_security_events(
    domain, event, actor_user_id, object_id, metadata
  ) VALUES (
    'driver_readiness', 'admin_verification_changed', v_actor, p_driver_id,
    jsonb_build_object('before', v_before, 'after', v_after)
  );

  RETURN jsonb_build_object('success', true, 'driver_id', p_driver_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_admin_set_manual_verifications(
  uuid, boolean, boolean, boolean, boolean
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_set_manual_verifications(
  uuid, boolean, boolean, boolean, boolean
) TO authenticated;

-- ---------------------------------------------------------------------------
-- Protected driver columns: direct clients may edit profile/submission fields,
-- but never backend trust, billing, derived stats, or account state.
-- SECURITY DEFINER commands continue to run as their owner and are unaffected.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_guard_driver_authority_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, private, pg_catalog
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated')
     AND (
       NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.status IS DISTINCT FROM OLD.status
       OR NEW.profile_status IS DISTINCT FROM OLD.profile_status
       OR NEW.compliance_status IS DISTINCT FROM OLD.compliance_status
       OR NEW.subscription_active IS DISTINCT FROM OLD.subscription_active
       OR NEW.subscription_end_date IS DISTINCT FROM OLD.subscription_end_date
       OR NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at
       OR NEW.subscription_expiry IS DISTINCT FROM OLD.subscription_expiry
       OR NEW.mollie_customer_id IS DISTINCT FROM OLD.mollie_customer_id
       OR NEW.mollie_subscription_id IS DISTINCT FROM OLD.mollie_subscription_id
       OR NEW.kvk_verified IS DISTINCT FROM OLD.kvk_verified
       OR NEW.kvk_verified_at IS DISTINCT FROM OLD.kvk_verified_at
       OR NEW.kvk_manual_verified_at IS DISTINCT FROM OLD.kvk_manual_verified_at
       OR NEW.kvk_manual_verified_by IS DISTINCT FROM OLD.kvk_manual_verified_by
       OR NEW.chauffeurspas_verified IS DISTINCT FROM OLD.chauffeurspas_verified
       OR NEW.chauffeurspas_verified_at IS DISTINCT FROM OLD.chauffeurspas_verified_at
       OR NEW.rijbewijs_verified IS DISTINCT FROM OLD.rijbewijs_verified
       OR NEW.rijbewijs_verified_at IS DISTINCT FROM OLD.rijbewijs_verified_at
       OR NEW.vehicle_verified IS DISTINCT FROM OLD.vehicle_verified
       OR NEW.vehicle_verified_at IS DISTINCT FROM OLD.vehicle_verified_at
       OR NEW.vehicle_verification_status IS DISTINCT FROM OLD.vehicle_verification_status
       OR NEW.vehicle_photos_approved IS DISTINCT FROM OLD.vehicle_photos_approved
       OR NEW.is_verified_badge IS DISTINCT FROM OLD.is_verified_badge
       OR NEW.verified_badge_at IS DISTINCT FROM OLD.verified_badge_at
       OR NEW.verified_badge_criteria IS DISTINCT FROM OLD.verified_badge_criteria
       OR NEW.rating IS DISTINCT FROM OLD.rating
       OR NEW.avg_rating IS DISTINCT FROM OLD.avg_rating
       OR NEW.total_ratings IS DISTINCT FROM OLD.total_ratings
       OR NEW.trip_count IS DISTINCT FROM OLD.trip_count
       OR NEW.rides_accepted_count IS DISTINCT FROM OLD.rides_accepted_count
       OR NEW.total_earnings_cents IS DISTINCT FROM OLD.total_earnings_cents
       OR NEW.acceptance_rate IS DISTINCT FROM OLD.acceptance_rate
       OR NEW.cancellation_rate IS DISTINCT FROM OLD.cancellation_rate
       OR NEW.total_requests_received IS DISTINCT FROM OLD.total_requests_received
       OR NEW.total_requests_accepted IS DISTINCT FROM OLD.total_requests_accepted
       OR NEW.total_cancellations_by_driver IS DISTINCT FROM OLD.total_cancellations_by_driver
       OR NEW.total_cancellations_by_passenger IS DISTINCT FROM OLD.total_cancellations_by_passenger
       OR NEW.account_status IS DISTINCT FROM OLD.account_status
       OR NEW.account_deletion_requested_at IS DISTINCT FROM OLD.account_deletion_requested_at
       OR NEW.account_deactivated_at IS DISTINCT FROM OLD.account_deactivated_at
       OR NEW.personal_data_delete_after IS DISTINCT FROM OLD.personal_data_delete_after
       OR NEW.account_anonymized_at IS DISTINCT FROM OLD.account_anonymized_at
       OR NEW.deletion_job_status IS DISTINCT FROM OLD.deletion_job_status
       OR NEW.is_founding_driver IS DISTINCT FROM OLD.is_founding_driver
       OR NEW.founding_number IS DISTINCT FROM OLD.founding_number
       OR NEW.founding_rate_locked IS DISTINCT FROM OLD.founding_rate_locked
       OR NEW.weekly_rate_euros IS DISTINCT FROM OLD.weekly_rate_euros
       OR NEW.billing_starts_after_euros IS DISTINCT FROM OLD.billing_starts_after_euros
       OR NEW.admin_approved_at IS DISTINCT FROM OLD.admin_approved_at
       OR NEW.admin_approved_by IS DISTINCT FROM OLD.admin_approved_by
     ) THEN
    INSERT INTO private.domain_security_events(
      domain, event, actor_user_id, object_id, metadata
    ) VALUES (
      'driver_readiness', 'protected_column_write_denied', auth.uid(), OLD.id,
      jsonb_build_object('db_role', current_user)
    );
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'protected_driver_state_requires_backend_command';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_driver_authority_columns ON public.drivers;
CREATE TRIGGER guard_driver_authority_columns
BEFORE UPDATE ON public.drivers
FOR EACH ROW
EXECUTE FUNCTION public.trg_guard_driver_authority_columns();

REVOKE ALL ON FUNCTION public.trg_guard_driver_authority_columns()
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Canonical marketplace commands.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_rider_accept_marketplace_offer(
  p_ride_request_id uuid,
  p_bid_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_bid public.ride_bids%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_readiness jsonb;
  v_billing jsonb;
  v_cfg jsonb := public.fn_dispatch_config();
  v_gps_minutes numeric;
BEGIN
  IF auth.uid() IS NULL
     OR NOT private.rider_owns_ride(p_ride_request_id) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ride_not_found');
  END IF;

  IF v_ride.booking_mode::text <> 'marketplace' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'wrong_booking_mode');
  END IF;

  IF v_ride.driver_id IS NOT NULL THEN
    SELECT * INTO v_bid
    FROM public.ride_bids rb
    WHERE rb.id = p_bid_id;
    IF v_bid.driver_id = v_ride.driver_id AND v_bid.status = 'accepted' THEN
      RETURN jsonb_build_object(
        'ok', true,
        'code', 'already_assigned',
        'ride_request_id', v_ride.id,
        'driver_id', v_ride.driver_id,
        'state_version', floor(extract(epoch FROM v_ride.updated_at) * 1000)::bigint
      );
    END IF;
    RETURN jsonb_build_object('ok', false, 'code', 'race_lost');
  END IF;

  IF v_ride.status NOT IN ('pending', 'bidding') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ride_not_assignable');
  END IF;

  SELECT * INTO v_bid
  FROM public.ride_bids rb
  WHERE rb.id = p_bid_id
    AND rb.ride_request_id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_bid.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'bid_not_available');
  END IF;

  SELECT * INTO v_driver
  FROM public.drivers d
  WHERE d.id = v_bid.driver_id;

  IF NOT FOUND OR v_driver.status::text <> 'available' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'driver_not_available');
  END IF;

  v_readiness := public.fn_driver_readiness_eval(v_driver.id);
  IF COALESCE((v_readiness->>'can_go_online')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'code', 'driver_not_ready');
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver.id);
  IF COALESCE((v_billing->>'allowed')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'code', 'driver_billing_blocked');
  END IF;

  v_gps_minutes := COALESCE((v_cfg->>'gps_freshness_minutes')::numeric, 3);
  IF NOT EXISTS (
    SELECT 1
    FROM public.driver_locations dl
    WHERE dl.driver_id = v_driver.id
      AND dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
      AND dl.updated_at > timezone('utc', now())
        - make_interval(secs => (v_gps_minutes * 60)::integer)
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'driver_location_stale');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.ride_requests active
    WHERE active.driver_id = v_driver.id
      AND active.id <> p_ride_request_id
      AND active.status IN (
        'accepted', 'assigned', 'driver_found', 'driver_en_route',
        'driver_arrived', 'in_progress'
      )
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'driver_has_active_ride');
  END IF;

  UPDATE public.ride_requests rr
  SET
    driver_id = v_driver.id,
    status = 'assigned',
    accepted_at = COALESCE(rr.accepted_at, timezone('utc', now())),
    marketplace_offered_fare = v_bid.bid_amount,
    offered_fare = v_bid.bid_amount,
    quoted_fare = v_bid.bid_amount,
    estimated_fare = v_bid.bid_amount,
    updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  UPDATE public.ride_bids rb
  SET
    status = CASE WHEN rb.id = p_bid_id THEN 'accepted' ELSE 'rejected' END,
    updated_at = timezone('utc', now())
  WHERE rb.ride_request_id = p_ride_request_id
    AND rb.status = 'pending';

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'marketplace.offer_accepted',
    auth.uid(),
    jsonb_build_object(
      'bid_id', p_bid_id,
      'driver_id', v_driver.id,
      'agreed_fare', v_bid.bid_amount
    ),
    'rider',
    'rpc',
    p_ride_request_id
  );

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'ride_assigned',
    'ride_request_id', p_ride_request_id,
    'bid_id', p_bid_id,
    'driver_id', v_driver.id,
    'agreed_fare', v_bid.bid_amount,
    'effective_status', 'driver_assigned',
    'state_version', floor(extract(epoch FROM timezone('utc', now())) * 1000)::bigint
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_accept_marketplace_offer(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_accept_marketplace_offer(uuid, uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_rider_boost_marketplace_offer(
  p_ride_request_id uuid,
  p_new_fare numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_updated_at timestamptz;
BEGIN
  IF auth.uid() IS NULL
     OR NOT private.rider_owns_ride(p_ride_request_id) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
  END IF;

  IF p_new_fare IS NULL OR p_new_fare <= 0 OR p_new_fare >= 9999 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_fare');
  END IF;

  UPDATE public.ride_requests rr
  SET
    marketplace_offered_fare = p_new_fare,
    offered_fare = p_new_fare,
    quoted_fare = p_new_fare,
    estimated_fare = p_new_fare,
    updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id
    AND rr.booking_mode::text = 'marketplace'
    AND rr.driver_id IS NULL
    AND rr.status IN ('pending', 'bidding')
  RETURNING rr.updated_at INTO v_updated_at;

  IF v_updated_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ride_not_boostable');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'offer_boosted',
    'ride_request_id', p_ride_request_id,
    'fare', p_new_fare,
    'state_version', floor(extract(epoch FROM v_updated_at) * 1000)::bigint
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_boost_marketplace_offer(uuid, numeric)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_boost_marketplace_offer(uuid, numeric)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_rider_set_marketplace_bid_status(
  p_bid_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_ride_id uuid;
BEGIN
  IF p_status NOT IN ('rejected', 'expired') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_status');
  END IF;

  SELECT rb.ride_request_id
  INTO v_ride_id
  FROM public.ride_bids rb
  WHERE rb.id = p_bid_id
  FOR UPDATE;

  IF v_ride_id IS NULL
     OR auth.uid() IS NULL
     OR NOT private.rider_owns_ride(v_ride_id) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
  END IF;

  UPDATE public.ride_bids rb
  SET status = p_status, updated_at = timezone('utc', now())
  WHERE rb.id = p_bid_id
    AND rb.status = 'pending';

  RETURN jsonb_build_object(
    'ok', FOUND,
    'code', CASE WHEN FOUND THEN 'bid_' || p_status ELSE 'bid_not_pending' END,
    'bid_id', p_bid_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_set_marketplace_bid_status(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_set_marketplace_bid_status(uuid, text)
  TO authenticated;

-- Compatibility guard for released Rider versions that directly update the
-- ride: assignment is permitted only when it exactly matches a pending bid on
-- the rider-owned marketplace ride. Arbitrary driver assignment is rejected.
CREATE OR REPLACE FUNCTION public.trg_guard_ride_authority_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_matching_bid public.ride_bids%ROWTYPE;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN NEW;
  END IF;

  IF NEW.rider_id IS DISTINCT FROM OLD.rider_id
     OR NEW.rider_identity_id IS DISTINCT FROM OLD.rider_identity_id
     OR NEW.rider_token IS DISTINCT FROM OLD.rider_token
     OR NEW.payment_status IS DISTINCT FROM OLD.payment_status
     OR NEW.payment_confirmed_at IS DISTINCT FROM OLD.payment_confirmed_at
     OR NEW.rider_payment_confirmed_at IS DISTINCT FROM OLD.rider_payment_confirmed_at
     OR NEW.driver_payment_confirmed_at IS DISTINCT FROM OLD.driver_payment_confirmed_at
     OR NEW.final_fare IS DISTINCT FROM OLD.final_fare THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'protected_ride_state_requires_backend_command';
  END IF;

  IF NEW.driver_id IS DISTINCT FROM OLD.driver_id THEN
    IF OLD.driver_id IS NOT NULL
       OR OLD.booking_mode::text <> 'marketplace'
       OR OLD.status NOT IN ('pending', 'bidding')
       OR NEW.status <> 'assigned'
       OR NOT private.rider_owns_ride(OLD.id) THEN
      RAISE EXCEPTION USING
        ERRCODE = '42501',
        MESSAGE = 'ride_assignment_requires_backend_command';
    END IF;

    SELECT * INTO v_matching_bid
    FROM public.ride_bids rb
    WHERE rb.ride_request_id = OLD.id
      AND rb.driver_id = NEW.driver_id
      AND rb.status = 'pending'
      AND rb.bid_amount = NEW.offered_fare
      AND rb.bid_amount = NEW.quoted_fare
      AND rb.bid_amount = NEW.estimated_fare
    ORDER BY rb.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = '42501',
        MESSAGE = 'marketplace_assignment_does_not_match_pending_bid';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_ride_authority_columns ON public.ride_requests;
CREATE TRIGGER guard_ride_authority_columns
BEFORE UPDATE ON public.ride_requests
FOR EACH ROW
EXECUTE FUNCTION public.trg_guard_ride_authority_columns();

REVOKE ALL ON FUNCTION public.trg_guard_ride_authority_columns()
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Notification intent is backend-owned; clients consume RPCs for read/delete.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "rider insert own notify" ON public.driver_notify_queue;
DROP POLICY IF EXISTS "rider read own notify" ON public.driver_notify_queue;
DROP POLICY IF EXISTS "service role full access notify" ON public.driver_notify_queue;

REVOKE ALL ON TABLE public.driver_notify_queue FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_notify_queue
  TO service_role;

DROP POLICY IF EXISTS "service_role_manage_notify_queue"
  ON public.driver_notify_queue;
CREATE POLICY "service_role_manage_notify_queue"
ON public.driver_notify_queue
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Users can insert own notifications"
  ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications (read_at)"
  ON public.notifications;

REVOKE INSERT, UPDATE ON TABLE public.notifications FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- Chat content/sender fields are immutable. Recipients may acknowledge read.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "messages_update_participant" ON public.messages;
CREATE POLICY "messages_recipient_marks_read"
ON public.messages
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = messages.ride_request_id
      AND (
        (
          messages.sender_type::text = 'rider'
          AND rr.driver_id IN (
            SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
          )
        )
        OR (
          messages.sender_type::text = 'driver'
          AND (
            rr.rider_identity_id IN (
              SELECT ri.id
              FROM public.rider_identities ri
              WHERE ri.user_id = auth.uid()
            )
            OR rr.rider_token IN (
              SELECT rs.session_token
              FROM public.rider_sessions rs
              WHERE rs.user_id = auth.uid()
            )
          )
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = messages.ride_request_id
      AND (
        (
          messages.sender_type::text = 'rider'
          AND rr.driver_id IN (
            SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
          )
        )
        OR (
          messages.sender_type::text = 'driver'
          AND (
            rr.rider_identity_id IN (
              SELECT ri.id
              FROM public.rider_identities ri
              WHERE ri.user_id = auth.uid()
            )
            OR rr.rider_token IN (
              SELECT rs.session_token
              FROM public.rider_sessions rs
              WHERE rs.user_id = auth.uid()
            )
          )
        )
      )
  )
);

REVOKE UPDATE ON TABLE public.messages FROM anon, authenticated;
GRANT UPDATE (is_read) ON TABLE public.messages TO authenticated;

-- ---------------------------------------------------------------------------
-- Bid reads and status transitions are bound to the owning rider/driver.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "session_riders_read_bids" ON public.ride_bids;
DROP POLICY IF EXISTS "riders_read_bids_on_own_request" ON public.ride_bids;
DROP POLICY IF EXISTS "drivers_insert_bids" ON public.ride_bids;
DROP POLICY IF EXISTS "drivers_read_own_bids" ON public.ride_bids;

CREATE POLICY "riders_read_bids_on_owned_ride"
ON public.ride_bids
FOR SELECT
TO authenticated
USING (private.rider_owns_ride(ride_request_id));

CREATE POLICY "drivers_read_own_bids"
ON public.ride_bids
FOR SELECT
TO authenticated
USING (
  driver_id IN (
    SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
  )
);

CREATE POLICY "drivers_insert_own_bids"
ON public.ride_bids
FOR INSERT
TO authenticated
WITH CHECK (
  driver_id IN (
    SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
  )
);

CREATE POLICY "riders_update_bid_status_on_owned_ride"
ON public.ride_bids
FOR UPDATE
TO authenticated
USING (private.rider_owns_ride(ride_request_id))
WITH CHECK (private.rider_owns_ride(ride_request_id));

REVOKE UPDATE ON TABLE public.ride_bids FROM anon, authenticated;
GRANT UPDATE (status) ON TABLE public.ride_bids TO authenticated;

CREATE OR REPLACE FUNCTION public.trg_guard_ride_bid_status_transition()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.ride_request_id IS DISTINCT FROM OLD.ride_request_id
     OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
     OR NEW.bid_amount IS DISTINCT FROM OLD.bid_amount
     OR NEW.eta_minutes IS DISTINCT FROM OLD.eta_minutes
     OR NEW.message IS DISTINCT FROM OLD.message
     OR NEW.bid_number IS DISTINCT FROM OLD.bid_number
     OR NEW.driver_snapshot IS DISTINCT FROM OLD.driver_snapshot
     OR OLD.status <> 'pending'
     OR NEW.status NOT IN ('accepted', 'rejected', 'expired') THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'bid_transition_requires_backend_command';
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = OLD.ride_request_id;

  IF NEW.status = 'accepted'
     AND (v_ride.driver_id IS DISTINCT FROM OLD.driver_id
          OR v_ride.status NOT IN ('accepted', 'assigned', 'driver_found')) THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'bid_acceptance_requires_assigned_ride';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_ride_bid_status_transition ON public.ride_bids;
CREATE TRIGGER guard_ride_bid_status_transition
BEFORE UPDATE ON public.ride_bids
FOR EACH ROW
EXECUTE FUNCTION public.trg_guard_ride_bid_status_transition();

REVOKE ALL ON FUNCTION public.trg_guard_ride_bid_status_transition()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.trg_expire_marketplace_bids_on_terminal_ride()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NEW.status IN ('cancelled', 'expired', 'no_driver')
     AND NEW.status IS DISTINCT FROM OLD.status THEN
    UPDATE public.ride_bids rb
    SET status = 'expired', updated_at = timezone('utc', now())
    WHERE rb.ride_request_id = NEW.id
      AND rb.status = 'pending';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS expire_marketplace_bids_on_terminal_ride
  ON public.ride_requests;
CREATE TRIGGER expire_marketplace_bids_on_terminal_ride
AFTER UPDATE OF status ON public.ride_requests
FOR EACH ROW
EXECUTE FUNCTION public.trg_expire_marketplace_bids_on_terminal_ride();

REVOKE ALL ON FUNCTION public.trg_expire_marketplace_bids_on_terminal_ride()
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Rider safety events are authenticated ride events, not anonymous table CRUD.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_rider_log_safety_event(
  p_ride_request_id uuid,
  p_event_type text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_driver_id uuid;
  v_event_id uuid;
  v_event_type text := lower(trim(COALESCE(p_event_type, '')));
BEGIN
  IF auth.uid() IS NULL
     OR NOT private.rider_owns_ride(p_ride_request_id) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
  END IF;

  IF v_event_type !~ '^[a-z0-9_]{3,64}$' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_event_type');
  END IF;

  SELECT rr.driver_id
  INTO v_driver_id
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ride_has_no_driver');
  END IF;

  INSERT INTO public.driver_safety_events(
    driver_id,
    event_type,
    ride_request_id,
    metadata
  ) VALUES (
    v_driver_id,
    v_event_type,
    p_ride_request_id,
    COALESCE(p_metadata, '{}'::jsonb)
      || jsonb_build_object('reported_by', 'rider')
  )
  RETURNING id INTO v_event_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'safety_event_recorded',
    'event_id', v_event_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_log_safety_event(uuid, text, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_log_safety_event(uuid, text, jsonb)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
