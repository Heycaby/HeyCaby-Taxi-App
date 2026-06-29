import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'driver_colors.dart';

/// Driver typography scale — maps to [HeyCabyTypography] from theme.
@immutable
class DriverTypography {
  const DriverTypography._(this._typo);

  final HeyCabyTypography _typo;

  TextStyle get displayLarge => _typo.displayLarge;
  TextStyle get displayMedium => _typo.displayMedium;
  TextStyle get displaySmall => _typo.displaySmall;

  TextStyle get headlineLarge => _typo.headingLarge;
  TextStyle get headlineMedium => _typo.headingMedium;
  TextStyle get headlineSmall => _typo.headingSmall;

  TextStyle get titleLarge => _typo.titleLarge;
  TextStyle get titleMedium => _typo.titleMedium;
  TextStyle get titleSmall => _typo.titleSmall;

  TextStyle get bodyLarge => _typo.bodyLarge;
  TextStyle get bodyMedium => _typo.bodyMedium;
  TextStyle get bodySmall => _typo.bodySmall;

  TextStyle get labelLarge => _typo.labelLarge;
  TextStyle get labelMedium => _typo.labelMedium;
  TextStyle get labelSmall => _typo.labelSmall;

  TextStyle get mono => _typo.mono;

  /// Fares, earnings, stats — tabular figures when available.
  TextStyle numberLarge(BuildContext context, DriverColors colors) =>
      displayMedium.copyWith(
        color: colors.text,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 0,
      );

  TextStyle numberMedium(DriverColors colors) => titleLarge.copyWith(
        color: colors.text,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @visibleForTesting
  factory DriverTypography.fromHeyCaby(HeyCabyTypography typography) =>
      DriverTypography._(typography);

  /// Wrap shared typography for driver UI.
  factory DriverTypography.fromTheme(HeyCabyTypography typography) =>
      DriverTypography._(typography);

  static DriverTypography of(WidgetRef ref) =>
      DriverTypography._(ref.watch(typographyProvider));
}
