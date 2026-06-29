import 'dart:convert';

import 'package:heycaby_api/heycaby_api.dart';

import '../models/rider_home_banner.dart';

/// Fetches active home banners from Supabase (`fn_rider_home_banners`).
class RiderHomeBannersService {
  List<RiderHomeBanner> _cached = const [];
  DateTime? _lastFetchAt;

  List<RiderHomeBanner> get cached => _cached;

  Future<List<RiderHomeBanner>> refresh({
    required String locale,
    bool force = false,
  }) async {
    if (!force && _lastFetchAt != null) {
      final age = DateTime.now().difference(_lastFetchAt!);
      if (age < const Duration(minutes: 5)) return _cached;
    }

    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_home_banners',
        params: {'p_locale': locale},
      );
      final list = _parseList(raw);
      _cached = list;
      _lastFetchAt = DateTime.now();
      return list;
    } catch (_) {
      return _cached;
    }
  }

  static List<RiderHomeBanner> _parseList(Object? raw) {
    if (raw == null) return const [];

    dynamic decoded = raw;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return const [];
      }
    }

    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => RiderHomeBanner.fromJson(Map<String, dynamic>.from(m)))
        .where((b) => b.id.isNotEmpty && b.title.isNotEmpty)
        .toList();
  }
}

final riderHomeBannersService = RiderHomeBannersService();
