import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Large tap targets for OTP — avoids full keyboard on iOS.
class DriverLoginOtpKeypad extends StatelessWidget {
  const DriverLoginOtpKeypad({
    super.key,
    required this.colors,
    required this.typography,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  Widget _key(String label, {VoidCallback? onTap, Widget? child}) {
    return Material(
      color: colors.card,
      borderRadius: DriverRadius.smAll,
      child: InkWell(
        onTap: enabled && onTap != null ? onTap : null,
        borderRadius: DriverRadius.smAll,
        child: Container(
          height: DriverSpacing.touchTargetLarge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: DriverRadius.smAll,
            border: Border.all(color: colors.border),
          ),
          child: child ??
              Text(
                label,
                style: typography.titleLarge.copyWith(
                  color: enabled ? colors.text : colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
            child: Row(
              children: row.map((d) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DriverSpacing.xs,
                    ),
                    child: _key(d, onTap: () => onDigit(d)),
                  ),
                );
              }).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
          child: Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DriverSpacing.xs,
                  ),
                  child: _key('0', onTap: () => onDigit('0')),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DriverSpacing.xs,
                  ),
                  child: _key(
                    '',
                    onTap: onBackspace,
                    child: Icon(
                      Icons.backspace_outlined,
                      color: enabled ? colors.textSecondary : colors.textMuted,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
