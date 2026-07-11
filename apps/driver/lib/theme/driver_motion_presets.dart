import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/driver_strings.dart';
import 'driver_colors.dart';
import 'driver_motion.dart';
import 'driver_radius.dart';
import 'driver_spacing.dart';
import 'driver_typography.dart';

/// Global motion gate — disabled in golden tests for pixel-stable baselines.
bool kDriverMotionEnabled = true;

/// Canonical motion presets for Phase 2 surfaces. Uses [DriverMotion] tokens only.
extension DriverWidgetMotion on Widget {
  /// Standard content entrance (sheet sections, form blocks).
  Widget driverFadeSlideIn({
    int staggerIndex = 0,
    double slideY = 0.08,
  }) {
    if (!kDriverMotionEnabled) return this;
    final delay = DriverMotion.staggerDelay(staggerIndex);
    return animate(delay: delay)
        .fadeIn(
          duration: DriverMotion.standard,
          curve: DriverMotion.enterCurve,
        )
        .slideY(
          begin: slideY,
          end: 0,
          duration: DriverMotion.standard,
          curve: DriverMotion.standardCurve,
        );
  }

  /// Map overlay chrome — drops in from above.
  Widget driverMapChromeEnter({int staggerIndex = 0}) {
    if (!kDriverMotionEnabled) return this;
    final delay = DriverMotion.staggerDelay(staggerIndex);
    return animate(delay: delay)
        .fadeIn(
          duration: DriverMotion.fast,
          curve: DriverMotion.enterCurve,
        )
        .slideY(
          begin: -0.18,
          end: 0,
          duration: DriverMotion.emphasis,
          curve: DriverMotion.standardCurve,
        );
  }

  /// Success / confirmation pop (online, OTP sent).
  Widget driverSuccessPop() {
    if (!kDriverMotionEnabled) return this;
    return animate()
        .scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1, 1),
          duration: DriverMotion.emphasis,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: DriverMotion.fast, curve: DriverMotion.enterCurve);
  }

  /// Urgent incoming ride — subtle repeating emphasis.
  Widget driverRideIncomingPulse({bool enabled = true}) {
    if (!enabled || !kDriverMotionEnabled) return this;
    return animate(onPlay: (c) => c.repeat(reverse: true)).scale(
      begin: const Offset(1, 1),
      end: const Offset(1.012, 1.012),
      duration: DriverMotion.emphasis,
      curve: Curves.easeInOut,
    );
  }
}

/// Cross-fades earnings text when the formatted value changes.
class DriverAnimatedEarnings extends StatelessWidget {
  const DriverAnimatedEarnings({
    super.key,
    required this.value,
    required this.style,
    this.textAlign,
  });

  final String value;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: DriverMotion.standard,
      switchInCurve: DriverMotion.enterCurve,
      switchOutCurve: DriverMotion.standardCurve,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: DriverMotion.standardCurve,
        ));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Text(
        value,
        key: ValueKey<String>(value),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// Animated online / offline badge for the Money Dashboard header.
class DriverOnlineStatusBadge extends StatelessWidget {
  const DriverOnlineStatusBadge({
    super.key,
    required this.isOnline,
    required this.colors,
    required this.typography,
  });

  final bool isOnline;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: DriverMotion.standard,
      curve: DriverMotion.standardCurve,
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOnline
              ? [
                  colors.primary.withValues(alpha: 0.18),
                  colors.primary.withValues(alpha: 0.08),
                ]
              : [
                  colors.textMuted.withValues(alpha: 0.12),
                  colors.textMuted.withValues(alpha: 0.06),
                ],
        ),
        borderRadius: BorderRadius.circular(DriverRadius.pill),
        border: Border.all(
          color: isOnline
              ? colors.primary.withValues(alpha: 0.35)
              : colors.border.withValues(alpha: 0.8),
        ),
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: DriverMotion.fast,
        switchInCurve: DriverMotion.enterCurve,
        switchOutCurve: DriverMotion.standardCurve,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Row(
          key: ValueKey<bool>(isOnline),
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(
              active: isOnline,
              activeColor: colors.primary,
              inactiveColor: colors.textMuted,
            ),
            const SizedBox(width: DriverSpacing.sm),
            Text(
              isOnline ? DriverStrings.online : DriverStrings.offline,
              style: typography.labelLarge.copyWith(
                color: isOnline ? colors.primary : colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
  });

  final bool active;
  final Color activeColor;
  final Color inactiveColor;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncController();
  }

  void _syncController() {
    if (widget.active && kDriverMotionEnabled) {
      _controller ??= AnimationController(
        vsync: this,
        duration: DriverMotion.emphasis,
      )..repeat(reverse: true);
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.activeColor : widget.inactiveColor;
    if (_controller == null) {
      return _dot(color, glow: 0);
    }
    return AnimatedBuilder(
      animation: _controller!,
      builder: (_, __) {
        final glow = 0.35 + _controller!.value * 0.35;
        return _dot(color, glow: glow);
      },
    );
  }

  Widget _dot(Color color, {required double glow}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow > 0
            ? [
                BoxShadow(
                  color: color.withValues(alpha: glow),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
    );
  }
}
