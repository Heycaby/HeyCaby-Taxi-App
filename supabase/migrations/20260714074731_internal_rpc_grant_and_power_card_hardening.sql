-- Restore least-privilege execution for backend-only maintenance, lifecycle,
-- billing, and Shift Handover helpers. Production caller inventory on
-- 2026-07-14 found only service-role Edge callers, owner-context SQL callers,
-- or no active caller; no Rider/Driver Flutter caller or pg_cron job exists.

REVOKE ALL ON FUNCTION public.check_all_compliance_expiries()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_all_compliance_expiries()
  TO service_role;

REVOKE ALL ON FUNCTION public.expire_stale_auctions()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_auctions()
  TO service_role;

REVOKE ALL ON FUNCTION public.expire_stale_favorite_requests()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_favorite_requests()
  TO service_role;

REVOKE ALL ON FUNCTION public.expire_stale_swaps()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_swaps()
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_claim_due_rider_lifecycle_jobs(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_claim_due_rider_lifecycle_jobs(integer)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_community_cleanup_expired_posts()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_community_cleanup_expired_posts()
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_force_offline_for_handover(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_force_offline_for_handover(uuid, text)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_billing_audit_append(
  uuid, text, uuid, jsonb, uuid
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_billing_audit_append(
  uuid, text, uuid, jsonb, uuid
) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_billing_apply_settlement(
  uuid, integer, text, text, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_apply_settlement(
  uuid, integer, text, text, jsonb
) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_billing_checkout_intent_by_payment(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_checkout_intent_by_payment(text)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_billing_record_checkout_intent(
  uuid, integer, text, text, text, text, text, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_record_checkout_intent(
  uuid, integer, text, text, text, text, text, jsonb
) TO service_role;

-- Preserve the released Driver power-card signatures while binding the
-- caller-supplied driver id to the authenticated Driver account.

CREATE OR REPLACE FUNCTION public.fn_dismiss_power_card(
  p_card_id uuid,
  p_driver_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_driver_id uuid;
BEGIN
  SELECT d.id
  INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL OR v_driver_id <> p_driver_id THEN
    INSERT INTO private.domain_security_events(
      domain, event, actor_user_id, object_id, metadata
    ) VALUES (
      'driver_community', 'power_card_identity_mismatch', auth.uid(),
      p_card_id, jsonb_build_object('requested_driver_id', p_driver_id)
    );
    RETURN false;
  END IF;

  UPDATE public.driver_power_suggestions
  SET dismissed_at = timezone('utc', now())
  WHERE id = p_card_id
    AND driver_id = v_driver_id
    AND dismissed_at IS NULL;

  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_act_on_power_card(
  p_card_id uuid,
  p_driver_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_driver_id uuid;
BEGIN
  SELECT d.id
  INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL OR v_driver_id <> p_driver_id THEN
    INSERT INTO private.domain_security_events(
      domain, event, actor_user_id, object_id, metadata
    ) VALUES (
      'driver_community', 'power_card_identity_mismatch', auth.uid(),
      p_card_id, jsonb_build_object('requested_driver_id', p_driver_id)
    );
    RETURN false;
  END IF;

  UPDATE public.driver_power_suggestions
  SET acted_on_at = timezone('utc', now())
  WHERE id = p_card_id
    AND driver_id = v_driver_id
    AND acted_on_at IS NULL;

  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_dismiss_power_card(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_dismiss_power_card(uuid, uuid)
  TO authenticated;

REVOKE ALL ON FUNCTION public.fn_act_on_power_card(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_act_on_power_card(uuid, uuid)
  TO authenticated;

COMMENT ON FUNCTION public.fn_dismiss_power_card(uuid, uuid) IS
  'Authenticated Driver command; p_driver_id must match auth.uid().';
COMMENT ON FUNCTION public.fn_act_on_power_card(uuid, uuid) IS
  'Authenticated Driver command; p_driver_id must match auth.uid().';
