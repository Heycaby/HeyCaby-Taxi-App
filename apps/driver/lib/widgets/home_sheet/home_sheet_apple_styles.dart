import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Visual tokens for the driver home bottom sheet (Apple-inspired, no logic).
/// All values derive from [HeyCabyColorTokens] — no hardcoded palette colors.
abstract final class HomeSheetAppleStyles {
  /// Grouped list background (maps to theme surface).
  static Color groupedBackground(HeyCabyColorTokens c) => c.surface;

  /// Hairline separator / grab handle tone.
  static Color separatorTone(HeyCabyColorTokens c) => c.border;

  static List<BoxShadow> cardShadow(HeyCabyColorTokens colors) => [
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

  static BoxDecoration cardDecoration(HeyCabyColorTokens colors) {
    return BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(20),
      boxShadow: cardShadow(colors),
    );
  }

  static BoxDecoration iconWell(Color accent, {double opacity = 0.12}) {
    return BoxDecoration(
      color: accent.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(14),
    );
  }
}
