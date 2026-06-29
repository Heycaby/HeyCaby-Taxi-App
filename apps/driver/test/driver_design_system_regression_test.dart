import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('driver design system regression', () {
    final appSource = File('lib/app.dart').readAsStringSync();
    final localeSource =
        File('lib/providers/driver_locale_provider.dart').readAsStringSync();
    final preferencesScreenSource =
        File('lib/screens/driver_preferences_screen.dart').readAsStringSync();
    final preferencesBodySource =
        File('lib/widgets/driver_preferences_body.dart').readAsStringSync();
    final shellSource =
        File('lib/widgets/driver_shell.dart').readAsStringSync();
    final splashSource =
        File('lib/widgets/driver_brand_moment_body.dart').readAsStringSync();
    final tellFriendSource =
        File('lib/screens/driver_tell_friend_screen.dart').readAsStringSync();
    final fleetAllowlistSource =
        File('lib/screens/driver_fleet_allowlist_screen.dart')
            .readAsStringSync();
    final fleetAllowlistVehicleSource = File(
      'lib/screens/driver_fleet_allowlist_vehicle_screen.dart',
    ).readAsStringSync();
    final shiftAuditSource = File(
      'lib/screens/driver_shift_handover_audit_screen.dart',
    ).readAsStringSync();
    final shiftCommandFlowSource =
        File('lib/widgets/driver_shift_command_flow_common.dart')
            .readAsStringSync();
    final logoSource =
        File('lib/widgets/heycaby_driver_logo.dart').readAsStringSync();
    final brandAssetsSource =
        File('lib/constants/driver_brand_assets.dart').readAsStringSync();
    final brandMarkSource =
        File('assets/branding/heycaby_mark.svg').readAsStringSync();
    final themeProviderSource = File(
      '../../packages/heycaby_ui/lib/src/theme/theme_provider.dart',
    ).readAsStringSync();
    final themeRegistrySource = File(
      '../../packages/heycaby_ui/lib/src/theme/theme_registry.dart',
    ).readAsStringSync();
    final driverLibSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => MapEntry(file.path, file.readAsStringSync()))
        .toList();

    test('locks driver app to the single green theme', () {
      expect(
        themeProviderSource,
        contains('state = kThemes[kDriverDefaultTheme]!'),
      );
      expect(
        themeProviderSource,
        contains(
            'await storage.write(key: _kThemeKey, value: kDriverDefaultTheme)'),
      );
      expect(preferencesScreenSource, isNot(contains('_showThemePicker')));
      expect(preferencesScreenSource, isNot(contains('kThemes.keys')));
      expect(preferencesBodySource, isNot(contains('onTheme')));
      expect(preferencesBodySource, isNot(contains('themeSubtitle')));
      expect(themeRegistrySource, contains("'driver-warm': 'driver-pro'"));
      expect(themeRegistrySource, isNot(contains('kHeyCabyDriverWarmThemeId')));
      expect(themeRegistrySource, isNot(contains('Soft Warm White')));
      expect(themeRegistrySource, isNot(contains('kHeyCabyDriverWarm,')));
    });

    test('keeps driver text spacing readable across screens', () {
      final offenders = driverLibSources
          .where((entry) => RegExp(r'letterSpacing:\s*-').hasMatch(entry.value))
          .map((entry) => entry.key)
          .toList();

      expect(offenders, isEmpty);
    });

    test('keeps known driver flow headers on shared app bar styling', () {
      for (final source in [
        tellFriendSource,
        fleetAllowlistSource,
        fleetAllowlistVehicleSource,
        shiftAuditSource,
        shiftCommandFlowSource,
      ]) {
        expect(source, contains('DriverAppBar('));
        expect(source, isNot(contains('appBar: AppBar(')));
      }
    });

    test('supports only Dutch, English, Spanish, and Arabic for driver app',
        () {
      expect(localeSource, contains("['nl', 'en', 'es', 'ar']"));
      expect(localeSource, isNot(contains("'de'")));
      expect(localeSource, isNot(contains("'fr'")));
      expect(localeSource, isNot(contains("'tr'")));
      expect(appSource, contains("Locale('nl')"));
      expect(appSource, contains("Locale('en')"));
      expect(appSource, contains("Locale('es')"));
      expect(appSource, contains("Locale('ar')"));
      expect(appSource, isNot(contains("Locale('de')")));
      expect(appSource, isNot(contains("Locale('fr')")));
      expect(appSource, isNot(contains("Locale('tr')")));
    });

    test('keeps splash on the green driver palette', () {
      expect(splashSource, contains('Color(0xFF00A651)'));
      expect(splashSource, isNot(contains('Color(0xFFFFD100)')));
      expect(splashSource, contains('letterSpacing: 0'));
      expect(logoSource, contains('SvgPicture.asset'));
      expect(brandAssetsSource, contains('assets/branding/heycaby_mark.svg'));
      expect(brandAssetsSource, isNot(contains('yellow')));
      expect(brandAssetsSource, isNot(contains('black_yellow')));
      expect(brandMarkSource, contains('#00A651'));
      expect(brandMarkSource, isNot(contains('#F4A800')));
      expect(shellSource, isNot(contains('warmChrome')));
    });
  });
}
