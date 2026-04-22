# HeyCaby Flutter — Color Theme System
## Complete Theme Reference & Flutter Implementation Guide
### Version 1.0 — 8 Themes, Rider + Driver Apps

> **Rule:** Never hardcode a color value in a widget or screen. Every color comes from `ref.watch(colorsProvider)`. Every font comes from `ref.watch(typographyProvider)`. No exceptions.

---

## PART 1 — THE 8 THEMES

### Theme 1 — Taxi Shade 6 (Rider Default)
**ID:** `taxi-shade-6` | **Tagline:** "High contrast — white & strong yellow" | **Font:** Inter

```dart
const _taxiShade6 = HeyCabyColorTokens(
  bg:        Color(0xFFFBFBFA),
  bgAlt:     Color(0xFFF6F6F5),
  surface:   Color(0xFFF8F8F7),
  card:      Color(0xFFFDFDFC),
  border:    Color(0xFFE6E6E4),
  accent:    Color(0xFFE6A800),
  accentL:   Color(0xFFFFF6D6),
  text:      Color(0xFF1A1A1A),
  textMid:   Color(0xFF525252),
  textSoft:  Color(0xFF737373),
  success:   Color(0xFF0D9488),
  warning:   Color(0xFFB45309),
  error:     Color(0xFFDC2626),
  previewDots: [Color(0xFFE6E6E4), Color(0xFFE6A800), Color(0xFFE6E6E4)],
);
```

### Theme 2 — Taxi Shade 2 (Driver Default)
**ID:** `taxi-shade-2` | **Tagline:** "Mid glass — balanced yellow, white & black" | **Font:** Inter

```dart
const _taxiShade2 = HeyCabyColorTokens(
  bg:        Color(0xFFFAF8F4),
  bgAlt:     Color(0xFFFDFBF6),
  surface:   Color(0xFFFBF9F4),
  card:      Color(0xFFFEFDF9),
  border:    Color(0xFFE8E4DC),
  accent:    Color(0xFFFFC700),
  accentL:   Color(0xFFFFF8E0),
  text:      Color(0xFF1A1A1A),
  textMid:   Color(0xFF4A4A4A),
  textSoft:  Color(0xFF737373),
  success:   Color(0xFF10B981),
  warning:   Color(0xFFF59E0B),
  error:     Color(0xFFEF4444),
  previewDots: [Color(0xFFE6E6E4), Color(0xFFFFC700), Color(0xFFE6E6E4)],
);
```

### Theme 3 — Forest Dusk
**ID:** `forest-dusk` | **Tagline:** "Calm reliability — arrive in peace" | **Font:** Cormorant Garamond + Source Sans Pro

```dart
const _forestDusk = HeyCabyColorTokens(
  bg:        Color(0xFFF2F9F4),
  bgAlt:     Color(0xFFEBF5EF),
  surface:   Color(0xFFE8F3EC),
  card:      Color(0xFFF8FCF9),
  border:    Color(0xFFC8E0D0),
  accent:    Color(0xFF1C5C3E),
  accentL:   Color(0xFFD4EDDC),
  text:      Color(0xFF0A1F12),
  textMid:   Color(0xFF2A5038),
  textSoft:  Color(0xFF5C8A6A),
  success:   Color(0xFF10B981),
  warning:   Color(0xFFF59E0B),
  error:     Color(0xFFEF4444),
  previewDots: [Color(0xFFC8E0D0), Color(0xFF1C5C3E), Color(0xFFC8E0D0)],
);
```

### Theme 4 — Rose Noir
**ID:** `rose-noir` | **Tagline:** "Parisian premium — the app that turns heads" | **Font:** Libre Baskerville + Mulish

```dart
const _roseNoir = HeyCabyColorTokens(
  bg:        Color(0xFFFBF6F5),
  bgAlt:     Color(0xFFF7EFEE),
  surface:   Color(0xFFF2E8E7),
  card:      Color(0xFFFCF8F7),
  border:    Color(0xFFE8D8D6),
  accent:    Color(0xFFA8294A),
  accentL:   Color(0xFFFAE4E9),
  text:      Color(0xFF1A0A0D),
  textMid:   Color(0xFF5A2535),
  textSoft:  Color(0xFFA07080),
  success:   Color(0xFF10B981),
  warning:   Color(0xFFF59E0B),
  error:     Color(0xFFEF4444),
  previewDots: [Color(0xFFE8D8D6), Color(0xFFA8294A), Color(0xFFE8D8D6)],
);
```

