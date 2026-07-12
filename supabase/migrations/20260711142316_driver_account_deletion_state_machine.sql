-- Server-owned, idempotent driver account deletion request.
-- Access is removed atomically; personal-data erasure is completed by a
-- privileged worker according to the retention class recorded on the job.

CREATE TABLE IF NOT EXISTS public.driver_business_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid UNIQUE REFERENCES public.drivers(id) ON DELETE RESTRICT,
  public_reference text NOT NULL UNIQUE
    DEFAULT ('HC-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'restricted', 'retained', 'closed')),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.driver_business_accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.driver_business_accounts FROM PUBLIC, anon, authenticated;

INSERT INTO public.driver_business_accounts (driver_id)
SELECT d.id FROM public.drivers d
ON CONFLICT (driver_id) DO NOTHING;

ALTER TABLE public.billing_ledger
  ADD COLUMN IF NOT EXISTS driver_business_account_id uuid
    REFERENCES public.driver_business_accounts(id) ON DELETE RESTRICT;

UPDATE public.billing_ledger bl
SET driver_business_account_id = dba.id
FROM public.driver_business_accounts dba
WHERE dba.driver_id = bl.driver_id
  AND bl.driver_business_account_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_billing_ledger_business_account_created
  ON public.billing_ledger (driver_business_account_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.trg_billing_ledger_business_account()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.driver_business_account_id IS NULL THEN
    SELECT dba.id INTO NEW.driver_business_account_id
    FROM public.driver_business_accounts dba
    WHERE dba.driver_id = NEW.driver_id;
  END IF;
  IF NEW.driver_business_account_id IS NULL THEN
    RAISE EXCEPTION 'driver_business_account_not_found';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_billing_ledger_business_account ON public.billing_ledger;
CREATE TRIGGER trg_billing_ledger_business_account
  BEFORE INSERT ON public.billing_ledger
  FOR EACH ROW EXECUTE FUNCTION public.trg_billing_ledger_business_account();

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS account_status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS account_deletion_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS account_deactivated_at timestamptz,
  ADD COLUMN IF NOT EXISTS personal_data_delete_after timestamptz,
  ADD COLUMN IF NOT EXISTS account_anonymized_at timestamptz,
  ADD COLUMN IF NOT EXISTS deletion_reason text,
  ADD COLUMN IF NOT EXISTS deletion_job_status text;

ALTER TABLE public.drivers DROP CONSTRAINT IF EXISTS drivers_account_status_check;
ALTER TABLE public.drivers ADD CONSTRAINT drivers_account_status_check
  CHECK (account_status IN (
    'active', 'deletion_requested', 'deactivated',
    'anonymization_pending', 'anonymized'
  ));

CREATE TABLE IF NOT EXISTS public.driver_account_deletion_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL UNIQUE REFERENCES public.drivers(id) ON DELETE RESTRICT,
  driver_business_account_id uuid NOT NULL
    REFERENCES public.driver_business_accounts(id) ON DELETE RESTRICT,
  former_auth_user_id uuid,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'awaiting_retention_policy', 'completed', 'failed')),
  profile_assets jsonb NOT NULL DEFAULT '{}'::jsonb,
  retention_classes jsonb NOT NULL DEFAULT jsonb_build_object(
    'access', 'immediate',
    'public_profile', 'prompt_delete',
    'precise_location', 'short_documented_policy',
    'financial', 'statutory_accounting_period',
    'safety_legal', 'case_and_claim_period',
    'fraud_prevention', 'minimal_while_justified'
  ),
  attempts integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  last_error text,
  requested_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.driver_former_account_registry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  former_driver_id uuid NOT NULL UNIQUE,
  driver_business_account_id uuid NOT NULL
    REFERENCES public.driver_business_accounts(id) ON DELETE RESTRICT,
  restriction_reason text,
  restriction_expires_at timestamptz,
  legal_retention_basis text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.driver_account_deletion_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  driver_id uuid NOT NULL,
  driver_business_account_id uuid NOT NULL,
  event_type text NOT NULL,
  actor_auth_user_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.driver_account_deletion_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_former_account_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_account_deletion_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.driver_account_deletion_jobs FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.driver_former_account_registry FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.driver_account_deletion_audit FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.fn_request_driver_account_deletion(
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_driver public.drivers%ROWTYPE;
  v_business_id uuid;
  v_job_id uuid;
  v_outstanding bigint := 0;
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT d.* INTO v_driver
  FROM public.drivers d
  WHERE d.user_id = v_uid
  FOR UPDATE;

  IF NOT FOUND THEN
    SELECT j.id, j.driver_id INTO v_job_id, v_driver.id
    FROM public.driver_account_deletion_jobs j
    WHERE j.former_auth_user_id = v_uid
    LIMIT 1;
    IF v_job_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true, 'already_requested', true,
        'job_id', v_job_id, 'account_status', 'deactivated'
      );
    END IF;
    RETURN jsonb_build_object('success', false, 'error', 'driver_not_found');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.ride_requests rr
    WHERE rr.driver_id = v_driver.id
      AND rr.status IN (
        'accepted', 'driver_en_route', 'arrived', 'waiting',
        'in_progress', 'payment_pending'
      )
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'active_ride_must_be_completed',
      'message', 'Complete or cancel your active ride before deleting your account.'
    );
  END IF;

  INSERT INTO public.driver_business_accounts (driver_id)
  VALUES (v_driver.id)
  ON CONFLICT (driver_id) DO UPDATE SET updated_at = EXCLUDED.updated_at
  RETURNING id INTO v_business_id;

  SELECT COALESCE(sum(bl.amount_cents), 0)::bigint INTO v_outstanding
  FROM public.billing_ledger bl
  WHERE bl.driver_business_account_id = v_business_id;

  INSERT INTO public.driver_account_deletion_jobs (
    driver_id, driver_business_account_id, former_auth_user_id, profile_assets
  ) VALUES (
    v_driver.id,
    v_business_id,
    v_uid,
    jsonb_build_object(
      'profile_photo_url', v_driver.profile_photo_url,
      'vehicle_photo_front_url', v_driver.vehicle_photo_front_url,
      'vehicle_photo_rear_url', v_driver.vehicle_photo_rear_url,
      'vehicle_photo_urls', to_jsonb(v_driver.vehicle_photo_urls)
    )
  )
  ON CONFLICT (driver_id) DO UPDATE SET
    updated_at = v_now,
    next_attempt_at = LEAST(driver_account_deletion_jobs.next_attempt_at, v_now)
  RETURNING id INTO v_job_id;

  UPDATE public.ride_requests
  SET driver_id = NULL,
      accepted_at = NULL,
      scheduled_confirmed_by_driver = false,
      driver_released_at = v_now,
      driver_released_reason = 'driver_account_deactivated',
      updated_at = v_now
  WHERE driver_id = v_driver.id
    AND is_scheduled = true
    AND status = 'pending'
    AND COALESCE(scheduled_pickup_at, scheduled_at) > v_now;

  UPDATE public.taxi_vehicle_sessions
  SET is_active = false, ended_at = v_now, ended_reason = 'account_deactivated'
  WHERE driver_id = v_driver.id AND is_active = true AND ended_at IS NULL;

  UPDATE public.driver_shift_sessions
  SET shift_ended_at = COALESCE(shift_ended_at, v_now)
  WHERE driver_id = v_driver.id AND shift_ended_at IS NULL;

  DELETE FROM public.driver_locations WHERE driver_id = v_driver.id;
  DELETE FROM public.push_devices
  WHERE driver_id = v_driver.id OR auth_user_id = v_uid;

  UPDATE public.driver_business_accounts
  SET status = CASE WHEN v_outstanding <> 0 THEN 'restricted' ELSE 'retained' END,
      updated_at = v_now
  WHERE id = v_business_id;

  INSERT INTO public.driver_former_account_registry (
    former_driver_id, driver_business_account_id, restriction_reason,
    legal_retention_basis
  ) VALUES (
    v_driver.id,
    v_business_id,
    CASE WHEN v_outstanding <> 0 THEN 'outstanding_platform_balance' END,
    CASE WHEN v_outstanding <> 0
      THEN 'contractual_financial_obligation_and_fraud_prevention'
      ELSE 'accounting_audit_linkage'
    END
  )
  ON CONFLICT (former_driver_id) DO UPDATE SET
    restriction_reason = EXCLUDED.restriction_reason,
    legal_retention_basis = EXCLUDED.legal_retention_basis,
    updated_at = v_now;

  UPDATE public.drivers
  SET account_status = 'anonymization_pending',
      account_deletion_requested_at = COALESCE(account_deletion_requested_at, v_now),
      account_deactivated_at = COALESCE(account_deactivated_at, v_now),
      deletion_reason = NULLIF(btrim(p_reason), ''),
      deletion_job_status = 'pending',
      status = 'offline',
      profile_status = 'suspended',
      current_shift_id = NULL,
      shift_start_at = NULL,
      shift_started_at = NULL,
      return_mode_enabled = false,
      return_mode_auto_accept_enabled = false,
      user_id = NULL,
      updated_at = v_now
  WHERE id = v_driver.id;

  -- Revokes refresh-token sessions. The already-issued JWT may live until its
  -- short expiry, but user_id=NULL removes all owner-scoped application access.
  DELETE FROM auth.sessions WHERE user_id = v_uid;

  INSERT INTO public.driver_account_deletion_audit (
    driver_id, driver_business_account_id, event_type, actor_auth_user_id, metadata
  ) VALUES (
    v_driver.id, v_business_id, 'deletion_requested', v_uid,
    jsonb_build_object(
      'job_id', v_job_id,
      'outstanding_balance_cents', v_outstanding,
      'scheduled_rides_released', true
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'job_id', v_job_id,
    'account_status', 'deactivated',
    'outstanding_balance_cents', v_outstanding,
    'personal_data_schedule', 'processed_by_retention_class'
  );
END;
$$;

-- Keep the old RPC name as a compatibility shim. It no longer hard-deletes.
CREATE OR REPLACE FUNCTION public.fn_delete_driver_owned_data()
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT public.fn_request_driver_account_deletion(NULL);
$$;

REVOKE ALL ON FUNCTION public.fn_request_driver_account_deletion(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_request_driver_account_deletion(text) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_delete_driver_owned_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_delete_driver_owned_data() TO authenticated;
REVOKE ALL ON FUNCTION public.trg_billing_ledger_business_account() FROM PUBLIC;
