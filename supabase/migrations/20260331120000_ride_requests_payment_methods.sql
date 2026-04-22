-- Rider app sends payment_methods (cash | pin | tikkie) from the payment screen.
ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS payment_methods text[] DEFAULT '{}'::text[];

COMMENT ON COLUMN public.ride_requests.payment_methods IS
  'Accepted payment options for this request; rider UI ids: cash, pin, tikkie';
