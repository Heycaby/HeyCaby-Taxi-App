import 'package:heycaby_api/src/supabase_client.dart';

/// Supabase Edge mutations for driver billing (Phase C completion).
class DriverBillingEdgeService {
  const DriverBillingEdgeService();

  static bool isLedgerV1(Map<String, dynamic>? status) =>
      status?['billing_model'] == 'ledger_v1';

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

  Future<Map<String, dynamic>?> createCheckoutOrNull({
    String kind = 'settlement',
    String? plan,
  }) async {
    try {
      final body = <String, dynamic>{
        'kind': kind,
        if (plan != null && plan.trim().isNotEmpty) 'plan': plan.trim().toLowerCase(),
      };
      final res = await HeyCabySupabase.client.functions.invoke(
        'driver-billing-checkout',
        body: body,
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

  Future<bool> verifyAppleReceiptOrNull({
    required String receiptData,
    String planCode = '',
  }) async {
    if (receiptData.trim().isEmpty) return false;
    try {
      final res = await HeyCabySupabase.client.functions.invoke(
        'driver-billing-apple-verify',
        body: {
          'receipt_data': receiptData,
          'plan_code': planCode.trim().toLowerCase(),
        },
      );
      final data = res.data;
      return data is Map && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
