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

/// Post-auth destination from Supabase `fn_driver_runtime()` — single source of truth.
String resolveDriverEntryRoute(DriverRuntimeSnapshot runtime) {
  if (!runtime.plateVerified) {
    return '/driver/onboarding/plate';
  }
  if (!runtime.termsAccepted) {
    return '/driver/terms';
  }
  return '/driver';
}

/// Returns true when [location] should be replaced by [resolveDriverEntryRoute].
bool driverEntryRouteMismatch(String location, DriverRuntimeSnapshot runtime) {
  if (isDriverEntryExemptRoute(location)) return false;
  final expected = resolveDriverEntryRoute(runtime);
  if (location == expected || location.startsWith('$expected/')) return false;
  // On shell home while onboarding incomplete.
  if (!runtime.plateVerified || !runtime.termsAccepted) return true;
  return false;
}

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

  DriverRuntimeSnapshot runtime;
  try {
    runtime = await refreshDriverRuntime(ref);
  } catch (_) {
    runtime = DriverRuntimeSnapshot.fromRpc(const {'ok': false, 'error': 'runtime_fetch_failed'});
  }

  await restoreDriverOperationalState(ref, router);
  if (!context.mounted) return;

  if (ref.read(driverStateProvider).activeRideId != null) {
    return;
  }

  final target = runtime.ok ? resolveDriverEntryRoute(runtime) : '/driver';
  final current = router.routeInformationProvider.value.uri.path;
  if (current != target && !current.startsWith('$target/')) {
    context.go(target);
  }
}
