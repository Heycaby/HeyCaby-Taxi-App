import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';

/// Shared premium surfaces for core ride flow (Program 4).
abstract final class DriverRidePremiumStyle {
  DriverRidePremiumStyle._();

  static LinearGradient screenBackground(DriverColors colors) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.primary.withValues(alpha: 0.035),
          colors.background,
          colors.background,
        ],
        stops: const [0.0, 0.18, 1.0],
      );

  static BoxDecoration modalSurface(DriverColors colors) => BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      );

  /// Frosted "liquid glass" sheet/card. Blurs whatever sits behind it (map,
  /// gradient, or a parent glass surface) and layers a translucent tint on top.
  ///
  /// This is the single blur layer for a stacking context. Inner cards that sit
  /// on top of a [glassSurface] should use [frostedFill] (a translucent
  /// decoration with no second blur) to avoid muddy nested backdrops.
  static Widget glassSurface({
    required DriverColors colors,
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    BorderRadius? borderRadius,
    double blurSigma = 22,
    double tintOpacity = 0.72,
    Color? tint,
    Color? borderColor,
    List<BoxShadow>? boxShadow,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(30);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (tint ?? colors.card).withValues(alpha: tintOpacity),
            borderRadius: radius,
            border: Border.all(
              color: (borderColor ?? colors.border).withValues(alpha: 0.55),
            ),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: colors.text.withValues(alpha: 0.10),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  /// Translucent fill for cards layered on top of a [glassSurface]. No blur of
  /// its own so the parent's frosted backdrop shows through as depth.
  static BoxDecoration frostedFill(
    DriverColors colors, {
    BorderRadius? borderRadius,
    Color? tint,
    Color? borderColor,
    double tintOpacity = 0.55,
  }) =>
      BoxDecoration(
        color: (tint ?? colors.surface).withValues(alpha: tintOpacity),
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        border: Border.all(
          color: (borderColor ?? colors.border).withValues(alpha: 0.5),
        ),
      );

  static Widget sheetHandle(DriverColors colors) => Center(
        child: Container(
          width: 52,
          height: 5,
          decoration: BoxDecoration(
            color: colors.border.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );

  static Widget modalTopBar({
    required DriverColors colors,
    required String title,
    required TextStyle titleStyle,
    required VoidCallback? onBack,
    IconData icon = Icons.arrow_back_rounded,
    String? tooltip,
    Widget? trailing,
  }) =>
      Row(
        children: [
          _ModalIconButton(
            colors: colors,
            icon: icon,
            tooltip: tooltip,
            onPressed: onBack,
          ),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: DriverSpacing.sm),
            trailing,
          ],
        ],
      );
}

class _ModalIconButton extends StatelessWidget {
  const _ModalIconButton({
    required this.colors,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final DriverColors colors;
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: colors.text),
      ),
    );
  }
}
