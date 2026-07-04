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
  String? addressFallback,
}) async {
  final pref =
      ref.read(driverNavAppPrefProvider).valueOrNull ?? DriverNavApp.waze;

  if (lat == null || lng == null) {
    final fallback = addressFallback?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      HapticService.selectionClick();
      final opened = await DriverNavigationLauncher.launchAddress(
        destination: fallback,
        app: pref,
      );
      if (opened || !context.mounted) return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(coordinatesUnavailableMessage)),
    );
    return;
  }

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
