-- Cover payment-domain foreign keys before enabling rollout traffic.
-- These are additive indexes only; no released behavior changes.

create index if not exists mollie_oauth_states_driver_idx
  on public.mollie_oauth_states (driver_id);

create index if not exists ride_payment_events_payment_idx
  on public.ride_payment_events (ride_payment_id);

create index if not exists ride_payment_refunds_payment_idx
  on public.ride_payment_refunds (ride_payment_id);

create index if not exists ride_payments_rider_identity_idx
  on public.ride_payments (rider_identity_id);
