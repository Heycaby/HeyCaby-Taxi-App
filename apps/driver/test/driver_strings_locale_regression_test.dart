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
    expect(DriverStrings.cancel, 'Cancel');
    expect(DriverStrings.enableLocation, 'Enable location');
    expect(DriverStrings.tryAgain, 'Try again');
    expect(DriverStrings.loginFormTitle, 'Welcome back');
    expect(DriverStrings.appSuggestion, 'Suggestion for the app');
    expect(DriverStrings.homeAutoAcceptReturnRides, 'Auto-accept return rides');
    expect(DriverStrings.homeTodayRidesCount(0), 'No rides yet');
    expect(DriverStrings.homeAvailableCount(3), '3 available');
    expect(DriverStrings.returnTrips, 'Return rides');
    expect(DriverStrings.returnTripsEmpty, 'No return rides available.');
    expect(DriverStrings.ridesThisWeek, 'Rides this week');
    expect(DriverStrings.vehicleRdwTitle, 'Your vehicle');
    expect(DriverStrings.vehicleRdwSubtitle,
        'Enter your plate number. We automatically fetch vehicle details from RDW.');
    expect(DriverStrings.vehicleMake, 'Make');
    expect(DriverStrings.vehicleModel, 'Model');
    expect(DriverStrings.vehicleApk, 'APK');
    expect(
        DriverStrings.failedToUpdateStatus, 'Status update failed. Try again.');
    expect(
        DriverStrings.serverErrorMessage('rate limit'), 'Server: rate limit');
    expect(
      DriverStrings.driverProfileIncompleteForStatus,
      'Server rejected the request. Check that your driver profile is complete.',
    );
    expect(DriverStrings.pricingBase, 'Start price');
    expect(DriverStrings.pricingSwitchTariff, 'Switch tariff');
    expect(DriverStrings.announcements, 'Announcements');
    expect(DriverStrings.driverTalk, 'Driver Talk');
    expect(DriverStrings.communityHubSubtitle,
        'Connect, share, and grow together.');
    expect(DriverStrings.communityNotificationsTitle, 'Notifications');
    expect(
        DriverStrings.communitySearchHint, 'Search posts, topics, or users...');
    expect(DriverStrings.communityNewPostTitle, 'New post');
    expect(
      DriverStrings.communityPostComposerHint,
      'Share a tip, update, or question...',
    );
    expect(DriverStrings.communityPostButton, 'Post');
    expect(
      DriverStrings.rideActionFailedMessage,
      'Action failed. Check your connection and try again.',
    );
    expect(
      DriverStrings.acceptRideFailedMessage,
      'Could not accept the ride. The request may have expired.',
    );
    expect(DriverStrings.preferencesPlayPreviewTooltip, 'Play 10s preview');
    expect(DriverStrings.insuranceProviderLabel, 'Insurer');
    expect(DriverStrings.insurancePolicyLabel, 'Policy number');
    expect(DriverStrings.insuranceExpiryLabel, 'Expiry date');
    expect(
      DriverStrings.missingFieldsMessage(['insurer', 'policy number']),
      'Missing: insurer, policy number.',
    );
    expect(DriverStrings.kvkNumberLabel, 'KvK number (8 digits)');
    expect(DriverStrings.kvkBusinessNameLabel, 'Business name');
    expect(DriverStrings.kvkBusinessAddressLabel, 'Business address');
    expect(
      DriverStrings.documentSaveFailed,
      'Save failed. Check your details and try again.',
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
    expect(
      DriverStrings.indemnificationQuizQuestion1,
      '1) Who is responsible for transport obligations during rides?',
    );
    expect(
      DriverStrings.indemnificationQuizQuestion1Options[1],
      'The Driver',
    );
    expect(
      DriverStrings.indemnificationQuizQuestion5Options[1],
      'Licences/permits/insurance and legal compliance',
    );

    DriverStrings.useLocale(const Locale('es'));
    expect(DriverStrings.home, 'Inicio');
    expect(DriverStrings.goOnline, 'Conectarse');
    expect(DriverStrings.myRides, 'Mis viajes');
    expect(DriverStrings.cancel, 'Cancelar');
    expect(DriverStrings.enableLocation, 'Activar ubicación');
    expect(DriverStrings.tryAgain, 'Intentar de nuevo');
    expect(DriverStrings.loginFormTitle, 'Bienvenido de nuevo');
    expect(DriverStrings.appSuggestion, 'Sugerencia para la app');
    expect(
      DriverStrings.homeAutoAcceptReturnRides,
      'Aceptar viajes de vuelta automáticamente',
    );
    expect(DriverStrings.homeTodayRidesCount(0), 'Aún no hay viajes');
    expect(DriverStrings.homeAvailableCount(3), '3 disponibles');
    expect(DriverStrings.returnTrips, 'Viajes de vuelta');
    expect(
      DriverStrings.returnTripsEmpty,
      'No hay viajes de vuelta disponibles.',
    );
    expect(DriverStrings.ridesThisWeek, 'Viajes esta semana');
    expect(DriverStrings.vehicleRdwTitle, 'Tu vehículo');
    expect(DriverStrings.vehicleRdwSubtitle,
        'Introduce tu matrícula. Obtenemos automáticamente los datos del vehículo desde RDW.');
    expect(DriverStrings.vehicleMake, 'Marca');
    expect(DriverStrings.vehicleModel, 'Modelo');
    expect(DriverStrings.vehicleApk, 'APK');
    expect(
      DriverStrings.failedToUpdateStatus,
      'No se pudo actualizar el estado. Inténtalo de nuevo.',
    );
    expect(DriverStrings.serverErrorMessage('límite'), 'Servidor: límite');
    expect(
      DriverStrings.driverProfileIncompleteForStatus,
      'El servidor rechazó la solicitud. Comprueba que tu perfil de conductor esté completo.',
    );
    expect(DriverStrings.pricingBase, 'Precio inicial');
    expect(DriverStrings.pricingSwitchTariff, 'Cambiar tarifa');
    expect(DriverStrings.announcements, 'Anuncios');
    expect(DriverStrings.driverTalk, 'Charla de conductores');
    expect(DriverStrings.communityHubSubtitle,
        'Conecta, comparte y crece junto a otros.');
    expect(DriverStrings.communityNotificationsTitle, 'Notificaciones');
    expect(DriverStrings.communitySearchHint,
        'Buscar publicaciones, temas o usuarios...');
    expect(DriverStrings.communityNewPostTitle, 'Nueva publicación');
    expect(
      DriverStrings.communityPostComposerHint,
      'Comparte un consejo, una novedad o una pregunta...',
    );
    expect(DriverStrings.communityPostButton, 'Publicar');
    expect(
      DriverStrings.rideActionFailedMessage,
      'La acción falló. Revisa tu conexión e inténtalo de nuevo.',
    );
    expect(
      DriverStrings.acceptRideFailedMessage,
      'No se pudo aceptar el viaje. Es posible que la solicitud haya caducado.',
    );
    expect(
      DriverStrings.preferencesPlayPreviewTooltip,
      'Reproducir vista previa de 10 s',
    );
    expect(DriverStrings.insuranceProviderLabel, 'Aseguradora');
    expect(DriverStrings.insurancePolicyLabel, 'Número de póliza');
    expect(DriverStrings.insuranceExpiryLabel, 'Fecha de vencimiento');
    expect(
      DriverStrings.missingFieldsMessage(['aseguradora', 'número de póliza']),
      'Falta: aseguradora, número de póliza.',
    );
    expect(DriverStrings.kvkNumberLabel, 'Número KvK (8 dígitos)');
    expect(DriverStrings.kvkBusinessNameLabel, 'Nombre de la empresa');
    expect(DriverStrings.kvkBusinessAddressLabel, 'Dirección comercial');
    expect(
      DriverStrings.documentSaveFailed,
      'No se pudo guardar. Revisa tus datos e inténtalo de nuevo.',
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
    expect(
      DriverStrings.indemnificationQuizQuestion1,
      '1) ¿Quién es responsable de las obligaciones de transporte durante los viajes?',
    );
    expect(
      DriverStrings.indemnificationQuizQuestion1Options[1],
      'El conductor',
    );
    expect(
      DriverStrings.indemnificationQuizQuestion5Options[1],
      'Licencias, permisos, seguro y cumplimiento legal',
    );

    DriverStrings.useLocale(const Locale('ar'));
    expect(DriverStrings.home, 'الرئيسية');
    expect(DriverStrings.goOnline, 'الاتصال');
    expect(DriverStrings.myRides, 'رحلاتي');
    expect(DriverStrings.cancel, 'إلغاء');
    expect(DriverStrings.enableLocation, 'تفعيل الموقع');
    expect(DriverStrings.tryAgain, 'حاول مرة أخرى');
    expect(DriverStrings.loginFormTitle, 'مرحبا بعودتك');
    expect(DriverStrings.appSuggestion, 'اقتراح للتطبيق');
    expect(
        DriverStrings.homeAutoAcceptReturnRides, 'قبول رحلات العودة تلقائيا');
    expect(DriverStrings.homeTodayRidesCount(0), 'لا توجد رحلات بعد');
    expect(DriverStrings.homeAvailableCount(3), '3 متاحة');
    expect(DriverStrings.returnTrips, 'رحلات العودة');
    expect(DriverStrings.returnTripsEmpty, 'لا توجد رحلات عودة متاحة.');
    expect(DriverStrings.ridesThisWeek, 'رحلات هذا الأسبوع');
    expect(DriverStrings.vehicleRdwTitle, 'مركبتك');
    expect(
      DriverStrings.vehicleRdwSubtitle,
      'أدخل رقم اللوحة. سنجلب بيانات المركبة تلقائيا من RDW.',
    );
    expect(DriverStrings.vehicleMake, 'الشركة');
    expect(DriverStrings.vehicleModel, 'الطراز');
    expect(DriverStrings.vehicleApk, 'APK');
    expect(
        DriverStrings.failedToUpdateStatus, 'فشل تحديث الحالة. حاول مرة أخرى.');
    expect(DriverStrings.serverErrorMessage('الحد'), 'الخادم: الحد');
    expect(
      DriverStrings.driverProfileIncompleteForStatus,
      'رفض الخادم الطلب. تحقق من اكتمال ملفك الشخصي كسائق.',
    );
    expect(DriverStrings.pricingBase, 'سعر البداية');
    expect(DriverStrings.pricingSwitchTariff, 'تغيير التعرفة');
    expect(DriverStrings.announcements, 'الإعلانات');
    expect(DriverStrings.driverTalk, 'حديث السائقين');
    expect(DriverStrings.communityHubSubtitle, 'تواصل وشارك وانم مع الآخرين.');
    expect(DriverStrings.communityNotificationsTitle, 'الإشعارات');
    expect(DriverStrings.communitySearchHint,
        'ابحث في المنشورات أو المواضيع أو المستخدمين...');
    expect(DriverStrings.communityNewPostTitle, 'منشور جديد');
    expect(
      DriverStrings.communityPostComposerHint,
      'شارك نصيحة أو تحديثا أو سؤالا...',
    );
    expect(DriverStrings.communityPostButton, 'نشر');
    expect(
      DriverStrings.rideActionFailedMessage,
      'فشل الإجراء. تحقق من اتصالك وحاول مرة أخرى.',
    );
    expect(
      DriverStrings.acceptRideFailedMessage,
      'تعذر قبول الرحلة. ربما انتهت صلاحية الطلب.',
    );
    expect(DriverStrings.preferencesPlayPreviewTooltip, 'تشغيل معاينة 10 ثوان');
    expect(DriverStrings.insuranceProviderLabel, 'شركة التأمين');
    expect(DriverStrings.insurancePolicyLabel, 'رقم الوثيقة');
    expect(DriverStrings.insuranceExpiryLabel, 'تاريخ الانتهاء');
    expect(
      DriverStrings.missingFieldsMessage(['شركة التأمين', 'رقم الوثيقة']),
      'الحقول الناقصة: شركة التأمين, رقم الوثيقة.',
    );
    expect(DriverStrings.kvkNumberLabel, 'رقم KvK (8 أرقام)');
    expect(DriverStrings.kvkBusinessNameLabel, 'اسم الشركة');
    expect(DriverStrings.kvkBusinessAddressLabel, 'عنوان العمل');
    expect(
      DriverStrings.documentSaveFailed,
      'فشل الحفظ. تحقق من بياناتك وحاول مرة أخرى.',
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
    expect(
      DriverStrings.indemnificationQuizQuestion1,
      '1) من المسؤول عن التزامات النقل أثناء الرحلات؟',
    );
    expect(
      DriverStrings.indemnificationQuizQuestion1Options[1],
      'السائق',
    );
    expect(
      DriverStrings.indemnificationQuizQuestion5Options[1],
      'التراخيص والتصاريح والتأمين والامتثال القانوني',
    );
  });
}
