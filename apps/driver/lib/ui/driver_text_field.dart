import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

class DriverTextField extends StatelessWidget {
  const DriverTextField({
    super.key,
    required this.controller,
    required this.colors,
    required this.typography,
    this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController controller;
  final DriverColors colors;
  final DriverTypography typography;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: typography.labelMedium.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DriverSpacing.sm),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          style: typography.bodyLarge.copyWith(color: colors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: typography.bodyMedium.copyWith(color: colors.textMuted),
            filled: true,
            fillColor: colors.card,
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.lg,
              vertical: DriverSpacing.lg,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: DriverRadius.smAll,
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: DriverRadius.smAll,
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: DriverRadius.smAll,
              borderSide: BorderSide(color: colors.error),
            ),
          ),
        ),
      ],
    );
  }
}
