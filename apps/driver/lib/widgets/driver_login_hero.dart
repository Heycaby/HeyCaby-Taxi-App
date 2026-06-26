import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';

/// Trust Screen hero — full-bleed photography, bottom fade only (no copy on image).
class DriverLoginHero extends StatelessWidget {
  const DriverLoginHero({
    super.key,
    required this.colors,
    required this.typography,
    required this.compact,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact
        ? MediaQuery.sizeOf(context).height * 0.32
        : MediaQuery.sizeOf(context).height * 0.42;

    return SizedBox(
      height: height.clamp(200, 380),
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/driver_login_hero.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.12),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.text.withValues(alpha: 0.28),
                  Colors.transparent,
                  Colors.transparent,
                  colors.background.withValues(alpha: 0.72),
                  colors.background,
                ],
                stops: const [0.0, 0.28, 0.55, 0.86, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
