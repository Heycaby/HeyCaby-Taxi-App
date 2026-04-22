import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

Future<bool> showCancelBookingDialog(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typography,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        l10n.cancelBookingTitle,
        style: typography.headingMedium.copyWith(color: colors.text),
      ),
      content: Text(
        l10n.cancelBookingMessage,
        style: typography.bodyMedium.copyWith(color: colors.textMid),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            l10n.keepGoing,
            style: typography.labelLarge.copyWith(color: colors.textMid),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            l10n.cancel,
            style: typography.labelLarge.copyWith(color: colors.error),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
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
              onPressed: onPrimary,
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

