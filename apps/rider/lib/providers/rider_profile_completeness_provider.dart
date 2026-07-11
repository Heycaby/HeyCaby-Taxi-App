import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rider_profile_display_provider.dart';

/// Rider profile is **100%** when both **name** and **email** are available.
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
  final display = ref.watch(riderProfileDisplayProvider);
  return RiderProfileCompleteness(
    hasName: display.hasName,
    hasEmail: display.hasEmail,
  );
});
