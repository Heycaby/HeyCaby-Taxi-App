import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Mapbox style URI for [themeId], using the same `MAPBOX_STYLE_*` compile-time
/// env keys as rider IPA builds (`--dart-define-from-file`).
///
/// Keep rider and driver on this single implementation so both apps resolve styles
/// identically for the same `.env` / IPA pipeline.
String mapboxStyleUriForTheme(String themeId) {
  const env = <String, String>{
    'MAPBOX_STYLE_DAYLIGHT': String.fromEnvironment('MAPBOX_STYLE_DAYLIGHT'),
    'MAPBOX_STYLE_FRESH': String.fromEnvironment('MAPBOX_STYLE_FRESH'),
    'MAPBOX_STYLE_BLOSSOM': String.fromEnvironment('MAPBOX_STYLE_BLOSSOM'),
    'MAPBOX_STYLE_TAXI_SHADE_6': String.fromEnvironment('MAPBOX_STYLE_TAXI_SHADE_6'),
    'MAPBOX_STYLE_TAXI_SHADE_2': String.fromEnvironment('MAPBOX_STYLE_TAXI_SHADE_2'),
    'MAPBOX_STYLE_FOREST_DUSK': String.fromEnvironment('MAPBOX_STYLE_FOREST_DUSK'),
    'MAPBOX_STYLE_ROSE_NOIR': String.fromEnvironment('MAPBOX_STYLE_ROSE_NOIR'),
    'MAPBOX_STYLE_ALPINE_CREAM': String.fromEnvironment('MAPBOX_STYLE_ALPINE_CREAM'),
    'MAPBOX_STYLE_WARM_GLOSS': String.fromEnvironment('MAPBOX_STYLE_WARM_GLOSS'),
    'MAPBOX_STYLE_FROSTY_BLACK_WHITE':
        String.fromEnvironment('MAPBOX_STYLE_FROSTY_BLACK_WHITE'),
    'MAPBOX_STYLE_FROSTY_BLACK_YELLOW':
        String.fromEnvironment('MAPBOX_STYLE_FROSTY_BLACK_YELLOW'),
    'MAPBOX_STYLE_MIDNIGHT_CARBON': String.fromEnvironment('MAPBOX_STYLE_MIDNIGHT_CARBON'),
    'MAPBOX_STYLE_DEFAULT': String.fromEnvironment('MAPBOX_STYLE_DEFAULT'),
    'MAPBOX_STYLE_NAVIGATION_DAY': String.fromEnvironment('MAPBOX_STYLE_NAVIGATION_DAY'),
  };

  String? pick(String? a, String? b) {
    if (a != null && a.isNotEmpty) return a;
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  String? styleFromEnv;
  switch (themeId) {
    case 'daylight':
      styleFromEnv = pick(env['MAPBOX_STYLE_DAYLIGHT'], env['MAPBOX_STYLE_TAXI_SHADE_6']);
      break;
    case 'fresh':
      styleFromEnv = pick(env['MAPBOX_STYLE_FRESH'], env['MAPBOX_STYLE_FOREST_DUSK']);
      break;
    case 'blossom':
      styleFromEnv = pick(env['MAPBOX_STYLE_BLOSSOM'], env['MAPBOX_STYLE_ROSE_NOIR']);
      break;
    case 'taxi-shade-6':
      styleFromEnv = env['MAPBOX_STYLE_TAXI_SHADE_6'];
      break;
    case 'taxi-shade-2':
      styleFromEnv = env['MAPBOX_STYLE_TAXI_SHADE_2'];
      break;
    case 'forest-dusk':
      styleFromEnv = env['MAPBOX_STYLE_FOREST_DUSK'];
      break;
    case 'rose-noir':
      styleFromEnv = env['MAPBOX_STYLE_ROSE_NOIR'];
      break;
    case 'alpine-cream':
      styleFromEnv = env['MAPBOX_STYLE_ALPINE_CREAM'];
      break;
    case 'warm-gloss':
      styleFromEnv = env['MAPBOX_STYLE_WARM_GLOSS'];
      break;
    case 'frosty-black-white':
      styleFromEnv = env['MAPBOX_STYLE_FROSTY_BLACK_WHITE'];
      break;
    case 'frosty-black-yellow':
      styleFromEnv = env['MAPBOX_STYLE_FROSTY_BLACK_YELLOW'];
      break;
    case 'midnight-carbon':
      styleFromEnv = env['MAPBOX_STYLE_MIDNIGHT_CARBON'];
      break;
    case 'driver-warm':
    case 'driver-pro':
      styleFromEnv = pick(
        env['MAPBOX_STYLE_WARM_GLOSS'],
        env['MAPBOX_STYLE_ALPINE_CREAM'],
      );
      break;
    case 'taxi-1':
      styleFromEnv =
          pick(env['MAPBOX_STYLE_DAYLIGHT'], env['MAPBOX_STYLE_TAXI_SHADE_6']);
      break;
    case 'taxi-2':
      styleFromEnv = env['MAPBOX_STYLE_MIDNIGHT_CARBON'];
      break;
    case 'taxi-3':
      styleFromEnv =
          pick(env['MAPBOX_STYLE_DAYLIGHT'], env['MAPBOX_STYLE_ALPINE_CREAM']);
      break;
    case 'taxi-4':
      styleFromEnv = env['MAPBOX_STYLE_MIDNIGHT_CARBON'];
      break;
    default:
      styleFromEnv = env['MAPBOX_STYLE_DEFAULT'];
  }

  if (styleFromEnv != null && styleFromEnv.isNotEmpty) {
    return styleFromEnv;
  }

  const navDay = String.fromEnvironment('MAPBOX_STYLE_NAVIGATION_DAY');
  if (navDay.isNotEmpty) return navDay;

  return MapboxStyles.STANDARD;
}
