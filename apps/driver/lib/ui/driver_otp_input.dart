import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Six-digit OTP slot row — driving-safe, glanceable code entry.
class DriverOtpInput extends StatelessWidget {
  const DriverOtpInput({
    super.key,
    required this.code,
    required this.colors,
    required this.typography,
    this.length = 6,
  });

  final String code;
  final DriverColors colors;
  final DriverTypography typography;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(length, (i) {
        final filled = i < code.length;
        final active = i == code.length && code.length < length;
        final digit = filled ? code[i] : '';

        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: i == 0 ? 0 : DriverSpacing.xs,
              end: i == length - 1 ? 0 : DriverSpacing.xs,
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: DriverRadius.smAll,
                  border: Border.all(
                    color: active ? colors.primary : colors.border,
                    width: active ? 2 : 1,
                  ),
                  boxShadow: active ? DriverShadows.subtle(colors) : null,
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: typography.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
