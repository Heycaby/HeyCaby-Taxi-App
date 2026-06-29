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
    expect(DriverStrings.appSuggestion, 'Suggestion for the app');
    expect(DriverStrings.homeAutoAcceptReturnRides, 'Auto-accept return rides');
    expect(DriverStrings.homeTodayRidesCount(0), 'No rides yet');
    expect(DriverStrings.homeAvailableCount(3), '3 available');
    expect(DriverStrings.pricingBase, 'Start price');
    expect(DriverStrings.pricingSwitchTariff, 'Switch tariff');
    expect(DriverStrings.faq, 'Frequently asked questions');
    expect(DriverStrings.faqHowGoOnlineQuestion, 'How do I go online?');

    DriverStrings.useLocale(const Locale('es'));
    expect(DriverStrings.home, 'Inicio');
    expect(DriverStrings.goOnline, 'Conectarse');
    expect(DriverStrings.myRides, 'Mis viajes');
    expect(DriverStrings.loginFormTitle, 'Bienvenido de nuevo');
    expect(DriverStrings.appSuggestion, 'Sugerencia para la app');
    expect(
      DriverStrings.homeAutoAcceptReturnRides,
      'Aceptar viajes de vuelta automáticamente',
    );
    expect(DriverStrings.homeTodayRidesCount(0), 'Aún no hay viajes');
    expect(DriverStrings.homeAvailableCount(3), '3 disponibles');
    expect(DriverStrings.pricingBase, 'Precio inicial');
    expect(DriverStrings.pricingSwitchTariff, 'Cambiar tarifa');
    expect(DriverStrings.faq, 'Preguntas frecuentes');
    expect(DriverStrings.faqHowGoOnlineQuestion, '¿Cómo me conecto?');

    DriverStrings.useLocale(const Locale('ar'));
    expect(DriverStrings.home, 'الرئيسية');
    expect(DriverStrings.goOnline, 'الاتصال');
    expect(DriverStrings.myRides, 'رحلاتي');
    expect(DriverStrings.loginFormTitle, 'مرحبا بعودتك');
    expect(DriverStrings.appSuggestion, 'اقتراح للتطبيق');
    expect(
        DriverStrings.homeAutoAcceptReturnRides, 'قبول رحلات العودة تلقائيا');
    expect(DriverStrings.homeTodayRidesCount(0), 'لا توجد رحلات بعد');
    expect(DriverStrings.homeAvailableCount(3), '3 متاحة');
    expect(DriverStrings.pricingBase, 'سعر البداية');
    expect(DriverStrings.pricingSwitchTariff, 'تغيير التعرفة');
    expect(DriverStrings.faq, 'الأسئلة الشائعة');
    expect(DriverStrings.faqHowGoOnlineQuestion, 'كيف أصبح متصلا؟');
  });
}
