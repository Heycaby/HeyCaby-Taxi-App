import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';

Future<void> copyDriverRideAddress(
  BuildContext context, {
  required String address,
  required DriverColors colors,
  required DriverTypography typography,
}) async {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: trimmed));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        DriverStrings.addressCopied,
        style: typography.bodyMedium.copyWith(color: colors.text),
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
