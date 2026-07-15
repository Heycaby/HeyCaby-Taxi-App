import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/src/app_notifications_service.dart';
import 'package:heycaby_api/src/driver_billing_edge_service.dart';
import 'package:heycaby_api/src/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase RPC [fn_driver_accept_ride_invite] returned a business error (no HTTP fallback).
class DriverAcceptRideException implements Exception {
  const DriverAcceptRideException(
    this.code, {
    this.message,
    this.reason,
    this.details,
  });

  final String code;
  final String? message;
  final String? reason;
  final Map<String, dynamic>? details;

  @override
  String toString() => message ?? code;
}

/// Supabase ride lifecycle RPC returned a business error.
class DriverRideLifecycleException implements Exception {
  const DriverRideLifecycleException(this.code, {this.message});

  final String code;
  final String? message;

  @override
  String toString() => message ?? code;
}

/// Supabase-first driver API.
class DriverApi {
  const DriverApi();

  static const _notifications = AppNotificationsService();
  static const _billingEdge = DriverBillingEdgeService();

  Future<List<DriverNotificationItem>> getNotifications({
    bool unreadOnly = false,
    int limit = 30,
  }) async {
    final supabaseRows = await _notifications.listOrNull(
      userType: 'driver',
      unreadOnly: unreadOnly,
      limit: limit,
    );
    return (supabaseRows ?? const [])
        .map((e) => DriverNotificationItem.fromJson(e))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _notifications.markRead(notificationId);
  }

  Future<void> markAllNotificationsRead() async {
    await _notifications.markAllRead(userType: 'driver');
  }

  Future<void> clearReadNotifications() async {
    await _notifications.clearRead(userType: 'driver');
  }

  Future<void> deleteAllNotifications() async {
    await _notifications.deleteAll(userType: 'driver');
  }

  Future<void> deleteNotifications(List<String> notificationIds) async {
    await _notifications.deleteIds(
      notificationIds: notificationIds,
      userType: 'driver',
    );
  }

  /// Billing / platform-fee status — Supabase [fn_driver_billing_status] (Phase E; no Go).
  Future<Map<String, dynamic>> fetchDriverStatus() async {
    final status = await _billingEdge.fetchBillingStatusOrNull();
    if (status != null) return status;
    throw UnsupportedError('Billing status unavailable from Supabase.');
  }

  /// Mollie checkout — Supabase Edge settlement for the current Platform Balance.
  Future<Map<String, dynamic>> createDriverPlatformPayment() async {
    final edge = await _billingEdge.createCheckoutOrNull();
    if (edge != null) {
      return edge;
    }
    throw UnsupportedError('Billing checkout unavailable from Supabase Edge.');
  }

  /// Confirm Mollie payment after checkout redirect (Edge webhook fallback).
  Future<bool> syncDriverBillingPayment(String molliePaymentId) =>
      _billingEdge.syncMolliePayment(molliePaymentId);

  /// Ledger history from [fn_driver_billing_ledger_history].
  Future<List<Map<String, dynamic>>> fetchDriverPaymentLedger() async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_driver_billing_ledger_history',
        params: {'p_limit': 50},
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

  /// Mollie mandate portal — not used on ledger V1.
  Future<String?> fetchDriverPaymentMethodsPortalUrl() async => null;

