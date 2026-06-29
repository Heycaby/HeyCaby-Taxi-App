import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';

void main() {
  tearDown(() => DriverStrings.useLocale(const Locale('nl')));

  test('DriverStrings defaults to Dutch for unsupported or missing locales',
      () {
    DriverStrings.useLocale(null);
    expect(DriverStrings.home, 'Start');
    expect(DriverStrings.goOnline, 'Ga online');

    DriverStrings.useLocale(const Locale('fr'));
    expect(DriverStrings.home, 'Start');
    expect(DriverStrings.goOnline, 'Ga online');
  });

  test('DriverStrings switches core driver labels by supported locale', () {
    DriverStrings.useLocale(const Locale('en'));
    expect(DriverStrings.home, 'Home');
    expect(DriverStrings.goOnline, 'Go online');
    expect(DriverStrings.myRides, 'My rides');
    expect(DriverStrings.loginFormTitle, 'Welcome back');

    DriverStrings.useLocale(const Locale('es'));
    expect(DriverStrings.home, 'Inicio');
    expect(DriverStrings.goOnline, 'Conectarse');
    expect(DriverStrings.myRides, 'Mis viajes');
    expect(DriverStrings.loginFormTitle, 'Bienvenido de nuevo');

    DriverStrings.useLocale(const Locale('ar'));
    expect(DriverStrings.home, 'الرئيسية');
    expect(DriverStrings.goOnline, 'الاتصال');
    expect(DriverStrings.myRides, 'رحلاتي');
    expect(DriverStrings.loginFormTitle, 'مرحبا بعودتك');
  });
}
