import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full Material [TextTheme] for HeyCaby: **Syne** (display + headlines) +
/// **Plus Jakarta Sans** (titles, body, labels). Use with [buildHeyCabyMaterialTheme].
TextTheme buildHeyCabyBrandMaterialTextTheme() {
  return TextTheme(
    displayLarge: GoogleFonts.syne(
      fontSize: 40,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.1,
    ),
    displayMedium: GoogleFonts.syne(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      height: 1.2,
    ),
    displaySmall: GoogleFonts.syne(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.2,
    ),
    headlineLarge: GoogleFonts.syne(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    headlineMedium: GoogleFonts.syne(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    headlineSmall: GoogleFonts.syne(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleSmall: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),
    bodySmall: GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.2,
    ),
    labelMedium: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.2,
    ),
    labelSmall: GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      height: 1.3,
    ),
  );
}

/// Semantic typography tokens used across apps via [typographyProvider].
/// Prefer [Theme.of(context).textTheme] for new code; these mirror the brand theme.
@immutable
class HeyCabyTypography {
  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle headingLarge;
  final TextStyle headingMedium;
  final TextStyle headingSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;
  final TextStyle mono;

  const HeyCabyTypography({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headingLarge,
    required this.headingMedium,
    required this.headingSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
    required this.mono,
  });
}

HeyCabyTypography buildTypographyForTheme(String themeId) {
  final t = buildHeyCabyBrandMaterialTextTheme();
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
    mono: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
  );
}
