import 'package:flutter/material.dart';

import '../haptics/haptic_service.dart';
import '../theme/color_tokens.dart';
import '../theme/typography.dart';
import 'glass_panel.dart';

const _kPremiumSheetRadius = 32.0;
const _kPremiumSheetInset = 16.0;
const _kPremiumButtonRadius = 18.0;

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
    barrierColor: colors.text.withValues(alpha: 0.48),
    isDismissible: barrierDismissible,
    enableDrag: barrierDismissible,
    useSafeArea: false,
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
    barrierColor: colors.text.withValues(alpha: 0.48),
    isDismissible: barrierDismissible,
    enableDrag: barrierDismissible,
    useSafeArea: false,
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

/// Floating premium card — rounded on all corners, lifted above the home indicator.
class _HeyCabyPremiumSheetFrame extends StatelessWidget {
  const _HeyCabyPremiumSheetFrame({
    required this.colors,
    required this.typography,
    required this.child,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kPremiumSheetInset,
        0,
        _kPremiumSheetInset,
        bottom + _kPremiumSheetInset,
      ),
      child: GlassPanel(
        colors: colors,
        typography: typography,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        borderRadius: BorderRadius.circular(_kPremiumSheetRadius),
        tintColor: colors.card,
        borderColor: colors.border.withValues(alpha: 0.55),
        child: child,
      ),
    );
  }
}

class _HeyCabySheetHandle extends StatelessWidget {
  const _HeyCabySheetHandle({required this.colors});

  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _HeyCabySheetIconBadge extends StatelessWidget {
  const _HeyCabySheetIconBadge({
    required this.colors,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
  });

  final HeyCabyColorTokens colors;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: iconBackgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: iconColor.withValues(alpha: 0.22),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
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
    final accentIcon = iconColor ?? colors.warning;
    final iconBg = iconBackgroundColor ?? accentIcon.withValues(alpha: 0.12);

    return _HeyCabyPremiumSheetFrame(
      colors: colors,
      typography: typography,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeyCabySheetHandle(colors: colors),
          _HeyCabySheetIconBadge(
            colors: colors,
            icon: icon,
            iconColor: accentIcon,
            iconBackgroundColor: iconBg,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: typography.titleLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: typography.bodyMedium.copyWith(
              color: colors.textMid,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              HapticService.lightTap();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kPremiumButtonRadius),
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
    final accentIcon = iconColor ??
        (confirmDestructive ? colors.error : colors.warning);
    final iconBg = iconBackgroundColor ??
        accentIcon.withValues(alpha: 0.12);
    final confirmColor =
        confirmDestructive ? colors.error : colors.accent;

    return _HeyCabyPremiumSheetFrame(
      colors: colors,
      typography: typography,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeyCabySheetHandle(colors: colors),
          _HeyCabySheetIconBadge(
            colors: colors,
            icon: icon,
            iconColor: accentIcon,
            iconBackgroundColor: iconBg,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: typography.titleLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: typography.bodyMedium.copyWith(
              color: colors.textMid,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (detail != null && detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: typography.bodySmall.copyWith(
                color: colors.textSoft,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              HapticService.lightTap();
              Navigator.of(context).pop(false);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kPremiumButtonRadius),
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
              minimumSize: const Size.fromHeight(54),
              foregroundColor: confirmColor,
              side: BorderSide(
                color: confirmColor.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kPremiumButtonRadius),
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
    );
  }
}
