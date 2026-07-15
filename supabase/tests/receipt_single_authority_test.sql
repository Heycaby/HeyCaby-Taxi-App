-- Run after receipt_single_authority. This transaction never persists data.
BEGIN;

DO $verify$
DECLARE
  v_definition text;
BEGIN
  IF has_function_privilege(
    'anon',
    'public.fn_driver_ride_issue_auto_receipt(uuid,uuid)',
    'EXECUTE'
  ) OR has_function_privilege(
    'authenticated',
    'public.fn_driver_ride_issue_auto_receipt(uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'internal receipt issuer remains client executable';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.fn_driver_create_receipt(uuid,numeric,numeric,text,text)',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated',
    'public.fn_driver_create_receipt(uuid,numeric,numeric,text,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'receipt compatibility grants invalid';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indrelid = 'public.receipts'::regclass
      AND i.indisunique
      AND pg_get_indexdef(i.indexrelid) ILIKE '%(ride_request_id)%'
  ) THEN
    RAISE EXCEPTION 'one-receipt-per-ride unique index missing';
  END IF;

  SELECT pg_get_functiondef(
    'public.fn_driver_create_receipt(uuid,numeric,numeric,text,text)'::regprocedure
  )
  INTO v_definition;

  IF v_definition NOT ILIKE '%fn_driver_ride_issue_auto_receipt%'
     OR v_definition ILIKE '%INSERT INTO public.receipts%' THEN
    RAISE EXCEPTION 'compatibility function is not a thin receipt wrapper';
  END IF;
END;
$verify$;

SELECT 'receipt_single_authority_passed' AS result;

ROLLBACK;
