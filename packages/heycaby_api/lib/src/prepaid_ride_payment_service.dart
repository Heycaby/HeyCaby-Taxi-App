import 'package:heycaby_api/src/supabase_client.dart';

/// Thin presentation-layer client for backend-owned ride prepayments.
///
/// Amounts and state transitions are never accepted from Flutter. The backend
/// derives the fare from the accepted ride and Mollie webhooks confirm payment.
class PrepaidRidePaymentService {
  const PrepaidRidePaymentService();

  Future<PrepaidRidePaymentResult> createCheckout({
    required String rideId,
    String? riderToken,
    bool instantPrepayOptIn = false,
  }) async {
    try {
      final response = await HeyCabySupabase.client.functions.invoke(
        'ride-payment-create',
        body: <String, dynamic>{
          'ride_id': rideId,
          if (riderToken != null && riderToken.trim().isNotEmpty)
            'rider_token': riderToken.trim(),
          'instant_prepay_opt_in': instantPrepayOptIn,
        },
      );
      final raw = response.data;
      if (raw is! Map) {
        return const PrepaidRidePaymentResult.failed('invalid_response');
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['ok'] != true) {
        return PrepaidRidePaymentResult.failed(
          data['error']?.toString() ?? 'payment_create_failed',
        );
      }
      final payment = data['payment'];
      if (payment is! Map) {
        return const PrepaidRidePaymentResult.failed('payment_missing');
      }
      return PrepaidRidePaymentResult.ok(
        PrepaidRidePayment.fromJson(Map<String, dynamic>.from(payment)),
        existing: data['existing'] == true,
      );
    } catch (error) {
      return PrepaidRidePaymentResult.failed(error.toString());
    }
  }

  Future<PrepaidRidePaymentResult> snapshot({
    required String rideId,
    String? riderToken,
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_ride_payment_snapshot',
        params: <String, dynamic>{
          'p_ride_id': rideId,
          'p_rider_token': riderToken,
        },
      );
      if (raw is! Map) {
        return const PrepaidRidePaymentResult.failed('invalid_response');
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['ok'] != true) {
        return PrepaidRidePaymentResult.failed(
          data['error']?.toString() ?? 'payment_snapshot_failed',
        );
      }
      if (data['payment'] == null) {
        return const PrepaidRidePaymentResult.ok(null);
      }
      return PrepaidRidePaymentResult.ok(
        PrepaidRidePayment.fromJson(
          Map<String, dynamic>.from(data['payment'] as Map),
        ),
      );
    } catch (error) {
      return PrepaidRidePaymentResult.failed(error.toString());
    }
  }

  /// Requests backend-owned settlement after the canonical ride completion.
  ///
  /// The Edge Function verifies Driver ownership and completed ride state. It
  /// returns a successful no-op for rides that were not prepaid.
  Future<PrepaidRideRouteResult> routeCompletedPayment({
    required String rideId,
  }) async {
    try {
      final response = await HeyCabySupabase.client.functions.invoke(
        'ride-payment-route',
        body: <String, dynamic>{'ride_id': rideId},
      );
      final raw = response.data;
      if (raw is! Map) {
        return const PrepaidRideRouteResult.failed('invalid_response');
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['ok'] != true) {
        return PrepaidRideRouteResult.failed(
          data['error']?.toString() ?? 'payment_route_failed',
        );
      }
      return PrepaidRideRouteResult.ok(
        routed: data['routed'] == true,
        skipped: data['skipped']?.toString(),
      );
    } catch (error) {
      return PrepaidRideRouteResult.failed(error.toString());
    }
  }
}

class PrepaidRideRouteResult {
  const PrepaidRideRouteResult.ok({
    required this.routed,
    this.skipped,
  })  : ok = true,
        error = null;

  const PrepaidRideRouteResult.failed(this.error)
      : ok = false,
        routed = false,
        skipped = null;

  final bool ok;
  final bool routed;
  final String? skipped;
  final String? error;
}

class DriverMollieConnectService {
  const DriverMollieConnectService();

  Future<DriverMollieConnectResult> start() => _invoke('driver-mollie-connect');

  Future<DriverMollieConnectResult> sync() => _invoke('driver-mollie-sync');

  Future<DriverMollieConnectResult> status() async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_driver_mollie_connection_status',
      );
      return DriverMollieConnectResult.fromRaw(raw);
    } catch (error) {
      return DriverMollieConnectResult.failed(error.toString());
    }
  }

  Future<DriverMollieConnectResult> _invoke(String function) async {
    try {
      final response = await HeyCabySupabase.client.functions.invoke(function);
      return DriverMollieConnectResult.fromRaw(response.data);
    } catch (error) {
      return DriverMollieConnectResult.failed(error.toString());
    }
  }
}

class PrepaidRidePayment {
  const PrepaidRidePayment({
    required this.id,
    required this.state,
    required this.amountCents,
    required this.currency,
    this.checkoutUrl,
    this.paidAt,
    this.refundedCents = 0,
  });

  final String id;
  final String state;
  final int amountCents;
  final String currency;
  final String? checkoutUrl;
  final DateTime? paidAt;
  final int refundedCents;

  bool get isPaid =>
      state == 'paid' ||
      state == 'routing_pending' ||
      state == 'routed' ||
      state == 'partially_refunded';

  factory PrepaidRidePayment.fromJson(Map<String, dynamic> json) =>
      PrepaidRidePayment(
        id: json['id']?.toString() ?? '',
        state: json['state']?.toString() ?? 'unknown',
        amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
        currency: json['currency']?.toString() ?? 'EUR',
        checkoutUrl: json['checkout_url']?.toString(),
        paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
        refundedCents: (json['refunded_cents'] as num?)?.toInt() ?? 0,
      );
}

class PrepaidRidePaymentResult {
  const PrepaidRidePaymentResult.ok(this.payment, {this.existing = false})
      : ok = true,
        error = null;

  const PrepaidRidePaymentResult.failed(this.error)
      : ok = false,
        payment = null,
        existing = false;

  final bool ok;
  final PrepaidRidePayment? payment;
  final bool existing;
  final String? error;
}

class DriverMollieConnectResult {
  const DriverMollieConnectResult._({
    required this.ok,
    this.authorizeUrl,
    this.status,
    this.onboardingStatus,
    this.canReceivePrepaidRides = false,
    this.error,
  });

  final bool ok;
  final String? authorizeUrl;
  final String? status;
  final String? onboardingStatus;
  final bool canReceivePrepaidRides;
  final String? error;

  factory DriverMollieConnectResult.fromRaw(Object? raw) {
    if (raw is! Map) {
      return DriverMollieConnectResult.failed('invalid_response');
    }
    final data = Map<String, dynamic>.from(raw);
    if (data['ok'] != true) {
      return DriverMollieConnectResult.failed(
        data['error']?.toString() ?? 'mollie_connect_failed',
      );
    }
    return DriverMollieConnectResult._(
      ok: true,
      authorizeUrl: data['authorize_url']?.toString(),
      status: data['status']?.toString(),
      onboardingStatus: data['onboarding_status']?.toString(),
      canReceivePrepaidRides: data['can_receive_prepaid_rides'] == true,
    );
  }

  factory DriverMollieConnectResult.failed(String error) =>
      DriverMollieConnectResult._(ok: false, error: error);
}
