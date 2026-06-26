-- Keep legal acknowledgements independently auditable:
-- - terms_accepted_at: user explicitly checked Terms of Service
-- - indemnification_read_at: user explicitly checked indemnification declaration
alter table public.drivers
  add column if not exists terms_accepted_at timestamptz;
