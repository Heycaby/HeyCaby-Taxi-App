import 'color_tokens.dart';
import 'theme_data.dart';
import 'typography.dart';

const String kRiderDefaultTheme = 'taxi-1';

/// Soft Warm White — Chacool neutrals, taxi amber, paper-warm surfaces (driver).
const String kHeyCabyDriverWarmThemeId = 'driver-warm';

/// Premium green driver palette (Phase 1 default).
const String kHeyCabyDriverProThemeId = 'driver-pro';

const String kDriverDefaultTheme = kHeyCabyDriverProThemeId;

/// Maps legacy theme ids (secure storage / persisted prefs) → current HeyCaby theme ids.
const Map<String, String> kMigratedThemeIds = {
  'taxi-shade-6': 'daylight',
  'taxi-shade-2': 'daylight',
  'forest-dusk': 'fresh',
  'rose-noir': 'blossom',
  'alpine-cream': 'daylight',
  'warm-gloss': 'daylight',
  'frosty-black-white': 'daylight',
  'frosty-black-yellow': 'daylight',
  'midnight-carbon': 'taxi-2',
  'amber-nights': 'taxi-2',
  'midnight-pro': 'taxi-4',
  'driver-warm': 'driver-pro',
};

String migrateThemeId(String? id) {
  if (id == null || id.isEmpty) return kRiderDefaultTheme;
  return kMigratedThemeIds[id] ?? id;
}

final Map<String, HeyCabyThemeData> kThemes = {
  'daylight': HeyCabyThemeData(
    id: 'daylight',
    name: 'Daylight',
    tagline: 'Signature HeyCaby — clean light & brand amber',
    colors: kHeyCabyDaylight,
    typography: buildTypographyForTheme('daylight'),
  ),
  'fresh': HeyCabyThemeData(
    id: 'fresh',
    name: 'Fresh',
    tagline: 'Botanical light — calm & clarity',
    colors: kHeyCabyFresh,
    typography: buildTypographyForTheme('fresh'),
  ),
  'blossom': HeyCabyThemeData(
    id: 'blossom',
    name: 'Blossom',
    tagline: 'Soft blush — warm & inviting',
    colors: kHeyCabyBlossom,
    typography: buildTypographyForTheme('blossom'),
  ),
  'taxi-1': HeyCabyThemeData(
    id: 'taxi-1',
    name: 'Taxi 1',
    tagline: 'Heritage ivory — lamp gold & editorial calm',
    colors: kHeyCabyTaxi1,
    typography: buildTypographyForTheme('taxi-1'),
  ),
  'taxi-2': HeyCabyThemeData(
    id: 'taxi-2',
    name: 'Taxi 2',
    tagline: 'Night meter — deep navy & classic taxi amber',
    colors: kHeyCabyTaxi2,
    typography: buildTypographyForTheme('taxi-2'),
  ),
  'taxi-3': HeyCabyThemeData(
    id: 'taxi-3',
    name: 'Taxi 3',
    tagline: 'Platinum route — cool steel & corporate navy',
    colors: kHeyCabyTaxi3,
    typography: buildTypographyForTheme('taxi-3'),
  ),
  'taxi-4': HeyCabyThemeData(
    id: 'taxi-4',
    name: 'Taxi 4',
    tagline: 'Executive lane — leather-warm dark & champagne gold',
    colors: kHeyCabyTaxi4,
    typography: buildTypographyForTheme('taxi-4'),
  ),
  kHeyCabyDriverProThemeId: HeyCabyThemeData(
    id: kHeyCabyDriverProThemeId,
    name: 'Driver Pro',
    tagline: 'Premium green — earn with confidence',
    colors: kHeyCabyDriverPro,
    typography: buildTypographyForTheme(kHeyCabyDriverProThemeId),
  ),
  kHeyCabyDriverWarmThemeId: HeyCabyThemeData(
    id: kHeyCabyDriverWarmThemeId,
    name: 'Soft Warm White',
    tagline: 'Paper-warm light — Chacool neutrals & taxi amber',
    colors: kHeyCabyDriverWarm,
    typography: buildTypographyForTheme(kHeyCabyDriverWarmThemeId),
  ),
};

/// Whether [themeId] is a driver app palette (warm legacy or pro green).
extension HeyCabyThemeIdHelpers on String {
  bool get isHeyCabyDriverWarmTheme => this == kHeyCabyDriverWarmThemeId;

  bool get isHeyCabyDriverProTheme => this == kHeyCabyDriverProThemeId;

  bool get isHeyCabyDriverTheme =>
      isHeyCabyDriverWarmTheme || isHeyCabyDriverProTheme;
}

HeyCabyThemeData getTheme(String id) {
  final migrated = migrateThemeId(id);
  return kThemes[migrated] ?? kThemes[kRiderDefaultTheme]!;
}
