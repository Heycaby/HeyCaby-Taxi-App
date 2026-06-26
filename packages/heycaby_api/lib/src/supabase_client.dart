import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project credentials must be supplied at build/run time.
///
/// Use `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`
/// (see `scripts/build_ios_ipas.py`, `.env.example`).
class HeyCabySupabase {
  static String get _urlFromDefine =>
      const String.fromEnvironment('SUPABASE_URL').trim();

  static String get _anonKeyFromDefine =>
      const String.fromEnvironment('SUPABASE_ANON_KEY').trim();

  static Future<void> initialize() async {
    final url = _urlFromDefine;
    final anonKey = _anonKeyFromDefine;
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. '
        'Pass --dart-define for both, or use a run configuration / .env merged by the IPA script. '
        'See .env.example.',
      );
    }
    if (anonKey.contains('YOUR_ANON') ||
        anonKey == 'your-anon-key-here' ||
        url.contains('your-project.supabase.co')) {
      throw StateError(
        'Supabase credentials are still placeholders (YOUR_ANON_KEY). '
        'Stop the app, then run: ./scripts/run_driver_ios_debug.sh '
        'or flutter run --dart-define-from-file=ios/.ipa_dart_defines.json. '
        'Hot reload cannot fix compile-time defines — you need a full rebuild.',
      );
    }
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  /// Resolved project URL (for Auth REST calls such as user self-deletion).
  static String get supabaseUrl {
    final u = _urlFromDefine;
    if (u.isEmpty) {
      throw StateError('SUPABASE_URL is not set (dart-define).');
    }
    return u;
  }

  /// Resolved anon key (required as `apikey` header with Auth REST).
  static String get supabaseAnonKey {
    final k = _anonKeyFromDefine;
    if (k.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is not set (dart-define).');
    }
    return k;
  }
}
