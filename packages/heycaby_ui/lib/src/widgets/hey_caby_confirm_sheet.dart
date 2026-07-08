import 'package:flutter/material.dart';

import '../haptics/haptic_service.dart';
import '../theme/color_tokens.dart';
import '../theme/typography.dart';
import 'glass_panel.dart';

/// Sleek pull-up confirmation for cancel, delete, go back, logout, etc.
///
/// Returns `true` when the user taps [confirmLabel] (the committing action).
/// Returns `false` when they tap [dismissLabel], dismisses the sheet, or taps
/// outside (if [barrierDismissible]).
Future<bool> showHeyCabyConfirmSheet(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typography,
  required String title,
  required String message,
  required String dismissLabel,
  required String confirmLabel,
  IconData icon = Icons.warning_amber_rounded,
  Color? iconColor,
  Color? iconBackgroundColor,
  bool confirmDestructive = true,
  String? detail,
  bool barrierDismissible = true,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.42),
    isDismissible: barrierDismissible,
    enableDrag: true,
    builder: (ctx) => _HeyCabyConfirmSheet(
      colors: colors,
      typography: typography,
      title: title,
      message: message,
      dismissLabel: dismissLabel,
      confirmLabel: confirmLabel,
      icon: icon,
      iconColor: iconColor,
      iconBackgroundColor: iconBackgroundColor,
      confirmDestructive: confirmDestructive,
      detail: detail,
    ),
  );
  return result ?? false;
}

/// Single-action pull-up sheet for notices (rider cancelled, missed request, etc.).
Future<void> showHeyCabyAcknowledgeSheet(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typography,
  required String title,
  required String message,
  required String actionLabel,
  IconData icon = Icons.info_outline_rounded,
  Color? iconColor,
  Color? iconBackgroundColor,
  bool barrierDismissible = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.42),
    isDismissible: barrierDismissible,
    enableDrag: barrierDismissible,
    builder: (ctx) => _HeyCabyAcknowledgeSheet(
      colors: colors,
      typography: typography,
      title: title,
      message: message,
      actionLabel: actionLabel,
      icon: icon,
      iconColor: iconColor,
      iconBackgroundColor: iconBackgroundColor,
    ),
  );
}

class _HeyCabyAcknowledgeSheet extends StatelessWidget {
  const _HeyCabyAcknowledgeSheet({
    required this.colors,
    required this.typography,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.icon,
    this.iconColor,
    this.iconBackgroundColor,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final String title;
  final String message;
  final String actionLabel;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accentIcon = iconColor ?? colors.warning;
    final iconBg = iconBackgroundColor ?? accentIcon.withValues(alpha: 0.12);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
        child: GlassPanel(
          colors: colors,
          typography: typography,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          tintColor: colors.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentIcon, size: 26),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: typography.titleLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: typography.bodyMedium.copyWith(
                  color: colors.textMid,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () {
                  HapticService.lightTap();
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: typography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeyCabyConfirmSheet extends StatelessWidget {
  const _HeyCabyConfirmSheet({
    required this.colors,
    required this.typography,
    required this.title,
    required this.message,
    required this.dismissLabel,
    required this.confirmLabel,
    required this.icon,
    required this.confirmDestructive,
    this.iconColor,
    this.iconBackgroundColor,
    this.detail,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final String title;
  final String message;
  final String dismissLabel;
  final String confirmLabel;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final bool confirmDestructive;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accentIcon = iconColor ??
        (confirmDestructive ? colors.error : colors.warning);
    final iconBg = iconBackgroundColor ??
        accentIcon.withValues(alpha: 0.12);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
        child: GlassPanel(
          colors: colors,
          typography: typography,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          tintColor: colors.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentIcon, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: typography.titleLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: typography.bodyMedium.copyWith(
                  color: colors.textMid,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (detail != null && detail!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  detail!,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSoft,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () {
                  HapticService.lightTap();
                  Navigator.of(context).pop(false);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  dismissLabel,
                  style: typography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  HapticService.mediumTap();
                  Navigator.of(context).pop(true);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor:
                      confirmDestructive ? colors.error : colors.accent,
                  side: BorderSide(
                    color: (confirmDestructive ? colors.error : colors.accent)
                        .withValues(alpha: 0.55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: typography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
