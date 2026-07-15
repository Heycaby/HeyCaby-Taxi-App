import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/driver_data_providers.dart';

/// After Supabase session exists: ensure the driver row and refresh profile state.
/// Invalidates profile/compliance/driver id providers. Returns `drivers.id`.
Future<String?> bootstrapDriverSessionAfterAuth(WidgetRef ref) async {
  final svc = ref.read(driverDataServiceProvider);
  await svc.ensureDriverJwtUserType();
  final driverId = await svc.bootstrapDriverRow();
  ref.invalidate(driverIdProvider);
  ref.invalidate(driverProfileProvider);
  ref.invalidate(driverComplianceProvider);
  if (driverId != null) {
    await HeyCabyFcmRegistration.sync(appRole: 'driver');
  }
  return driverId;
}
