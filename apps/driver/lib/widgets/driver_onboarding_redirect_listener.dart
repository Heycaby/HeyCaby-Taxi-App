import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/driver_runtime_models.dart';
import '../providers/driver_runtime_providers.dart';
import '../utils/driver_entry_navigation.dart';

/// Safety net: if the user lands on the main shell before onboarding completes,
/// redirect using `fn_driver_runtime()` (not local profile heuristics).
class DriverOnboardingRedirectListener extends ConsumerStatefulWidget {
  const DriverOnboardingRedirectListener({super.key});

  @override
  ConsumerState<DriverOnboardingRedirectListener> createState() =>
      _DriverOnboardingRedirectListenerState();
}

class _DriverOnboardingRedirectListenerState
    extends ConsumerState<DriverOnboardingRedirectListener> {
  bool _redirectScheduled = false;

  void _maybeRedirect(DriverRuntimeSnapshot? runtime) {
    if (runtime == null || !runtime.ok) return;
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectScheduled = false;
      if (!mounted) return;

      final location = GoRouterState.of(context).uri.toString();
      if (!driverEntryRouteMismatch(location, runtime)) return;

      final target = resolveDriverEntryRoute(runtime);
      if (location.startsWith(target)) return;
      context.go(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DriverRuntimeSnapshot>>(
      driverRuntimeSnapshotProvider,
      (_, next) => _maybeRedirect(next.valueOrNull),
    );
    _maybeRedirect(ref.watch(driverRuntimeSnapshotProvider).valueOrNull);
    return const SizedBox.shrink();
  }
}
