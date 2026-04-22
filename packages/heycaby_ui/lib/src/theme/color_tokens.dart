import 'package:flutter/material.dart';

/// HeyCaby design tokens — surfaces, text, and brand accent [#F4A800].
/// All UI color must come from [HeyCabyColorTokens] via [colorsProvider], not literals.
@immutable
class HeyCabyColorTokens {
  final Color bg;
  final Color bgAlt;
  final Color surface;
  final Color card;
  final Color accent;
  final Color accentL;
  final Color border;
  final Color text;
  final Color textMid;
  final Color textSoft;
  final Color success;
  final Color warning;
  final Color error;
  final List<Color> previewDots;

  const HeyCabyColorTokens({
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.card,
    required this.accent,
    required this.accentL,
    required this.border,
    required this.text,
    required this.textMid,
    required this.textSoft,
    required this.success,
    required this.warning,
    required this.error,
    required this.previewDots,
  });

  Color get onAccent =>
      ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? card
          : text;

  Color get onError =>
      ThemeData.estimateBrightnessForColor(error) == Brightness.dark
          ? card
          : text;
}

// --- HeyCaby themes (see docs/Rebranding.MD §3) — Apple-tier neutrals + #F4A800 ---

/// Signature light — grouped surfaces, white cards.
const kHeyCabyDaylight = HeyCabyColorTokens(
  bg: Color(0xFFF5F5F7),
  bgAlt: Color(0xFFE5E5EA),
  surface: Color(0xFFE5E5EA),
  card: Color(0xFFFFFFFF),
  border: Color(0xFFC6C6C8),
  accent: Color(0xFFF4A800),
  accentL: Color(0xFFFFF4DC),
  text: Color(0xFF1D1D1F),
  textMid: Color(0xFF6E6E73),
  textSoft: Color(0xFFAEAEB2),
  success: Color(0xFF248A3D),
  warning: Color(0xFFF4A800),
  error: Color(0xFFD70015),
  previewDots: [Color(0xFFC6C6C8), Color(0xFFF4A800), Color(0xFFC6C6C8)],
);

/// Botanical light — forest teal + quiet neutrals.
const kHeyCabyFresh = HeyCabyColorTokens(
  bg: Color(0xFFF2F4F3),
  bgAlt: Color(0xFFE8EBE9),
  surface: Color(0xFFE8EBE9),
  card: Color(0xFFFFFFFF),
  border: Color(0xFFD1D5D3),
  accent: Color(0xFF1A5C45),
  accentL: Color(0xFFD8EEE5),
  text: Color(0xFF1D1D1F),
  textMid: Color(0xFF4A5560),
  textSoft: Color(0xFF8E9894),
  success: Color(0xFF248A3D),
  warning: Color(0xFFF4A800),
  error: Color(0xFFD70015),
  previewDots: [Color(0xFFD1D5D3), Color(0xFF1A5C45), Color(0xFFD1D5D3)],
);

/// Soft blush — wine rose accent, champagne surfaces.
const kHeyCabyBlossom = HeyCabyColorTokens(
  bg: Color(0xFFF8F6F7),
  bgAlt: Color(0xFFF0EAEC),
  surface: Color(0xFFF0EAEC),
  card: Color(0xFFFFFFFF),
  border: Color(0xFFDDD5D8),
  accent: Color(0xFF8E3A52),
  accentL: Color(0xFFF5E8EC),
  text: Color(0xFF1C1216),
  textMid: Color(0xFF6B5A61),
  textSoft: Color(0xFFA89BA0),
  success: Color(0xFF248A3D),
  warning: Color(0xFFF4A800),
  error: Color(0xFFD70015),
  previewDots: [Color(0xFFDDD5D8), Color(0xFF8E3A52), Color(0xFFDDD5D8)],
);

/// Premium taxi I — warm ivory, antique lamp gold, editorial ink.
const kHeyCabyTaxi1 = HeyCabyColorTokens(
  bg: Color(0xFFF5F3ED),
  bgAlt: Color(0xFFEBE8E0),
  surface: Color(0xFFE8E5DD),
  card: Color(0xFFFFFCF7),
  border: Color(0xFFD4D0C6),
  accent: Color(0xFFC6A035),
  accentL: Color(0xFFF5EDD6),
  text: Color(0xFF141210),
  textMid: Color(0xFF4A4740),
  textSoft: Color(0xFF7A756B),
  success: Color(0xFF248A3D),
  warning: Color(0xFFB45309),
  error: Color(0xFFC41E3A),
  previewDots: [Color(0xFFD4D0C6), Color(0xFFC6A035), Color(0xFFD4D0C6)],
);

/// Premium taxi II — deep navy night, classic meter amber on OLED depth.
const kHeyCabyTaxi2 = HeyCabyColorTokens(
  bg: Color(0xFF0A0E14),
  bgAlt: Color(0xFF101824),
  surface: Color(0xFF121A24),
  card: Color(0xFF182230),
  border: Color(0xFF2A3544),
  accent: Color(0xFFFFC927),
  accentL: Color(0xFF2A2408),
  text: Color(0xFFF0F2F5),
  textMid: Color(0xFF9AA3AE),
  textSoft: Color(0xFF5C6674),
  success: Color(0xFF32D74B),
  warning: Color(0xFFFFC927),
  error: Color(0xFFFF453A),
  previewDots: [Color(0xFF2A3544), Color(0xFFFFC927), Color(0xFF2A3544)],
);

/// Premium taxi III — platinum cool light, corporate navy accent.
const kHeyCabyTaxi3 = HeyCabyColorTokens(
  bg: Color(0xFFF0F2F6),
  bgAlt: Color(0xFFE4E8EF),
  surface: Color(0xFFE4E8EF),
  card: Color(0xFFFFFFFF),
  border: Color(0xFFC8CED8),
  accent: Color(0xFF1B3A5F),
  accentL: Color(0xFFE4EDF7),
  text: Color(0xFF0F1720),
  textMid: Color(0xFF445566),
  textSoft: Color(0xFF7A8798),
  success: Color(0xFF248A3D),
  warning: Color(0xFFF4A800),
  error: Color(0xFFD70015),
  previewDots: [Color(0xFFC8CED8), Color(0xFF1B3A5F), Color(0xFFC8CED8)],
);

/// Premium taxi IV — executive leather dark, champagne gold trim.
const kHeyCabyTaxi4 = HeyCabyColorTokens(
  bg: Color(0xFF0D0C0A),
  bgAlt: Color(0xFF161412),
  surface: Color(0xFF1A1815),
  card: Color(0xFF222018),
  border: Color(0xFF3A3630),
  accent: Color(0xFFE8C547),
  accentL: Color(0xFF2B2618),
  text: Color(0xFFF5F3EE),
  textMid: Color(0xFFA8A29A),
  textSoft: Color(0xFF6B6560),
  success: Color(0xFF32D74B),
  warning: Color(0xFFE8C547),
  error: Color(0xFFFF453A),
  previewDots: [Color(0xFF3A3630), Color(0xFFE8C547), Color(0xFF3A3630)],
);
