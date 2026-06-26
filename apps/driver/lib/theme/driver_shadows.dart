import 'package:flutter/material.dart';

import 'driver_colors.dart';

/// Soft elevation shadows — minimal, premium.
abstract final class DriverShadows {
  DriverShadows._();

  static List<BoxShadow> card(DriverColors colors) => [
        BoxShadow(
          color: colors.text.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> floating(DriverColors colors) => [
        BoxShadow(
          color: colors.text.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> subtle(DriverColors colors) => [
        BoxShadow(
          color: colors.text.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}
