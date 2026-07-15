-- Driver Mollie onboarding is independently gated so OAuth can be rolled out
-- to an internal cohort before any rider prepayment mode is enabled.
update public.app_config
set value = (
  coalesce(nullif(value, '')::jsonb, '{}'::jsonb)
  || jsonb_build_object('ride_prepaid_driver_connect_enabled', false)
)::text
where key = 'feature_flags';
