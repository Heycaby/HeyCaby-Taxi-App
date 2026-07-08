import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Confirms stopping background notify-me search (cancels open ride request).
Future<bool> showActiveSearchStopDialog({
  required BuildContext context,
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
  required AppLocalizations l10n,
}) async {
  return showHeyCabyConfirmSheet(
    context,
    colors: colors,
    typography: typo,
    title: l10n.activeSearchStopTitle,
    message: l10n.activeSearchStopBody,
    dismissLabel: l10n.activeSearchStopKeep,
    confirmLabel: l10n.activeSearchStopConfirm,
    icon: Icons.notifications_off_rounded,
    confirmDestructive: true,
  );
}
