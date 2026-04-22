import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';

/// Alpha applied to [HeyCabyColorTokens.accent] for disabled primary CTAs.
const double kHeyCabyCtaDisabledBgAlpha = 0.42;

/// Alpha applied to [HeyCabyColorTokens.onAccent] for disabled primary CTA labels.
const double kHeyCabyCtaDisabledFgAlpha = 0.78;

ColorScheme heyCabyColorScheme(HeyCabyColorTokens colors) {
  return ColorScheme.light(
    primary: colors.accent,
    onPrimary: colors.onAccent,
    secondary: colors.accent,
    onSecondary: colors.onAccent,
    surface: colors.surface,
    onSurface: colors.text,
    error: colors.error,
    onError: colors.onError,
    outline: colors.border,
  );
}

/// Accent primary CTA (filled): paired enabled/disabled colors from tokens.
///
/// [buildHeyCabyMaterialTheme] applies this as [ThemeData.filledButtonTheme] so most
/// screens only need [FilledButton.styleFrom] for padding, shape, or rare disabled
/// background overrides — do not set `foregroundColor: colors.text` on accent fills.
ButtonStyle heyCabyFilledAccentStyle(HeyCabyColorTokens colors) {
  return FilledButton.styleFrom(
    backgroundColor: colors.accent,
    foregroundColor: colors.onAccent,
    disabledBackgroundColor:
        colors.accent.withValues(alpha: kHeyCabyCtaDisabledBgAlpha),
    disabledForegroundColor:
        colors.onAccent.withValues(alpha: kHeyCabyCtaDisabledFgAlpha),
    elevation: 0,
  );
}

/// Accent primary CTA (elevated): paired enabled/disabled colors from tokens.
///
/// [buildHeyCabyMaterialTheme] applies this as [ThemeData.elevatedButtonTheme].
ButtonStyle heyCabyElevatedAccentStyle(HeyCabyColorTokens colors) {
  return ElevatedButton.styleFrom(
    backgroundColor: colors.accent,
    foregroundColor: colors.onAccent,
    disabledBackgroundColor:
        colors.accent.withValues(alpha: kHeyCabyCtaDisabledBgAlpha),
    disabledForegroundColor:
        colors.onAccent.withValues(alpha: kHeyCabyCtaDisabledFgAlpha),
    elevation: 0,
  );
}

ThemeData buildHeyCabyMaterialTheme({
  required HeyCabyColorTokens colors,
  required TextTheme textTheme,
}) {
  final jakarta = GoogleFonts.plusJakartaSans();
  return ThemeData(
    useMaterial3: true,
    colorScheme: heyCabyColorScheme(colors),
    scaffoldBackgroundColor: colors.bg,
    textTheme: textTheme,
    fontFamily: jakarta.fontFamily,
    splashFactory: NoSplash.splashFactory,
    highlightColor: colors.accentL,
    filledButtonTheme: FilledButtonThemeData(
      style: heyCabyFilledAccentStyle(colors),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: heyCabyElevatedAccentStyle(colors),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.accent,
      foregroundColor: colors.onAccent,
    ),
  );
}

/// Baseline [ElevatedButton] on [HeyCabyColorTokens.error].
ButtonStyle heyCabyElevatedErrorStyle(HeyCabyColorTokens colors) {
  return ElevatedButton.styleFrom(
    backgroundColor: colors.error,
    foregroundColor: colors.onError,
    disabledBackgroundColor:
        colors.border,
    disabledForegroundColor: colors.textMid,
    elevation: 0,
  );
}
