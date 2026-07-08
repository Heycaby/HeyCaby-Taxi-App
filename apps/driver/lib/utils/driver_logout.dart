import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/location_service.dart';

/// Signs out of Supabase, clears driver session state, and navigates to [loginRoute].
///
/// Shows a confirmation sheet first. Safe to call from drawer, profile, etc.
Future<void> performDriverLogout(
  BuildContext context,
  WidgetRef ref, {
  String loginRoute = '/login',
}) async {
  final colors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);
  final confirmed = await showHeyCabyConfirmSheet(
    context,
    colors: colors,
    typography: typo,
    title: DriverStrings.logout,
    message: DriverStrings.logoutConfirm,
    dismissLabel: DriverStrings.cancel,
    confirmLabel: DriverStrings.logoutConfirmAction,
    icon: Icons.logout_rounded,
    confirmDestructive: true,
  );

  if (!confirmed || !context.mounted) return;

  DriverLocationService().resetSession();

  try {
    await HeyCabyFcmRegistration.unregisterAll(appRole: 'driver');
  } catch (_) {}

  try {
    await HeyCabySupabase.client.auth.signOut();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    return;
  }

  ref.read(driverStateProvider.notifier).logout();
  ref.read(foundingDriverPostClaimProvider.notifier).state = null;

  if (context.mounted) {
    context.go(loginRoute);
  }
}

/// Immediate logout without confirmation (session revoked, security).
Future<void> forceDriverLogout(
  BuildContext context,
  WidgetRef ref, {
  String loginRoute = '/login',
}) async {
  DriverLocationService().resetSession();

  try {
    await HeyCabyFcmRegistration.unregisterAll(appRole: 'driver');
  } catch (_) {}

  try {
    await HeyCabySupabase.client.auth.signOut();
  } catch (_) {}

  ref.read(driverStateProvider.notifier).logout();
  ref.read(foundingDriverPostClaimProvider.notifier).state = null;

  if (context.mounted) {
    context.go(loginRoute);
  }
}
