-- Reconciliation, reporting, and immutable ride projection for Driver Service Fee v2.

ALTER TABLE public.billing_ledger ADD COLUMN IF NOT EXISTS idempotency_key text;
CREATE UNIQUE INDEX IF NOT EXISTS billing_ledger_idempotency_key_idx
  ON public.billing_ledger(idempotency_key) WHERE idempotency_key IS NOT NULL;

CREATE OR REPLACE FUNCTION private.trg_billing_ledger_idempotency_key()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  new.idempotency_key:=COALESCE(new.idempotency_key,NULLIF(new.metadata->>'idempotency_key',''));
  RETURN new;
END; $$;

DROP TRIGGER IF EXISTS trg_billing_ledger_idempotency_key ON public.billing_ledger;
CREATE TRIGGER trg_billing_ledger_idempotency_key
BEFORE INSERT ON public.billing_ledger FOR EACH ROW
EXECUTE FUNCTION private.trg_billing_ledger_idempotency_key();

CREATE OR REPLACE FUNCTION private.trg_driver_fee_acceptance_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_check jsonb; v_snapshot jsonb;
BEGIN
  IF new.driver_id IS NULL OR new.status NOT IN ('assigned','accepted','driver_found')
     OR (old.driver_id IS NOT DISTINCT FROM new.driver_id AND old.status IS NOT DISTINCT FROM new.status)
  THEN RETURN new; END IF;
  v_check:=public.fn_check_driver_payment_eligibility(new.driver_id,new.id);
  IF COALESCE((v_check->>'ride_allowed')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'driver_platform_balance_limit_reached' USING ERRCODE='P0001';
  END IF;
  v_snapshot:=public.fn_snapshot_driver_service_fee(new.id,new.driver_id);
  IF COALESCE((v_snapshot->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'driver_fee_snapshot_failed' USING ERRCODE='P0001';
  END IF;
  IF COALESCE((v_snapshot->>'enabled')::boolean,true)
     AND v_snapshot->>'service_fee_cents' IS NOT NULL THEN
    new.platform_fee_cents:=(v_snapshot->>'service_fee_cents')::integer;
    new.driver_earnings_cents:=(v_snapshot->>'estimated_driver_net_cents')::integer;
  END IF;
  RETURN new;
END; $$;

CREATE OR REPLACE FUNCTION public.fn_reverse_driver_service_fee(
  p_ride_id uuid,p_reason_code text,p_reason_text text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_charge public.billing_ledger%ROWTYPE; v_id uuid; v_key text;
BEGIN
  SELECT * INTO v_charge FROM public.billing_ledger
  WHERE ride_id=p_ride_id AND reason='ride_fee' ORDER BY created_at LIMIT 1;
  IF v_charge.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','driver_service_fee_not_found'); END IF;
  IF char_length(btrim(COALESCE(p_reason_code,'')))<3 THEN
    RETURN jsonb_build_object('ok',false,'error','reason_required'); END IF;
  v_key:='driver_fee_reversal:'||p_ride_id::text||':'||lower(btrim(p_reason_code));
  INSERT INTO public.billing_ledger(driver_id,amount_cents,reason,ride_id,currency,
    country_code,metadata,idempotency_key,created_by)
  VALUES(v_charge.driver_id,-v_charge.amount_cents,'reversal',p_ride_id,
    v_charge.currency,v_charge.country_code,jsonb_build_object(
      'source','driver_service_fee_reversal','reversed_ledger_id',v_charge.id,
      'reason_code',lower(btrim(p_reason_code)),'reason_text',p_reason_text,
      'idempotency_key',v_key),v_key,auth.uid())
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING
  RETURNING id INTO v_id;
  IF v_id IS NOT NULL THEN PERFORM public.fn_billing_audit_append(
    v_charge.driver_id,'billing.driver_service_fee_reversed',p_ride_id,
    jsonb_build_object('ledger_id',v_id,'reversed_ledger_id',v_charge.id,
      'amount_cents',v_charge.amount_cents,'reason_code',p_reason_code),p_ride_id); END IF;
  RETURN jsonb_build_object('ok',true,'reversed',v_id IS NOT NULL,'idempotent_replay',v_id IS NULL);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_waive_driver_balance_entry(
  p_ledger_id uuid,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor public.admin_users; v_entry public.billing_ledger%ROWTYPE; v_id uuid; v_key text;
BEGIN
  v_actor:=private.fn_admin_os_actor('finance.manage',true);
  IF char_length(btrim(COALESCE(p_reason,'')))<8 THEN
    RETURN jsonb_build_object('ok',false,'error','reason_required'); END IF;
  SELECT * INTO v_entry FROM public.billing_ledger WHERE id=p_ledger_id FOR UPDATE;
  IF v_entry.id IS NULL OR v_entry.amount_cents<=0 THEN
    RETURN jsonb_build_object('ok',false,'error','positive_ledger_entry_required'); END IF;
  v_key:='admin_waiver:'||p_ledger_id::text;
  INSERT INTO public.billing_ledger(driver_id,amount_cents,reason,ride_id,currency,
    country_code,metadata,idempotency_key,created_by)
  VALUES(v_entry.driver_id,-v_entry.amount_cents,'waiver',v_entry.ride_id,
    v_entry.currency,v_entry.country_code,jsonb_build_object('source','admin_os',
      'waived_ledger_id',v_entry.id,'reason',btrim(p_reason),'idempotency_key',v_key),
    v_key,v_actor.user_id)
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING RETURNING id INTO v_id;
  IF v_id IS NOT NULL THEN PERFORM private.fn_admin_os_audit(v_actor,
    'driver_service_fee.waive','billing_ledger',v_entry.id::text,
    jsonb_build_object('waiver_ledger_id',v_id,'driver_id',v_entry.driver_id,
      'amount_cents',v_entry.amount_cents,'reason',btrim(p_reason))); END IF;
  RETURN jsonb_build_object('ok',true,'waived',v_id IS NOT NULL,'idempotent_replay',v_id IS NULL);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_driver_service_fee_report()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor:=private.fn_admin_os_actor('finance.manage',false);
  RETURN jsonb_build_object(
    'gross_service_fees_cents',COALESCE((SELECT sum(amount_cents) FROM public.billing_ledger WHERE reason='ride_fee'),0),
    'prepaid_collected_cents',COALESCE(-(SELECT sum(amount_cents) FROM public.billing_ledger WHERE reason='prepaid_fee_collection'),0),
    'outstanding_platform_balance_cents',COALESCE((SELECT sum(amount_cents) FROM public.billing_ledger),0),
    'reversals_cents',COALESCE(-(SELECT sum(amount_cents) FROM public.billing_ledger WHERE reason IN ('reversal','waiver')),0),
    'driver_gross_fares_cents',COALESCE((SELECT sum(fare_amount_cents) FROM public.ride_driver_fee_snapshots WHERE finalized_at IS NOT NULL),0),
    'driver_net_entitlement_cents',COALESCE((SELECT sum(estimated_driver_net_cents) FROM public.ride_driver_fee_snapshots WHERE finalized_at IS NOT NULL),0),
    'mollie_processing_cost_cents',COALESCE((SELECT sum(mollie_processing_cost_cents) FROM public.ride_payments),0),
    'unreconciled_prepaid_count',(SELECT count(*) FROM public.ride_payments rp
      JOIN public.ride_driver_fee_snapshots s ON s.ride_id=rp.ride_id
      WHERE rp.state='routed' AND s.collection_method='mollie_deduction'
        AND NOT EXISTS(SELECT 1 FROM public.billing_ledger bl WHERE bl.ride_id=rp.ride_id AND bl.reason='prepaid_fee_collection'))
  );
END; $$;

CREATE OR REPLACE FUNCTION public.fn_scan_driver_service_fee_alerts()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_count integer:=0; v_rows integer:=0;
BEGIN
  INSERT INTO public.ride_payment_operational_alerts(
    dedupe_key,alert_type,severity,ride_id,ride_payment_id,driver_id,correlation_id,details)
  SELECT 'service-fee-split:'||rp.id,'driver_service_fee_split_mismatch','critical',
    rp.ride_id,rp.id,rp.driver_id,rp.correlation_id,jsonb_build_object(
      'payment_fee_cents',rp.platform_fee_cents,'snapshot_fee_cents',s.fee_amount_cents)
  FROM public.ride_payments rp JOIN public.ride_driver_fee_snapshots s ON s.ride_id=rp.ride_id
  WHERE rp.platform_fee_cents<>s.fee_amount_cents
  ON CONFLICT(dedupe_key) DO UPDATE SET last_detected_at=excluded.last_detected_at,
    details=excluded.details,resolved_at=NULL;
  GET DIAGNOSTICS v_rows=ROW_COUNT; v_count:=v_count+v_rows;

  INSERT INTO public.ride_payment_operational_alerts(
    dedupe_key,alert_type,severity,ride_id,ride_payment_id,driver_id,correlation_id,details)
  SELECT 'service-fee-unreconciled:'||rp.id,'driver_service_fee_reconciliation_failure','critical',
    rp.ride_id,rp.id,rp.driver_id,rp.correlation_id,jsonb_build_object('routed_at',rp.routed_at)
  FROM public.ride_payments rp JOIN public.ride_driver_fee_snapshots s ON s.ride_id=rp.ride_id
  WHERE rp.state='routed' AND rp.routed_at<timezone('utc',now())-interval '5 minutes'
    AND s.collection_method='mollie_deduction'
    AND NOT EXISTS(SELECT 1 FROM public.billing_ledger bl
      WHERE bl.ride_id=rp.ride_id AND bl.reason='prepaid_fee_collection')
  ON CONFLICT(dedupe_key) DO UPDATE SET last_detected_at=excluded.last_detected_at,
    details=excluded.details,resolved_at=NULL;
  GET DIAGNOSTICS v_rows=ROW_COUNT; v_count:=v_count+v_rows;
  RETURN v_count;
END; $$;

REVOKE ALL ON FUNCTION public.fn_reverse_driver_service_fee(uuid,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.fn_admin_waive_driver_balance_entry(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.fn_admin_driver_service_fee_report() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.fn_scan_driver_service_fee_alerts() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fn_reverse_driver_service_fee(uuid,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_admin_waive_driver_balance_entry(uuid,text) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.fn_admin_driver_service_fee_report() TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.fn_scan_driver_service_fee_alerts() TO service_role;

COMMENT ON FUNCTION public.fn_scan_driver_service_fee_alerts() IS
  'Monitoring command for payment/snapshot split mismatches and routed-but-unreconciled prepaid service fees.';
