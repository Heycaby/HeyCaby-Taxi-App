import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_runtime_providers.dart';
import 'driver_runtime_refresh.dart';

/// Query value: onboarding steps were opened from a Go Online attempt.
const kDriverGoOnlineResumeQuery = 'go-online';

bool driverGoOnlineResumeRequested(GoRouterState state) {
  return state.uri.queryParameters['resume'] == kDriverGoOnlineResumeQuery;
}

/// Plate + terms are collected on first Go Online — not after login.
Future<bool> ensureDriverGoOnlineOnboarding(
  BuildContext context,
  WidgetRef ref,
) async {
  final runtime = await ref.read(driverRuntimeServiceProvider).fetchRuntime();
  if (!context.mounted) return false;

  if (!runtime.plateVerified) {
    await context.push(
      '/driver/onboarding/plate?resume=$kDriverGoOnlineResumeQuery',
    );
    return false;
  }

  if (!runtime.termsAccepted) {
    await context.push(
      '/driver/documents?resume=$kDriverGoOnlineResumeQuery',
    );
    return false;
  }

  return true;
}

/// After plate claim or legal acceptance during a Go Online resume flow.
Future<void> continueDriverGoOnlineOnboarding({
  required BuildContext context,
  required WidgetRef ref,
  required bool resumeGoOnline,
}) async {
  final runtime = await refreshDriverRuntime(ref);
  if (!context.mounted) return;

  if (!runtime.termsAccepted) {
    context.go('/driver/documents?resume=$kDriverGoOnlineResumeQuery');
    return;
  }

  context.go('/driver');
  if (resumeGoOnline && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(DriverStrings.goOnlineOnboardingReadyHint)),
    );
  }
}
