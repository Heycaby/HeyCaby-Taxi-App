import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

Future<bool> showCancelBookingDialog(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typography,
}) async {
  final l10n = AppLocalizations.of(context);
  return showHeyCabyConfirmSheet(
    context,
    colors: colors,
    typography: typography,
    title: l10n.cancelBookingTitle,
    message: l10n.cancelBookingMessage,
    dismissLabel: l10n.keepGoing,
    confirmLabel: l10n.cancel,
    icon: Icons.close_rounded,
    confirmDestructive: true,
  );
}

class PrimaryCancelRow extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onCancel;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;

  const PrimaryCancelRow({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onCancel,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: onPrimary == null
                  ? null
                  : () {
                      HapticService.heavyTap();
                      onPrimary!();
                    },
              style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: colors.border,
                  disabledForegroundColor: colors.textMid,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              child: Text(
                primaryLabel,
                style: typography.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 52,
          height: 52,
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.card,
              foregroundColor: colors.text,
              side: BorderSide(color: colors.border, width: 1.5),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Icon(Icons.close, color: colors.text, size: 20),
          ),
        ),
      ],
    );
  }
}
