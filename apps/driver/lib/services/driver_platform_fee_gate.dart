import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/driver_data_providers.dart';
import '../utils/driver_runtime_refresh.dart';

/// `true` when the signed-in user has [user_metadata.review_account].
bool driverAuthIsAppReviewAccount() {
  final meta = HeyCabySupabase.client.auth.currentSession?.user.userMetadata;
  if (meta == null) return false;
  final value = meta['review_account'];
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

/// Compatibility hook retained for older call sites.
///
/// Platform Balance never blocks presence. The server separately excludes an
/// overdue driver from new platform rides, so this hook refreshes that state
/// and always permits the online transition.
Future<bool> ensureDriverPlatformFeeAllowsOnline(
  BuildContext context,
  WidgetRef ref,
) async {
  ref.invalidate(driverBillingStatusProvider);
  await refreshDriverRuntime(ref);
  return true;
}
