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
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        l10n.activeSearchStopTitle,
        style: typo.titleLarge.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        l10n.activeSearchStopBody,
        style: typo.bodyMedium.copyWith(
          color: colors.textMid,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            l10n.activeSearchStopKeep,
            style: typo.labelLarge.copyWith(color: colors.textMid),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.activeSearchStopConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
