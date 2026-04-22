-- Allow multiple saved rows per category (e.g. Mom's home, Dad's home).
ALTER TABLE public.saved_addresses
  DROP CONSTRAINT IF EXISTS saved_addresses_rider_identity_id_type_key;

-- Recent destinations: rider app reads/writes used_at for type = recent
ALTER TABLE public.saved_addresses
  ADD COLUMN IF NOT EXISTS used_at timestamptz;

UPDATE public.saved_addresses
SET used_at = created_at
WHERE used_at IS NULL;
