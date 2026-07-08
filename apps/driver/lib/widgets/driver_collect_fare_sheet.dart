import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

/// Driver checkpoint before completing a ride — fare collection must be obvious.
Future<bool> showDriverCollectFareSheet(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typography,
  required String? amountLabel,
  bool barrierDismissible = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.48),
    isDismissible: barrierDismissible,
    enableDrag: barrierDismissible,
    builder: (ctx) => _DriverCollectFareSheet(
      colors: colors,
      typography: typography,
      amountLabel: amountLabel,
    ),
  );
  return result ?? false;
}

String formatDriverCollectAmount(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final trimmed = raw.trim();
  if (trimmed.toUpperCase().startsWith('EUR ')) {
    return '€${trimmed.substring(4).trim()}';
  }
  if (trimmed.startsWith('€')) return trimmed;
  return trimmed;
}

class _DriverCollectFareSheet extends StatelessWidget {
  const _DriverCollectFareSheet({
    required this.colors,
    required this.typography,
    required this.amountLabel,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final String? amountLabel;

  static const double _scale = 1.1;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final amount = formatDriverCollectAmount(amountLabel);
    final iconSize = 58.0 * _scale;
    final buttonHeight = 58.0 * _scale;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 14),
        child: GlassPanel(
          colors: colors,
          typography: typography,
          padding: EdgeInsets.fromLTRB(22 * _scale, 12 * _scale, 22 * _scale, 22 * _scale),
          borderRadius: BorderRadius.circular(30 * _scale),
          tintColor: colors.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48 * _scale,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: 20 * _scale),
              Center(
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: MoneySilhouetteIcon(
                      color: colors.accent,
                      size: 30 * _scale,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18 * _scale),
              Text(
                DriverStrings.collectPaymentTitle,
                textAlign: TextAlign.center,
                style: typography.titleLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: (typography.titleLarge.fontSize ?? 22) * _scale,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 10 * _scale),
              Text(
                DriverStrings.collectPaymentBody,
                textAlign: TextAlign.center,
                style: typography.bodyMedium.copyWith(
                  color: colors.textMid,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  fontSize: (typography.bodyMedium.fontSize ?? 14) * 1.05,
                ),
              ),
              SizedBox(height: 20 * _scale),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * _scale,
                  vertical: 18 * _scale,
                ),
                decoration: BoxDecoration(
                  color: colors.accentL.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20 * _scale),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      DriverStrings.collectPaymentAmountCaption,
                      textAlign: TextAlign.center,
                      style: typography.labelLarge.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 8 * _scale),
                    Text(
                      amount,
                      textAlign: TextAlign.center,
                      style: typography.displaySmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 42 * _scale,
                        height: 1.05,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24 * _scale),
              FilledButton(
                onPressed: () {
                  HapticService.lightTap();
                  Navigator.of(context).pop(false);
                },
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18 * _scale),
                  ),
                ),
                child: Text(
                  DriverStrings.collectPaymentBack,
                  style: typography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: (typography.labelLarge.fontSize ?? 14) * 1.05,
                  ),
                ),
              ),
              SizedBox(height: 11 * _scale),
              OutlinedButton(
                onPressed: () {
                  HapticService.mediumTap();
                  Navigator.of(context).pop(true);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(buttonHeight),
                  foregroundColor: colors.accent,
                  side: BorderSide(
                    color: colors.accent.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18 * _scale),
                  ),
                ),
                child: Text(
                  DriverStrings.collectPaymentContinue,
                  style: typography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: (typography.labelLarge.fontSize ?? 14) * 1.05,
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
