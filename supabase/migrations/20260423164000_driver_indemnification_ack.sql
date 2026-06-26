-- Driver indemnification acknowledgement + quiz gate before online.
alter table public.drivers
  add column if not exists indemnification_read_at timestamptz;

alter table public.drivers
  add column if not exists indemnification_quiz_passed boolean not null default false;
