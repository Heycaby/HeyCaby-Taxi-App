import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/src/app_public_config.dart';
import 'package:heycaby_api/src/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-driven external URLs from `app_config` / `fn_app_public_links`.
class AppPublicLinks {
  const AppPublicLinks({
    this.customerAppStore,
    this.driverAppStore,
    this.customerPlayStore,
    this.driverPlayStore,
    required this.website,
    this.supportEmail,
    this.privacyPolicy,
    this.terms,
    this.instagram,
    this.facebook,
    this.linkedin,
  });

  final String? customerAppStore;
  final String? driverAppStore;
  final String? customerPlayStore;
  final String? driverPlayStore;
  final String website;
  final String? supportEmail;
  final String? privacyPolicy;
  final String? terms;
  final String? instagram;
  final String? facebook;
  final String? linkedin;

  /// Approved rider App Store — used only until Supabase `customer_app_store_url` loads.
  static const bootstrapCustomerAppStoreUrl =
      'https://apps.apple.com/nl/app/heycaby/id6761512910';

  static AppPublicLinks get fallback => AppPublicLinks(
        website: kAppPublicSiteRoot,
        customerAppStore: _compileTimeOverride(kRiderIosAppStoreUrl) ??
            bootstrapCustomerAppStoreUrl,
        driverAppStore: _compileTimeOverride(kDriverIosAppStoreUrl),
      );

  static String? _compileTimeOverride(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory AppPublicLinks.fromJson(Object? raw) {
    if (raw is! Map) return fallback;
    final json = raw.cast<String, dynamic>();
    final website = _nullableString(json['website']) ?? kAppPublicSiteRoot;
    return AppPublicLinks(
      customerAppStore: _nullableString(json['customer_app_store']),
      driverAppStore: _nullableString(json['driver_app_store']),
      customerPlayStore: _nullableString(json['customer_play_store']),
      driverPlayStore: _nullableString(json['driver_play_store']),
      website: website,
      supportEmail: _nullableString(json['support_email']),
      privacyPolicy: _nullableString(json['privacy_policy']),
      terms: _nullableString(json['terms']),
      instagram: _nullableString(json['instagram']),
      facebook: _nullableString(json['facebook']),
      linkedin: _nullableString(json['linkedin']),
    );
  }

  /// Rider Grow / invite: customer App Store from Supabase, then bootstrap, then website.
  String riderInviteShareUrl() {
    final store = customerAppStore?.trim();
    if (store != null && store.isNotEmpty) return store;
    final compileTime = _compileTimeOverride(kRiderIosAppStoreUrl);
    if (compileTime != null) return compileTime;
    if (bootstrapCustomerAppStoreUrl.trim().isNotEmpty) {
      return bootstrapCustomerAppStoreUrl.trim();
    }
    return website.trim();
  }

  bool get riderSharingAppStoreUrl {
    final url = riderInviteShareUrl();
    return url.contains('apps.apple.com') || url.contains('play.google.com');
  }

  /// Driver Grow / invite: driver App Store when configured, otherwise website.
  String driverInviteShareUrl() =>
      driverAppStore?.trim().isNotEmpty == true
          ? driverAppStore!.trim()
          : website.trim();

  bool get riderInviteShareReady => riderInviteShareUrl().trim().isNotEmpty;

  bool get driverInviteShareReady => driverInviteShareUrl().trim().isNotEmpty;
}

Future<AppPublicLinks?> fetchAppPublicLinks(SupabaseClient client) async {
  try {
    final raw = await client.rpc('fn_app_public_links');
    return AppPublicLinks.fromJson(raw);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('fn_app_public_links failed: $e\n$st');
    }
    return null;
  }
}

/// Cached public links — refreshed on app boot and via [appPublicLinksProvider].
class AppPublicLinksService {
  AppPublicLinks _current = AppPublicLinks.fallback;
  DateTime? _lastFetchAt;

  AppPublicLinks get current => _current;

  void apply(AppPublicLinks links) {
    _current = links;
    _lastFetchAt = DateTime.now();
  }

  Future<AppPublicLinks> refresh({bool force = false}) async {
    if (!force && _lastFetchAt != null) {
      final age = DateTime.now().difference(_lastFetchAt!);
      if (age < const Duration(minutes: 5)) return _current;
    }
    final fetched = await fetchAppPublicLinks(HeyCabySupabase.client);
    if (fetched != null) {
      _current = fetched;
      _lastFetchAt = DateTime.now();
    }
    return _current;
  }
}

final appPublicLinks = AppPublicLinksService();

final appPublicLinksProvider = FutureProvider<AppPublicLinks>((ref) async {
  return appPublicLinks.refresh(force: true);
});
