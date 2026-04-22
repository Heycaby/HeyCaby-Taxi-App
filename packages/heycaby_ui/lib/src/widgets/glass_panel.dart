import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/typography.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? tintColor;
  final Color? borderColor;

  const GlassPanel({
    super.key,
    required this.child,
    required this.colors,
    required this.typography,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.tintColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = (tintColor ?? colors.surface).withValues(alpha: 0.82);
    final stroke = (borderColor ?? colors.border).withValues(alpha: 0.75);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: borderRadius,
            border: Border.all(
              color: stroke,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

