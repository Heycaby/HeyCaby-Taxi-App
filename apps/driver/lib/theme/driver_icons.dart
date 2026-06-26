import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';

export 'app_icons.dart' show AppIcons;

/// Consistent icon sizing and color from tokens.
class DriverIcon extends StatelessWidget {
  const DriverIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  factory DriverIcon.nav(
    IconData icon, {
    Key? key,
    required DriverColors colors,
    bool active = false,
  }) {
    return DriverIcon(
      icon,
      key: key,
      size: 22,
      color: active ? colors.primary : colors.textSecondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Icon(icon, size: size, color: color),
    );
  }
}

/// Ensures minimum 48dp touch target around an icon control.
class DriverIconButton extends StatelessWidget {
  const DriverIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.colors,
    this.tooltip,
    this.size = 24,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final DriverColors? colors;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: DriverIcon(icon, size: size, color: c?.textSecondary),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(DriverSpacing.touchTarget),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
