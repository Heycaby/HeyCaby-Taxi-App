-- Default ride preferences for repeat bookings (nullable; rider can change anytime in-app).
ALTER TABLE public.rider_identities
  ADD COLUMN IF NOT EXISTS preferred_payment_methods text[],
  ADD COLUMN IF NOT EXISTS preferred_vehicle_category text,
  ADD COLUMN IF NOT EXISTS preferred_pet_friendly boolean;

COMMENT ON COLUMN public.rider_identities.preferred_payment_methods IS
  'Default payment method ids for booking: cash, pin, tikkie';
COMMENT ON COLUMN public.rider_identities.preferred_vehicle_category IS
  'Default vehicle category: standard, comfort, taxibus, wheelchair';
COMMENT ON COLUMN public.rider_identities.preferred_pet_friendly IS
  'Default pet-friendly filter for matching';
