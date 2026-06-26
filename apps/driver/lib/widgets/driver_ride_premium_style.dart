import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';

/// Shared premium surfaces for core ride flow (Program 4).
abstract final class DriverRidePremiumStyle {
  DriverRidePremiumStyle._();

  static LinearGradient screenBackground(DriverColors colors) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.primary.withValues(alpha: 0.06),
          colors.background,
          colors.background,
        ],
        stops: const [0.0, 0.22, 1.0],
      );
}
