-- Driver Veriff hosted page URL — read at runtime by the Flutter app (no URL baked into the IPA).
-- Same HVP base + integration UUID as documented in apps/driver/docs/VERIFF_FLUTTER.md (Veriff Station → HVP).
-- Change `value` here or via Dashboard when Veriff gives a new HVP / campaign link (e.g. trial).
INSERT INTO public.app_config (key, value)
SELECT
  'driver_veriff_hvp_url',
  'https://hvp.saas-3.veriff.com/7aca3362-d582-4d4f-b270-67dd3aed3571'
WHERE NOT EXISTS (
  SELECT 1 FROM public.app_config WHERE key = 'driver_veriff_hvp_url'
);