### Theme 5 — Alpine Cream
**ID:** `alpine-cream` | **Tagline:** "Swiss precision — clarity in every detail" | **Font:** SF Pro (system)

```dart
const _alpineCream = HeyCabyColorTokens(
  bg:        Color(0xFFF9F8F5),
  bgAlt:     Color(0xFFF4F2ED),
  surface:   Color(0xFFF0EDE8),
  card:      Color(0xFFFBF9F6),
  border:    Color(0xFFDED9D2),
  accent:    Color(0xFF2D5A3D),
  accentL:   Color(0xFFEBF2EB),
  text:      Color(0xFF1A1A1A),
  textMid:   Color(0xFF4A4A4A),
  textSoft:  Color(0xFF8A8A8A),
  success:   Color(0xFF2D5A3D),
  warning:   Color(0xFFD97706),
  error:     Color(0xFFDC2626),
  previewDots: [Color(0xFFDED9D2), Color(0xFF2D5A3D), Color(0xFFDED9D2)],
);
```

### Theme 6 — Warm Gloss
**ID:** `warm-gloss` | **Tagline:** "Sunset glow — rich yellow & crisp white" | **Font:** Syne + Inter

```dart
const _warmGloss = HeyCabyColorTokens(
  bg:        Color(0xFFF8EED4),
  bgAlt:     Color(0xFFFBF4E4),
  surface:   Color(0xFFFDF9F0),
  card:      Color(0xFFFEFCF7),
  border:    Color(0xFFEDE2C4),
  accent:    Color(0xFF1A1A1A),
  accentL:   Color(0xFFF5EFE0),
  text:      Color(0xFF1A1A1A),
  textMid:   Color(0xFF3D3520),
  textSoft:  Color(0xFF5C5030),
  success:   Color(0xFF0D9488),
  warning:   Color(0xFFB45309),
  error:     Color(0xFF991B1B),
  previewDots: [Color(0xFFEDE2C4), Color(0xFF1A1A1A), Color(0xFFEDE2C4)],
);
```

### Theme 7 — Frosty Black & White
**ID:** `frosty-black-white` | **Tagline:** "Frosted glass — clean monochrome" | **Font:** Inter

```dart
const _frostyBlackWhite = HeyCabyColorTokens(
  bg:        Color(0xFFF5F5F5),
  bgAlt:     Color(0xFFEFEFEF),
  surface:   Color(0xFFE8E8E8),
  card:      Color(0xFFFAFAFA),
  border:    Color(0xFFD4D4D4),
  accent:    Color(0xFF1A1A1A),
  accentL:   Color(0xFFE5E5E5),
  text:      Color(0xFF0A0A0A),
  textMid:   Color(0xFF404040),
  textSoft:  Color(0xFF737373),
  success:   Color(0xFF22C55E),
  warning:   Color(0xFFEAB308),
  error:     Color(0xFFEF4444),
  previewDots: [Color(0xFFD4D4D4), Color(0xFF1A1A1A), Color(0xFFD4D4D4)],
);
```

### Theme 8 — Frosty Black & Yellow
**ID:** `frosty-black-yellow` | **Tagline:** "Frosted glass — black and warm yellow" | **Font:** Inter

```dart
const _frostyBlackYellow = HeyCabyColorTokens(
  bg:        Color(0xFFFBF8F0),
  bgAlt:     Color(0xFFF7F2E4),
  surface:   Color(0xFFF3EDE0),
  card:      Color(0xFFFDFBF6),
  border:    Color(0xFFE8E0D0),
  accent:    Color(0xFF1A1A1A),
  accentL:   Color(0xFFFFF8E0),
  text:      Color(0xFF0A0A0A),
  textMid:   Color(0xFF3D3520),
  textSoft:  Color(0xFF5C5030),
  success:   Color(0xFF16A34A),
  warning:   Color(0xFFCA8A04),
  error:     Color(0xFFDC2626),
  previewDots: [Color(0xFFE8E0D0), Color(0xFF1A1A1A), Color(0xFFE8E0D0)],
);
```

---

## PART 2 — TOKEN DATA CLASS

