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
