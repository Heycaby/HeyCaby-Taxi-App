import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/driver_data_providers.dart';
import '../providers/driver_runtime_providers.dart';

const _onboardingExemptPrefixes = [
  '/splash',
  '/login',
  '/driver/onboarding/plate',
  '/driver/terms',
  '/driver/indemnification',
  '/driver/privacy',
  '/driver/go-online',
  '/driver/runtime-gate',
];

bool _isOnboardingExemptRoute(String location) {
  for (final prefix in _onboardingExemptPrefixes) {
    if (location.startsWith(prefix)) return true;
  }
  if (location.startsWith('/driver/ride/')) return true;
  if (location.startsWith('/driver/chat/')) return true;
  return false;
}

/// Sends drivers without a plate to plate-first onboarding when V2 is enabled.
class DriverOnboardingRedirectListener extends ConsumerStatefulWidget {
  const DriverOnboardingRedirectListener({super.key});

  @override
  ConsumerState<DriverOnboardingRedirectListener> createState() =>
      _DriverOnboardingRedirectListenerState();
}

class _DriverOnboardingRedirectListenerState
    extends ConsumerState<DriverOnboardingRedirectListener> {
  bool _redirectScheduled = false;

  void _maybeRedirect() {
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectScheduled = false;
      if (!mounted) return;

      final location = GoRouterState.of(context).uri.toString();
      if (_isOnboardingExemptRoute(location)) return;

      final config = ref.read(driverRemoteConfigProvider).valueOrNull;
      if (config != null && !config.driverOnboardingV2) return;

      final profile = ref.read(driverProfileProvider).valueOrNull;
      final compliance = ref.read(driverComplianceProvider).valueOrNull;
      final plate = (compliance?.vehiclePlate ?? profile?.vehiclePlate ?? '')
          .trim();
      if (plate.isNotEmpty) return;

      if (location.startsWith('/driver/onboarding/plate')) return;
      context.go('/driver/onboarding/plate');
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(driverProfileProvider, (_, __) => _maybeRedirect());
    ref.listen(driverComplianceProvider, (_, __) => _maybeRedirect());
    ref.listen(driverRemoteConfigProvider, (_, __) => _maybeRedirect());
    _maybeRedirect();
    return const SizedBox.shrink();
  }
}