```dart
// packages/heycaby_ui/lib/src/theme/color_tokens.dart

import 'package:flutter/material.dart';

@immutable
class HeyCabyColorTokens {
  final Color bg;       // Main screen background
  final Color bgAlt;    // Alt background (sections, list separators)
  final Color surface;  // Modals, sheets, overlays
  final Color card;     // Card component backgrounds
  final Color accent;   // Primary CTA: buttons, highlights
  final Color accentL;  // Light accent: selected state background
  final Color border;   // Inputs, cards, dividers
  final Color text;     // Primary text: headings, body
  final Color textMid;  // Secondary text: labels, captions
  final Color textSoft; // Tertiary text: hints, placeholders
  final Color success;  // Online, completed, confirmed
  final Color warning;  // On-break, caution, alert
  final Color error;    // Offline, error, failure
  final List<Color> previewDots; // [border, accent, border] for theme picker

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
}
```

---

## PART 3 — TYPOGRAPHY SYSTEM

```dart
// packages/heycaby_ui/lib/src/theme/typography.dart
// Add to pubspec: google_fonts: ^6.2.1

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class HeyCabyTypography {
  final TextStyle displayLarge;   // Hero headings
  final TextStyle displayMedium;  // Section headings
  final TextStyle headingLarge;   // Screen titles (22px)
  final TextStyle headingMedium;  // Card titles (18px)
  final TextStyle titleMedium;    // Sheet headings (16px medium)
  final TextStyle bodyLarge;      // Primary body (16px)
  final TextStyle bodyMedium;     // Secondary body (14px)
  final TextStyle bodySmall;      // Captions, badges (12px)
  final TextStyle labelLarge;     // Button text (15px semi-bold)
  final TextStyle labelSmall;     // Chip/tag text (11px)
  final TextStyle mono;           // Prices, ETAs, distances

  const HeyCabyTypography({
    required this.displayLarge,
    required this.displayMedium,
    required this.headingLarge,
    required this.headingMedium,
    required this.titleMedium,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelSmall,
    required this.mono,
  });
}

HeyCabyTypography buildTypographyForTheme(String themeId) {
  switch (themeId) {
    case 'taxi-shade-6':
    case 'taxi-shade-2':
    case 'frosty-black-white':
    case 'frosty-black-yellow':
      return _interTypography();

    case 'forest-dusk':
      return _cormorantSourceSansTypography();

    case 'rose-noir':
      return _baskervilleMulishTypography();

    case 'alpine-cream':
      return _systemFontTypography();

    case 'warm-gloss':
      return _syneInterTypography();

    default:
      return _interTypography();
  }
}

HeyCabyTypography _interTypography() => HeyCabyTypography(
  displayLarge:  GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2),
  displayMedium: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w600, height: 1.25),
  headingLarge:  GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
  headingMedium: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35),
  titleMedium:   GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
  bodyLarge:     GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
  bodyMedium:    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
  bodySmall:     GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
  labelLarge:    GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
  labelSmall:    GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
  mono:          GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
);

HeyCabyTypography _cormorantSourceSansTypography() => HeyCabyTypography(
  displayLarge:  GoogleFonts.cormorantGaramond(fontSize: 34, fontWeight: FontWeight.w700, height: 1.15),
  displayMedium: GoogleFonts.cormorantGaramond(fontSize: 28, fontWeight: FontWeight.w600, height: 1.2),
  headingLarge:  GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w600, height: 1.25),
  headingMedium: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
  titleMedium:   GoogleFonts.sourceSansPro(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
  bodyLarge:     GoogleFonts.sourceSansPro(fontSize: 16, fontWeight: FontWeight.w400, height: 1.65),
  bodyMedium:    GoogleFonts.sourceSansPro(fontSize: 14, fontWeight: FontWeight.w400, height: 1.55),
  bodySmall:     GoogleFonts.sourceSansPro(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
  labelLarge:    GoogleFonts.sourceSansPro(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
  labelSmall:    GoogleFonts.sourceSansPro(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
  mono:          GoogleFonts.sourceSansPro(fontSize: 16, fontWeight: FontWeight.w700),
);

HeyCabyTypography _baskervilleMulishTypography() => HeyCabyTypography(
  displayLarge:  GoogleFonts.libreBaskerville(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15),
  displayMedium: GoogleFonts.libreBaskerville(fontSize: 26, fontWeight: FontWeight.w600, height: 1.2),
  headingLarge:  GoogleFonts.libreBaskerville(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25),
  headingMedium: GoogleFonts.libreBaskerville(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
  titleMedium:   GoogleFonts.mulish(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
  bodyLarge:     GoogleFonts.mulish(fontSize: 16, fontWeight: FontWeight.w400, height: 1.65),
  bodyMedium:    GoogleFonts.mulish(fontSize: 14, fontWeight: FontWeight.w400, height: 1.55),
  bodySmall:     GoogleFonts.mulish(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
  labelLarge:    GoogleFonts.mulish(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2),
  labelSmall:    GoogleFonts.mulish(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
  mono:          GoogleFonts.mulish(fontSize: 16, fontWeight: FontWeight.w700),
);

HeyCabyTypography _systemFontTypography() => HeyCabyTypography(
  displayLarge:  const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.15),
  displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.2),
  headingLarge:  const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25),
  headingMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
  titleMedium:   const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
  bodyLarge:     const TextStyle(fontSize: 17, fontWeight: FontWeight.w400, height: 1.55),
  bodyMedium:    const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
  bodySmall:     const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45),
  labelLarge:    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
  labelSmall:    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
  mono:          const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3),
);

HeyCabyTypography _syneInterTypography() => HeyCabyTypography(
  displayLarge:  GoogleFonts.syne(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1),
  displayMedium: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15),
  headingLarge:  GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
  headingMedium: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
  titleMedium:   GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
  bodyLarge:     GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
  bodyMedium:    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
  bodySmall:     GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
  labelLarge:    GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2),
  labelSmall:    GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
  mono:          GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
);
```

