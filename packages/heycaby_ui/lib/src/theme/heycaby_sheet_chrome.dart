import 'package:flutter/material.dart';
import 'package:heycaby_ui/src/theme/color_tokens.dart';
import 'package:heycaby_ui/src/theme/theme_registry.dart';

/// Driver home sheet card chrome (radii, shadows, borders). Defined next to
/// [buildHeyCabyMaterialTheme] so sheet visuals stay aligned with tokens.
abstract final class HeyCabySheetChrome {
  static Color groupedBackground(HeyCabyColorTokens c) => c.surface;

  static Color separatorTone(HeyCabyColorTokens c) => c.border;

  static double cardRadius(
    String themeId, {
    bool elevated = false,
  }) {
    if (themeId.isHeyCabyDriverTheme) {
      return elevated ? 20 : 16;
    }
    return 20;
  }

  static List<BoxShadow> cardShadow(
    HeyCabyColorTokens colors, {
    String themeId = '',
    bool elevated = false,
  }) {
    if (themeId.isHeyCabyDriverTheme) {
      if (elevated) {
        return [
          BoxShadow(
            color: const Color(0x0D000000),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
      }
      return [
        BoxShadow(
          color: const Color(0x08000000),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: const Color(0x0D000000),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];
    }
    return [
      BoxShadow(
        color: colors.text.withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 10),
        spreadRadius: -6,
      ),
      BoxShadow(
        color: colors.text.withValues(alpha: 0.04),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static BoxDecoration cardDecoration(
    HeyCabyColorTokens colors, {
    String themeId = '',
    bool elevated = false,
  }) {
    final r = cardRadius(themeId, elevated: elevated);
    return BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(r),
      boxShadow: cardShadow(colors, themeId: themeId, elevated: elevated),
      border: themeId.isHeyCabyDriverTheme
          ? Border.all(color: colors.border, width: 0.5)
          : null,
    );
  }

  static BoxDecoration iconWell(Color accent, {double opacity = 0.12}) {
    return BoxDecoration(
      color: accent.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(14),
    );
  }

  /// Stronger accent chip for light cards (vs faint [iconWell]) — bold icon color on tinted ground.
  static BoxDecoration accentEmphasisIconWell(Color accent) {
    return BoxDecoration(
      color: accent.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
    );
  }

  /// Saturated accent card (gradient, thick border, shadow) — same recipe as the
  /// driver Community hub “selected channel” cards for high-contrast tiles.
  static BoxDecoration boldAccentCardDecoration(
    HeyCabyColorTokens colors, {
    String themeId = '',
  }) {
    final r = cardRadius(themeId, elevated: true);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.accent, colors.accent.withValues(alpha: 0.8)],
      ),
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: colors.accent, width: 2),
      boxShadow: [
        BoxShadow(
          color: colors.accent.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Icon chip on [boldAccentCardDecoration] — same idea as community “active” cards.
  static BoxDecoration boldAccentIconWell(HeyCabyColorTokens colors) {
    return BoxDecoration(
      color: colors.onAccent.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
    );
  }
}
