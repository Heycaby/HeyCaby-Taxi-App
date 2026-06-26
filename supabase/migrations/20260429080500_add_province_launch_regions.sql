-- Province-level rollout support (additive, non-breaking)
-- NL-first execution with global-ready region activation.

-- 1) Add province_code on cities while keeping existing city activation model.
ALTER TABLE public.cities
  ADD COLUMN IF NOT EXISTS province_code TEXT;

CREATE INDEX IF NOT EXISTS idx_cities_country_province_active
  ON public.cities (country_code, province_code, is_active);

-- 2) Create launch_regions table for province-level activation.
CREATE TABLE IF NOT EXISTS public.launch_regions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_code TEXT NOT NULL,
  province_code TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT false,
  rollout_starts_at TIMESTAMPTZ,
  rollout_ends_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT launch_regions_country_province_unique UNIQUE (country_code, province_code)
);

CREATE INDEX IF NOT EXISTS idx_launch_regions_country_active
  ON public.launch_regions (country_code, is_active);

-- 3) Seed NL provinces for rollout control (city-level stays as override).
INSERT INTO public.launch_regions (country_code, province_code, is_active, notes)
VALUES
  ('NL', 'ZH', true,  'Zuid-Holland (South Holland)'),
  ('NL', 'NH', true,  'Noord-Holland (North Holland)'),
  ('NL', 'UT', true,  'Utrecht'),
  ('NL', 'NB', true,  'Noord-Brabant (North Brabant)'),
  ('NL', 'OV', true,  'Overijssel'),
  ('NL', 'GE', false, 'Gelderland'),
  ('NL', 'LI', false, 'Limburg'),
  ('NL', 'DR', false, 'Drenthe'),
  ('NL', 'FL', false, 'Flevoland'),
  ('NL', 'FR', false, 'Friesland'),
  ('NL', 'GR', false, 'Groningen'),
  ('NL', 'ZE', false, 'Zeeland')
ON CONFLICT (country_code, province_code) DO NOTHING;

-- 4) Backfill known launch cities to province codes (best effort by slug/name).
UPDATE public.cities
SET province_code = 'ZH'
WHERE country_code = 'NL'
  AND (
    slug IN ('rotterdam', 'dordrecht', 'den-haag', 's-gravenhage', 'the-hague')
    OR lower(name) IN ('rotterdam', 'dordrecht', 'den haag', '''s-gravenhage', 'the hague')
  );

UPDATE public.cities
SET province_code = 'NH'
WHERE country_code = 'NL'
  AND (
    slug IN ('amsterdam', 'haarlem', 'alkmaar')
    OR lower(name) IN ('amsterdam', 'haarlem', 'alkmaar')
  );

UPDATE public.cities
SET province_code = 'UT'
WHERE country_code = 'NL'
  AND (
    slug IN ('utrecht', 'amersfoort')
    OR lower(name) IN ('utrecht', 'amersfoort')
  );

UPDATE public.cities
SET province_code = 'NB'
WHERE country_code = 'NL'
  AND (
    slug IN ('eindhoven', 'breda')
    OR lower(name) IN ('eindhoven', 'breda')
  );

UPDATE public.cities
SET province_code = 'OV'
WHERE country_code = 'NL'
  AND (
    slug IN ('hengelo', 'enschede')
    OR lower(name) IN ('hengelo', 'enschede')
  );

