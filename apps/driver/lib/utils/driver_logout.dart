import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';

/// Signs out of Supabase, clears driver session state, and navigates to [loginRoute].
///
/// Shows a confirmation dialog first. Safe to call from drawer, profile, etc.
Future<void> performDriverLogout(
  BuildContext context,
  WidgetRef ref, {
  String loginRoute = '/login',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final err = Theme.of(ctx).colorScheme.error;
      return AlertDialog(
        title: const Text(DriverStrings.logout),
        content: const Text(DriverStrings.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(DriverStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: err),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(DriverStrings.logoutConfirmAction),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

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
