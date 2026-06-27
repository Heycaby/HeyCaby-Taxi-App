import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_client.dart';
import 'app_notifications_service.dart';
import 'driver_api_base_resolver.dart';

class RiderApi {
  static const _notifications = AppNotificationsService();

  RiderApi({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
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

  Future<List<RiderNotificationItem>> getNotifications({
    required String riderIdentityId,
    bool unreadOnly = false,
    int limit = 30,
  }) async {
    final supabaseRows = await _notifications.listOrNull(
      userType: 'rider',
      unreadOnly: unreadOnly,
      limit: limit,
      riderIdentityId: riderIdentityId,
    );
    return (supabaseRows ?? const [])
        .map((e) => RiderNotificationItem.fromJson(e))
        .toList();
  }

  Future<void> markNotificationRead({
    required String riderIdentityId,
    required String notificationId,
  }) async {
    await _notifications.markRead(notificationId);
  }

  Future<void> markAllNotificationsRead({required String riderIdentityId}) async {
    await _notifications.markAllRead(
      userType: 'rider',
      riderIdentityId: riderIdentityId,
    );
  }

  /// Fetches a completed-ride receipt payload for rider view (Supabase RPC).
  Future<Map<String, dynamic>?> fetchRideReceipt({
    required String rideRequestId,
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_receipt_for_ride',
        params: {'p_ride_request_id': rideRequestId},
      );
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      if (map['ok'] != true) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  /// Accept marketplace bid — Supabase-first in app; legacy Go route removed (Phase E).
  Future<void> acceptBid({
    required String rideRequestId,
    required String bidId,
  }) async {
    throw GoApiDisabledException(
      'Use Supabase ride_requests update (acceptMarketplaceOffer).',
    );
  }
}

final riderApiProvider = Provider<RiderApi>((_) => RiderApi());

class RiderNotificationItem {
  const RiderNotificationItem({
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

  factory RiderNotificationItem.fromJson(Map<String, dynamic> j) {
    return RiderNotificationItem(
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
