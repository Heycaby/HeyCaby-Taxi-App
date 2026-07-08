import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
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
    // Fall through to sheet confirm.
  }

  if (!context.mounted) return false;
  final theme = kThemes[kDriverDefaultTheme]!;
  return showHeyCabyConfirmSheet(
    context,
    colors: theme.colors,
    typography: theme.typography,
    title: DriverStrings.shiftHandoverEndShiftConfirmTitle,
    message: DriverStrings.shiftHandoverEndShiftConfirmBody,
    dismissLabel: DriverStrings.cancel,
    confirmLabel: DriverStrings.shiftHandoverEndShift,
    icon: Icons.handshake_rounded,
    confirmDestructive: true,
    barrierDismissible: false,
  );
}
