import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heycaby_ui/src/theme/color_tokens.dart';
import 'package:heycaby_ui/src/theme/heycaby_app_chrome.dart';
import 'package:heycaby_ui/src/theme/theme_registry.dart';

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
  String themeId = '',
}) {
  final fontFamily = GoogleFonts.config.allowRuntimeFetching
      ? GoogleFonts.plusJakartaSans().fontFamily
      : 'Roboto';
  var theme = ThemeData(
    useMaterial3: true,
    colorScheme: heyCabyColorScheme(colors),
    scaffoldBackgroundColor: colors.bg,
    textTheme: textTheme,
    fontFamily: fontFamily,
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
  ).copyWith(
    // Shared chrome so apps can omit per-widget backgroundColor on Scaffold / AppBar /
    // AlertDialog / modal sheets. Driver-warm layers extra tokens in [_applySoftWarmWhiteMaterial].
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: colors.text),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colors.text,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.border,
      thickness: 0.5,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.card,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.text),
      behavior: SnackBarBehavior.floating,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
    ),
  );

  if (themeId.isHeyCabyDriverTheme) {
    theme = _applySoftWarmWhiteMaterial(theme, colors, textTheme);
  }

  return theme.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      HeyCabyAppChrome(themeId: themeId),
    ],
  );
}

/// Maps driver UI chrome (inputs, cards, app bars, sheets) from the green driver guide.
ThemeData _applySoftWarmWhiteMaterial(
  ThemeData base,
  HeyCabyColorTokens colors,
  TextTheme textTheme,
) {
  final outlineRadius = BorderRadius.circular(12);
  final outlineIdle = OutlineInputBorder(
    borderRadius: outlineRadius,
    borderSide: BorderSide(color: colors.border, width: 1),
  );
  final bodyFont = textTheme.bodyMedium?.fontFamily;
  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: colors.textSoft, fontFamily: bodyFont),
      labelStyle: TextStyle(color: colors.textMid, fontFamily: bodyFont),
      floatingLabelStyle:
          TextStyle(color: colors.textMid, fontFamily: bodyFont),
      enabledBorder: outlineIdle,
      border: outlineIdle,
      focusedBorder: OutlineInputBorder(
        borderRadius: outlineRadius,
        borderSide: BorderSide(color: colors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: outlineRadius,
        borderSide: BorderSide(color: colors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: outlineRadius,
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: const Color(0x0D000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colors.text,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: colors.text, size: 24),
      shape: Border(
        bottom: BorderSide(color: colors.border, width: 0.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.border,
      thickness: 0.5,
      space: 1,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.text, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border, width: 0.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.card,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border, width: 0.5),
      ),
    ),
  );
}

/// Baseline [ElevatedButton] on [HeyCabyColorTokens.error].
ButtonStyle heyCabyElevatedErrorStyle(HeyCabyColorTokens colors) {
  return ElevatedButton.styleFrom(
    backgroundColor: colors.error,
    foregroundColor: colors.onError,
    disabledBackgroundColor: colors.border,
    disabledForegroundColor: colors.textMid,
    elevation: 0,
  );
}
