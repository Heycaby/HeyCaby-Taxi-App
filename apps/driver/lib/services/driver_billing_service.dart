import 'package:heycaby_api/heycaby_api.dart';

/// Supabase-first billing reads (Phase C — Backend Consolidation Program).
class DriverBillingService {
  const DriverBillingService();

  static bool isLedgerV1(Map<String, dynamic>? status) =>
      DriverBillingEdgeService.isLedgerV1(status);

  /// Ledger V1 status from [fn_driver_billing_status]; null on hard failure.
  Future<Map<String, dynamic>?> fetchBillingStatus() async {
    return const DriverBillingEdgeService().fetchBillingStatusOrNull();
  }

  /// Ledger rows from [fn_driver_billing_ledger_history].
  Future<List<Map<String, dynamic>>> fetchLedgerHistory(
      {int limit = 50}) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_driver_billing_ledger_history',
        params: {'p_limit': limit},
      );
      if (raw is! Map || raw['ok'] != true) return const [];
      final entries = raw['entries'];
      if (entries is! List) return const [];
      return [
        for (final e in entries)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return const [];
    }
  }
}