---

## PART 4 — THEME REGISTRY & PROVIDER

```dart
// packages/heycaby_ui/lib/src/theme/theme_registry.dart

const String kRiderDefaultTheme = 'taxi-shade-6';
const String kDriverDefaultTheme = 'taxi-shade-2';

final Map<String, HeyCabyThemeData> kThemes = {
  'taxi-shade-6':       HeyCabyThemeData(id: 'taxi-shade-6',      name: 'Taxi Shade 6',       tagline: 'High contrast — white & strong yellow',          colors: _taxiShade6,       typography: buildTypographyForTheme('taxi-shade-6')),
  'taxi-shade-2':       HeyCabyThemeData(id: 'taxi-shade-2',      name: 'Taxi Shade 2',       tagline: 'Mid glass — balanced yellow, white & black',     colors: _taxiShade2,       typography: buildTypographyForTheme('taxi-shade-2')),
  'forest-dusk':        HeyCabyThemeData(id: 'forest-dusk',       name: 'Forest Dusk',        tagline: 'Calm reliability — arrive in peace',             colors: _forestDusk,       typography: buildTypographyForTheme('forest-dusk')),
  'rose-noir':          HeyCabyThemeData(id: 'rose-noir',         name: 'Rose Noir',          tagline: 'Parisian premium — the app that turns heads',    colors: _roseNoir,         typography: buildTypographyForTheme('rose-noir')),
  'alpine-cream':       HeyCabyThemeData(id: 'alpine-cream',      name: 'Alpine Cream',       tagline: 'Swiss precision — clarity in every detail',     colors: _alpineCream,      typography: buildTypographyForTheme('alpine-cream')),
  'warm-gloss':         HeyCabyThemeData(id: 'warm-gloss',        name: 'Warm Gloss',         tagline: 'Sunset glow — rich yellow & crisp white',        colors: _warmGloss,        typography: buildTypographyForTheme('warm-gloss')),
  'frosty-black-white': HeyCabyThemeData(id: 'frosty-black-white',name: 'Frosty Black & White',tagline: 'Frosted glass — clean monochrome',              colors: _frostyBlackWhite, typography: buildTypographyForTheme('frosty-black-white')),
  'frosty-black-yellow':HeyCabyThemeData(id: 'frosty-black-yellow',name: 'Frosty Black & Yellow',tagline: 'Frosted glass — black and warm yellow',       colors: _frostyBlackYellow,typography: buildTypographyForTheme('frosty-black-yellow')),
};

HeyCabyThemeData getTheme(String id) => kThemes[id] ?? kThemes[kRiderDefaultTheme]!;
```

