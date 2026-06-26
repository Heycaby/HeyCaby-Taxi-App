import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_data_providers.dart';

/// After Supabase session exists: claim founding-driver web signup, then ensure `drivers` row.
/// Invalidates profile/compliance/driver id providers. Returns `drivers.id`.
Future<String?> bootstrapDriverSessionAfterAuth(WidgetRef ref) async {
  final svc = ref.read(driverDataServiceProvider);
  await svc.ensureDriverJwtUserType();
  final claim = await svc.claimFoundingDriver();
  if (claim != null && claim.isFoundingDriver) {
    ref.read(foundingDriverPostClaimProvider.notifier).state = claim;
  }
  final driverId = await svc.bootstrapDriverRow();
  ref.invalidate(driverIdProvider);
  ref.invalidate(driverProfileProvider);
  ref.invalidate(driverComplianceProvider);
  return driverId;
}
