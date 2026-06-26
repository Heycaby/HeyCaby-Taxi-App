import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Deterministic text theme for golden tests (no Google Fonts / network).
TextTheme buildDriverGoldenTextTheme() {
  const family = 'Roboto';
  return const TextTheme(
    displayLarge: TextStyle(fontFamily: family, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1),
    displayMedium: TextStyle(fontFamily: family, fontSize: 32, fontWeight: FontWeight.w800, height: 1.2),
    displaySmall: TextStyle(fontFamily: family, fontSize: 26, fontWeight: FontWeight.w700, height: 1.2),
    headlineLarge: TextStyle(fontFamily: family, fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
    headlineMedium: TextStyle(fontFamily: family, fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
    headlineSmall: TextStyle(fontFamily: family, fontSize: 18, fontWeight: FontWeight.w700, height: 1.4),
    titleLarge: TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
    titleMedium: TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
    titleSmall: TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge: TextStyle(fontFamily: family, fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
    bodyMedium: TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w400, height: 1.6),
    bodySmall: TextStyle(fontFamily: family, fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
    labelLarge: TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
    labelMedium: TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
    labelSmall: TextStyle(fontFamily: family, fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
  );
}

HeyCabyTypography buildDriverGoldenTypography() {
  final t = buildDriverGoldenTextTheme();
  return HeyCabyTypography(
    displayLarge: t.displayLarge!,
    displayMedium: t.displayMedium!,
    displaySmall: t.displaySmall!,
    headingLarge: t.headlineLarge!,
    headingMedium: t.headlineMedium!,
    headingSmall: t.headlineSmall!,
    titleLarge: t.titleLarge!,
    titleMedium: t.titleMedium!,
    titleSmall: t.titleSmall!,
    bodyLarge: t.bodyLarge!,
    bodyMedium: t.bodyMedium!,
    bodySmall: t.bodySmall!,
    labelLarge: t.labelLarge!,
    labelMedium: t.labelMedium!,
    labelSmall: t.labelSmall!,
    mono: t.titleMedium!,
  );
}

ThemeData buildDriverGoldenMaterialTheme(HeyCabyColorTokens colors) {
  final textTheme = buildDriverGoldenTextTheme();
  return ThemeData(
    useMaterial3: true,
    colorScheme: heyCabyColorScheme(colors),
    scaffoldBackgroundColor: colors.bg,
    textTheme: textTheme,
    fontFamily: 'Roboto',
    filledButtonTheme: FilledButtonThemeData(
      style: heyCabyFilledAccentStyle(colors),
    ),
  );
}
