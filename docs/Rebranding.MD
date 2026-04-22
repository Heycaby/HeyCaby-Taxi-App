# HeyCaby — Brand Identity & Rebrand Guide
## Complete developer briefing
### Rebranded: April 2026

---

## 1. Brand overview

**New name:** HeyCaby  
**Domain:** heycaby.nl (register immediately if not done)  
**App Store name:** HeyCaby — Driver  
**Rider PWA title:** HeyCaby  
**Support email:** support@heycaby.nl  
**Terms URL:** heycaby.nl/chauffeur/voorwaarden

**The brand in one sentence:**  
HeyCaby is a Dutch taxi marketplace where verified drivers keep 100% of their fares and riders book in seconds. The name feels like a friend texting you — "Hey, your caby is here."

**Why the name works:**  
- "Hey" = instant, warm, human — works in Dutch and English  
- "caby" = invented word from "cab" — cannot be confused with any competitor  
- Together: unambiguous, memorable, spellable after hearing it once  
- Eliminates confusion with similarly named competitors

---

## 2. Logo system

### The icon mark
The HeyCaby icon is a circle (amber #F4A800) containing a white C-arc with two dots at each end. It represents a taxi route — from point A to point B. It works as:
- App icon
- Favicon
- Notification badge
- Watermark

**SVG source code — copy this exactly:**
```svg
<svg width="56" height="56" viewBox="0 0 56 56" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="28" cy="28" r="28" fill="#F4A800"/>
  <path d="M35 15 A16 16 0 1 0 35 41"
    stroke="white" stroke-width="4.5"
    stroke-linecap="round" fill="none"/>
  <circle cx="35" cy="41" r="4" fill="white"/>
  <circle cx="35" cy="15" r="4" fill="white"/>
</svg>
```

### The wordmark
Two words, two weights, one brand:
- `hey` — Plus Jakarta Sans, weight 300, #FFFFFF (on dark) or rgba(26,18,8,0.6) (on light)
- `caby` — Syne, weight 800, #F4A800 (on dark) or #1A1208 (on light)

The weight contrast between "hey" (thin) and "caby" (heavy) IS the logo. Do not change these weights.

### Logo variations

| Variant | Background | hey color | caby color | Use |
|---|---|---|---|---|
| Primary dark | #0B0804 | rgba(255,255,255,0.85) | #F4A800 | App default, splash screen |
| Primary light | #FFF8EC | rgba(26,18,8,0.6) | #1A1208 | Web, light contexts |
| Amber | #F4A800 | rgba(0,0,0,0.6) | #0B0804 | Social media, marketing |
| Icon only | Any | — | — | App icon, favicon |
| One-color white | Dark bg | #FFFFFF | #FFFFFF | Monochrome use |
| One-color black | Light bg | #000000 | #000000 | Print |

### Clear space rule
Always maintain a minimum clear space of 1× the icon height around the full lockup.

### What NOT to do
- Do not stretch or compress the wordmark
- Do not change the font weights
- Do not use "HeyCaby" as two words in the logo (wordmark is always one word)
- Do not put the icon on the right side of the wordmark
- Do not use any color for "caby" other than #F4A800 on dark backgrounds

---

## 3. Color system — all 5 themes

The brand color **#F4A800** (amber) remains the signature accent everywhere it is specified below. Surfaces, borders, and text are tuned for an **Apple-tier** feel: layered neutrals, hairline separation, almost-black typography on light UI, and true depth on dark UI — not heavy color washes.

**Premium principles (think iPhone / Apple.com):**
- **Surfaces** stack like `systemBackground` → `secondarySystemBackground` → `tertiarySystemBackground` (subtle steps, not big hue shifts).
- **Borders** are cool gray separators (#C6C6C8 / #38383A class), not thick saturated strokes.
- **Text** uses near-neutral hierarchy (#F5F5F7 / #1D1D1F class) so amber reads as *intentional*, not “everything is orange-tinted.”
- **Chroma lives in the accent** and status colors; backgrounds stay disciplined.

---

### Theme 1: Amber Nights
**Type:** Warm-leaning premium dark (not muddy)  
**Mood:** OLED-adjacent depth with a whisper of warmth — night drive, luxury interior  
**Use:** Default dark mode, evening UX

```dart
// Flutter ThemeData
// lib/themes/amber_nights.dart

const amberNights = {
  // Backgrounds — near-black base, stepped lifts (Apple dark stack + warm bias)
  'bg_primary':   Color(0xFF0A0A09),
  'bg_secondary': Color(0xFF141312),
  'bg_card':      Color(0xFF1C1B1A),
  'bg_elevated':  Color(0xFF252422),

  // Border — separator, not a brown frame
  'border':       Color(0xFF3A3836),

  // Brand accent
  'accent':       Color(0xFFF4A800),
  'accent_alt':   Color(0xFFFFB020),  // refined highlight (less neon than pure iOS orange)

  // Text — neutral off-white hierarchy (readable, expensive)
  'text_primary':   Color(0xFFF5F5F7),
  'text_secondary': Color(0xFFAEAEB2),
  'text_tertiary':  Color(0xFF636366),
  'text_disabled':  Color(0xFF48484A),

  // Status — saturated but clean
  'status_success': Color(0xFF32D74B),
  'status_error':   Color(0xFFFF453A),
  'status_warning': Color(0xFFF4A800),
  'status_info':    Color(0xFF64D2FF),

  // Controls
  'button_primary_bg':   Color(0xFFF4A800),
  'button_primary_text': Color(0xFF0B0804),
  'button_secondary_bg': Color(0xFF2C2C2E),
  'button_secondary_text': Color(0xFFF5F5F7),
};
```

---

### Theme 2: Midnight Pro
**Type:** Cool premium dark (Pro hardware energy)  
**Mood:** Precision, depth, zero visual noise — “pro” without sci-fi neon  
**Use:** Alternative dark mode

```dart
// lib/themes/midnight_pro.dart

const midnightPro = {
  'bg_primary':   Color(0xFF000000),
  'bg_secondary': Color(0xFF0D0D0F),
  'bg_card':      Color(0xFF1C1C1E),
  'bg_elevated':  Color(0xFF2C2C2E),
  'border':       Color(0xFF38383A),

  'accent':       Color(0xFFF4A800),
  'accent_blue':  Color(0xFF0A84FF),  // iOS-system blue class, for links / info only

  'text_primary':   Color(0xFFF5F5F7),
  'text_secondary': Color(0xFF98989D),
  'text_tertiary':  Color(0xFF636366),
  'text_disabled':  Color(0xFF48484A),

  'status_success': Color(0xFF32D74B),
  'status_error':   Color(0xFFFF453A),
  'status_warning': Color(0xFFF4A800),
  'status_info':    Color(0xFF0A84FF),

  'button_primary_bg':   Color(0xFFF4A800),
  'button_primary_text': Color(0xFF0B0804),
  'button_secondary_bg': Color(0xFF1C1C1E),
  'button_secondary_text': Color(0xFFF5F5F7),
};
```

---

### Theme 3: Daylight ⭐ (Signature brand theme)
**Type:** Main light — Apple grouped-surface light UI  
**Mood:** Gallery-white cards on soft gray fields; amber is the hero  
**Use:** Default light mode — this is THE HeyCaby theme  
**Note:** Marketing and screenshots: prioritize **white cards** on **#F5F5F7**, not flat all-cream.

```dart
// lib/themes/daylight.dart

const daylight = {
  'bg_primary':   Color(0xFFF5F5F7),
  'bg_secondary': Color(0xFFE5E5EA),
  'bg_card':      Color(0xFFFFFFFF),
  'bg_elevated':  Color(0xFFFFFFFF),
  'border':       Color(0xFFC6C6C8),

  'accent':       Color(0xFFF4A800),
  'accent_dark':  Color(0xFF1D1D1F),

  'text_primary':   Color(0xFF1D1D1F),
  'text_secondary': Color(0xFF6E6E73),
  'text_tertiary':  Color(0xFFAEAEB2),
  'text_disabled':  Color(0xFFC7C7CC),

  'status_success': Color(0xFF248A3D),
  'status_error':   Color(0xFFD70015),
  'status_warning': Color(0xFFF4A800),
  'status_info':    Color(0xFF007AFF),

  'button_primary_bg':   Color(0xFFF4A800),
  'button_primary_text': Color(0xFF0B0804),
  'button_secondary_bg': Color(0xFFE5E5EA),
  'button_secondary_text': Color(0xFF1D1D1F),
};
```

---

### Theme 4: Fresh
**Type:** Botanical light — luxury wellness, not candy mint  
**Mood:** Restrained sage on cool neutrals; teal is *surgical*, backgrounds stay quiet  
**Use:** Alternative light mode — daytime outdoor use  
**Note:** Amber remains the family tie as secondary accent.

```dart
// lib/themes/fresh.dart

const fresh = {
  'bg_primary':   Color(0xFFF2F4F3),
  'bg_secondary': Color(0xFFE8EBE9),
  'bg_card':      Color(0xFFFFFFFF),
  'bg_elevated':  Color(0xFFFFFFFF),
  'border':       Color(0xFFD1D5D3),

  'accent':       Color(0xFF1A5C45),  // deep forest teal (more expensive than bright mint)
  'accent_amber': Color(0xFFF4A800),

  'text_primary':   Color(0xFF1D1D1F),
  'text_secondary': Color(0xFF4A5560),
  'text_tertiary':  Color(0xFF8E9894),
  'text_disabled':  Color(0xFFC7C7CC),

  'status_success': Color(0xFF248A3D),
  'status_error':   Color(0xFFD70015),
  'status_warning': Color(0xFFF4A800),
  'status_info':    Color(0xFF007AFF),

  'button_primary_bg':   Color(0xFF1A5C45),
  'button_primary_text': Color(0xFFFFFFFF),
  'button_secondary_bg': Color(0xFFE8EBE9),
  'button_secondary_text': Color(0xFF1D1D1F),
};
```

---

### Theme 5: Blossom
**Type:** Soft light — haute blush, not bubblegum  
**Mood:** Dusty rose + champagne white; editorial / beauty-brand restraint  
**Use:** Optional theme — rider PWA, preference  
**Note:** Berry accent is **desaturated**; amber secondary keeps HeyCaby DNA.

```dart
// lib/themes/blossom.dart

const blossom = {
  'bg_primary':   Color(0xFFF8F6F7),
  'bg_secondary': Color(0xFFF0EAEC),
  'bg_card':      Color(0xFFFFFFFF),
  'bg_elevated':  Color(0xFFFFFFFF),
  'border':       Color(0xFFDDD5D8),

  'accent':       Color(0xFF8E3A52),  // wine rose (luxury, not hot pink)
  'accent_amber': Color(0xFFF4A800),

  'text_primary':   Color(0xFF1C1216),
  'text_secondary': Color(0xFF6B5A61),
  'text_tertiary':  Color(0xFFA89BA0),
  'text_disabled':  Color(0xFFC7C7CC),

  'status_success': Color(0xFF248A3D),
  'status_error':   Color(0xFFD70015),
  'status_warning': Color(0xFFF4A800),
  'status_info':    Color(0xFF5E5CE6),

  'button_primary_bg':   Color(0xFF8E3A52),
  'button_primary_text': Color(0xFFFFFFFF),
  'button_secondary_bg': Color(0xFFF0EAEC),
  'button_secondary_text': Color(0xFF1C1216),
};
```

---

## 4. Typography

### Font stack
```dart
// pubspec.yaml — add these Google Fonts
dependencies:
  google_fonts: ^6.1.0

// Usage in theme
import 'package:google_fonts/google_fonts.dart';

ThemeData(
  textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
    displayLarge: GoogleFonts.syne(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.02,
    ),
    displayMedium: GoogleFonts.syne(
      fontWeight: FontWeight.w700,
    ),
    // All other text uses Plus Jakarta Sans (body font)
  ),
)
```

### Type scale

| Role | Font | Weight | Size | Use |
|---|---|---|---|---|
| Brand display | Syne | 800 | 36–48px | Splash, hero screens |
| Screen title | Syne | 700 | 22–28px | Tab headers, screen names |
| Card title | Syne | 700 | 18px | Card headings |
| Body | Plus Jakarta Sans | 400 | 15–16px | All body copy |
| Body emphasis | Plus Jakarta Sans | 600 | 15px | Highlighted body text |
| UI label | Plus Jakarta Sans | 600 | 13–14px | Buttons, form labels |
| Caption | Plus Jakarta Sans | 300 | 11–12px | Subtitles, hints |
| Mono data | Plus Jakarta Sans | 500 | 13px | Fares, distances, ETAs |

### Typefaces for web (Next.js / rider PWA)
```css
/* In globals.css */
@import url('https://fonts.googleapis.com/css2?family=Syne:wght@700;800&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap');

:root {
  --font-display: 'Syne', sans-serif;
  --font-body: 'Plus Jakarta Sans', sans-serif;
}
```

---

## 5. Complete rebrand checklist — every file to change

### Flutter driver app

**App metadata**
- [x] `pubspec.yaml` — `name: heycaby_driver` *(done)*
- [x] `pubspec.yaml` — change `description:` to HeyCaby Driver *(done — see `apps/driver/pubspec.yaml`)*
- [x] `android/app/src/main/AndroidManifest.xml` — `android:label="HeyCaby Driver"` *(done)*
- [x] `ios/Runner/Info.plist` — display name **HeyCaby Driver** *(verify on next release)*
- [x] `ios/Runner/Info.plist` — bundle display name aligned *(verify)*
- [ ] `ios/Runner.xcodeproj/project.pbxproj` — review `PRODUCT_NAME` vs marketing

**Bundle identifier (important — changing this means a new App Store listing)**
- [x] iOS bundle ID: `nl.heycaby.driver` *(updated in project — confirm App Store Connect)*
- [x] Android: `com.heycaby.driver` *(Gradle — Play Console must match)*
- Note: Contact Apple if you need to update the bundle ID of an existing submission

**Brand assets to replace**
- [ ] `assets/images/logo.png` — replace with new HeyCaby logo
- [ ] `assets/images/logo_dark.png`
- [ ] `assets/images/logo_light.png`
- [ ] `assets/images/icon.png` — the amber circle with C-arc
- [ ] `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — all app icon sizes
- [ ] `android/app/src/main/res/` — all mipmap directories

**Theme files**
- [x] Shared themes live in `heycaby_ui` / design tokens
- [ ] Create `lib/themes/amber_nights.dart`
- [ ] Create `lib/themes/midnight_pro.dart`
- [ ] Create `lib/themes/daylight.dart`
- [ ] Create `lib/themes/fresh.dart`
- [ ] Create `lib/themes/blossom.dart`
- [ ] Create `lib/themes/heycaby_theme.dart` — main ThemeData builder
- [ ] Update `lib/main.dart` — replace theme references

**Copy / text changes (search and replace in entire codebase)**

| Find | Replace |
|---|---|
| Legacy Android label | `HeyCaby Driver` |
| Legacy in-app strings | `HeyCaby` |
| Legacy domain | `heycaby.nl` (301 from old hosts) |
| Support | `support@heycaby.nl` |
| `heycaby.nl/chauffeur/voorwaarden` | (already correct) |
| Deep link scheme | `heycaby://` |

**Specific screens to review**
- [ ] `login_screen.dart` — update brand header, tagline
- [ ] `splash_screen.dart` — new logo animation
- [ ] `driver_profile_screen.dart` — HeyCaby branding
- [ ] `onboarding_screen.dart` — audit for any leftover non–HeyCaby copy
- [ ] Any hardcoded strings not matching HeyCaby voice

---

### Rider PWA (Next.js at heycaby.nl)

**Metadata**
- [ ] `apps/rider/package.json` — name to `heycaby-rider`
- [ ] `apps/rider/public/manifest.json` — update name, short_name, theme_color
- [ ] `apps/rider/src/app/layout.tsx` — update `<title>`, `<meta name="description">`
- [ ] `apps/rider/public/favicon.ico` — replace with HeyCaby amber icon
- [ ] `apps/rider/public/icon-192.png` — replace
- [ ] `apps/rider/public/icon-512.png` — replace

**PWA manifest template:**
```json
{
  "name": "HeyCaby",
  "short_name": "HeyCaby",
  "description": "Book a caby in seconds. Dutch drivers, zero commission.",
  "theme_color": "#F4A800",
  "background_color": "#0B0804",
  "display": "standalone",
  "start_url": "/",
  "icons": [
    { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

**CSS variables to update:**
```css
/* globals.css */
:root {
  --brand-primary:    #F4A800;
  --brand-dark:       #C88000;
  --brand-bg:         #0B0804;
  --font-display:     'Syne', sans-serif;
  --font-body:        'Plus Jakarta Sans', sans-serif;
}
```

---

### Supabase / backend

**app_config table — update these values:**
```sql
UPDATE public.app_config SET value = 'HeyCaby' WHERE key = 'app_name';
UPDATE public.app_config SET value = 'heycaby.nl' WHERE key = 'app_url';
UPDATE public.app_config SET value = 'support@heycaby.nl' WHERE key = 'support_email';
-- Apple review account email can stay the same or update:
UPDATE public.app_config SET value = 'review@heycaby.nl' WHERE key = 'apple_review_email';
```

**Edge Functions — update the VAPID subject and any hardcoded URLs:**
- `send-push` — update `VAPID_SUBJECT` secret to `mailto:info@heycaby.nl`
- `driver-support-chat` (Lee) — system prompt must reference **HeyCaby** only
- `rider-support-chat` (Neo) — same when built
- `apple-review-auth` — update `redirectTo` URL to `heycaby://driver/auth/callback`

**Lee's system prompt update — find and replace:**
```
Use **HeyCaby**, **heycaby.nl**, and **support@heycaby.nl** everywhere in prompts and copy.
```

**Paperclip agents — update all system prompts:**
- CEO agent: "I am the CEO of HeyCaby..."
- Lee: "You are Lee, the HeyCaby driver support assistant..."
- Neo: "You are Neo, the HeyCaby passenger support assistant..."
- Growth: "You promote HeyCaby..."
- Tech Monitor: "You monitor HeyCaby's infrastructure..."

---

### Domain and infrastructure

- [ ] Register `heycaby.nl` immediately
- [ ] Register `heycaby.com` if available
- [ ] Set up SEO redirects from any legacy domains → `heycaby.nl` (301 permanent)
- [ ] Update all DNS records
- [ ] Update Railway environment variables:
  - `PAPERCLIP_PUBLIC_URL` → update if Paperclip uses a heycaby domain
  - `APP_URL` → `https://heycaby.nl`
- [ ] Update Supabase auth allowed redirect URLs to include `heycaby.nl`

---

## 6. Flutter theme implementation

Create this file as your main theme entry point:

```dart
// lib/themes/heycaby_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum HeyCabyTheme {
  amberNights,   // warm dark
  midnightPro,   // cool dark
  daylight,      // main light (default)
  fresh,         // mint light
  blossom,       // feminine light
}

class HeyCabyThemeData {
  static ThemeData build(HeyCabyTheme theme) {
    final colors = _colorMap[theme]!;

    return ThemeData(
      useMaterial3: true,
      brightness: _isDark(theme) ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors['bg_primary'],
      colorScheme: ColorScheme(
        brightness: _isDark(theme) ? Brightness.dark : Brightness.light,
        primary:    colors['accent']!,
        onPrimary:  colors['button_primary_text']!,
        secondary:  colors['accent_alt'] ?? colors['accent']!,
        onSecondary: colors['button_primary_text']!,
        surface:    colors['bg_card']!,
        onSurface:  colors['text_primary']!,
        error:      colors['status_error']!,
        onError:    Colors.white,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.syne(
          fontWeight: FontWeight.w800,
          color: colors['text_primary'],
          letterSpacing: -0.02,
        ),
        displayMedium: GoogleFonts.syne(
          fontWeight: FontWeight.w700,
          color: colors['text_primary'],
        ),
        headlineMedium: GoogleFonts.syne(
          fontWeight: FontWeight.w700,
          color: colors['text_primary'],
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w400,
          color: colors['text_primary'],
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w400,
          color: colors['text_secondary'],
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          color: colors['text_primary'],
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors['accent'],
          foregroundColor: colors['button_primary_text'],
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      cardTheme: CardTheme(
        color: colors['bg_card'],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors['border']!, width: 0.5),
        ),
        elevation: 0,
      ),
      dividerColor: colors['border'],
      appBarTheme: AppBarTheme(
        backgroundColor: colors['bg_primary'],
        foregroundColor: colors['text_primary'],
        elevation: 0,
        titleTextStyle: GoogleFonts.syne(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: colors['text_primary'],
        ),
      ),
    );
  }

  static bool _isDark(HeyCabyTheme t) =>
    t == HeyCabyTheme.amberNights || t == HeyCabyTheme.midnightPro;

  // Import individual theme maps here — values match §3 (Apple-tier refinement)
  static final Map<HeyCabyTheme, Map<String, Color>> _colorMap = {
    HeyCabyTheme.amberNights: {
      'bg_primary': const Color(0xFF0A0A09),
      'bg_secondary': const Color(0xFF141312),
      'bg_card': const Color(0xFF1C1B1A),
      'border': const Color(0xFF3A3836),
      'accent': const Color(0xFFF4A800),
      'accent_alt': const Color(0xFFFFB020),
      'text_primary': const Color(0xFFF5F5F7),
      'text_secondary': const Color(0xFFAEAEB2),
      'text_tertiary': const Color(0xFF636366),
      'button_primary_text': const Color(0xFF0B0804),
      'status_success': const Color(0xFF32D74B),
      'status_error': const Color(0xFFFF453A),
    },
    HeyCabyTheme.midnightPro: {
      'bg_primary': const Color(0xFF000000),
      'bg_secondary': const Color(0xFF0D0D0F),
      'bg_card': const Color(0xFF1C1C1E),
      'border': const Color(0xFF38383A),
      'accent': const Color(0xFFF4A800),
      'accent_alt': const Color(0xFF0A84FF),
      'text_primary': const Color(0xFFF5F5F7),
      'text_secondary': const Color(0xFF98989D),
      'text_tertiary': const Color(0xFF636366),
      'button_primary_text': const Color(0xFF0B0804),
      'status_success': const Color(0xFF32D74B),
      'status_error': const Color(0xFFFF453A),
    },
    HeyCabyTheme.daylight: {
      'bg_primary': const Color(0xFFF5F5F7),
      'bg_secondary': const Color(0xFFE5E5EA),
      'bg_card': const Color(0xFFFFFFFF),
      'border': const Color(0xFFC6C6C8),
      'accent': const Color(0xFFF4A800),
      'accent_alt': const Color(0xFF1D1D1F),
      'text_primary': const Color(0xFF1D1D1F),
      'text_secondary': const Color(0xFF6E6E73),
      'text_tertiary': const Color(0xFFAEAEB2),
      'button_primary_text': const Color(0xFF0B0804),
      'status_success': const Color(0xFF248A3D),
      'status_error': const Color(0xFFD70015),
    },
    HeyCabyTheme.fresh: {
      'bg_primary': const Color(0xFFF2F4F3),
      'bg_secondary': const Color(0xFFE8EBE9),
      'bg_card': const Color(0xFFFFFFFF),
      'border': const Color(0xFFD1D5D3),
      'accent': const Color(0xFF1A5C45),
      'accent_alt': const Color(0xFFF4A800),
      'text_primary': const Color(0xFF1D1D1F),
      'text_secondary': const Color(0xFF4A5560),
      'text_tertiary': const Color(0xFF8E9894),
      'button_primary_text': const Color(0xFFFFFFFF),
      'status_success': const Color(0xFF248A3D),
      'status_error': const Color(0xFFD70015),
    },
    HeyCabyTheme.blossom: {
      'bg_primary': const Color(0xFFF8F6F7),
      'bg_secondary': const Color(0xFFF0EAEC),
      'bg_card': const Color(0xFFFFFFFF),
      'border': const Color(0xFFDDD5D8),
      'accent': const Color(0xFF8E3A52),
      'accent_alt': const Color(0xFFF4A800),
      'text_primary': const Color(0xFF1C1216),
      'text_secondary': const Color(0xFF6B5A61),
      'text_tertiary': const Color(0xFFA89BA0),
      'button_primary_text': const Color(0xFFFFFFFF),
      'status_success': const Color(0xFF248A3D),
      'status_error': const Color(0xFFD70015),
    },
  };
}
```

---

## 7. Brand voice and copy guidelines

### The HeyCaby tone
- **Direct:** "Your caby is here" not "Your vehicle has arrived"
- **Warm:** Start with "Hey" whenever contextually appropriate
- **Dutch-first:** All in-app copy is Dutch by default, English on request
- **Driver-respectful:** Drivers are professionals, not "delivery agents"
- **No corporate language:** No "leverage", "utilise", "vehicle", "transportation service"

### Sample copy replacements

| Before | After (HeyCaby) |
|---|---|
| Legacy driver app title | "HeyCaby Driver" |
| "Uw rit is bevestigd" | "Hey, je caby is onderweg!" |
| "Ontvangst bevestiging" | "Je caby is er!" |
| "Uw ritbeoordeling" | "Hoe was je rit?" |
| "Geen chauffeurs beschikbaar" | "Nog geen caby's in jouw buurt" |
| "Ga online" | "Start je dienst" |
| "Rit voltooid" | "Mooi gedaan — €X verdiend" |

### Lee's updated identity (driver support)
Lee is the HeyCaby driver support assistant. Update the system prompt:
> "You are Lee, the HeyCaby driver support assistant. You help verified Dutch taxi drivers (ZZP chauffeurs) with HeyCaby — the Dutch taxi platform where drivers keep 100% of their fares."

### Neo's updated identity (rider support)
> "You are Neo, the HeyCaby passenger support assistant. HeyCaby connects riders with verified Dutch taxi drivers in the Netherlands. Drivers are independent professionals who keep 100% of their fares."

---

## 8. Brand amber — the one rule

**#F4A800 is the HeyCaby signature.**

This exact amber appears as the primary accent in every single theme (and as the secondary accent in Fresh and Blossom). It is the visual thread across the family. **Backgrounds and borders** are deliberately low-chroma — Apple-style layered neutrals — so the amber reads deliberate and expensive, not “the whole UI is tinted orange.”

Never substitute another yellow or orange for #F4A800 in the app UI. Tints and shades are allowed for states (hover, disabled) but the base value is always #F4A800.

---

## 9. Quick reference

| Asset | Value |
|---|---|
| Brand amber | #F4A800 |
| Deep dark bg | #0B0804 |
| Display font | Syne (Google Fonts) |
| Body font | Plus Jakarta Sans (Google Fonts) |
| App names | HeyCaby (rider) / HeyCaby Driver |
| Bundle ID (iOS rider) | nl.heycaby.rider |
| Bundle ID (iOS driver) | nl.heycaby.driver |
| App Store SKU (rider) | `HEYCABY_RIDER_IOS` |
| App Store SKU (driver) | `HEYCABY_DRIVER_ios` *(set at app creation; cannot be changed in ASC — internal only, not shown on the store)* |
| App Store Connect app ID (rider) | 6761512910 |
| App Store Connect app ID (driver) | 6761512563 |
| Package (Android rider) | com.heycaby.rider |
| Package (Android driver) | com.heycaby.driver |
| Domain | heycaby.nl |
| Support | support@heycaby.nl |
| Deep link scheme | heycaby:// |
| Supabase project | fvrprxguoternoxnyhoj (unchanged) |
| Theme 1 | Amber Nights (warm dark) |
| Theme 2 | Midnight Pro (cool dark) |
| Theme 3 | Daylight (main light ⭐) |
| Theme 4 | Fresh (mint light) |
| Theme 5 | Blossom (feminine light) |

**App Store — Content Rights:** In App Store Connect, answer the content-rights questions accurately (you own the app / have rights to all content in it). Third-party SDKs and fonts are covered by their licenses; keep Mapbox, font, and other attribution notes in **App Privacy** and legal links as required.

---

*HeyCaby brand guide v1.0 — April 2026. Keep this document updated as the brand evolves.*