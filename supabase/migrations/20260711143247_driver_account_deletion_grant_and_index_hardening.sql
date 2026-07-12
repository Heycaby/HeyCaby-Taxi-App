-- Explicit per-role grants for projects that auto-expose new public functions.
REVOKE ALL ON FUNCTION public.fn_request_driver_account_deletion(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_request_driver_account_deletion(text)
  TO authenticated;

REVOKE ALL ON FUNCTION public.fn_delete_driver_owned_data()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_delete_driver_owned_data()
  TO authenticated;

REVOKE ALL ON FUNCTION public.trg_billing_ledger_business_account()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_driver_prevent_deleted_identity_reuse()
  FROM PUBLIC, anon, authenticated;

CREATE INDEX IF NOT EXISTS idx_driver_deletion_jobs_business_account
  ON public.driver_account_deletion_jobs (driver_business_account_id);
CREATE INDEX IF NOT EXISTS idx_driver_former_registry_business_account
  ON public.driver_former_account_registry (driver_business_account_id);
