-- PostgREST cannot reliably resolve two fn_driver_return_mode_activate overloads
-- when the app sends journey-intent params. Keep the 9-arg wizard contract only.

DROP FUNCTION IF EXISTS public.fn_driver_return_mode_activate(
  text,
  uuid,
  double precision,
  double precision,
  numeric,
  numeric
);

GRANT EXECUTE ON FUNCTION public.fn_driver_return_mode_activate(
  text,
  uuid,
  double precision,
  double precision,
  numeric,
  numeric,
  text,
  timestamptz,
  numeric
) TO authenticated, service_role;
