import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';

/// Confirms, calls cancel API, clears active ride, returns home.
Future<bool> confirmAndCancelDriverRide({
  required BuildContext context,
  required WidgetRef ref,
  required String rideId,
  Future<void> Function()? afterCancel,
}) async {
  final reasonCtrl = TextEditingController();
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(DriverStrings.cancelOrder),
      content: TextField(
        controller: reasonCtrl,
        decoration: const InputDecoration(
          hintText: DriverStrings.optionalReason,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(DriverStrings.back),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(DriverStrings.cancelRide),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return false;

  try {
    await ref.read(driverApiProvider).cancelRide(
          rideRequestId: rideId,
          reason: reasonCtrl.text.trim(),
        );
    if (afterCancel != null) await afterCancel();
    ref.read(driverStateProvider.notifier).clearActiveRide();
    if (!context.mounted) return true;
    context.go('/driver');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(DriverStrings.rideCancelled)),
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${DriverStrings.rideCancelFailed} $e')),
    );
    return false;
  } finally {
    reasonCtrl.dispose();
  }
}
