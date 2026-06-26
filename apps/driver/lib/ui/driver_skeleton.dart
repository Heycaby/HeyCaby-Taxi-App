import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';

/// Shimmer placeholder — use while content loads.
class DriverSkeleton extends StatefulWidget {
  const DriverSkeleton({
    super.key,
    required this.colors,
    this.width,
    this.height = 16,
    this.borderRadius = DriverRadius.sm,
  });

  final DriverColors colors;
  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<DriverSkeleton> createState() => _DriverSkeletonState();
}

class _DriverSkeletonState extends State<DriverSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.colors.backgroundAlt,
                widget.colors.surface.withValues(alpha: 0.6 + t * 0.3),
                widget.colors.backgroundAlt,
              ],
            ),
          ),
        );
      },
    );
  }
}
