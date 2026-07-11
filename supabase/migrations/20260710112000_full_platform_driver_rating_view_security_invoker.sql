-- Full-platform stabilization follow-up.
-- The view already filters by auth.uid(), and driver_trust_scores has
-- owner-scoped RLS. Run it with the caller's permissions so the view cannot
-- bypass that RLS as its owner.

ALTER VIEW public.driver_my_rating SET (security_invoker = true);

REVOKE ALL ON public.driver_my_rating FROM PUBLIC, anon;
GRANT SELECT ON public.driver_my_rating TO authenticated, service_role;