  /// Driver availability — Supabase RPC `fn_driver_set_status` only (no Go fallback).
  Future<void> setStatus({
    required String status,
    double? lat,
    double? lng,
    String? driverId,
  }) async {
    if (status == 'available' && (lat == null || lng == null)) {
      throw DioException(
        requestOptions: RequestOptions(path: 'rpc/fn_driver_set_status'),
        response: Response(
          requestOptions: RequestOptions(path: 'rpc/fn_driver_set_status'),
          statusCode: 409,
          data: const {
            'status': 'offline',
            'blocked_reason': 'location_required',
            'message': 'Turn on location before going online.',
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }
    final raw = await HeyCabySupabase.client.rpc(
      'fn_driver_set_status',
      params: {
        'p_status': status,
        if (lat != null) 'p_lat': lat,
        if (lng != null) 'p_lng': lng,
      },
    );
    if (raw is Map) {
      final blocked = raw['blocked_reason'];
      if (blocked != null && blocked.toString().isNotEmpty) {
        throw DioException(
          requestOptions: RequestOptions(path: 'rpc/fn_driver_set_status'),
          response: Response(
            requestOptions: RequestOptions(path: 'rpc/fn_driver_set_status'),
            statusCode: 409,
            data: raw,
          ),
          type: DioExceptionType.badResponse,
        );
      }
      final returnedStatus = raw['status']?.toString();
      if (returnedStatus != null &&
          returnedStatus.isNotEmpty &&
          returnedStatus != status) {
        throw DioException(
          requestOptions: RequestOptions(path: 'rpc/fn_driver_set_status'),
          response: Response(
            requestOptions: RequestOptions(path: 'rpc/fn_driver_set_status'),
            statusCode: 409,
            data: raw,
          ),
          type: DioExceptionType.badResponse,
        );
      }
    }
  }

  Future<DriverManualRideResult> createManualRide({
    required String dropoffAddress,
    required int fareCents,
    required String paymentMethod,
    String? pickupAddress,
    String? passengerName,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    String currency = 'EUR',
  }) async {
    final manualResult = await _createManualRideViaSupabaseFallback(
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      fareCents: fareCents,
      paymentMethod: paymentMethod,
      passengerName: passengerName,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      currency: currency,
    );
    if (manualResult != null) return manualResult;
    throw DioException(
      requestOptions: RequestOptions(path: 'rpc/fn_driver_create_manual_ride'),
      error: 'manual_ride_save_failed',
    );
  }

  Future<DriverManualRideResult?> _createManualRideViaSupabaseFallback({
    required String dropoffAddress,
    required int fareCents,
    required String paymentMethod,
    String? pickupAddress,
    String? passengerName,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    String currency = 'EUR',
  }) async {
    try {
      final rpc = await HeyCabySupabase.client.rpc(
        'fn_driver_create_manual_ride',
        params: {
          'p_pickup_address': pickupAddress?.trim(),
          'p_dropoff_address': dropoffAddress.trim(),
          'p_fare_cents': fareCents,
          'p_currency': currency,
          'p_payment_method': paymentMethod,
          'p_passenger_name': passengerName?.trim(),
          'p_pickup_lat': pickupLat,
          'p_pickup_lng': pickupLng,
          'p_dropoff_lat': dropoffLat,
          'p_dropoff_lng': dropoffLng,
        },
      );
      if (rpc is! Map) return null;
      final success = rpc['success'] == true;
      if (!success) return null;
      final rideId = rpc['ride_id'] as String?;
      if (rideId == null || rideId.isEmpty) return null;
      return DriverManualRideResult(
        success: true,
        rideId: rideId,
        message: (rpc['message'] as String?) ?? 'Ride recorded successfully',
      );
    } catch (_) {
      return null;
    }
  }

  /// Location uploads use direct Supabase upsert ([DriverLocationService]).
  Future<void> uploadLocation({
    required double lat,
    required double lng,
    double? heading,
  }) async {}

  /// Notify rider — use Supabase Edge `driver-agent` ([sendDriverRiderPing]).
  Future<void> nudgeRider({
    required String rideRequestId,
    required String kind,
  }) async {
    throw UnsupportedError('Use driver-agent Edge for rider pings.');
  }

  /// Atomic Supabase RPC [fn_driver_accept_ride_invite] — instant / invite rides.
  Future<void> acceptRide({required String rideRequestId}) async {
    await _invokeAcceptRpc('fn_driver_accept_ride_invite', rideRequestId);
  }

  /// Planned scheduled work — no live invite required.
  Future<void> acceptScheduledRide({required String rideRequestId}) async {
    await _invokeAcceptRpc('fn_driver_accept_scheduled_ride', rideRequestId);
  }

  Future<void> _invokeAcceptRpc(String rpcName, String rideRequestId) async {
    try {
      final r = await HeyCabySupabase.client.rpc(
        rpcName,
        params: {'p_ride_request_id': rideRequestId},
      );
      if (r is Map) {
        if (r['ok'] == true) return;
        final details = r['details'];
        throw DriverAcceptRideException(
          r['error']?.toString() ?? r['reason']?.toString() ?? 'rpc_failed',
          message: r['message']?.toString(),
          reason: r['reason']?.toString(),
          details: details is Map ? Map<String, dynamic>.from(details) : null,
        );
      }
      throw const DriverAcceptRideException('rpc_failed');
    } on DriverAcceptRideException {
      rethrow;
    } on PostgrestException catch (e) {
      final lowerMessage = e.message.toLowerCase();
      if (lowerMessage.contains('ride_invite_expired') ||
          lowerMessage.contains('ride_request_expired')) {
        throw const DriverAcceptRideException(
          'invite_expired',
          reason: 'invite_expired',
        );
      }
      throw DriverAcceptRideException(
        e.code ?? 'rpc_error',
        message: e.message,
        reason: 'rpc_error',
        details: {
          if (e.hint != null) 'hint': e.hint,
          if (e.details != null) 'details': e.details,
        },
      );
    } catch (e) {
      throw DriverAcceptRideException(
        'rpc_unavailable',
        message: e.toString(),
        reason: 'rpc_unavailable',
      );
    }
  }

  Future<void> _invokeDriverRideRpc(
    String rpcName,
    Map<String, dynamic> params,
  ) async {
    try {
      final r = await HeyCabySupabase.client.rpc(rpcName, params: params);
      if (r is Map && r['ok'] == true) return;
      if (r is Map) {
        final err =
            r['error']?.toString() ?? r['reason']?.toString() ?? 'rpc_failed';
        throw DriverRideLifecycleException(
          err,
          message: r['message']?.toString(),
        );
      }
      throw const DriverRideLifecycleException('rpc_failed');
    } on DriverRideLifecycleException {
      rethrow;
    } on PostgrestException catch (e) {
      throw DriverRideLifecycleException(
        _postgresLifecycleErrorCode(e),
        message: e.message,
      );
    } catch (e) {
      throw DriverRideLifecycleException(
        _clientLifecycleErrorCode(e),
        message: e.toString(),
      );
    }
  }

  static String _postgresLifecycleErrorCode(PostgrestException e) {
    final message = e.message.toLowerCase();
    const known = [
      'driver_business_account_not_found',
      'ride_invite_expired',
      'ride_request_expired',
      'not_a_driver',
      'invalid_transition',
      'ride_not_found',
      'ride_not_completed',
      'driver_location_unavailable',
      'target_location_unavailable',
      'missing_rider_token',
      'ride_prepayment_required',
      'ride_prepayment_config_invalid',
    ];
    for (final code in known) {
      if (message.contains(code)) return code;
    }
    return e.code?.trim().isNotEmpty == true ? e.code!.trim() : 'rpc_error';
  }

  static String _clientLifecycleErrorCode(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused')) {
      return 'network_unreachable';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'request_timeout';
    }
    return 'rpc_unavailable';
  }

  /// Supabase RPC `fn_driver_ride_arrived` — no Go fallback (Phase B).
  Future<void> markArrived({required String rideRequestId}) async {
    await _invokeDriverRideRpc(
      'fn_driver_ride_arrived',
      {'p_ride_request_id': rideRequestId},
    );
  }

  /// Driver started navigation to pickup (`driver_en_route`).
  Future<void> markEnRoute({required String rideRequestId}) async {
    await _invokeDriverRideRpc(
      'fn_driver_ride_en_route',
      {'p_ride_request_id': rideRequestId},
    );
  }

  /// Supabase RPC `fn_driver_ride_start` — no Go fallback (Phase B).
  Future<void> startRide({required String rideRequestId}) async {
    await _invokeDriverRideRpc(
      'fn_driver_ride_start',
      {'p_ride_request_id': rideRequestId},
    );
  }

  /// Supabase RPC `fn_driver_waive_waiting_fee` — rider is notified server-side.
  Future<void> waiveWaitingFee({
    required String rideRequestId,
    String? reason,
  }) async {
    await _invokeDriverRideRpc(
      'fn_driver_waive_waiting_fee',
      {
        'p_ride_request_id': rideRequestId,
        if (reason != null && reason.trim().isNotEmpty)
          'p_reason': reason.trim(),
      },
    );
  }

  /// Supabase RPC `fn_driver_ride_complete` — no Go fallback (Phase B).
  Future<void> completeRide({required String rideRequestId}) async {
    await _invokeDriverRideRpc(
      'fn_driver_ride_complete',
      {'p_ride_request_id': rideRequestId},
    );
  }

  /// Backend-truthful distance check before arrival/completion actions.
  Future<Map<String, dynamic>> checkRideActionProximity({
    required String rideRequestId,
    required String action,
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_driver_ride_action_proximity',
        params: {
          'p_ride_request_id': rideRequestId,
          'p_action': action,
        },
      );
      if (raw is Map) return Map<String, dynamic>.from(raw);
      throw const DriverRideLifecycleException('proximity_unavailable');
    } on DriverRideLifecycleException {
      rethrow;
    } on PostgrestException catch (e) {
      throw DriverRideLifecycleException(
        _postgresLifecycleErrorCode(e),
        message: e.message,
      );
    } catch (error) {
      throw DriverRideLifecycleException(
        _clientLifecycleErrorCode(error),
        message: error.toString(),
      );
    }
  }

  /// Supabase RPC `fn_driver_ride_cancel` — no Go fallback (Phase B).
  Future<void> cancelRide({
    required String rideRequestId,
    String? reason,
  }) async {
    await _invokeDriverRideRpc(
      'fn_driver_ride_cancel',
      {
        'p_ride_request_id': rideRequestId,
        if (reason != null && reason.trim().isNotEmpty)
          'p_reason': reason.trim(),
      },
    );
  }

  /// Structured mid-ride cancellation including settlement and availability.
  Future<void> cancelRideV2({
    required String rideRequestId,
    required String reasonCode,
    String? details,
    int riderPaidCents = 0,
    bool waiveRemaining = false,
    bool pauseNewRequests = false,
  }) async {
    await _invokeDriverRideRpc(
      'fn_driver_ride_cancel_v2',
      {
        'p_ride_request_id': rideRequestId,
        'p_reason_code': reasonCode,
        if (details != null && details.trim().isNotEmpty)
          'p_details': details.trim(),
        'p_rider_paid_cents': riderPaidCents,
        'p_waive_remaining': waiveRemaining,
        'p_pause_new_requests': pauseNewRequests,
      },
    );
  }

  /// Legacy auction routes — removed after Phase E (marketplace uses Supabase).
  Future<void> placeBid({required Map<String, dynamic> payload}) async {
    throw UnsupportedError('Auction bidding is not available.');
  }

  Future<void> acceptFirst({required String rideRequestId}) async {
    throw UnsupportedError('Auction accept-first is not available.');
  }

  Future<Map<String, dynamic>> getRadar(
      {required double lat, required double lng}) async {
    throw UnsupportedError('Auction radar is not available.');
  }

  /// Supabase RPC `fn_driver_ride_no_show` — no Go fallback (Phase B).
  Future<void> reportNoShow({required Map<String, dynamic> payload}) async {
    final rideRequestId = payload['ride_request_id']?.toString();
    if (rideRequestId == null || rideRequestId.isEmpty) {
      throw const DriverRideLifecycleException('missing_ride_request_id');
    }
    await _invokeDriverRideRpc(
      'fn_driver_ride_no_show',
      {'p_ride_request_id': rideRequestId},
    );
  }

  /// Supabase RPC `fn_driver_rate_rider` — no Go fallback (Phase B).
  Future<void> rateRider({required Map<String, dynamic> payload}) async {
    final rideRequestId = payload['ride_request_id']?.toString();
    if (rideRequestId == null || rideRequestId.isEmpty) {
      throw const DriverRideLifecycleException('missing_ride_request_id');
    }
    final rating = payload['driver_rating_of_rider'];
    final stars = rating is num ? rating.toInt() : int.tryParse('$rating');
    if (stars == null || stars < 1 || stars > 5) {
      throw const DriverRideLifecycleException('invalid_rating');
    }
    final comment = payload['rider_comment']?.toString();
    await _invokeDriverRideRpc(
      'fn_driver_rate_rider',
      {
        'p_ride_request_id': rideRequestId,
        'p_rating': stars,
        if (comment != null && comment.trim().isNotEmpty)
          'p_comment': comment.trim(),
      },
    );
  }

  /// Supabase RPC `fn_driver_create_receipt` — no Go fallback (Phase B).
  Future<void> createReceipt({required Map<String, dynamic> payload}) async {
    final rideRequestId = payload['ride_request_id']?.toString();
    if (rideRequestId == null || rideRequestId.isEmpty) {
      throw const DriverRideLifecycleException('missing_ride_request_id');
    }
    final paidRaw = payload['paid_amount'];
    final paid = paidRaw is num
        ? paidRaw.toDouble()
        : double.tryParse('$paidRaw'.replaceAll(',', '.'));
    if (paid == null || paid <= 0) {
      throw const DriverRideLifecycleException('invalid_amount');
    }
    final expectedRaw = payload['expected_amount'];
    final expected = expectedRaw is num
        ? expectedRaw.toDouble()
        : double.tryParse('$expectedRaw'.replaceAll(',', '.'));
    final method = payload['payment_method']?.toString() ?? 'cash';
    final note = payload['note']?.toString();
    await _invokeDriverRideRpc(
      'fn_driver_create_receipt',
      {
        'p_ride_request_id': rideRequestId,
        'p_paid_amount': paid,
        if (expected != null) 'p_expected_amount': expected,
        'p_payment_method': method,
        if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
      },
    );
  }

  /// Supabase RPC `fn_driver_decline_ride_invite` — no Go fallback (Phase B).
  Future<void> declineRide({required String rideRequestId}) async {
    await _invokeDriverRideRpc(
      'fn_driver_decline_ride_invite',
      {'p_ride_request_id': rideRequestId},
    );
  }
}

class DriverManualRideResult {
  const DriverManualRideResult({
    required this.success,
    required this.rideId,
    required this.message,
  });

  final bool success;
  final String? rideId;
  final String message;

  factory DriverManualRideResult.fromJson(Map<String, dynamic> json) {
    return DriverManualRideResult(
      success: json['success'] == true,
      rideId: json['ride_id'] as String?,
      message: (json['message'] as String?) ?? '',
    );
  }
}

final driverApiProvider = Provider<DriverApi>((_) => const DriverApi());

class DriverNotificationItem {
  const DriverNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.category,
    this.priority,
    this.readAt,
    this.createdAt,
    this.data,
  });

  final String id;
  final String title;
  final String body;
  final String? category;
  final String? priority;
  final DateTime? readAt;
  final DateTime? createdAt;
  final Map<String, dynamic>? data;

  bool get isUnread => readAt == null;

  static DateTime? _parseDate(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  factory DriverNotificationItem.fromJson(Map<String, dynamic> j) {
    return DriverNotificationItem(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      category: j['category'] as String?,
      priority: j['priority'] as String?,
      readAt: _parseDate(j['read_at']),
      createdAt: _parseDate(j['created_at']),
      data:
          j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : null,
    );
  }
}
