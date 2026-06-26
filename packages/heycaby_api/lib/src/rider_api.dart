import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_client.dart';

class RiderApi {
  RiderApi({String? baseUrl}) {
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

  bool _isUnauthorizedIdentity(DioException e) {
    final status = e.response?.statusCode;
    if (status != 401) return false;
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error']?.toString().toLowerCase() ?? '';
      return err.contains('invalid or unauthorized');
    }
    if (data is String) {
      return data.toLowerCase().contains('invalid or unauthorized');
    }
    return false;
  }

  Future<List<RiderNotificationItem>> getNotifications({
    required String riderIdentityId,
    bool unreadOnly = false,
    int limit = 30,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/rider/notifications',
        queryParameters: {
          'rider_identity_id': riderIdentityId,
          'limit': limit,
          if (unreadOnly) 'unread': 1,
        },
        options: Options(headers: {
          'x-rider-identity-id': riderIdentityId,
        }),
      );
      final raw = res.data?['notifications'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => RiderNotificationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      if (_isUnauthorizedIdentity(e)) {
        // Stale/mismatched rider identity should not break the app UX.
        return const [];
      }
      rethrow;
    }
  }

  Future<void> markNotificationRead({
    required String riderIdentityId,
    required String notificationId,
  }) async {
    try {
      await _dio.patch(
        '/api/rider/notifications',
        data: {'notification_id': notificationId},
        options: Options(headers: {'x-rider-identity-id': riderIdentityId}),
      );
    } on DioException catch (e) {
      if (_isUnauthorizedIdentity(e)) return;
      rethrow;
    }
  }

  Future<void> markAllNotificationsRead({required String riderIdentityId}) async {
    try {
      await _dio.patch(
        '/api/rider/notifications',
        data: {'all': true},
        options: Options(headers: {'x-rider-identity-id': riderIdentityId}),
      );
    } on DioException catch (e) {
      if (_isUnauthorizedIdentity(e)) return;
      rethrow;
    }
  }

  /// Fetches a completed-ride receipt payload for rider view.
  /// Returns null when route is unavailable or receipt is missing.
  Future<Map<String, dynamic>?> fetchRideReceipt({
    required String rideRequestId,
  }) async {
    DioException? lastError;
    for (final path in const [
      '/api/rider/receipt',
      '/api/rider/ride/receipt',
      '/api/receipt/rider',
    ]) {
      try {
        final res = await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: {'ride_request_id': rideRequestId},
        );
        final data = res.data;
        if (data == null || data.isEmpty) return null;
        return Map<String, dynamic>.from(data);
      } on DioException catch (e) {
        lastError = e;
        if (e.response?.statusCode == 404) continue;
      }
    }
    if (lastError?.response?.statusCode == 404) return null;
    if (lastError != null) throw lastError!;
    return null;
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
