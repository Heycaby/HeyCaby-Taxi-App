import 'package:heycaby_ui/src/theme/color_tokens.dart';
import 'package:heycaby_ui/src/theme/theme_data.dart';
import 'package:heycaby_ui/src/theme/typography.dart';

const String kRiderDefaultTheme = 'taxi-3';

const Set<String> kRiderSelectableThemeIds = {
  'fresh',
  'blossom',
  'taxi-1',
  'taxi-3',
};

/// Premium green driver palette. This is the only driver app palette.
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

String resolveRiderThemeId(String? id) {
  final migrated = migrateThemeId(id);
  if (!kRiderSelectableThemeIds.contains(migrated)) return kRiderDefaultTheme;
  if (!kThemes.containsKey(migrated)) return kRiderDefaultTheme;
  return migrated;
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
};

/// Whether [themeId] is the driver app palette.
extension HeyCabyThemeIdHelpers on String {
  bool get isHeyCabyDriverProTheme => this == kHeyCabyDriverProThemeId;

  bool get isHeyCabyDriverTheme => isHeyCabyDriverProTheme;
}

HeyCabyThemeData getTheme(String id) {
  final migrated = migrateThemeId(id);
  return kThemes[migrated] ?? kThemes[kRiderDefaultTheme]!;
}
