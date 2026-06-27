import 'package:heycaby_api/src/supabase_client.dart';

/// Thrown when a legacy Go REST call is attempted but no API origin is configured.
class GoApiDisabledException implements Exception {
  GoApiDisabledException([this.message = 'Go REST API is disabled (Phase E cutover).']);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when the Go REST API origin cannot be determined from compile-time
/// defines or Supabase `app_config` + RPC (no silent default hostname).
class DriverApiBaseResolutionException implements Exception {
  DriverApiBaseResolutionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resolves the HTTPS origin for legacy HeyCaby Go driver routes.
///
/// Order (first success wins — **no** hardcoded production URL):
/// 1. Compile-time `API_BASE_URL` when non-empty (release IPA / CI).
/// 2. Supabase RPC [get_driver_rest_api_base_url] → `app_config.driver_rest_api_base_url`.
///
/// Returns `null` when unset/empty (Phase E production cutover — Supabase-only).
/// Requires [HeyCabySupabase.initialize] before RPC can succeed.
class DriverApiBaseResolver {
  DriverApiBaseResolver._();

  static String? _cached;
  static bool _cachedResolved = false;
  static Future<String?>? _inFlight;

  /// Clears cache (e.g. after logout in tests).
  static void reset() {
    _cached = null;
    _cachedResolved = false;
    _inFlight = null;
  }

  /// Non-throwing resolve; `null` means Go is disabled.
  static Future<String?> resolveOptional() async {
    if (_cachedResolved) return _cached;
    _inFlight ??= _resolveUncached();
    final v = await _inFlight!;
    _cached = v;
    _cachedResolved = true;
    return v;
  }

  /// Legacy callers that require Go; throws [GoApiDisabledException] when unset.
  static Future<String> resolve() async {
    final base = await resolveOptional();
    if (base != null && base.isNotEmpty) return base;
    throw GoApiDisabledException();
  }

  static Future<String?> _resolveUncached() async {
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
      return null;
    } on StateError {
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _normalize(String u) {
    var x = u.trim();
    if (x.endsWith('/')) {
      x = x.substring(0, x.length - 1);
    }
    return x;
  }
}
