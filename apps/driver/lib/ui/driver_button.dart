import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

enum DriverButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
  warning
}

enum DriverButtonSize { sm, md, lg }

/// Primary driver CTA — 48dp+ touch target, token-only styling.
class DriverButton extends StatefulWidget {
  const DriverButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.colors,
    required this.typography,
    this.variant = DriverButtonVariant.primary,
    this.size = DriverButtonSize.md,
    this.expanded = true,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DriverButtonVariant variant;
  final DriverButtonSize size;
  final bool expanded;
  final IconData? icon;
  final bool loading;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverButton> createState() => _DriverButtonState();
}

class _DriverButtonState extends State<DriverButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  double get _height {
    switch (widget.size) {
      case DriverButtonSize.sm:
        return DriverSpacing.touchTarget;
      case DriverButtonSize.md:
        return DriverSpacing.touchTarget;
      case DriverButtonSize.lg:
        return DriverSpacing.touchTargetLarge;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typography;
    final (bg, fg, border) = _colorsForVariant(colors);

    final child = AnimatedScale(
      scale: _pressed && _enabled ? DriverMotion.cardPressScale : 1,
      duration: DriverMotion.pressDuration,
      curve: DriverMotion.pressCurve,
      child: Material(
        color: _enabled ? bg : bg.withValues(alpha: 0.45),
        elevation: 0,
        borderRadius: DriverRadius.smAll,
        child: InkWell(
          onTap: _enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                }
              : null,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: DriverRadius.smAll,
          child: Container(
            height: _height,
            padding: const EdgeInsets.symmetric(horizontal: DriverSpacing.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: DriverRadius.smAll,
              border: border,
            ),
            child: widget.loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize:
                        widget.expanded ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: fg),
                        const SizedBox(width: DriverSpacing.sm),
                      ],
                      if (widget.expanded)
                        Flexible(
                          child: Text(
                            widget.label,
                            style: typo.labelLarge.copyWith(color: fg),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Text(
                          widget.label,
                          style: typo.labelLarge.copyWith(color: fg),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return widget.expanded
        ? SizedBox(width: double.infinity, child: child)
        : child;
  }

  (Color, Color, Border?) _colorsForVariant(DriverColors colors) {
    switch (widget.variant) {
      case DriverButtonVariant.primary:
        return (colors.primary, colors.onPrimary, null);
      case DriverButtonVariant.secondary:
        return (colors.primaryLight, colors.primary, null);
      case DriverButtonVariant.outline:
        return (
          colors.card,
          colors.text,
          Border.all(color: colors.border),
        );
      case DriverButtonVariant.ghost:
        return (Colors.transparent, colors.textSecondary, null);
      case DriverButtonVariant.destructive:
        return (colors.error, colors.onError, null);
      case DriverButtonVariant.warning:
        return (colors.warning, colors.onPrimary, null);
    }
  }
}
