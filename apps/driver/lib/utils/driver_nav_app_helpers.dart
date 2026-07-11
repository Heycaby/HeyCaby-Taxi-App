import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_nav_app_pref_provider.dart';
import '../services/driver_navigation_launcher.dart';

/// Driver's saved navigation app from profile (SharedPreferences).
DriverNavApp watchDriverNavApp(WidgetRef ref) {
  return ref.watch(driverNavAppPrefProvider).value ?? DriverNavApp.waze;
}

DriverNavApp readDriverNavApp(WidgetRef ref) {
  return ref.read(driverNavAppPrefProvider).value ?? DriverNavApp.waze;
}

String watchDriverNavAppLabel(WidgetRef ref) => watchDriverNavApp(ref).label;

/// Profile picker — persists choice for all ride-flow navigation CTAs.
Future<void> promptDriverNavAppChange({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final choice = await DriverNavigationLauncher.pickNavApp(context);
  if (choice == null) return;
  await ref.read(driverNavAppPrefProvider.notifier).setApp(choice);
}
