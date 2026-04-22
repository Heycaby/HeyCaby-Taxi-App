---
name: rider-theme-language
description: Instructs the agent how to manage Rider themes, glassmorphism, and localization, including using design tokens, theme switching, and device-plus-user locale handling.
---

# Rider Theme and Language Skill

## When to use this skill

Use this skill whenever you:
- Change colors, typography, or visual styling in the Rider app.
- Implement or adjust theme selection and persistence.
- Work on localization, supported locales, or device-language behavior.

## Theme system

- Theme data is defined in `packages/heycaby_ui`:
  - Color tokens: `HeyCabyColorTokens` and theme registry.
  - Typography: `HeyCabyTypography`, built from Google Fonts per theme ID.
  - Registry: `kThemes` and default theme IDs for Rider and Driver.
- Providers:
  - `themeProvider` → `HeyCabyThemeData`.
  - `colorsProvider` → `HeyCabyColorTokens`.
  - `typographyProvider` → `HeyCabyTypography`.
  - `ThemeNotifier` loads/saves the active theme using secure storage.

### Theme usage rules

- In Rider screens:
  - Obtain colors via `ref.watch(colorsProvider)` or equivalent.
  - Obtain text styles via `ref.watch(typographyProvider)`.
  - Do not hard-code colors or fonts.
- When a new visual token is needed:
  - Add it to `HeyCabyColorTokens` and to each registered theme in `heycaby_ui`.
  - Use that token from the screen instead of raw ARGB values.

### Theme switching

- Theme switching must go through `ThemeNotifier`:
  - Present a list of available theme IDs from the registry.
  - Call `setTheme(id)` when the user selects a theme.
  - Persist the theme choice and ensure the Rider app reads it at startup.

## Glassmorphism (“liquid glass”)

- Implement shared glass widgets in `heycaby_ui`, for example:
  - `GlassPanel` for cards.
  - `GlassBottomSheet` for booking sheets.
- These widgets should:
  - Use `BackdropFilter` with `ImageFilter.blur`.
  - Use semi-transparent colors derived from theme tokens.
  - Be the only place where blur parameters and radii are configured.
- Rider booking screens should wrap their major bottom sheets and overlays using these glass widgets instead of duplicating blur logic.

## Localization and language handling

- Localization uses generated `AppLocalizations` in `apps/rider/lib/l10n/`.
- `HeyCabyRiderApp` should:
  - Register `AppLocalizations.delegate` and Flutter global localization delegates.
  - Use `AppLocalizations.supportedLocales` for `supportedLocales`.
  - Bind `locale` to a provider that combines device locale with any user override from settings.
- Settings:
  - Store a language code in settings when the user explicitly picks a language.
  - When present, this language code should override the device locale.
  - When absent, fall back to device locale and default language (for example, English).

### Localization rules

- All UI strings must come from `AppLocalizations` and not from inline literals.
- When adding a new key, add entries for every supported language.
- Use directional layout constructs (for example, `EdgeInsetsDirectional`) to support RTL languages such as Arabic.