```dart
// packages/heycaby_ui/lib/src/theme/theme_provider.dart
// (imports: flutter_riverpod, flutter_secure_storage, theme_data.dart, theme_registry.dart for migrateThemeId)

const _kThemeKey = 'heycaby_theme_id';
/// Same codepoints as production — on-device key from pre–HeyCaby builds.
final _kLegacyThemeKey = String.fromCharCodes(const <int>[
  114, 121, 100, 116, 97, 112, 95, 116, 104, 101, 109, 101, 95, 105, 100,
]);

class ThemeNotifier extends Notifier<HeyCabyThemeData> {
  @override
  HeyCabyThemeData build() => kThemes[kRiderDefaultTheme]!;

  Future<void> loadSavedTheme() async {
    const storage = FlutterSecureStorage();
    var id = await storage.read(key: _kThemeKey);
    id ??= await storage.read(key: _kLegacyThemeKey);
    id = migrateThemeId(id);
    if (kThemes.containsKey(id)) {
      state = kThemes[id]!;
      await storage.write(key: _kThemeKey, value: id);
    }
  }

  Future<void> setTheme(String id) async {
    final resolved = migrateThemeId(id);
    if (!kThemes.containsKey(resolved)) return;
    state = kThemes[resolved]!;
    const storage = FlutterSecureStorage();
    await storage.write(key: _kThemeKey, value: resolved);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, HeyCabyThemeData>(ThemeNotifier.new);
final colorsProvider = Provider((ref) => ref.watch(themeProvider).colors);
final typographyProvider = Provider((ref) => ref.watch(themeProvider).typography);
```

---

## PART 5 — CORRECT USAGE PATTERN

```dart
// In any ConsumerWidget
final colors = ref.watch(colorsProvider);
final typo = ref.watch(typographyProvider);

// Screen background
Scaffold(backgroundColor: colors.bg)

// Card
Container(color: colors.card, decoration: BoxDecoration(
  border: Border.all(color: colors.border),
  borderRadius: BorderRadius.circular(12),
))

// Primary button
ElevatedButton.styleFrom(
  backgroundColor: colors.accent,
  textStyle: typo.labelLarge,
)

// Headings
Text('Where to?', style: typo.headingLarge.copyWith(color: colors.text))

// Body copy
Text('3.2 km away', style: typo.bodyMedium.copyWith(color: colors.textMid))

// Hint / placeholder
Text('Enter destination', style: typo.bodyMedium.copyWith(color: colors.textSoft))

// Price / ETA
Text('€14.20', style: typo.mono.copyWith(color: colors.text))

// Driver status dots
Icon(Icons.circle, color: colors.success)  // online
Icon(Icons.circle, color: colors.warning)  // on break
Icon(Icons.circle, color: colors.error)    // offline
```

---

## PART 6 — NEVER DO THIS

```dart
// BANNED — no hardcoded hex
Container(color: const Color(0xFFFBFBFA))
Container(color: Colors.white)
Text('Hello', style: TextStyle(color: Colors.black))
Text('Hello', style: TextStyle(fontFamily: 'Inter'))
ElevatedButton.styleFrom(backgroundColor: Color(0xFFE6A800))
```

---

## PART 7 — SEMANTIC TOKEN GUIDE

| UI Element | Token |
|-----------|-------|
| Every Scaffold background | `colors.bg` |
| Bottom sheet / modal | `colors.surface` |
| Cards, list tiles | `colors.card` |
| Section alt background | `colors.bgAlt` |
| All borders, dividers | `colors.border` |
| Primary CTA button | `colors.accent` |
| Selected card / toggle on | `colors.accentL` |
| All headings | `colors.text` |
| Labels, secondary info | `colors.textMid` |
| Hints, placeholders | `colors.textSoft` |
| Price, ETA, distance | `colors.text` + `typo.mono` |
| Driver online (green dot) | `colors.success` |
| Driver on-break (amber dot) | `colors.warning` |
| Driver offline (red dot) | `colors.error` |
| Ride completed | `colors.success` |
| Validation errors | `colors.error` |
| "Best price" badge | `colors.accentL` background + `colors.accent` text |

---

## PART 8 — PUBSPEC DEPENDENCIES

```yaml
# packages/heycaby_ui/pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  flutter_secure_storage: ^9.0.0
  google_fonts: ^6.2.1
```

---

*HeyCaby Flutter Color Theme System v1.0 — March 2026*
*Rider default: taxi-shade-6 | Driver default: taxi-shade-2*
*No hardcoded colors or fonts anywhere in the codebase.*
