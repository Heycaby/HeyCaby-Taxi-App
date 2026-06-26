import 'package:heycaby_api/src/supabase_client.dart';

/// Thrown when the Go REST API origin cannot be determined from compile-time
/// defines or Supabase `app_config` + RPC (no silent default hostname).
class DriverApiBaseResolutionException implements Exception {
  DriverApiBaseResolutionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resolves the HTTPS origin for HeyCaby Go driver routes (`/api/v1/driver/*`, `/api/driver/*`).
///
/// Order (first success wins — **no** hardcoded production URL):
/// 1. Compile-time `API_BASE_URL` when non-empty (release IPA / CI).
/// 2. Supabase RPC [get_driver_rest_api_base_url] → `app_config.driver_rest_api_base_url`.
///
/// If none resolve to a valid `http(s)` URL, throws [DriverApiBaseResolutionException].
/// Requires [HeyCabySupabase.initialize] before RPC can succeed.
class DriverApiBaseResolver {
  DriverApiBaseResolver._();

  static String? _cached;
  static Future<String>? _inFlight;

  /// Clears cache (e.g. after logout in tests).
  static void reset() {
    _cached = null;
    _inFlight = null;
  }

  static Future<String> resolve() async {
    if (_cached != null) return _cached!;
    _inFlight ??= _resolveUncached();
    final v = await _inFlight!;
    _cached = v;
    return v;
  }

  static Future<String> _resolveUncached() async {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final trimmedEnv = fromEnv.trim();
    if (trimmedEnv.isNotEmpty) {
      return _normalize(trimmedEnv);
    }

    try {
      final client = HeyCabySupabase.client;
      final raw = await client.rpc<dynamic>('get_driver_rest_api_base_url');
      final s = raw?.toString().trim();
      if (s != null && s.isNotEmpty && s.startsWith('http')) {
        return _normalize(s);
      }
    } on StateError catch (e) {
      throw DriverApiBaseResolutionException(
        'Supabase not initialized ($e). '
        'Pass API_BASE_URL via --dart-define for this build, or initialize HeyCabySupabase first.',
      );
    } catch (e) {
      throw DriverApiBaseResolutionException(
        'Could not load Go API base URL from Supabase (get_driver_rest_api_base_url): $e. '
        'Set app_config.driver_rest_api_base_url to your live AWS HTTPS origin, '
        'or set dart-define API_BASE_URL.',
      );
    }

    throw DriverApiBaseResolutionException(
      'Go API base URL is missing or empty in app_config (key driver_rest_api_base_url). '
      'Set it to your live AWS HTTPS origin, or build with API_BASE_URL.',
    );
  }

  static String _normalize(String u) {
    var x = u.trim();
    if (x.endsWith('/')) {
      x = x.substring(0, x.length - 1);
    }
    return x;
  }
}
