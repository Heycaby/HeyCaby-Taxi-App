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
    expect(DriverStrings.announcements, 'Announcements');
    expect(DriverStrings.driverTalk, 'Driver Talk');
    expect(DriverStrings.communityHubSubtitle,
        'Connect, share, and grow together.');
    expect(DriverStrings.communityNotificationsTitle, 'Notifications');
    expect(
        DriverStrings.communitySearchHint, 'Search posts, topics, or users...');
    expect(
      DriverStrings.rideActionFailedMessage,
      'Action failed. Check your connection and try again.',
    );
    expect(
      DriverStrings.acceptRideFailedMessage,
      'Could not accept the ride. The request may have expired.',
    );
    expect(DriverStrings.faq, 'Frequently asked questions');
    expect(DriverStrings.faqHowGoOnlineQuestion, 'How do I go online?');
    expect(
      DriverStrings.veriffTermsDataMinimizationTitle,
      'GDPR and data minimisation',
    );
    expect(
      DriverStrings.veriffTermsSecurityLiabilityTitle,
      'Security and third-party responsibility',
    );
    expect(DriverStrings.veriffTermsLegalDisclosureTitle, 'Legal disclosure');

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
    expect(DriverStrings.announcements, 'Anuncios');
    expect(DriverStrings.driverTalk, 'Charla de conductores');
    expect(DriverStrings.communityHubSubtitle,
        'Conecta, comparte y crece junto a otros.');
    expect(DriverStrings.communityNotificationsTitle, 'Notificaciones');
    expect(DriverStrings.communitySearchHint,
        'Buscar publicaciones, temas o usuarios...');
    expect(
      DriverStrings.rideActionFailedMessage,
      'La acción falló. Revisa tu conexión e inténtalo de nuevo.',
    );
    expect(
      DriverStrings.acceptRideFailedMessage,
      'No se pudo aceptar el viaje. Es posible que la solicitud haya caducado.',
    );
    expect(DriverStrings.faq, 'Preguntas frecuentes');
    expect(DriverStrings.faqHowGoOnlineQuestion, '¿Cómo me conecto?');
    expect(
      DriverStrings.veriffTermsDataMinimizationTitle,
      'RGPD y minimización de datos',
    );
    expect(
      DriverStrings.veriffTermsSecurityLiabilityTitle,
      'Seguridad y responsabilidad de terceros',
    );
    expect(DriverStrings.veriffTermsLegalDisclosureTitle, 'Divulgación legal');

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
    expect(DriverStrings.announcements, 'الإعلانات');
    expect(DriverStrings.driverTalk, 'حديث السائقين');
    expect(DriverStrings.communityHubSubtitle, 'تواصل وشارك وانم مع الآخرين.');
    expect(DriverStrings.communityNotificationsTitle, 'الإشعارات');
    expect(DriverStrings.communitySearchHint,
        'ابحث في المنشورات أو المواضيع أو المستخدمين...');
    expect(
      DriverStrings.rideActionFailedMessage,
      'فشل الإجراء. تحقق من اتصالك وحاول مرة أخرى.',
    );
    expect(
      DriverStrings.acceptRideFailedMessage,
      'تعذر قبول الرحلة. ربما انتهت صلاحية الطلب.',
    );
    expect(DriverStrings.faq, 'الأسئلة الشائعة');
    expect(DriverStrings.faqHowGoOnlineQuestion, 'كيف أصبح متصلا؟');
    expect(
      DriverStrings.veriffTermsDataMinimizationTitle,
      'اللائحة العامة وحفظ أقل قدر من البيانات',
    );
    expect(
      DriverStrings.veriffTermsSecurityLiabilityTitle,
      'الأمان ومسؤولية الطرف الثالث',
    );
    expect(DriverStrings.veriffTermsLegalDisclosureTitle, 'الإفصاح القانوني');
  });
}
