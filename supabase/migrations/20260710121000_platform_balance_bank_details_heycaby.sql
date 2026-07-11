-- Canonical NL Platform Balance bank-transfer destination.
-- Keep the public recipient name consistent with the HeyCaby brand.

DO $$
DECLARE
  v_updated integer;
BEGIN
  UPDATE public.market_config
  SET config_value = COALESCE(config_value, '{}'::jsonb) || jsonb_build_object(
        'enabled', true,
        'account_holder', 'Hey Caby',
        'iban', 'NL31MLLE0644991305',
        'bank_name', 'Mollie',
        'bic', 'MLLENL2A'
      ),
      active = true,
      updated_at = timezone('utc', now())
  WHERE scope = 'country'
    AND country_code = 'NL'
    AND city_id IS NULL
    AND zone_id IS NULL
    AND config_key = 'platform_balance_bank_transfer';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    INSERT INTO public.market_config (
      scope,
      country_code,
      city_id,
      zone_id,
      config_key,
      config_value,
      active
    ) VALUES (
      'country',
      'NL',
      NULL,
      NULL,
      'platform_balance_bank_transfer',
      jsonb_build_object(
        'enabled', true,
        'account_holder', 'Hey Caby',
        'iban', 'NL31MLLE0644991305',
        'bank_name', 'Mollie',
        'bic', 'MLLENL2A'
      ),
      true
    );
  END IF;
END;
$$;
