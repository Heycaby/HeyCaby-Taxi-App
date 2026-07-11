import 'supabase_client.dart';

/// Records manual payment confirmation (cash, Tikkie, PIN) — no money processing.
class RidePaymentService {
  const RidePaymentService();

  Future<RidePaymentConfirmResult> confirm({
    required String rideId,
    double tipEuro = 0,
    String? riderToken,
    String? paymentMethod,
  }) async {
    try {
      final res = await HeyCabySupabase.client.rpc(
        'fn_confirm_ride_payment',
        params: {
          'p_ride_id': rideId,
          'p_tip_eur': tipEuro,
          if (riderToken != null && riderToken.trim().isNotEmpty)
            'p_rider_token': riderToken.trim(),
          if (paymentMethod != null && paymentMethod.trim().isNotEmpty)
            'p_payment_method': paymentMethod.trim(),
        },
      );
      if (res is Map && res['ok'] == true) {
        return RidePaymentConfirmResult.ok(
          paymentStatus: res['payment_status']?.toString() ?? 'confirmed',
          confirmed: res['confirmed'] == true,
        );
      }
      final error = res is Map ? res['error']?.toString() : 'rpc_failed';
      return RidePaymentConfirmResult.failed(error ?? 'rpc_failed');
    } catch (e) {
      return RidePaymentConfirmResult.failed(e.toString());
    }
  }
}

class RidePaymentConfirmResult {
  const RidePaymentConfirmResult._({
    required this.ok,
    this.paymentStatus,
    this.confirmed = false,
    this.error,
  });

  final bool ok;
  final String? paymentStatus;
  final bool confirmed;
  final String? error;

  factory RidePaymentConfirmResult.ok({
    required String paymentStatus,
    bool confirmed = true,
  }) =>
      RidePaymentConfirmResult._(
        ok: true,
        paymentStatus: paymentStatus,
        confirmed: confirmed,
      );

  factory RidePaymentConfirmResult.failed(String error) =>
      RidePaymentConfirmResult._(ok: false, error: error);
}
