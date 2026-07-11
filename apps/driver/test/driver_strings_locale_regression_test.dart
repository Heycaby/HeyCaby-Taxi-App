import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';

void main() {
  tearDown(() => DriverStrings.useLocale(const Locale('nl')));

  test('DriverStrings.accept is localized per locale', () {
    DriverStrings.useLocale(const Locale('en'));
    expect(DriverStrings.accept, 'Accept');

    DriverStrings.useLocale(const Locale('nl'));
    expect(DriverStrings.accept, 'Accepteren');

    DriverStrings.useLocale(const Locale('es'));
    expect(DriverStrings.accept, 'Aceptar');

    DriverStrings.useLocale(const Locale('ar'));
    expect(DriverStrings.accept, 'قبول');
  });

  test('DriverStrings defaults to Dutch for unsupported or missing locales',
      () {
    DriverStrings.useLocale(null);
    expect(DriverStrings.home, 'Start');
    expect(DriverStrings.goOnline, 'Ga online');
    expect(
      DriverStrings.statusControlOfflineHint,
      'Ga online om live ritaanvragen in jouw zone te zien.',
    );
    expect(DriverStrings.mapDemandWaiting(12), '12 wachtend');

    DriverStrings.useLocale(const Locale('fr'));
    expect(DriverStrings.home, 'Start');
    expect(DriverStrings.goOnline, 'Ga online');
    expect(
      DriverStrings.goBreakFailed,
      'Pauze starten mislukt. Controleer je verbinding en probeer opnieuw.',
    );
  });

  test('DriverStrings supports Dutch driver labels explicitly', () {
    DriverStrings.useLocale(const Locale('nl'));
    expect(DriverStrings.home, 'Start');
    expect(DriverStrings.goOnline, 'Ga online');
    expect(
      DriverStrings.statusControlOfflineHint,
      'Ga online om live ritaanvragen in jouw zone te zien.',
    );
    expect(DriverStrings.mapDemandWaiting(12), '12 wachtend');
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
    expect(DriverStrings.createAccount, 'Create account');
    expect(DriverStrings.registerDriverSubtitle, 'Register as a driver');
    expect(DriverStrings.passwordMinSixHint, 'Password (min 6 characters)');
    expect(DriverStrings.swapOfferTitle, 'Offer ride for swap');
    expect(
      DriverStrings.swapReasonLabel('vehicle_breakdown'),
      'Vehicle breakdown',
    );
    expect(DriverStrings.swapOfferDetailHint, 'Details (optional)');
    expect(DriverStrings.supportContactSection, 'Contact');
    expect(DriverStrings.notificationOpenAction, 'Open');
    expect(DriverStrings.legalCopyForTranslation, 'Copy for translation');
    expect(DriverStrings.legalCopyAllText, 'Copy all text');
    expect(
      DriverStrings.legalDocumentLanguageNotice,
      'Legal documents are available in Dutch and English.',
    );
    expect(DriverStrings.matchChanceSummary(30), 'Match chance: high');
    expect(DriverStrings.appSuggestion, 'Suggestion for the app');
    expect(DriverStrings.homeTodayRidesCount(0), 'No rides yet');
    expect(DriverStrings.homeAvailableCount(3), '3 available');
    expect(DriverStrings.profilePhotoConfirmTitle, 'Use this photo?');
    expect(DriverStrings.profilePhotoConfirmYes, 'Yes, save');
    expect(DriverStrings.profileNameSaved, 'Name saved.');
    expect(DriverStrings.profilePhotoAddHint,
        'Tap the photo to choose from gallery');
    expect(DriverStrings.addVehiclePhoto, 'Add taxi photo');
    expect(DriverStrings.vehiclePhotoUploadFailed,
        'Vehicle photo upload failed. Try again.');
    expect(DriverStrings.addManualRideTitle, 'Add passenger');
    expect(DriverStrings.manualRideRouteSection, 'Route');
    expect(DriverStrings.manualRideDetailsSection, 'Trip details');
    expect(DriverStrings.manualRideDropoffRequired,
        'Dropoff address is required.');
    expect(DriverStrings.manualRideFarePreviewEmpty,
        'Set fare to preview trip summary');
    expect(DriverStrings.manualRideFarePreview('42.50', 'CASH'),
        'You keep 100%: EUR 42.50 • CASH');
    expect(DriverStrings.cash, 'Cash');
    expect(DriverStrings.card, 'Card');
    expect(DriverStrings.done, 'Done');
    expect(DriverStrings.rateRider, 'Rate rider');
    expect(DriverStrings.rateRiderHeadline, 'How was your rider?');
    expect(DriverStrings.rateRiderCommentHint, 'Optional note');
    expect(DriverStrings.rateRiderSubmit, 'Submit');
    expect(DriverStrings.rateRiderSkip, 'Skip');
    expect(DriverStrings.selectRatingPrompt, 'Select a rating.');
    expect(DriverStrings.thanksForRating, 'Thanks for your rating!');
    expect(DriverStrings.actionFailedPrefix, 'Failed:');
    expect(DriverStrings.returnTrips, 'Taxi Terug');
    expect(DriverStrings.returnMode, 'Taxi Terug');
    expect(DriverStrings.returnModeOff, 'Off');
    expect(
      DriverStrings.returnModeOffBody,
      'Heading home? Earn on the way with Taxi Terug.',
    );
    expect(
      DriverStrings.returnModeAvailableCount(3),
      '3 Taxi Terug rides available',
    );
    expect(
        DriverStrings.returnModeHeadingTo('Rotterdam'), 'Heading to Rotterdam');
    expect(
      DriverStrings.returnModeActiveBody(
        pickupRadiusKm: 10,
      ),
      'Pickup radius 10 km',
    );
    expect(
      DriverStrings.returnModeNoMatchesYet,
      "No Taxi Terug rides yet. We'll keep looking while you drive.",
    );
    expect(DriverStrings.returnModeActivate, 'Activate');
    expect(DriverStrings.returnModeManage, 'Manage');
    expect(DriverStrings.returnModeDisable, 'Disable');
    expect(DriverStrings.returnModeHeadingHomeTitle, 'Taxi Terug?');
    expect(
      DriverStrings.returnModeHeadingHomeBody('Rotterdam'),
      'We can find rides toward Rotterdam while you drive.',
    );
    expect(DriverStrings.notNow, 'Not now');
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
      DriverStrings.statusControlBreakHint,
      'Your break is active. Go online to see rides.',
    );
    expect(
      DriverStrings.statusControlOnlineHint,
      'You are live in your zone.',
    );
    expect(DriverStrings.mapDemandWaiting(12), '12 waiting');
    expect(
      DriverStrings.communityCategoryEmptyPosts,
      'No posts for this category.',
    );
    expect(
      DriverStrings.goOfflineFailed,
      'Could not go offline. Check your connection and try again.',
    );
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
      'Could not accept the ride. Try again or check your connection.',
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
    expect(DriverStrings.createAccount, 'Crear cuenta');
    expect(DriverStrings.registerDriverSubtitle, 'Regístrate como conductor');
    expect(DriverStrings.passwordMinSixHint, 'Contraseña (mín. 6 caracteres)');
    expect(DriverStrings.swapOfferTitle, 'Ofrecer viaje para cambio');
    expect(
      DriverStrings.swapReasonLabel('schedule_conflict'),
      'Conflicto de horario',
    );
    expect(DriverStrings.swapOfferConfirm, 'Sí, ofrecer viaje');
    expect(DriverStrings.supportContactSection, 'Contacto');
    expect(DriverStrings.notificationOpenAction, 'Abrir');
    expect(DriverStrings.legalCopyForTranslation, 'Copiar para traducir');
    expect(DriverStrings.legalCopyAllText, 'Copiar todo el texto');
    expect(
      DriverStrings.legalDocumentLanguageNotice,
      'Los documentos legales están disponibles en neerlandés e inglés.',
    );
    expect(
        DriverStrings.matchChanceSummary(20), 'Probabilidad de match: media');
    expect(DriverStrings.appSuggestion, 'Sugerencia para la app');
    expect(DriverStrings.returnModeOff, 'Desactivado');
    expect(DriverStrings.returnModeManage, 'Gestionar');
    expect(DriverStrings.homeTodayRidesCount(0), 'Aún no hay viajes');
    expect(DriverStrings.homeAvailableCount(3), '3 disponibles');
    expect(DriverStrings.profilePhotoConfirmTitle, '¿Usar esta foto?');
    expect(DriverStrings.profilePhotoConfirmYes, 'Sí, guardar');
    expect(DriverStrings.profileNameSaved, 'Nombre guardado.');
    expect(DriverStrings.profilePhotoAddHint,
        'Toca la foto para elegir desde la galería');
    expect(DriverStrings.addVehiclePhoto, 'Añadir foto del vehículo');
    expect(DriverStrings.vehiclePhotoUploadFailed,
        'No se pudo subir la foto del vehículo. Inténtalo de nuevo.');
    expect(DriverStrings.addManualRideTitle, 'Añadir pasajero');
    expect(DriverStrings.manualRideRouteSection, 'Ruta');
    expect(DriverStrings.manualRideDetailsSection, 'Detalles del viaje');
    expect(DriverStrings.manualRideDropoffRequired,
        'La dirección de destino es obligatoria.');
    expect(DriverStrings.manualRideFarePreviewEmpty,
        'Introduce la tarifa para ver el resumen');
    expect(DriverStrings.manualRideFarePreview('42.50', 'CASH'),
        'Conservas el 100%: EUR 42.50 • CASH');
    expect(DriverStrings.cash, 'Efectivo');
    expect(DriverStrings.card, 'Tarjeta');
    expect(DriverStrings.done, 'Listo');
    expect(DriverStrings.rateRider, 'Valorar pasajero');
    expect(DriverStrings.rateRiderHeadline, '¿Cómo fue tu pasajero?');
    expect(DriverStrings.rateRiderCommentHint, 'Nota opcional');
    expect(DriverStrings.rateRiderSubmit, 'Enviar');
    expect(DriverStrings.rateRiderSkip, 'Omitir');
    expect(DriverStrings.selectRatingPrompt, 'Selecciona una valoración.');
    expect(DriverStrings.thanksForRating, '¡Gracias por tu valoración!');
    expect(DriverStrings.actionFailedPrefix, 'Error:');
    expect(DriverStrings.returnTrips, 'Taxi Terug');
    expect(DriverStrings.returnMode, 'Taxi Terug');
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
    expect(
      DriverStrings.statusControlBreakHint,
      'Tu descanso está activo. Conéctate para ver viajes.',
    );
    expect(DriverStrings.mapDemandWaiting(12), '12 esperando');
    expect(
      DriverStrings.goBreakFailed,
      'No se pudo iniciar el descanso. Revisa tu conexión e inténtalo de nuevo.',
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
      'No se pudo aceptar el viaje. Inténtalo de nuevo o revisa tu conexión.',
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
    expect(DriverStrings.createAccount, 'إنشاء حساب');
    expect(DriverStrings.registerDriverSubtitle, 'سجل كسائق');
    expect(DriverStrings.passwordMinSixHint, 'كلمة المرور (6 أحرف على الأقل)');
    expect(DriverStrings.swapOfferTitle, 'عرض الرحلة للتبديل');
    expect(DriverStrings.swapReasonLabel('medical'), 'طبي');
    expect(DriverStrings.swapOfferFailed, 'فشل');
    expect(DriverStrings.supportContactSection, 'التواصل');
    expect(DriverStrings.notificationOpenAction, 'فتح');
    expect(DriverStrings.legalCopyForTranslation, 'نسخ للترجمة');
    expect(DriverStrings.legalCopyAllText, 'نسخ كل النص');
    expect(
      DriverStrings.legalDocumentLanguageNotice,
      'المستندات القانونية متاحة بالهولندية والإنجليزية.',
    );
    expect(DriverStrings.matchChanceSummary(8), 'فرصة المطابقة: منخفضة');
    expect(DriverStrings.appSuggestion, 'اقتراح للتطبيق');
    expect(DriverStrings.returnModeOff, 'متوقف');
    expect(DriverStrings.returnModeManage, 'إدارة');
    expect(DriverStrings.homeTodayRidesCount(0), 'لا توجد رحلات بعد');
    expect(DriverStrings.homeAvailableCount(3), '3 متاحة');
    expect(DriverStrings.profilePhotoConfirmTitle, 'استخدام هذه الصورة؟');
    expect(DriverStrings.profilePhotoConfirmYes, 'نعم، حفظ');
    expect(DriverStrings.profileNameSaved, 'تم حفظ الاسم.');
    expect(DriverStrings.profilePhotoAddHint,
        'اضغط على الصورة للاختيار من المعرض');
    expect(DriverStrings.addVehiclePhoto, 'إضافة صورة للمركبة');
    expect(DriverStrings.vehiclePhotoUploadFailed,
        'فشل تحميل صورة المركبة. حاول مرة أخرى.');
    expect(DriverStrings.addManualRideTitle, 'إضافة راكب');
    expect(DriverStrings.manualRideRouteSection, 'المسار');
    expect(DriverStrings.manualRideDetailsSection, 'تفاصيل الرحلة');
    expect(DriverStrings.manualRideDropoffRequired, 'عنوان الوصول مطلوب.');
    expect(DriverStrings.manualRideFarePreviewEmpty,
        'أدخل الأجرة لمعاينة ملخص الرحلة');
    expect(DriverStrings.manualRideFarePreview('42.50', 'CASH'),
        'تحتفظ بنسبة 100%: EUR 42.50 • CASH');
    expect(DriverStrings.cash, 'نقدا');
    expect(DriverStrings.card, 'بطاقة');
    expect(DriverStrings.done, 'تم');
    expect(DriverStrings.rateRider, 'تقييم الراكب');
    expect(DriverStrings.rateRiderHeadline, 'كيف كان الراكب؟');
    expect(DriverStrings.rateRiderCommentHint, 'ملاحظة اختيارية');
    expect(DriverStrings.rateRiderSubmit, 'إرسال');
    expect(DriverStrings.rateRiderSkip, 'تخطي');
    expect(DriverStrings.selectRatingPrompt, 'اختر تقييما.');
    expect(DriverStrings.thanksForRating, 'شكرا على تقييمك!');
    expect(DriverStrings.actionFailedPrefix, 'فشل:');
    expect(DriverStrings.returnTrips, 'Taxi Terug');
    expect(DriverStrings.returnMode, 'Taxi Terug');
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
    expect(
      DriverStrings.statusControlOnlineHint,
      'أنت نشط في منطقتك.',
    );
    expect(DriverStrings.mapDemandWaiting(12), '12 ينتظرون');
    expect(
      DriverStrings.goOfflineFailed,
      'تعذر عدم الاتصال. تحقق من اتصالك وحاول مرة أخرى.',
    );
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
      'تعذر قبول الرحلة. حاول مرة أخرى أو تحقق من اتصالك.',
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
