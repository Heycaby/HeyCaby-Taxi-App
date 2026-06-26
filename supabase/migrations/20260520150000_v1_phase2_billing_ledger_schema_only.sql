-- Phase 2 Steps 1–2: billing_ledger + market_config (schema only, no trip.completed trigger).
-- Step 4 (trip.completed trigger) → separate migration after smoke tests.
-- Billing LOCK (€60) → Phase 3.

-- ---------------------------------------------------------------------------
-- Step 1: billing_ledger (append-only, no balance triggers)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.billing_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE RESTRICT,
  ledger_sequence bigint NOT NULL,
  amount_cents integer NOT NULL,
  reason text NOT NULL CHECK (reason IN (
    'ride_fee', 'manual_adjustment', 'promotion', 'refund', 'settlement', 'credit', 'reversal'
  )),
  ride_id uuid REFERENCES public.ride_requests(id) ON DELETE SET NULL,
  currency text NOT NULL DEFAULT 'EUR',
  country_code text NOT NULL DEFAULT 'NL',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  created_by uuid,
  CONSTRAINT billing_ledger_nonzero_amount CHECK (amount_cents <> 0),
  CONSTRAINT billing_ledger_driver_sequence UNIQUE (driver_id, ledger_sequence)
);

COMMENT ON TABLE public.billing_ledger IS
  'Immutable platform fee ledger. Corrections via reversing entries (reversal reason), never UPDATE.';
COMMENT ON COLUMN public.billing_ledger.ledger_sequence IS
  'Monotonic per-driver sequence for deterministic ordering when timestamps collide.';

-- Assign next ledger_sequence per driver on insert (not balance — ledger remains source of truth).
CREATE OR REPLACE FUNCTION public.fn_billing_ledger_assign_sequence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.ledger_sequence IS NULL OR NEW.ledger_sequence = 0 THEN
    SELECT COALESCE(MAX(bl.ledger_sequence), 0) + 1
    INTO NEW.ledger_sequence
    FROM public.billing_ledger bl
    WHERE bl.driver_id = NEW.driver_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_billing_ledger_assign_sequence ON public.billing_ledger;
CREATE TRIGGER trg_billing_ledger_assign_sequence
  BEFORE INSERT ON public.billing_ledger
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_billing_ledger_assign_sequence();

-- Invariant: at most one ride_fee per ride
CREATE UNIQUE INDEX IF NOT EXISTS billing_ledger_one_ride_fee_per_ride
  ON public.billing_ledger (ride_id, reason)
  WHERE reason = 'ride_fee' AND ride_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_billing_ledger_driver_created
  ON public.billing_ledger (driver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_billing_ledger_driver_reason
  ON public.billing_ledger (driver_id, reason);

ALTER TABLE public.billing_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS billing_ledger_select_own ON public.billing_ledger;
CREATE POLICY billing_ledger_select_own
  ON public.billing_ledger
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = billing_ledger.driver_id AND d.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS billing_ledger_select_admin ON public.billing_ledger;
CREATE POLICY billing_ledger_select_admin
  ON public.billing_ledger
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
  );

-- Outstanding balance view (read-only)
CREATE OR REPLACE VIEW public.driver_platform_balance AS
SELECT
  driver_id,
  country_code,
  currency,
  COALESCE(SUM(amount_cents), 0)::bigint AS outstanding_cents,
  COUNT(*) FILTER (WHERE reason = 'ride_fee') AS ride_fee_entries
FROM public.billing_ledger
GROUP BY driver_id, country_code, currency;

COMMENT ON VIEW public.driver_platform_balance IS
  'Sum of ledger rows excluding settlement/credit; used for UI until lock logic (Phase 3).';

-- ---------------------------------------------------------------------------
-- Step 2: market_config (inherits: platform → country → city → zone)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.market_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL CHECK (scope IN ('platform', 'country', 'city', 'zone')),
  country_code text,
  city_id uuid REFERENCES public.cities(id) ON DELETE CASCADE,
  zone_id uuid REFERENCES public.bubble_zones(id) ON DELETE CASCADE,
  config_key text NOT NULL,
  config_value jsonb NOT NULL,
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT market_config_scope_keys CHECK (
    (scope = 'platform' AND country_code IS NULL AND city_id IS NULL AND zone_id IS NULL)
    OR (scope = 'country' AND country_code IS NOT NULL AND city_id IS NULL AND zone_id IS NULL)
    OR (scope = 'city' AND city_id IS NOT NULL)
    OR (scope = 'zone' AND zone_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS market_config_unique_platform
  ON public.market_config (config_key)
  WHERE scope = 'platform' AND active = true;

CREATE UNIQUE INDEX IF NOT EXISTS market_config_unique_country
  ON public.market_config (country_code, config_key)
  WHERE scope = 'country' AND active = true;

CREATE UNIQUE INDEX IF NOT EXISTS market_config_unique_city
  ON public.market_config (city_id, config_key)
  WHERE scope = 'city' AND active = true;

CREATE UNIQUE INDEX IF NOT EXISTS market_config_unique_zone
  ON public.market_config (zone_id, config_key)
  WHERE scope = 'zone' AND active = true;

ALTER TABLE public.market_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS market_config_select_all ON public.market_config;
CREATE POLICY market_config_select_all
  ON public.market_config
  FOR SELECT
  TO authenticated, anon
  USING (active = true);

-- NL country defaults
INSERT INTO public.market_config (scope, country_code, config_key, config_value)
SELECT 'country', 'NL', 'platform_fee_cents', '100'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.market_config
  WHERE scope = 'country' AND country_code = 'NL' AND config_key = 'platform_fee_cents' AND active = true
);

INSERT INTO public.market_config (scope, country_code, config_key, config_value)
SELECT 'country', 'NL', 'outstanding_limit_cents', '6000'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.market_config
  WHERE scope = 'country' AND country_code = 'NL' AND config_key = 'outstanding_limit_cents' AND active = true
);

INSERT INTO public.market_config (scope, country_code, config_key, config_value)
SELECT 'country', 'NL', 'currency', '"EUR"'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.market_config
  WHERE scope = 'country' AND country_code = 'NL' AND config_key = 'currency' AND active = true
);

-- Resolver: most specific wins (zone → city → country → platform)
CREATE OR REPLACE FUNCTION public.fn_get_market_config(
  p_config_key text,
  p_country_code text DEFAULT 'NL',
  p_city_id uuid DEFAULT NULL,
  p_zone_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT mc.config_value
  FROM public.market_config mc
  WHERE mc.active = true
    AND mc.config_key = p_config_key
    AND (
      (p_zone_id IS NOT NULL AND mc.scope = 'zone' AND mc.zone_id = p_zone_id)
      OR (p_city_id IS NOT NULL AND mc.scope = 'city' AND mc.city_id = p_city_id)
      OR (mc.scope = 'country' AND mc.country_code = p_country_code)
      OR (mc.scope = 'platform')
    )
  ORDER BY CASE mc.scope
    WHEN 'zone' THEN 1
    WHEN 'city' THEN 2
    WHEN 'country' THEN 3
    WHEN 'platform' THEN 4
  END
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.fn_get_market_config(text, text, uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_get_market_config(text, text, uuid, uuid) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Step 3 helpers (manual smoke — run after apply, before Step 4 trigger)
-- See: scripts/sql/smoke_phase2_billing_ledger_manual.sql
-- ---------------------------------------------------------------------------
