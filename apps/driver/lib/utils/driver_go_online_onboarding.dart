import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_runtime_providers.dart';
import '../models/driver_runtime_models.dart';
import 'driver_runtime_refresh.dart';

/// Query value: onboarding steps were opened from a Go Online attempt.
const kDriverGoOnlineResumeQuery = 'go-online';

bool driverGoOnlineResumeRequested(GoRouterState state) {
  return state.uri.queryParameters['resume'] == kDriverGoOnlineResumeQuery;
}

bool driverLegalOnboardingComplete(DriverRuntimeSnapshot runtime) {
  const legalKeys = {'terms_of_service', 'indemnification_quiz'};
  final legalItems = runtime.readiness.checklist
      .where((item) => legalKeys.contains(item.key.trim()))
      .toList(growable: false);
  if (legalItems.length < legalKeys.length) return false;
  return legalItems.every((item) => item.complete);
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

  if (!driverLegalOnboardingComplete(runtime)) {
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

  if (!driverLegalOnboardingComplete(runtime)) {
    context.go('/driver/documents?resume=$kDriverGoOnlineResumeQuery');
    return;
  }

  context.go('/driver');
  if (resumeGoOnline && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(DriverStrings.goOnlineOnboardingReadyHint)),
    );
  }
}
