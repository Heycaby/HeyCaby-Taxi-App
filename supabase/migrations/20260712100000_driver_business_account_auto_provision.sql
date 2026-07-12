-- Auto-provision driver_business_accounts for every driver so trip-complete billing
-- (trg_billing_ledger_trip_completed) never fails with driver_business_account_not_found.

CREATE OR REPLACE FUNCTION public.fn_ensure_driver_business_account(p_driver_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_driver_id IS NULL THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.driver_business_accounts (driver_id)
  VALUES (p_driver_id)
  ON CONFLICT (driver_id) DO UPDATE
    SET updated_at = timezone('utc', now())
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_ensure_driver_business_account(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_ensure_driver_business_account(uuid)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.trg_billing_ledger_business_account()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.driver_business_account_id IS NULL AND NEW.driver_id IS NOT NULL THEN
    NEW.driver_business_account_id :=
      public.fn_ensure_driver_business_account(NEW.driver_id);
  END IF;
  IF NEW.driver_business_account_id IS NULL THEN
    RAISE EXCEPTION 'driver_business_account_not_found';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_drivers_ensure_business_account()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.fn_ensure_driver_business_account(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_drivers_ensure_business_account ON public.drivers;
CREATE TRIGGER trg_drivers_ensure_business_account
  AFTER INSERT ON public.drivers
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_drivers_ensure_business_account();

INSERT INTO public.driver_business_accounts (driver_id)
SELECT d.id
FROM public.drivers d
LEFT JOIN public.driver_business_accounts dba ON dba.driver_id = d.id
WHERE dba.id IS NULL
ON CONFLICT (driver_id) DO NOTHING;
