-- Optional human-readable resolution for closed support tickets.
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS resolution_summary text,
  ADD COLUMN IF NOT EXISTS resolution_outcome text;

COMMENT ON COLUMN public.tickets.resolution_summary IS
  'Short reason or topic summary when the ticket was closed.';
COMMENT ON COLUMN public.tickets.resolution_outcome IS
  'How the issue was resolved (e.g. refund issued, explained policy).';
