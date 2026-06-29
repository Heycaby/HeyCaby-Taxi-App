-- Server-driven rider home banners (announcements, promos, supply notices).
-- Activate/update rows in rider_home_banners — no app rebuild required.

CREATE TABLE IF NOT EXISTS public.rider_home_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  subtitle text,
  variant text NOT NULL DEFAULT 'accent'
    CHECK (variant IN ('accent', 'promo', 'info', 'warning')),
  tap_action text NOT NULL DEFAULT 'none'
    CHECK (tap_action IN ('none', 'modal', 'url')),
  url text,
  modal_title text,
  modal_body text,
  locale text,
  priority integer NOT NULL DEFAULT 0,
  starts_at timestamptz,
  ends_at timestamptz,
  only_when_no_supply boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS rider_home_banners_active_idx
  ON public.rider_home_banners (is_active, priority DESC, starts_at);

ALTER TABLE public.rider_home_banners ENABLE ROW LEVEL SECURITY;

-- Reads go through SECURITY DEFINER RPC only.
REVOKE ALL ON TABLE public.rider_home_banners FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.rider_home_banners TO service_role;

CREATE OR REPLACE FUNCTION public.fn_rider_home_banners(p_locale text DEFAULT 'en')
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'slug', b.slug,
        'title', b.title,
        'subtitle', b.subtitle,
        'variant', b.variant,
        'tap_action', b.tap_action,
        'url', b.url,
        'modal_title', b.modal_title,
        'modal_body', b.modal_body,
        'only_when_no_supply', b.only_when_no_supply,
        'priority', b.priority
      )
      ORDER BY b.priority DESC, b.created_at DESC
    ),
    '[]'::jsonb
  )
  FROM public.rider_home_banners b
  WHERE b.is_active
    AND (b.starts_at IS NULL OR b.starts_at <= now())
    AND (b.ends_at IS NULL OR b.ends_at > now())
    AND (
      b.locale IS NULL
      OR lower(trim(b.locale)) = lower(trim(COALESCE(p_locale, 'en')))
      OR lower(trim(b.locale)) = lower(split_part(COALESCE(p_locale, 'en'), '-', 1))
    );
$$;

REVOKE ALL ON FUNCTION public.fn_rider_home_banners(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_home_banners(text) TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.fn_rider_home_banners(text) IS
  'Active rider home banners for the home sheet. Set is_active=true in rider_home_banners to publish.';

-- Example (inactive): anniversary promo with in-app modal copy.
INSERT INTO public.rider_home_banners (
  slug,
  title,
  subtitle,
  variant,
  tap_action,
  modal_title,
  modal_body,
  priority,
  is_active
)
VALUES (
  'anniversary_2026_example',
  'HeyCaby turns 1 today!',
  'Tap to see how we are celebrating with riders and drivers.',
  'promo',
  'modal',
  'One year of HeyCaby',
  'Thank you for riding with us. Stay tuned for anniversary perks — details will appear here when the campaign goes live.',
  100,
  false
)
ON CONFLICT (slug) DO NOTHING;

-- Optional: move the no-supply notice to the server (inactive by default; app keeps a local fallback).
INSERT INTO public.rider_home_banners (
  slug,
  title,
  subtitle,
  variant,
  tap_action,
  only_when_no_supply,
  priority,
  is_active
)
VALUES (
  'no_supply_notice',
  'No taxis in your zone',
  'You can request and we''ll notify you when a driver is available.',
  'accent',
  'none',
  true,
  50,
  false
)
ON CONFLICT (slug) DO NOTHING;
