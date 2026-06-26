import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Compact online / break status on the map — zone + tap to open panel.
class DriverMapOnlineChip extends StatelessWidget {
  const DriverMapOnlineChip({
    super.key,
    required this.zoneName,
    required this.isOnBreak,
    required this.colors,
    required this.typography,
    required this.onTap,
    this.pulseLiveIndicator = true,
  });

  final String zoneName;
  final bool isOnBreak;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;
  final bool pulseLiveIndicator;

  @override
  Widget build(BuildContext context) {
    final accent = isOnBreak ? colors.warning : colors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverRadius.pill),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(DriverRadius.pill),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
            boxShadow: DriverShadows.floating(colors),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.md,
              vertical: DriverSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                pulseLiveIndicator
                    ? _LiveDot(color: accent)
                    : _StaticDot(color: accent),
                const SizedBox(width: DriverSpacing.sm),
                Text(
                  isOnBreak ? DriverStrings.onBreak : DriverStrings.online,
                  style: typography.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: DriverSpacing.sm),
                  color: colors.border,
                ),
                Flexible(
                  child: Text(
                    isOnBreak ? DriverStrings.resume : zoneName,
                    style: typography.labelMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticDot extends StatelessWidget {
  const _StaticDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DriverMotion.emphasis,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final glow = 0.35 + _controller.value * 0.35;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glow),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
