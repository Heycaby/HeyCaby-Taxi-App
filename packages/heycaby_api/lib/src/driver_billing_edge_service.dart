import 'package:heycaby_api/src/supabase_client.dart';

/// Supabase Edge mutations for driver billing (Phase C completion).
class DriverBillingEdgeService {
  const DriverBillingEdgeService();

  static bool isLedgerV1(Map<String, dynamic>? status) =>
      status?['billing_model'] == 'ledger_v1' ||
      status?['billing_model'] == 'platform_balance_v1';

  static bool isPlatformBalanceV1(Map<String, dynamic>? status) =>
      status?['billing_model'] == 'platform_balance_v1';

  Future<Map<String, dynamic>?> fetchBillingStatusOrNull() async {
    try {
      final raw = await HeyCabySupabase.client.rpc('fn_driver_billing_status');
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      if (map['ok'] != true) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createCheckoutOrNull() async {
    try {
      final res = await HeyCabySupabase.client.functions.invoke(
        'driver-billing-checkout',
        body: const <String, dynamic>{},
      );
      final data = res.data;
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      if (map['ok'] != true) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  Future<bool> syncMolliePayment(String molliePaymentId) async {
    if (molliePaymentId.trim().isEmpty) return false;
    try {
      final res = await HeyCabySupabase.client.functions.invoke(
        'driver-billing-sync',
        body: {'mollie_payment_id': molliePaymentId.trim()},
      );
      final data = res.data;
      return data is Map && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
