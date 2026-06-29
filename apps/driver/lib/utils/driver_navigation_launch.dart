import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_nav_app_pref_provider.dart';
import '../services/driver_navigation_launcher.dart';

/// Opens external navigation using the driver's preferred app (Program 3D).
Future<void> launchDriverNavigation({
  required BuildContext context,
  required WidgetRef ref,
  required double? lat,
  required double? lng,
  required String coordinatesUnavailableMessage,
}) async {
  if (lat == null || lng == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(coordinatesUnavailableMessage)),
    );
    return;
  }

  final pref =
      ref.read(driverNavAppPrefProvider).valueOrNull ?? DriverNavApp.waze;
  HapticService.selectionClick();
  final opened = await DriverNavigationLauncher.launchPreferred(
    lat: lat,
    lng: lng,
    app: pref,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(DriverStrings.noNavigationAppAvailable)),
    );
  }
}
