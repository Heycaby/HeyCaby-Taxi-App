-- Server-driven public links (App Store, Play Store, website, legal, social).
-- Update values in app_config — no app rebuild required.

INSERT INTO public.app_config (key, value)
SELECT 'customer_app_store_url', 'https://apps.apple.com/nl/app/heycaby/id6761512910'
WHERE NOT EXISTS (SELECT 1 FROM public.app_config WHERE key = 'customer_app_store_url');

INSERT INTO public.app_config (key, value)
SELECT 'website_url', 'https://heycaby.nl'
WHERE NOT EXISTS (SELECT 1 FROM public.app_config WHERE key = 'website_url');

-- Intentionally unset until Apple approves the Driver app — omit row (app_config.value is NOT NULL).
-- Set later: INSERT INTO app_config (key, value) VALUES ('driver_app_store_url', 'https://...');
-- Optional legal/social keys are also omitted until configured (fn_app_public_links returns null).

-- ---------------------------------------------------------------------------
-- Public links JSON for all clients (rider + driver + web hooks).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_app_public_links()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'customer_app_store', NULLIF(trim(public.fn_app_config_text('customer_app_store_url')), ''),
    'driver_app_store', NULLIF(trim(public.fn_app_config_text('driver_app_store_url')), ''),
    'customer_play_store', NULLIF(trim(public.fn_app_config_text('customer_play_store_url')), ''),
    'driver_play_store', NULLIF(trim(public.fn_app_config_text('driver_play_store_url')), ''),
    'website', COALESCE(
      NULLIF(trim(public.fn_app_config_text('website_url')), ''),
      'https://heycaby.nl'
    ),
    'support_email', NULLIF(trim(public.fn_app_config_text('support_email')), ''),
    'privacy_policy', NULLIF(trim(public.fn_app_config_text('privacy_policy_url')), ''),
    'terms', NULLIF(trim(public.fn_app_config_text('terms_url')), ''),
    'instagram', NULLIF(trim(public.fn_app_config_text('instagram_url')), ''),
    'facebook', NULLIF(trim(public.fn_app_config_text('facebook_url')), ''),
    'linkedin', NULLIF(trim(public.fn_app_config_text('linkedin_url')), '')
  );
$$;

REVOKE ALL ON FUNCTION public.fn_app_public_links() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_app_public_links() TO anon, authenticated, service_role;

-- Extend driver runtime config module (no new RPC).
CREATE OR REPLACE FUNCTION public.fn_driver_runtime_configuration()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'search', public.fn_app_config_jsonb('search_config'),
    'feature_flags', public.fn_app_config_jsonb('feature_flags'),
    'links', public.fn_app_public_links()
  );
$$;
