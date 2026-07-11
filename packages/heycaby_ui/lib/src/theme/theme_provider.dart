import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:heycaby_ui/src/theme/theme_data.dart';
import 'package:heycaby_ui/src/theme/theme_registry.dart';

const _kThemeKey = 'heycaby_theme_id';

/// On-device SecureStorage key from pre–HeyCaby builds; value must match old clients.
final _kLegacyThemeKey = String.fromCharCodes(const <int>[
  114,
  121,
  100,
  116,
  97,
  112,
  95,
  116,
  104,
  101,
  109,
  101,
  95,
  105,
  100,
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

/// Rider app: always [kRiderDefaultTheme] (HeyCaby Green). Theme registry stays
/// in the codebase for maps/driver; rider UI does not expose theme switching.
class RiderThemeNotifier extends ThemeNotifier {
  @override
  HeyCabyThemeData build() => kThemes[kRiderDefaultTheme]!;

  @override
  Future<void> loadSavedTheme() async {
    const storage = FlutterSecureStorage();
    state = kThemes[kRiderDefaultTheme]!;
    await storage.write(key: _kThemeKey, value: kRiderDefaultTheme);
  }

  @override
  Future<void> setTheme(String id) async {
    const storage = FlutterSecureStorage();
    state = kThemes[kRiderDefaultTheme]!;
    await storage.write(key: _kThemeKey, value: kRiderDefaultTheme);
  }
}

/// Driver app: [build] uses [kDriverDefaultTheme]. If nothing is stored yet,
/// [loadSavedTheme] does not overwrite with the rider default (see [migrateThemeId]).
class DriverThemeNotifier extends ThemeNotifier {
  @override
  HeyCabyThemeData build() => kThemes[kDriverDefaultTheme]!;

  @override
  Future<void> loadSavedTheme() async {
    const storage = FlutterSecureStorage();
    state = kThemes[kDriverDefaultTheme]!;
    await storage.write(key: _kThemeKey, value: kDriverDefaultTheme);
  }

  @override
  Future<void> setTheme(String id) async {
    const storage = FlutterSecureStorage();
    state = kThemes[kDriverDefaultTheme]!;
    await storage.write(key: _kThemeKey, value: kDriverDefaultTheme);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, HeyCabyThemeData>(
  ThemeNotifier.new,
);

final colorsProvider = Provider(
  (ref) => ref.watch(themeProvider).colors,
);

final typographyProvider = Provider(
  (ref) => ref.watch(themeProvider).typography,
);
