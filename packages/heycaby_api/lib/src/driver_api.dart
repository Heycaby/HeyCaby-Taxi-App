import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heycaby_api/src/driver_api_base_resolver.dart';
import 'package:heycaby_api/src/supabase_client.dart';

/// Supabase RPC [fn_driver_accept_ride_invite] returned a business error (no HTTP fallback).
class DriverAcceptRideException implements Exception {
  const DriverAcceptRideException(this.code);
  final String code;
  @override
  String toString() => code;
}

/// HTTP client for driver app. Adds Supabase JWT to all requests.
/// Driver actions (status, ride lifecycle) go through the backend API.
class DriverApi {
  static const _apiBaseUrlFromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  late final Dio _dio;
  final bool _skipDynamicBase;
  bool _apiBaseReady = false;

  DriverApi({String? baseUrl})
      : _skipDynamicBase = baseUrl != null || _apiBaseUrlFromDefine.trim().isNotEmpty {
    final fromEnv = _apiBaseUrlFromDefine.trim();
    final initial = baseUrl ?? (fromEnv.isNotEmpty ? fromEnv : '');
    _dio = Dio(
      BaseOptions(
        baseUrl: initial,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_skipDynamicBase) {
            try {
              await _ensureGoApiBaseUrl();
            } catch (e, st) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: e,
                  stackTrace: st,
                  type: DioExceptionType.unknown,
                ),
              );
              return;
            }
          }
          handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = HeyCabySupabase.client.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Future<void> _ensureGoApiBaseUrl() async {
    if (_skipDynamicBase || _apiBaseReady) return;
    final resolved = await DriverApiBaseResolver.resolve();
    _dio.options.baseUrl = resolved;
    _apiBaseReady = true;
  }

  Future<List<DriverNotificationItem>> getNotifications({
    bool unreadOnly = false,
    int limit = 30,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      if (unreadOnly) 'unread': 1,
    };
    Response<Map<String, dynamic>> res;
    try {
      res = await _dio.get<Map<String, dynamic>>(
        '/api/driver/notifications',
        queryParameters: params,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != 401) {
        rethrow;
      }
      final refreshed = await HeyCabySupabase.client.auth.refreshSession();
      if (refreshed.session == null) return const [];
      try {
        res = await _dio.get<Map<String, dynamic>>(
          '/api/driver/notifications',
          queryParameters: params,
        );
      } on DioException catch (retryErr) {
        if (retryErr.response?.statusCode == 401) return const [];
        rethrow;
      }
    }

    final raw = res.data?['notifications'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) =>
            DriverNotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _dio.patch('/api/driver/notifications', data: {
        'notification_id': notificationId,
      });
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _dio.patch('/api/driver/notifications', data: {'all': true});
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;
    }
  }

  /// Update driver status via v1 server-driven endpoint.
  /// GET /api/driver/status — license + platform-fee eligibility (`can_go_online`, `payment_required`, etc.).
  Future<Map<String, dynamic>> fetchDriverStatus() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/driver/status');
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  /// POST /api/driver/billing/apple/verify — receipt validation; extends `subscription_expires_at`.
  Future<void> verifyAppleDriverReceipt({
    required String receiptData,
    String planCode = '',
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/driver/billing/apple/verify',
      data: {
        'receipt_data': receiptData,
        'plan_code': planCode.trim().toLowerCase(),
      },
    );
  }

  /// POST /api/driver/payment/create — returns `checkoutUrl` + `mollie_payment_id` when payment is required.
  Future<Map<String, dynamic>> createDriverPlatformPayment({String? plan}) async {
    final payload = <String, dynamic>{};
    if (plan != null && plan.trim().isNotEmpty) {
      payload['plan'] = plan.trim().toLowerCase();
    }
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/driver/payment/create',
      data: payload.isEmpty ? null : payload,
    );
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  /// POST /api/driver/subscription/cancel — cancels Mollie subscription if `mollie_subscription_id` exists; otherwise no-op JSON.
  Future<Map<String, dynamic>> cancelDriverPlatformSubscription() async {
    final res = await _dio
        .post<Map<String, dynamic>>('/api/driver/subscription/cancel');
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  /// POST /api/driver/subscription/pause — pauses recurring collection (backend → Mollie). Throws on hard errors.
  Future<Map<String, dynamic>> pauseDriverPlatformSubscription() async {
    final res =
        await _dio.post<Map<String, dynamic>>('/api/driver/subscription/pause');
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  /// POST /api/driver/subscription/resume — resumes paused subscription.
  Future<Map<String, dynamic>> resumeDriverPlatformSubscription() async {
    final res = await _dio
        .post<Map<String, dynamic>>('/api/driver/subscription/resume');
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  /// GET /api/driver/payments — payment ledger (`payments` / `items` / `rows`). Returns empty list if route missing (404).
  Future<List<Map<String, dynamic>>> fetchDriverPaymentLedger() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/driver/payments');
      final data = res.data;
      if (data == null) return const [];
      final raw = data['payments'] ?? data['items'] ?? data['rows'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      rethrow;
    }
  }

  /// GET /api/driver/payment/methods-portal — `{ portalUrl }` or `{ url }` for Mollie mandate/card management.
  /// Returns null if the route is not deployed (404) or the body has no URL.
  Future<String?> fetchDriverPaymentMethodsPortalUrl() async {
    try {
      final res = await _dio
          .get<Map<String, dynamic>>('/api/driver/payment/methods-portal');
      final m = res.data ?? const <String, dynamic>{};
      final u = m['portalUrl'] ?? m['url'] ?? m['checkoutUrl'];
      if (u is String && u.trim().isNotEmpty) return u.trim();
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> setStatus({
    required String status,
    double? lat,
    double? lng,
    String? driverId,
  }) async {
    try {
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
      }
      return;
    } on DioException {
      rethrow;
    } catch (_) {
      // Legacy Go path only if Supabase RPC is unavailable (non-launch fallback).
    }

    final data = <String, dynamic>{'status': status};
    if (lat != null && lng != null) {
      data['lat'] = lat;
      data['lng'] = lng;
    }
    await _dio.post('/api/v1/driver/status', data: data);
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

  Future<void> uploadLocation({
    required double lat,
    required double lng,
    double? heading,
  }) async {
    await _dio.post('/api/driver/location', data: {
      'lat': lat,
      'lng': lng,
      if (heading != null) 'heading': heading,
    });
  }

  /// Atomic Supabase RPC [fn_driver_accept_ride_invite] — no HTTP fallback.
  Future<void> acceptRide({required String rideRequestId}) async {
    try {
      final r = await HeyCabySupabase.client.rpc(
        'fn_driver_accept_ride_invite',
        params: {'p_ride_request_id': rideRequestId},
      );
      if (r is Map && r['ok'] == true) return;
      final err =
          r is Map ? r['error']?.toString() ?? 'rpc_failed' : 'rpc_failed';
      throw DriverAcceptRideException(err);
    } on DriverAcceptRideException {
      rethrow;
    } catch (e) {
      throw DriverAcceptRideException('rpc_unavailable:${e.toString()}');
    }
  }

  Future<void> markArrived({required String rideRequestId}) async {
    await _dio.post('/api/driver/ride/arrived',
        data: {'ride_request_id': rideRequestId});
  }

  Future<void> startRide({required String rideRequestId}) async {
    await _dio.post('/api/driver/ride/start',
        data: {'ride_request_id': rideRequestId});
  }

  Future<void> completeRide({required String rideRequestId}) async {
    await _dio.post('/api/driver/ride/complete',
        data: {'ride_request_id': rideRequestId});
  }

  /// Cancel an already accepted/assigned ride before completion.
  ///
  /// Backend routes vary by environment, so we try common variants.
  Future<void> cancelRide({
    required String rideRequestId,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'ride_request_id': rideRequestId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    DioException? lastError;
    for (final path in const [
      '/api/driver/ride/cancel',
      '/api/driver/ride/cancelled',
      '/api/driver/ride/end',
    ]) {
      try {
        await _dio.post(path, data: body);
        return;
      } on DioException catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
  }

  /// Notify rider that driver is waiting nearby/outside.
  ///
  /// Backend route names may vary during rollout; try common variants.
  Future<void> nudgeRider({
    required String rideRequestId,
    required String kind,
  }) async {
    final body = <String, dynamic>{
      'ride_request_id': rideRequestId,
      'kind': kind, // outside | nearby
    };
    DioException? lastError;
    for (final path in const [
      '/api/driver/ride/nudge',
      '/api/driver/rider/nudge',
      '/api/driver/notify-rider',
    ]) {
      try {
        await _dio.post(path, data: body);
        return;
      } on DioException catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
  }

  Future<void> reportNoShow({required Map<String, dynamic> payload}) async {
    await _dio.post('/api/driver/ride/no-show', data: payload);
  }

  Future<void> rateRider({required Map<String, dynamic> payload}) async {
    await _dio.post('/api/driver/ride/rate', data: payload);
  }

  Future<void> createReceipt({required Map<String, dynamic> payload}) async {
    await _dio.post('/api/driver/receipt', data: payload);
  }

  Future<void> placeBid({required Map<String, dynamic> payload}) async {
    await _dio.post('/api/auction/bid', data: payload);
  }

  Future<void> acceptFirst({required String rideRequestId}) async {
    await _dio.post('/api/auction/accept-first',
        data: {'ride_request_id': rideRequestId});
  }

  /// Best-effort decline path for incoming offers.
  ///
  /// Some environments expose `/api/driver/ride/decline`, others use
  /// `/api/driver/ride/reject`. We try both before surfacing the error.
  Future<void> declineRide({required String rideRequestId}) async {
    final body = {'ride_request_id': rideRequestId};
    DioException? lastError;

    for (final path in const [
      '/api/driver/ride/decline',
      '/api/driver/ride/reject',
    ]) {
      try {
        await _dio.post(path, data: body);
        return;
      } on DioException catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }

  Future<Map<String, dynamic>> getRadar(
      {required double lat, required double lng}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/auction/radar',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return res.data ?? {};
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

final driverApiProvider = Provider<DriverApi>((_) => DriverApi());

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
