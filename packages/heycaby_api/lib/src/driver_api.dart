import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_client.dart';

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
  DriverApi({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? 'https://heycaby.nl',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
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

  late final Dio _dio;

  Future<List<DriverNotificationItem>> getNotifications({
    bool unreadOnly = false,
    int limit = 30,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/driver/notifications',
      queryParameters: {
        'limit': limit,
        if (unreadOnly) 'unread': 1,
      },
    );
    final raw = res.data?['notifications'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => DriverNotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _dio.patch('/api/driver/notifications', data: {
      'notification_id': notificationId,
    });
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.patch('/api/driver/notifications', data: {'all': true});
  }

  /// Update driver status. When going 'available', pass lat/lng if you have them
  /// — some backends require location to place the driver on the map.
  ///
  /// Production API (`/api/driver/status`) expects **`driver_id`** in the JSON body
  /// (see error: "Invalid driver_id or status"). If [driverId] is omitted, we look up
  /// `drivers.id` for the current Supabase auth user.
  /// GET /api/driver/status — license + platform-fee eligibility (`can_go_online`, `payment_required`, etc.).
  Future<Map<String, dynamic>> fetchDriverStatus() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/driver/status');
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  /// POST /api/driver/payment/create — returns `checkoutUrl` + `mollie_payment_id` when payment is required.
  Future<Map<String, dynamic>> createDriverPlatformPayment() async {
    final res = await _dio.post<Map<String, dynamic>>('/api/driver/payment/create');
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  /// POST /api/driver/subscription/cancel — cancels Mollie subscription if `mollie_subscription_id` exists; otherwise no-op JSON.
  Future<Map<String, dynamic>> cancelDriverPlatformSubscription() async {
    final res = await _dio.post<Map<String, dynamic>>('/api/driver/subscription/cancel');
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  Future<void> setStatus({
    required String status,
    double? lat,
    double? lng,
    String? driverId,
  }) async {
    final id = driverId ?? await _resolveDriverIdFromAuth();
    final data = <String, dynamic>{'status': status};
    if (id != null) {
      data['driver_id'] = id;
    }
    if (lat != null && lng != null) {
      data['lat'] = lat;
      data['lng'] = lng;
    }
    await _dio.patch('/api/driver/status', data: data);
  }

  /// `drivers.id` for the signed-in user, or null if no row / not logged in.
  Future<String?> _resolveDriverIdFromAuth() async {
    try {
      final userId = HeyCabySupabase.client.auth.currentUser?.id;
      if (userId == null) return null;
      final res = await HeyCabySupabase.client
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      return res?['id'] as String?;
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

  /// Tries atomic Supabase RPC first (cascade invites). On RPC missing/network errors,
  /// falls back to production HTTP API. If RPC responds with `ok: false`, throws
  /// [DriverAcceptRideException] (do not fall back — invite was invalid or race lost).
  Future<void> acceptRide({required String rideRequestId}) async {
    try {
      final r = await HeyCabySupabase.client.rpc(
        'fn_driver_accept_ride_invite',
        params: {'p_ride_request_id': rideRequestId},
      );
      if (r is Map && r['ok'] == true) return;
      final err = r is Map ? r['error']?.toString() ?? 'rpc_failed' : 'rpc_failed';
      throw DriverAcceptRideException(err);
    } on DriverAcceptRideException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('acceptRide: Supabase RPC unavailable ($e), using HTTP fallback');
      }
      await _dio.post('/api/driver/ride/accept',
          data: {'ride_request_id': rideRequestId});
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

  Future<Map<String, dynamic>> getRadar(
      {required double lat, required double lng}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/auction/radar',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return res.data ?? {};
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
      data: j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : null,
    );
  }
}
