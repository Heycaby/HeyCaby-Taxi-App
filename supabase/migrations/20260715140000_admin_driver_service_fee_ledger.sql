CREATE OR REPLACE FUNCTION public.fn_admin_driver_service_fee_ledger(
  p_driver_id uuid DEFAULT NULL,p_limit integer DEFAULT 200
)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor:=private.fn_admin_os_actor('finance.manage',false);
  RETURN jsonb_build_object(
    'ok',true,
    'entries',COALESCE((SELECT jsonb_agg(jsonb_build_object(
      'id',x.id,'driver_id',x.driver_id,'driver_name',x.driver_name,
      'ride_id',x.ride_id,'reason',x.reason,'amount_cents',x.amount_cents,
      'currency',x.currency,'created_at',x.created_at,'metadata',x.metadata,
      'running_balance_cents',x.running_balance_cents
    ) ORDER BY x.created_at DESC,x.ledger_sequence DESC)
    FROM (
      SELECT bl.id,bl.driver_id,COALESCE(NULLIF(to_jsonb(d)->>'full_name',''),'Driver') driver_name,
        bl.ride_id,bl.reason,bl.amount_cents,bl.currency,bl.created_at,bl.metadata,
        sum(bl.amount_cents) OVER(PARTITION BY bl.driver_id ORDER BY bl.ledger_sequence) running_balance_cents,
        bl.ledger_sequence
      FROM public.billing_ledger bl JOIN public.drivers d ON d.id=bl.driver_id
      WHERE p_driver_id IS NULL OR bl.driver_id=p_driver_id
      ORDER BY bl.created_at DESC,bl.ledger_sequence DESC LIMIT LEAST(GREATEST(p_limit,1),500)
    ) x),'[]'::jsonb)
  );
END; $$;

REVOKE ALL ON FUNCTION public.fn_admin_driver_service_fee_ledger(uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_driver_service_fee_ledger(uuid,integer) TO authenticated,service_role;
