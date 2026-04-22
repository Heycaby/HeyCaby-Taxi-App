import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import 'settings_provider.dart';

/// Rider profile is **100%** when both **name** (booking / settings) and **email** (identity) exist.
class RiderProfileCompleteness {
  const RiderProfileCompleteness({
    required this.hasName,
    required this.hasEmail,
  });

  final bool hasName;
  final bool hasEmail;

  /// Each of name and email counts for 50%.
  int get percent => (hasName ? 50 : 0) + (hasEmail ? 50 : 0);

  bool get isComplete => hasName && hasEmail;
}

final riderProfileCompletenessProvider = Provider<RiderProfileCompleteness>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  final identity = ref.watch(riderIdentityProvider).valueOrNull;

  final hasName = (settings?.userName ?? '').trim().isNotEmpty ||
      (identity?.bookingName ?? '').trim().isNotEmpty;
  final hasEmail = (identity?.email ?? '').trim().isNotEmpty;

  return RiderProfileCompleteness(hasName: hasName, hasEmail: hasEmail);
});
