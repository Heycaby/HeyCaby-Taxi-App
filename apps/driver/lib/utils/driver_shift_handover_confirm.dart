import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../l10n/driver_strings.dart';

/// Deliberate second step before ending shift via Secure Shift Handover.
Future<bool> confirmShiftHandoverHighRiskAction(BuildContext context) async {
  final localAuth = LocalAuthentication();
  try {
    final canUseBiometric = await localAuth.canCheckBiometrics &&
        await localAuth.isDeviceSupported();
    if (canUseBiometric) {
      return localAuth.authenticate(
        localizedReason: DriverStrings.shiftHandoverEndShiftBiometricReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    }
  } catch (_) {
    // Fall through to dialog confirm.
  }

  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text(DriverStrings.shiftHandoverEndShiftConfirmTitle),
      content: const Text(DriverStrings.shiftHandoverEndShiftConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(DriverStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(DriverStrings.shiftHandoverEndShift),
        ),
      ],
    ),
  );
  return confirmed == true;
}
