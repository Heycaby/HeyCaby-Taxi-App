import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_battery_optimization_service.dart';

/// One-time Android prompt so GPS/FCM survive Doze (Program 3E).
Future<void> maybePromptDriverBatteryOptimization(
  BuildContext context,
  WidgetRef ref,
) async {
  const service = DriverBatteryOptimizationService();
  if (!await service.shouldPrompt()) return;
  if (!context.mounted) return;

  final colors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.battery_charging_full_rounded,
          color: colors.accent, size: 40),
      title: Text(
        DriverStrings.batteryOptimizationTitle,
        style: typo.titleMedium.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        DriverStrings.batteryOptimizationBody,
        style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.35),
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await service.markPromptDismissed();
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Text(DriverStrings.batteryOptimizationLater),
        ),
        FilledButton(
          onPressed: () async {
            await service.requestExemption();
            await service.markPromptDismissed();
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Text(DriverStrings.batteryOptimizationAllow),
        ),
      ],
    ),
  );
}
