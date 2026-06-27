import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../models/driver_runtime_models.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_operational_restore_service.dart';
import '../services/driver_session_bootstrap.dart';
import 'driver_runtime_refresh.dart';

/// Routes excluded from runtime onboarding enforcement (entry flow + active ride).
const kDriverEntryExemptRoutePrefixes = [
  '/splash',
  '/login',
  '/driver/onboarding/plate',
  '/driver/terms',
  '/driver/indemnification',
  '/driver/privacy',
  '/driver/runtime-gate',
];

bool isDriverEntryExemptRoute(String location) {
  for (final prefix in kDriverEntryExemptRoutePrefixes) {
    if (location.startsWith(prefix)) return true;
  }
  if (location.startsWith('/driver/ride/')) return true;
  if (location.startsWith('/driver/chat/')) return true;
  return false;
}

/// Post-auth destination — always home. Plate/terms run on first Go Online.
String resolveDriverEntryRoute(DriverRuntimeSnapshot runtime) => '/driver';

/// No longer redirect away from home for incomplete plate/terms.
bool driverEntryRouteMismatch(String location, DriverRuntimeSnapshot runtime) =>
    false;

/// Bootstrap session, fetch runtime, restore active ride, then navigate.
Future<void> navigateDriverAfterAuth({
  required WidgetRef ref,
  required GoRouter router,
  required BuildContext context,
}) async {
  final session = HeyCabySupabase.client.auth.currentSession;
  if (session == null) {
    if (context.mounted) context.go('/login');
    return;
  }

  ref.read(driverStateProvider.notifier).setUser(session.user.id, null);
  String? driverId;
  try {
    driverId = await bootstrapDriverSessionAfterAuth(ref);
  } catch (_) {
    driverId = null;
  }
  if (!context.mounted) return;
  ref.read(driverStateProvider.notifier).setUser(session.user.id, driverId);

  try {
    await refreshDriverRuntime(ref);
  } catch (_) {}

  await restoreDriverOperationalState(ref, router);
  if (!context.mounted) return;

  if (ref.read(driverStateProvider).activeRideId != null) {
    return;
  }

  final target = '/driver';
  final current = router.routeInformationProvider.value.uri.path;
  if (current != target && !current.startsWith('$target/')) {
    context.go(target);
  }
}
