import 'dart:ui';

/// Driver app strings (fallback language: Dutch).
/// Migrate to flutter gen-l10n when driver l10n is set up.
class DriverStrings {
  static String _languageCode = 'nl';

  static String get currentLanguageCode => _languageCode;

  static void useLocale(Locale? locale) {
    final code = locale?.languageCode.toLowerCase();
    _languageCode = switch (code) {
      'nl' || 'en' || 'es' || 'ar' => code!,
      _ => 'nl',
    };
  }

  static String _t(
    String nl, {
    required String en,
    required String es,
    required String ar,
  }) {
    return switch (_languageCode) {
      'nl' => nl,
      'en' => en,
      'es' => es,
      'ar' => ar,
      _ => nl,
    };
  }

  static String get goOnline => _t(
        'Ga online',
        en: 'Go online',
        es: 'Conectarse',
        ar: 'الاتصال',
      );
  static String get goOnlineTitle => goOnline;
  static String get goOnlineChangeStatus => _t(
        'Wijzig je status',
        en: 'Change your status',
        es: 'Cambia tu estado',
        ar: 'غيّر حالتك',
      );
  static String get goOnlineCardGoOnline => goOnline;
  static String get goOnlineCardGoOnlineSubtitle => _t(
        'Ontvang ritaanvragen',
        en: 'Receive ride requests',
        es: 'Recibe solicitudes de viaje',
        ar: 'استقبل طلبات الرحلات',
      );
  static String get goOnlineCardBreak => takeABreak;
  static String get goOnlineCardBreakSubtitle => _t(
        'Pauzeer aanvragen',
        en: 'Pause requests',
        es: 'Pausar solicitudes',
        ar: 'إيقاف الطلبات مؤقتا',
      );
  static String get goOnlineCardOffline => _t(
        'Dienst stoppen',
        en: 'End shift',
        es: 'Terminar turno',
        ar: 'إنهاء الوردية',
      );
  static String get goOnlineCardOfflineSubtitle => _t(
        'Ga offline',
        en: 'Go offline',
        es: 'Desconectarse',
        ar: 'عدم الاتصال',
      );
  static String get slideToGoOnline => _t(
        'Schuif om online te gaan',
        en: 'Slide to go online',
        es: 'Desliza para conectarte',
        ar: 'مرر للاتصال',
      );
  static String get offline => _t(
        'Offline',
        en: 'Offline',
        es: 'Sin conexión',
        ar: 'غير متصل',
      );
  static String get online => _t(
        'Online',
        en: 'Online',
        es: 'En línea',
        ar: 'متصل',
      );
  static String get youAreOnline => _t(
        'Je bent online!',
        en: 'You are online!',
        es: '¡Estás en línea!',
        ar: 'أنت متصل!',
      );
  static String get onBreak => _t(
        'Pauze',
        en: 'Break',
        es: 'Descanso',
        ar: 'استراحة',
      );
  static String get legalCopyForTranslation => _t(
        'Kopieer voor vertaling',
        en: 'Copy for translation',
        es: 'Copiar para traducir',
        ar: 'نسخ للترجمة',
      );
  static String get legalCopyAllText => _t(
        'Alle tekst kopiëren',
        en: 'Copy all text',
        es: 'Copiar todo el texto',
        ar: 'نسخ كل النص',
      );
  static String get legalDocumentLanguageNotice => _t(
        'Juridische documenten zijn beschikbaar in Nederlands en Engels.',
        en: 'Legal documents are available in Dutch and English.',
        es: 'Los documentos legales están disponibles en neerlandés e inglés.',
        ar: 'المستندات القانونية متاحة بالهولندية والإنجليزية.',
      );
  static String get resume => _t(
        'Hervatten',
        en: 'Resume',
        es: 'Reanudar',
        ar: 'استئناف',
      );
  static String get today => _t(
        'Vandaag',
        en: 'Today',
        es: 'Hoy',
        ar: 'اليوم',
      );
  static String get thisWeek => _t(
        'Deze week',
        en: 'This week',
        es: 'Esta semana',
        ar: 'هذا الأسبوع',
      );
  static const String acceptanceRate = 'Acceptatiegraad';
  static String get scheduledRides => _t(
        'Geplande ritten',
        en: 'Scheduled rides',
        es: 'Viajes programados',
        ar: 'الرحلات المجدولة',
      );
  static String get scheduledRidesSubtitle => _t(
        'ritten beschikbaar in jouw regio',
        en: 'rides available in your area',
        es: 'viajes disponibles en tu zona',
        ar: 'رحلات متاحة في منطقتك',
      );
  static String get driverRating => _t(
        'Chauffeursscore',
        en: 'Driver score',
        es: 'Puntuación del conductor',
        ar: 'تقييم السائق',
      );

  /// Migration 040 — shown on score screen when `drivers.avg_*` columns exist.
  static const String ratingBreakdownTitle = 'Jouw gemiddelden per gebied';
  static const String ratingPunctuality = 'Stiptheid';
  static const String ratingCleanliness = 'Netheid';
  static const String ratingAttitude = 'Houding';
  static const String ratingDrivingSafety = 'Rijveiligheid';
  static const String ratingCommunication = 'Communicatie';
  static const String trustScoreLabel = 'Vertrouwensscore';
  static const String trustScoreHint =
      'Interne kwaliteitsscore (0–100). Passagiers zien je openbare sterren.';
  static const String reviewFlagTitle = 'Beoordeling aangevraagd';
  static const String reviewFlagBody =
      'Ons team kan recente beoordelingen bekijken. Je hoeft niets te doen tenzij wij contact met je opnemen.';
  static const String newDriverShieldActive =
      'Bescherming nieuwe chauffeur actief';
  static const String newDriverShieldBody =
      'Eerste beoordelingen krijgen extra bescherming zodat één moeilijke rit je niet definieert.';
  static const String ratingBadges = 'Prestaties';
  static const String ratingsInScore = 'beoordelingen in je score';
  static String get todaysRides => _t(
        'Ritten vandaag',
        en: 'Today’s rides',
        es: 'Viajes de hoy',
        ar: 'رحلات اليوم',
      );
  static String get driverTalk => _t(
        'Chauffeurpraat',
        en: 'Driver Talk',
        es: 'Charla de conductores',
        ar: 'حديث السائقين',
      );
  static String get takeABreak => _t(
        'Neem pauze',
        en: 'Take a break',
        es: 'Tomar descanso',
        ar: 'خذ استراحة',
      );
  static const String shiftWorkdayActive = 'Werkdag actief';
  static const String shiftBreakActive = 'Pauze actief';
  static String get shiftTodaySummary => today;
  static const String shiftStatDriving = 'Rijden';
  static const String shiftStatBreak = 'Pauze';
  static const String shiftStatRides = 'Ritten';
  static const String shiftStatEarnings = 'Verdiensten';
  static const String shiftHoursShort = 'uur';
  static String get shiftBreakReminderTitle => _t(
        'Tijd voor een pauze',
        en: 'Time for a break',
        es: 'Hora de descansar',
        ar: 'حان وقت الاستراحة',
      );
  static String get shiftBreakReminderBody => _t(
        'Je rijdt al een tijdje. Overweeg een korte pauze.',
        en: 'You have been driving for a while. Consider a short break.',
        es: 'Llevas un tiempo conduciendo. Considera un breve descanso.',
        ar: 'لقد قدت لفترة. فكر في أخذ استراحة قصيرة.',
      );

  /// Shown on the warm break banner (continuous driving ≥ reminder interval).
  static String shiftBreakReminderBodyHours(int hours) => _t(
        'Je rijdt al $hours uur. Neem even rust.',
        en: 'You have been driving for $hours hours. Take a short rest.',
        es: 'Llevas $hours horas conduciendo. Tómate un breve descanso.',
        ar: 'لقد قدت لمدة $hours ساعات. خذ قسطا قصيرا من الراحة.',
      );
  static String shiftBreakConsiderAfter(String duration) => _t(
        'Je rijdt al $duration. Overweeg binnenkort een pauze.',
        en: 'You have been driving for $duration. Consider taking a break soon.',
        es: 'Llevas $duration conduciendo. Considera descansar pronto.',
        ar: 'لقد قدت لمدة $duration. فكر في أخذ استراحة قريبا.',
      );
  static String shiftBreakDueAfter(String duration) => _t(
        'Je rijdt al $duration. Een pauze is een goed idee.',
        en: 'You have been driving for $duration. A break is a good idea.',
        es: 'Llevas $duration conduciendo. Un descanso es buena idea.',
        ar: 'لقد قدت لمدة $duration. الاستراحة فكرة جيدة.',
      );
  static String get shiftChooseBreak => _t(
        'Kies pauzeduur',
        en: 'Choose break length',
        es: 'Elige duración del descanso',
        ar: 'اختر مدة الاستراحة',
      );
  static String shiftBreakMinutes(int minutes) => _t(
        '$minutes minuten',
        en: '$minutes minutes',
        es: '$minutes minutos',
        ar: '$minutes دقيقة',
      );
  static String get shiftStartBreak => _t(
        'Start pauze',
        en: 'Start break',
        es: 'Iniciar descanso',
        ar: 'ابدأ الاستراحة',
      );
  static String get shiftBreakTarget => _t(
        'Pauzedoel',
        en: 'Break target',
        es: 'Objetivo de descanso',
        ar: 'هدف الاستراحة',
      );
  static String shiftBreakRemaining(String remaining) => _t(
        '$remaining resterend',
        en: '$remaining remaining',
        es: 'Quedan $remaining',
        ar: 'متبق $remaining',
      );
  static String get shiftBreakComplete => _t(
        'Pauze voltooid',
        en: 'Break complete',
        es: 'Descanso completado',
        ar: 'اكتملت الاستراحة',
      );
  static String get shiftBreakCompleteBody => _t(
        'Klaar om weer beschikbaar te zijn wanneer jij wilt.',
        en: 'Ready to go available again when you are.',
        es: 'Listo para volver a estar disponible cuando quieras.',
        ar: 'جاهز للعودة إلى التوفر عندما تكون مستعدا.',
      );
  static const String pauze = 'Pauze';
  static const String hervat = 'Hervat';
  static const String stop = 'Stop';
  static const String shiftArcHint = '8 uur dienst';
  static const String endShift = 'Dienst beëindigen';
  static const String endShiftConfirm = 'Dienst beëindigen?';
  static const String endShiftDetail =
      'Je hebt vandaag X uur gereden en Y ritten voltooid.';
  static String get cancel => _t(
        'Annuleren',
        en: 'Cancel',
        es: 'Cancelar',
        ar: 'إلغاء',
      );
  static const String readyToGoBackOnline = 'Klaar om weer online te gaan?';
  static const String zoneView = 'Zone-weergave';
  static const String demandZones = 'Vraagzones';
  static const String demandZonesDesc =
      'Zie gouden cirkels met het aantal passagiers.';
  static const String clearMap = 'Kaart wissen';
  static const String clearMapDesc =
      'Verberg zone-overlays voor een rustig beeld.';
  static const String dutchBreakNotice =
      'Je rijdt al X uur. Nederlandse regels vereisen een pauze van 30 minuten na 4,5 uur rijden.';
  static const String breakRecommended = 'Pauze aanbevolen over X minuten';
  static const String breakRequired = 'Wettelijke pauze vereist';
  static const String setUpRates = 'Stel je tarieven in →';
  static String get home => _t(
        'Start',
        en: 'Home',
        es: 'Inicio',
        ar: 'الرئيسية',
      );
  static const String work = 'Werk';
  static String get myRides => _t(
        'Mijn ritten',
        en: 'My rides',
        es: 'Mis viajes',
        ar: 'رحلاتي',
      );
  static String get me => _t(
        'Ik',
        en: 'Me',
        es: 'Yo',
        ar: 'أنا',
      );
  static const String rideDetails = 'Ritdetails';
  static const String rideDetailsNotFound = 'Rit niet gevonden.';
  static String get noRidesYet => _t(
        'Nog geen ritten.',
        en: 'No rides yet.',
        es: 'Aún no hay viajes.',
        ar: 'لا توجد رحلات بعد.',
      );
  static const String myRidesLoadFailed = 'Ritten laden mislukt.';
  static const String manualRideTag = 'Handmatige rit';
  static const String standardRideTag = 'Standaardrit';
  static const String date = 'Datum';
  static const String status = 'Status';
  static const String type = 'Type';
  static const String pickup = 'Ophaalpunt';
  static const String dropoff = 'Afzet';
  static const String fare = 'Tarief';
  static const String paymentMethod = 'Betaalmethode';
  static const String driverEarnings = 'Jouw verdiensten';
  static const String platformFee = 'Platformfee';
  static String get earnings => _t(
        'Verdiensten',
        en: 'Earnings',
        es: 'Ganancias',
        ar: 'الأرباح',
      );
  static const String availableRides = 'Beschikbare ritten';
  static String get community => _t(
        'Gemeenschap',
        en: 'Community',
        es: 'Comunidad',
        ar: 'المجتمع',
      );
  static String get profile => _t(
        'Profiel',
        en: 'Profile',
        es: 'Perfil',
        ar: 'الملف الشخصي',
      );

  /// Profile header when `drivers.full_name` is empty.
  static String get profileNamePlaceholder => _t(
        'Voeg je naam toe',
        en: 'Add your name',
        es: 'Añade tu nombre',
        ar: 'أضف اسمك',
      );
  static String get profileEditNameTitle => _t(
        'Je naam',
        en: 'Your name',
        es: 'Tu nombre',
        ar: 'اسمك',
      );
  static String get profileEditNameSubtitle => _t(
        'Zichtbaar voor passagiers bij het boeken.',
        en: 'Visible to riders when they book.',
        es: 'Visible para pasajeros al reservar.',
        ar: 'يظهر للركاب عند الحجز.',
      );

  /// One-time profile photo confirmation (shown before upload).
  static String get profilePhotoConfirmTitle => _t(
        'Deze foto gebruiken?',
        en: 'Use this photo?',
        es: '¿Usar esta foto?',
        ar: 'استخدام هذه الصورة؟',
      );
  static String get profilePhotoConfirmBody => _t(
        'Zorg dat dit een echte, duidelijke foto van jou is — je kunt hem maximaal 2 keer in de app wijzigen. '
        'Passagiers zien hem bij het boeken van een taxi.\n\n'
        'Weet je zeker dat dit is wat passagiers moeten zien?',
        en: 'Make sure this is a real, clear photo of you. You can change it in the app up to 2 times. '
            'Riders see it when booking a taxi.\n\n'
            'Are you sure this is what riders should see?',
        es: 'Asegúrate de que sea una foto real y clara de ti. Puedes cambiarla en la app hasta 2 veces. '
            'Los pasajeros la ven al reservar un taxi.\n\n'
            '¿Seguro que esto es lo que deben ver los pasajeros?',
        ar: 'تأكد أنها صورة حقيقية وواضحة لك. يمكنك تغييرها داخل التطبيق حتى مرتين. '
            'يراها الركاب عند حجز سيارة أجرة.\n\n'
            'هل أنت متأكد أن هذه هي الصورة التي يجب أن يراها الركاب؟',
      );
  static String get profilePhotoConfirmYes => _t(
        'Ja, opslaan',
        en: 'Yes, save',
        es: 'Sí, guardar',
        ar: 'نعم، حفظ',
      );
  static String get profilePhotoLockedMessage => _t(
        'Je hebt de limiet van 2 wijzigingen voor profielfoto’s bereikt. Neem contact op met de ondersteuning voor een nieuwe wijziging.',
        en: 'You have reached the limit of 2 profile photo changes. Contact support for another change.',
        es: 'Has alcanzado el límite de 2 cambios de foto de perfil. Contacta con soporte para otro cambio.',
        ar: 'وصلت إلى حد تغيير صورة الملف الشخصي مرتين. تواصل مع الدعم لتغيير آخر.',
      );
  static String profilePhotoChangesRemaining(int remaining) => remaining <= 0
      ? _t(
          'Profielfoto-wijzigingen gebruikt (2/2). Volgende wijziging via de ondersteuning.',
          en: 'Profile photo changes used (2/2). Next change through support.',
          es: 'Cambios de foto de perfil usados (2/2). El siguiente cambio será por soporte.',
          ar: 'تم استخدام تغييرات صورة الملف الشخصي (2/2). التغيير التالي عبر الدعم.',
        )
      : _t(
          'Je kunt je profielfoto nog $remaining keer wijzigen.',
          en: 'You can change your profile photo $remaining more time(s).',
          es: 'Puedes cambiar tu foto de perfil $remaining vez/veces más.',
          ar: 'يمكنك تغيير صورة ملفك الشخصي $remaining مرة أخرى.',
        );
  static String get profilePhotoUploadFailed => _t(
        'Foto uploaden mislukt. Probeer opnieuw.',
        en: 'Photo upload failed. Try again.',
        es: 'No se pudo subir la foto. Inténtalo de nuevo.',
        ar: 'فشل تحميل الصورة. حاول مرة أخرى.',
      );
  static String get profilePhotoUploadConnectionError => _t(
        'Verbindingsfout bij uploaden. Controleer uw WiFi of schakel over naar mobiele data en probeer opnieuw.',
        en: 'Connection error during upload. Check Wi-Fi or switch to mobile data and try again.',
        es: 'Error de conexión al subir. Revisa el Wi-Fi o cambia a datos móviles e inténtalo de nuevo.',
        ar: 'خطأ في الاتصال أثناء التحميل. تحقق من Wi-Fi أو انتقل إلى بيانات الهاتف وحاول مرة أخرى.',
      );
  static String get profileNameSaved => _t(
        'Naam opgeslagen.',
        en: 'Name saved.',
        es: 'Nombre guardado.',
        ar: 'تم حفظ الاسم.',
      );
  static String get profileNameSaveFailed => _t(
        'Naam opslaan mislukt.',
        en: 'Could not save name.',
        es: 'No se pudo guardar el nombre.',
        ar: 'تعذر حفظ الاسم.',
      );
  static String get profilePhotoSaved => _t(
        'Profielfoto opgeslagen.',
        en: 'Profile photo saved.',
        es: 'Foto de perfil guardada.',
        ar: 'تم حفظ صورة الملف الشخصي.',
      );
  static String get profileDriverSetupFailed => _t(
        'Chauffeursprofiel aanmaken mislukt. Controleer je verbinding of probeer opnieuw.',
        en: 'Could not create driver profile. Check your connection or try again.',
        es: 'No se pudo crear el perfil de conductor. Revisa tu conexión o inténtalo de nuevo.',
        ar: 'تعذر إنشاء ملف السائق. تحقق من اتصالك أو حاول مرة أخرى.',
      );
  static String get profileEditSheetTitle => _t(
        'Je profiel',
        en: 'Your profile',
        es: 'Tu perfil',
        ar: 'ملفك الشخصي',
      );
  static String get profileEditSheetSubtitle => _t(
        'Passagiers zien je naam en foto bij het boeken.',
        en: 'Riders see your name and photo when booking.',
        es: 'Los pasajeros ven tu nombre y foto al reservar.',
        ar: 'يرى الركاب اسمك وصورتك عند الحجز.',
      );
  static String get profileTapHint => _t(
        'Tik om naam en foto toe te voegen',
        en: 'Tap to add name and photo',
        es: 'Toca para añadir nombre y foto',
        ar: 'اضغط لإضافة الاسم والصورة',
      );
  static String get profilePhotoAddHint => _t(
        'Tik op de foto om uit de galerij te kiezen',
        en: 'Tap the photo to choose from gallery',
        es: 'Toca la foto para elegir desde la galería',
        ar: 'اضغط على الصورة للاختيار من المعرض',
      );
  static String get profileRatingHint => _t(
        'Alle chauffeurs beginnen op 5,0 sterren; je score daalt als klachten worden bevestigd.',
        en: 'All drivers start at 5.0 stars; your score only drops when complaints are confirmed.',
        es: 'Todos los conductores empiezan con 5,0 estrellas; tu puntuación baja solo si se confirman quejas.',
        ar: 'يبدأ كل السائقين بتقييم 5.0 نجوم؛ ينخفض تقييمك فقط عند تأكيد الشكاوى.',
      );
  static String get vehicleCardTitle => _t(
        'Voertuig dat passagiers zien',
        en: 'Vehicle riders see',
        es: 'Vehículo que ven los pasajeros',
        ar: 'المركبة التي يراها الركاب',
      );
  static String get vehicleCardSubtitle => _t(
        'Kenteken + foto’s zichtbaar voor passagiers vóór ophalen.',
        en: 'Plate and photos are visible to riders before pickup.',
        es: 'La matrícula y fotos son visibles antes de la recogida.',
        ar: 'تظهر اللوحة والصور للركاب قبل الوصول.',
      );
  static String get vehiclePhotosLimitHint => _t(
        'Upload maximaal 2 voertuigfoto’s. Extra wijzigingen via de ondersteuning.',
        en: 'Upload up to 2 vehicle photos. Extra changes through support.',
        es: 'Sube hasta 2 fotos del vehículo. Cambios extra por soporte.',
        ar: 'حمّل حتى صورتين للمركبة. التغييرات الإضافية عبر الدعم.',
      );
  static String get vehiclePhotoLimitReached => _t(
        'Je hebt al 2 voertuigfoto’s geüpload. Neem contact op met de ondersteuning om ze te wijzigen.',
        en: 'You have already uploaded 2 vehicle photos. Contact support to change them.',
        es: 'Ya subiste 2 fotos del vehículo. Contacta con soporte para cambiarlas.',
        ar: 'لقد حمّلت صورتين للمركبة بالفعل. تواصل مع الدعم لتغييرهما.',
      );
  static String get addVehiclePhoto => _t(
        'Voertuigfoto toevoegen',
        en: 'Add taxi photo',
        es: 'Añadir foto del vehículo',
        ar: 'إضافة صورة للمركبة',
      );
  static String get replaceVehiclePhoto => _t(
        'Voertuigfoto vervangen',
        en: 'Replace taxi photo',
        es: 'Cambiar foto del vehículo',
        ar: 'استبدال صورة المركبة',
      );
  static String get vehiclePhotoRiderPreviewHint => _t(
        'Deze foto zien passagiers voordat je aankomt.',
        en: 'Riders see this photo before you arrive.',
        es: 'Los pasajeros ven esta foto antes de que llegues.',
        ar: 'يرى الركاب هذه الصورة قبل وصولك.',
      );
  static String get vehiclePhotoGuidanceTitle => _t(
        'Kies je beste taxifoto',
        en: 'Choose your best taxi photo',
        es: 'Elige tu mejor foto del taxi',
        ar: 'اختر أفضل صورة للتاكسي',
      );
  static String get vehiclePhotoGuidanceBody => _t(
        'Gebruik een duidelijke voor- of zijkantfoto met zichtbaar kenteken. Dit helpt passagiers je auto snel herkennen.',
        en: 'Use a clear front or side photo with the plate visible. This helps riders recognize your car quickly.',
        es: 'Usa una foto clara frontal o lateral con la matrícula visible. Ayuda a los pasajeros a reconocer tu coche rápido.',
        ar: 'استخدم صورة واضحة من الأمام أو الجانب مع ظهور اللوحة. هذا يساعد الركاب على التعرف على سيارتك بسرعة.',
      );
  static String get vehiclePhotoTakePhoto => _t(
        'Foto maken',
        en: 'Take photo',
        es: 'Tomar foto',
        ar: 'التقاط صورة',
      );
  static String get vehiclePhotoChooseLibrary => _t(
        'Kies uit bibliotheek',
        en: 'Choose from library',
        es: 'Elegir de la galería',
        ar: 'اختيار من المكتبة',
      );
  static String get vehiclePhotoPreviewTitle => _t(
        'Passagierspreview',
        en: 'Rider preview',
        es: 'Vista del pasajero',
        ar: 'معاينة للراكب',
      );
  static String get vehiclePhotoUseThis => _t(
        'Deze foto gebruiken',
        en: 'Use this photo',
        es: 'Usar esta foto',
        ar: 'استخدم هذه الصورة',
      );
  static String get vehiclePhotoRetake => _t(
        'Opnieuw kiezen',
        en: 'Retake',
        es: 'Volver a elegir',
        ar: 'إعادة الاختيار',
      );
  static String get vehiclePhotoSaved => _t(
        'Voertuigfoto opgeslagen.',
        en: 'Taxi photo saved.',
        es: 'Foto del vehículo guardada.',
        ar: 'تم حفظ صورة المركبة.',
      );
  static String get vehiclePhotoMissingStatus => _t(
        'Foto ontbreekt',
        en: 'Photo missing',
        es: 'Falta foto',
        ar: 'الصورة مفقودة',
      );
  static String get vehiclePhotoUploadedStatus => _t(
        'Foto geüpload',
        en: 'Photo uploaded',
        es: 'Foto subida',
        ar: 'تم رفع الصورة',
      );
  static String get vehicleDetails => _t(
        'Voertuigdetails',
        en: 'Vehicle details',
        es: 'Detalles del vehículo',
        ar: 'تفاصيل المركبة',
      );
  static String get vehiclePhotoUploadFailed => _t(
        'Voertuigfoto uploaden mislukt. Probeer opnieuw.',
        en: 'Vehicle photo upload failed. Try again.',
        es: 'No se pudo subir la foto del vehículo. Inténtalo de nuevo.',
        ar: 'فشل تحميل صورة المركبة. حاول مرة أخرى.',
      );
  static String vehicleApkExpiryLine(String value) => _t(
        'APK · $value',
        en: 'APK · $value',
        es: 'APK · $value',
        ar: 'APK · $value',
      );

  /// Web founding-driver flow — welcome after `claim-founding-driver` Edge Function.
  static const String foundingDriverWelcomeTitle = 'Founding Driver';
  static const String foundingDriverWelcomeBody =
      'Welkom terug! Je chauffeur-account is gekoppeld aan je aanmelding op heycaby.nl.';
  static String foundingDriverWelcomeNumber(int n) =>
      'Je Founding Driver-nummer is #$n. Je gegevens uit het formulier staan al in je profiel.';
  static const String foundingDriverWelcomeNext =
      'Voeg nog een profielfoto en een foto van je voertuig toe om klaar te zijn.';
  static const String foundingDriverProfilePhotoCta = 'Profielfoto';
  static const String foundingDriverVehiclePhotoCta = 'Voertuigfoto';
  static const String foundingDriverClose = 'Sluiten';
  static const String foundingMember = 'Founding Member';
  static String get member => _t(
        'Lid',
        en: 'Member',
        es: 'Miembro',
        ar: 'عضو',
      );
  static String foundingMemberNumber(int n) => 'Founding Member #$n';
  static String get documents => _t(
        'Documenten',
        en: 'Documents',
        es: 'Documentos',
        ar: 'المستندات',
      );
  static String get complianceAndDocuments => _t(
        'Professioneel profiel',
        en: 'Professional profile',
        es: 'Perfil profesional',
        ar: 'الملف المهني',
      );
  static String get goOnlineChecklistTitle => _t(
        'Vereist om te starten',
        en: 'Required to start driving',
        es: 'Necesario para empezar',
        ar: 'مطلوب لبدء القيادة',
      );
  static String get goOnlineChecklistHint => _t(
        'Alleen deze servercheck kan je tegenhouden om online te gaan. Alles hieronder helpt je profiel sterker maken en kan later worden afgerond.',
        en: 'Only this server checklist can stop you from going online. Everything below improves your profile and can be completed later.',
        es: 'Solo esta lista del servidor puede impedirte conectarte. Todo lo demás mejora tu perfil y puede completarse después.',
        ar: 'هذه القائمة من الخادم فقط يمكن أن تمنعك من الاتصال. كل ما يلي يحسن ملفك ويمكن إكماله لاحقاً.',
      );
  static const String goOnlineChecklistRefresh = 'Status vernieuwen';
  static const String complianceSubtitle =
      'De Nederlandse taxiwet (Wpv 2000) vereist deze onderdelen. HeyCaby controleert ze via ILT, RDW, KvK of handmatige beoordeling.';
  static String get complianceSubtitleV2 => _t(
        'Rond alleen de vereisten af die nodig zijn om te starten. Aanvullende documenten blijven beschikbaar voor je professionele profiel.',
        en: 'Complete only what is needed to start. Additional documents stay available for your professional profile.',
        es: 'Completa solo lo necesario para empezar. Los documentos adicionales siguen disponibles para tu perfil profesional.',
        ar: 'أكمل فقط المطلوب للبدء. تبقى المستندات الإضافية متاحة لملفك المهني.',
      );
  static const String complianceFooterV2 =
      'Aanvullende documenten kunnen later gevraagd worden naarmate je meer ritten rijdt. APK volgt uit je kenteken (RDW).';
  static String get complianceRequiredNowLabel => _t(
        'Nu nodig',
        en: 'Required now',
        es: 'Necesario ahora',
        ar: 'مطلوب الآن',
      );
  static String get complianceRecommendedNextLabel => _t(
        'Later afronden',
        en: 'Complete later',
        es: 'Completar después',
        ar: 'أكمل لاحقاً',
      );
  static String get complianceRecommendedNextHint => _t(
        'Deze onderdelen blokkeren je niet bij de lancering. Ze maken je profiel completer en makkelijker te beoordelen door support.',
        en: 'These do not block launch access. They make your profile more complete and easier for support to review.',
        es: 'Estos puntos no bloquean el acceso de lanzamiento. Hacen tu perfil más completo y fácil de revisar.',
        ar: 'هذه العناصر لا تمنع الوصول عند الإطلاق. إنها تجعل ملفك أكثر اكتمالاً وأسهل للمراجعة.',
      );
  static const String chauffeurspasHintV2 =
      'Chauffeurspasnummer (8–12 cijfers)';
  static const String insurancePhotoOnFile = 'Verzekeringsdocument aanwezig';
  static const String insurancePhotoTapToView =
      'Verzekeringsdocument aanwezig · Tik om te bekijken';
  static const String insurancePreviewTitle = 'Voorbeeld verzekeringsdocument';
  static const String insurancePreviewFailed =
      'Voorbeeld van verzekeringsdocument laden mislukt.';
  static const String kvkManualVerifyHint =
      'We controleren KvK-gegevens handmatig nadat je ze opslaat.';
  static const String kvkManualVerifyDetailed =
      'Vul je juiste KvK-nummer en geregistreerde bedrijfsadres in. '
      'Ons team controleert dit handmatig na indiening.';
  static String get kvkNumberAddressRequired => _t(
        'KvK-nummer en bedrijfsadres zijn vereist voor handmatige verificatie.',
        en: 'KvK number and business address are required for manual verification.',
        es: 'El número KvK y la dirección comercial son obligatorios para la verificación manual.',
        ar: 'رقم KvK وعنوان العمل مطلوبان للتحقق اليدوي.',
      );
  static String get kvkNumberLabel => _t(
        'KvK nummer (8 cijfers)',
        en: 'KvK number (8 digits)',
        es: 'Número KvK (8 dígitos)',
        ar: 'رقم KvK (8 أرقام)',
      );
  static String get kvkNumberInvalid => _t(
        'KvK nummer moet 8 cijfers hebben.',
        en: 'KvK number must be 8 digits.',
        es: 'El número KvK debe tener 8 dígitos.',
        ar: 'يجب أن يتكون رقم KvK من 8 أرقام.',
      );
  static String get kvkBusinessNameLabel => _t(
        'Bedrijfsnaam',
        en: 'Business name',
        es: 'Nombre de la empresa',
        ar: 'اسم الشركة',
      );
  static String get kvkBusinessAddressLabel => _t(
        'Vestigingsadres',
        en: 'Business address',
        es: 'Dirección comercial',
        ar: 'عنوان العمل',
      );
  static String get documentInformationSaved => _t(
        'Gegevens opgeslagen.',
        en: 'Information saved.',
        es: 'Información guardada.',
        ar: 'تم حفظ المعلومات.',
      );
  static String get documentSaveFailed => _t(
        'Opslaan mislukt. Controleer je gegevens en probeer opnieuw.',
        en: 'Save failed. Check your details and try again.',
        es: 'No se pudo guardar. Revisa tus datos e inténtalo de nuevo.',
        ar: 'فشل الحفظ. تحقق من بياناتك وحاول مرة أخرى.',
      );
  static const String complianceOverall = 'Profielstatus';
  static const String complianceProgressTitle = 'Professioneel profiel';
  static String complianceProgressCount(int done, int total) =>
      '$done/$total afgerond';
  static String complianceProgressPercent(int percent) => '$percent%';
  static const String complianceManualLicensePending =
      'Rijbewijs wacht op handmatige goedkeuring door beheer.';
  static const String docChauffeurspas = 'Chauffeurspas';
  static const String docRijbewijs = 'Rijbewijs';
  static const String docVog = 'VOG (verklaring omtrent gedrag)';
  static const String docTaxidiploma = 'Taxidiploma';
  static const String docTaxiInsurance = 'Taxiverzekering';
  static const String docKvk = 'KvK-inschrijving';
  static const String docApkVehicle = 'Voertuig & APK';
  static const String statusPending = 'In beoordeling';
  static const String statusActionNeeded = 'Actie nodig';
  static const String statusExpired = 'Verlopen';
  static const String statusImplied = 'Gedekt door chauffeurspas';
  static const String statusNotSet = 'Niet ingediend';
  static const String expiresOn = 'Verloopt';
  static const String chauffeurspasHint = '8-cijferig chauffeurspasnummer';
  static const String verifyWithIlt = 'Verifiëren via ILT';
  static const String verifying = 'Controleren bij ILT…';
  static const String chauffeurspasInvalidLength =
      'Vul het 8-cijferige nummer op je chauffeurspas in.';
  static const String chauffeurspasVerifiedOk = 'Chauffeurspas geverifieerd.';
  static const String chauffeurspasVerifyFailed =
      'Verificatie mislukt. Probeer opnieuw of neem contact op met de ondersteuning.';
  static const String complianceUploadPortal =
      'Rond verificatie hieronder met Veriff af, of uploads worden door de ondersteuning afgehandeld indien ingeschakeld.';
  static const String vehiclePlateRdw =
      'Kenteken wordt gecontroleerd bij RDW (taxiregistratie & APK).';
  static const String complianceCompliant = 'Compliant';
  static const String complianceIncomplete = 'Onvolledig';
  static const String compliancePending = 'In beoordeling';
  static const String complianceSuspended = 'Geschorst';
  static const String complianceRejected = 'Afgewezen';
  static String get support => _t(
        'Ondersteuning',
        en: 'Support',
        es: 'Soporte',
        ar: 'الدعم',
      );
  static String get settings => _t(
        'Instellingen',
        en: 'Settings',
        es: 'Ajustes',
        ar: 'الإعدادات',
      );
  static String get billing => platformBalanceTitle;
  static const String instellingen = 'Instellingen';
  static const String tarieven = 'Tarieven';
  static const String uitloggen = 'Uitloggen';
  static String get logout => _t(
        'Uitloggen',
        en: 'Log out',
        es: 'Cerrar sesión',
        ar: 'تسجيل الخروج',
      );
  static String get deleteAccount => _t(
        'Account verwijderen',
        en: 'Delete account',
        es: 'Eliminar cuenta',
        ar: 'حذف الحساب',
      );
  static const String deleteAccountConfirmTitle =
      'Account permanent verwijderen?';
  static const String deleteAccountConfirmBody =
      'Hiermee worden je chauffeursprofiel en inlog bij HeyCaby verwijderd. Dit kan niet ongedaan worden gemaakt.';
  static const String deleteAccountTypeDeleteHint =
      'Typ DELETE om te bevestigen';
  static const String deleteAccountTypeDeleteError =
      'Typ het woord DELETE (hoofdletters maakt niet uit) en tik daarna opnieuw op Account verwijderen.';
  static const String deleteAccountFailed =
      'Account verwijderen mislukt. Probeer opnieuw of neem contact op met de ondersteuning.';
  static const String deleteAccountSuccessModalTitle = 'Account verwijderd';
  static const String deleteAccountSuccessModalBody =
      'Je account is verwijderd. Je kunt de app nu van je telefoon verwijderen als je wilt.';
  static const String deleteAccountSuccessModalCta = 'Verder';
  static const String chatWithRiderTitle = 'Chat met passagier';
  static const String chatTypeMessageHint = 'Typ een bericht…';
  static const String blockRider = 'Passagier blokkeren';
  static const String blockRiderConfirm =
      'Je ziet geen nieuwe berichten meer van deze passagier in deze rit-chat.';
  static const String reportRider = 'Passagier melden';
  static const String reportRiderTitle = 'Deze passagier melden?';
  static const String reportRiderBody =
      'HeyCaby beoordeelt deze rit-chat. Je kunt hieronder details toevoegen (optioneel).';
  static const String reportReasonHint = 'Wat is er gebeurd? (optioneel)';
  static const String reportSubmitted =
      'Bedankt — we hebben je melding ontvangen.';
  static const String chatBlockFailed = 'Blokkeerlijst bijwerken mislukt.';
  static const String chatReportFailed =
      'Melding versturen mislukt. Probeer opnieuw.';
  static const String chatOnlyDuringActiveRideTitle =
      'Chat beschikbaar tijdens actieve ritten';
  static const String chatOnlyDuringActiveRideBody =
      'Je kunt de passagier alleen berichten zolang deze rit actief is.';
  static const String notifyRiderOutside = 'Ping: ik sta buiten';
  static const String notifyRiderNearby = 'Ping: onderweg';
  static const String notifyRiderSent = 'Ping verstuurd.';
  static const String notifyRiderFailed =
      'Ping versturen mislukt. Probeer opnieuw.';
  static const String pingRiderSent = notifyRiderSent;
  static const String pingRiderFailed = notifyRiderFailed;
  static String pingCooldownMessage(int seconds) =>
      'Even wachten — ping opnieuw over ${seconds}s.';
  static String pingCooldownButton(int seconds) => 'Wacht ${seconds}s…';
  static const String communicationCenterTitle = 'Communicatie';
  static const String communicationCenterSubtitle =
      'Geen telefoonnummers — chat of stuur een snelle status.';
  static const String communicationChat = 'Chat met reiziger';
  static const String communicationQuickActions = 'Snelle acties';
  static const String communicationOpen = 'Communicatie';
  static const String pingOnMyWay = 'Onderweg';
  static const String pingOutside = 'Ik sta buiten';
  static const String pingArrived = 'Aangekomen';
  static const String pingRunningLate = 'Ik heb vertraging';
  static const String pingTrafficDelay = 'Vertraging door verkeer';
  static const String pingCantFindRider = 'Kan je niet vinden';
  static const String pingThanks = 'Bedankt!';
  static const String communicationNearPickupHint =
      'Je bent in de buurt van het ophaalpunt — snelle acties aangepast.';
  static const String communicationPingHistory = 'Ping geschiedenis';
  static const String pingHistoryEmpty = 'Nog geen pings voor deze rit.';
  static const String pingDeliverySent = 'Verzonden';
  static const String pingDeliveryDelivered = 'Bezorgd op telefoon';
  static const String pingDeliveryOpened = 'Geopend door reiziger';
  static const String pingAutomaticBadge = 'Automatisch';
  static const String smartPingOnMyWayTitle = 'Onderweg ping sturen?';
  static const String smartPingOnMyWayBody =
      'Laat je passagier weten dat je onderweg bent — één tik.';
  static const String smartPingOutsideTitle = 'Je bent bij het ophaalpunt';
  static const String smartPingOutsideBody =
      'Passagier informeren dat je buiten staat?';
  static const String smartPingSend = 'Versturen';
  static const String smartPingDismiss = 'Niet nu';
  static const String sendOutsideMessage = 'Bericht sturen: ik sta buiten';
  static const String outsideMessageSent = 'Bericht naar passagier verstuurd.';
  static const String outsideMessageFailed = 'Bericht versturen mislukt.';
  static const String collectPaymentTitle = 'Betaal eerst voordat je afsluit';
  static const String collectPaymentBody =
      'Vergeet niet het tarief bij de passagier te innen voordat je deze rit afrondt.';
  static String collectPaymentAmount(String amountLabel) =>
      'Innen: $amountLabel nu.';
  static const String collectPaymentContinue = 'Ik heb betaald ontvangen';
  static const String collectPaymentBack = 'Terug';
  static String get recordPaymentReceived => _t(
        'Betaling vastleggen',
        en: 'Record payment',
        es: 'Registrar pago',
        ar: 'تسجيل الدفع',
      );
  static String get expectedFareLabel => _t(
        'Verwacht tarief',
        en: 'Expected fare',
        es: 'Tarifa esperada',
        ar: 'الأجرة المتوقعة',
      );
  static String get fareBreakdownTitle => _t(
        'Tariefopbouw',
        en: 'Fare breakdown',
        es: 'Desglose de tarifa',
        ar: 'تفاصيل الأجرة',
      );
  static String get rideFareLabel => _t(
        'Rittarief',
        en: 'Ride fare',
        es: 'Tarifa del viaje',
        ar: 'أجرة الرحلة',
      );
  static String get waitingFeeLabel => _t(
        'Wachttijd',
        en: 'Waiting time',
        es: 'Tiempo de espera',
        ar: 'وقت الانتظار',
      );
  static String get waitingFeeWaived => _t(
        'Kwijtgescholden',
        en: 'Waived',
        es: 'Condonado',
        ar: 'تم التنازل',
      );
  static String get waitingFeeWaivedTitle => _t(
        'Wachttijd kwijtgescholden',
        en: 'Waiting fee waived',
        es: 'Tiempo de espera condonado',
        ar: 'تم التنازل عن رسوم الانتظار',
      );
  static String get waitingFeeWaivedBody => _t(
        'De reiziger is direct geïnformeerd.',
        en: 'The rider has been notified.',
        es: 'El pasajero ha sido informado.',
        ar: 'تم إشعار الراكب.',
      );
  static String get waitingFeeFreeTimeTitle => _t(
        'Gratis ophaaltijd',
        en: 'Free pickup time',
        es: 'Tiempo gratis de recogida',
        ar: 'وقت الالتقاط المجاني',
      );
  static String get waitingFeeFreeTimeBody => _t(
        'Wachttijd start na de gratis tijd.',
        en: 'Waiting fee starts after the free time.',
        es: 'El tiempo de espera empieza después del tiempo gratis.',
        ar: 'تبدأ رسوم الانتظار بعد الوقت المجاني.',
      );
  static String get waitingFeeAddedSoFar => _t(
        'toegevoegd tot nu toe',
        en: 'added so far',
        es: 'añadido hasta ahora',
        ar: 'أضيف حتى الآن',
      );
  static String waitingFeeRateLabel(String amount) => _t(
        'Tarief: $amount/min',
        en: 'Rate: $amount/min',
        es: 'Tarifa: $amount/min',
        ar: 'السعر: $amount/دقيقة',
      );
  static String get waitingFeeRateNotSet => _t(
        'Wachttarief niet ingesteld',
        en: 'Waiting rate not set',
        es: 'Tarifa de espera no configurada',
        ar: 'لم يتم تحديد سعر الانتظار',
      );
  static String get waitingFeeWaiveAction => _t(
        'Wachttijd kwijtschelden',
        en: 'Waive waiting fee',
        es: 'Condonar espera',
        ar: 'التنازل عن رسوم الانتظار',
      );
  static String get waitingFeeWaivedNotice => _t(
        'Wachttijd kwijtgescholden. De reiziger is geïnformeerd.',
        en: 'Waiting fee waived. Rider has been notified.',
        es: 'Tiempo de espera condonado. El pasajero ha sido informado.',
        ar: 'تم التنازل عن رسوم الانتظار. تم إشعار الراكب.',
      );
  static String get totalToRecordLabel => _t(
        'Totaal vastleggen',
        en: 'Total to record',
        es: 'Total a registrar',
        ar: 'الإجمالي للتسجيل',
      );
  static String get paidAmountLabel => _t(
        'Betaald bedrag',
        en: 'Paid amount',
        es: 'Importe pagado',
        ar: 'المبلغ المدفوع',
      );
  static String get paymentMethodLabel => _t(
        'Betaalmethode',
        en: 'Payment method',
        es: 'Método de pago',
        ar: 'طريقة الدفع',
      );
  static const String accountingNoteLabel =
      'Administratieve notitie (optioneel)';
  static const String sendReceipt = 'Bon versturen';
  static const String sendingReceipt = 'Versturen…';
  static const String receiptSent = 'Bon verstuurd.';
  static const String receiptSendFailed = 'Bon versturen mislukt.';
  static const String logoutConfirm = 'Weet u zeker dat u wilt uitloggen?';

  /// Destructive confirm in logout dialog.
  static const String logoutConfirmAction = 'Uitloggen';
  static const String menu = 'Menu';
  static const String ride = 'rit';
  static String get rides => _t(
        'ritten',
        en: 'rides',
        es: 'viajes',
        ar: 'رحلات',
      );
  static const String now = 'Nu';
  static String get homeLiveRidesTitle => _t(
        'Live ritten',
        en: 'Live rides',
        es: 'Viajes en vivo',
        ar: 'رحلات مباشرة',
      );
  static String get homeActiveRideTitle => _t(
        'Actieve rit',
        en: 'Active ride',
        es: 'Viaje activo',
        ar: 'رحلة نشطة',
      );
  static String get homeIncomingRides => _t(
        'Binnenkomende ritten',
        en: 'Incoming rides',
        es: 'Viajes entrantes',
        ar: 'رحلات واردة',
      );
  static String get homeNoLiveRidesOffline => _t(
        'Ga online om live ritaanvragen in jouw zone te zien.',
        en: 'Go online to see live ride requests in your zone.',
        es: 'Conéctate para ver solicitudes de viaje en tu zona.',
        ar: 'اتصل لرؤية طلبات الرحلات المباشرة في منطقتك.',
      );
  static String get statusControlOfflineHint => homeNoLiveRidesOffline;
  static String get statusControlBreakHint => _t(
        'Je pauze is actief. Ga online om ritten te zien.',
        en: 'Your break is active. Go online to see rides.',
        es: 'Tu descanso está activo. Conéctate para ver viajes.',
        ar: 'استراحتك نشطة. اتصل لرؤية الرحلات.',
      );
  static String get statusControlOnlineHint => _t(
        'Je bent live in jouw zone.',
        en: 'You are live in your zone.',
        es: 'Estás activo en tu zona.',
        ar: 'أنت نشط في منطقتك.',
      );
  static String get homeNoLiveRidesOnline => _t(
        'Geen open ritaanvragen — we laten het weten zodra er iets binnenkomt.',
        en: 'No open ride requests — we’ll let you know when one arrives.',
        es: 'No hay solicitudes abiertas; te avisaremos cuando llegue una.',
        ar: 'لا توجد طلبات مفتوحة، سنخبرك عند وصول طلب.',
      );
  static String get homeLiveRidesOnBreak => _t(
        'Hervat dienst om nieuwe aanvragen te ontvangen.',
        en: 'Resume your shift to receive new requests.',
        es: 'Reanuda tu turno para recibir nuevas solicitudes.',
        ar: 'استأنف ورديتك لاستقبال طلبات جديدة.',
      );
  static String get homeViewAllRides => _t(
        'Alle beschikbare ritten',
        en: 'All available rides',
        es: 'Todos los viajes disponibles',
        ar: 'كل الرحلات المتاحة',
      );
  static String get homeRidesSection => _t(
        'Ritten',
        en: 'Rides',
        es: 'Viajes',
        ar: 'الرحلات',
      );
  static String get homeSettingsSection => settings;
  static String get homeShowTodayOnMap => _t(
        'Ritten vandaag op kaart tonen',
        en: 'Show today’s rides on map',
        es: 'Mostrar los viajes de hoy en el mapa',
        ar: 'عرض رحلات اليوم على الخريطة',
      );
  static String homeMatchingScheduledCount(int count) => _t(
        '$count passend',
        en: '$count matching',
        es: '$count compatibles',
        ar: '$count مناسبة',
      );
  static String homePlannedScheduledCount(int count) => _t(
        '$count gepland',
        en: '$count planned',
        es: '$count programados',
        ar: '$count مجدولة',
      );
  static String homeTodayRidesCount(int count) => count == 0
      ? _t(
          'Nog geen ritten',
          en: 'No rides yet',
          es: 'Aún no hay viajes',
          ar: 'لا توجد رحلات بعد',
        )
      : _t(
          '$count ritten',
          en: '$count rides',
          es: '$count viajes',
          ar: '$count رحلات',
        );
  static String get loading => _t(
        'Laden...',
        en: 'Loading...',
        es: 'Cargando...',
        ar: 'جار التحميل...',
      );
  static String get off => _t(
        'Uit',
        en: 'Off',
        es: 'Desactivado',
        ar: 'متوقف',
      );
  static String homeAvailableCount(int count) => _t(
        '$count beschikbaar',
        en: '$count available',
        es: '$count disponibles',
        ar: '$count متاحة',
      );
  static const String scheduled = 'Gepland';
  static const String requests = 'Aanvragen';
  static const String confirmed = 'Bevestigd';
  static const String marketplace = 'Marktplaats';
  static String get announcements => _t(
        'Aankondigingen',
        en: 'Announcements',
        es: 'Anuncios',
        ar: 'الإعلانات',
      );
  static String get rideSwap => _t(
        'Ritwissel',
        en: 'Ride swap',
        es: 'Intercambio de viaje',
        ar: 'تبديل الرحلة',
      );

  /// How Ride Swap works — title (swap screen, sheet, help).
  static const String rideSwapHowTitle = 'Hoe Ritwissel werkt';
  static const String rideSwapHowParagraph1 =
      'Ritwissel maakt het mogelijk om ritten soepel door te laten gaan wanneer plannen veranderen.';
  static const String rideSwapHowParagraph2 =
      'Wanneer een chauffeur een geboekte rit niet kan uitvoeren door tijdgebrek, vertraging of roosterwijzigingen, kan hij deze rit aanbieden zodat een andere beschikbare chauffeur deze eenvoudig kan overnemen.';
  static const String rideSwapWhatYouCanDoHeading = 'Wat je hier kunt doen';
  static const String rideSwapBulletViewSwaps =
      'Beschikbare wisselritten in jouw omgeving bekijken';
  static const String rideSwapBulletCheckDetails =
      'Details zoals ophaaltijd, route, urgentie en afstand controleren';
  static const String rideSwapBulletTakeRide =
      'Een rit overnemen die je met zekerheid kunt uitvoeren';
  static const String rideSwapBulletSupportColleague =
      'Een collega ondersteunen en zorgen dat de passagier geholpen blijft';
  static const String rideSwapPullToRefreshHint =
      'Trek naar beneden om te vernieuwen.';

  /// Empty-feed info sheet — line below the “how it works” copy.
  static const String rideSwapInfoModalFooter =
      'Tip: trek de lijst omlaag om te vernieuwen als er straks wél ritten zijn.';
  static const String rideSwapDontShowAgain = 'Niet meer tonen';
  static const String rideSwapGotIt = 'Begrepen';
  static const String rideSwapHowButton = rideSwapHowTitle;
  static const String swapFeedLoadFailed = 'Kon wisselritten niet laden';
  static const String swapDetailPickupPrefix = 'Ophaal:';
  static String rideSwapOpenCount(int n) => n == 0
      ? _t(
          'Geen open wissels',
          en: 'No open swaps',
          es: 'No hay cambios abiertos',
          ar: 'لا توجد تبديلات مفتوحة',
        )
      : n == 1
          ? _t(
              '1 open wissel',
              en: '1 open swap',
              es: '1 cambio abierto',
              ar: 'تبديل واحد مفتوح',
            )
          : _t(
              '$n open wissels',
              en: '$n open swaps',
              es: '$n cambios abiertos',
              ar: '$n تبديلات مفتوحة',
            );
  static String get swapOfferTitle => _t(
        'Rit aanbieden voor wissel',
        en: 'Offer ride for swap',
        es: 'Ofrecer viaje para cambio',
        ar: 'عرض الرحلة للتبديل',
      );
  static String get swapOfferBullet1 => _t(
        'Deze rit wordt zichtbaar voor andere chauffeurs in jouw netwerk.',
        en: 'This ride becomes visible to other drivers in your network.',
        es: 'Este viaje será visible para otros conductores de tu red.',
        ar: 'ستصبح هذه الرحلة مرئية للسائقين الآخرين في شبكتك.',
      );
  static String get swapOfferBullet2 => _t(
        'Zodra een chauffeur de rit overneemt, heb jij er geen toegang meer toe.',
        en: 'Once another driver takes it, you no longer have access to it.',
        es: 'Cuando otro conductor lo tome, ya no tendrás acceso.',
        ar: 'عندما يأخذها سائق آخر، لن تتمكن من الوصول إليها.',
      );
  static String get swapOfferBullet3 => _t(
        'De passagier ontvangt automatisch de gegevens van de nieuwe chauffeur.',
        en: 'The rider automatically receives the new driver details.',
        es: 'El pasajero recibe automáticamente los datos del nuevo conductor.',
        ar: 'يتلقى الراكب بيانات السائق الجديد تلقائيا.',
      );
  static String get swapOfferBullet4 => _t(
        'Wisselaanbiedingen verlopen automatisch als niemand ze oppakt. De rit blijft dan van jou.',
        en: 'Swap offers expire automatically if nobody takes them. The ride then stays yours.',
        es: 'Las ofertas de cambio caducan automáticamente si nadie las toma. El viaje seguirá siendo tuyo.',
        ar: 'تنتهي عروض التبديل تلقائيا إذا لم يأخذها أحد. عندها تبقى الرحلة لك.',
      );
  static String get swapOfferWhy => _t(
        'Waarom kun je niet rijden?',
        en: 'Why can’t you drive?',
        es: '¿Por qué no puedes conducir?',
        ar: 'لماذا لا يمكنك القيادة؟',
      );
  static String get swapReasonPersonal => _t(
        'Persoonlijke noodstoestand',
        en: 'Personal emergency',
        es: 'Emergencia personal',
        ar: 'حالة طارئة شخصية',
      );
  static String get swapReasonVehicle => _t(
        'Voertuigstoring',
        en: 'Vehicle breakdown',
        es: 'Avería del vehículo',
        ar: 'عطل في المركبة',
      );
  static String get swapReasonSchedule => _t(
        'Roosterconflict',
        en: 'Schedule conflict',
        es: 'Conflicto de horario',
        ar: 'تعارض في الجدول',
      );
  static String get swapReasonMedical => _t(
        'Medisch',
        en: 'Medical',
        es: 'Médico',
        ar: 'طبي',
      );
  static String get swapReasonOther => _t(
        'Anders',
        en: 'Other',
        es: 'Otro',
        ar: 'أخرى',
      );
  static String swapReasonLabel(String code) => switch (code) {
        'personal_emergency' => swapReasonPersonal,
        'vehicle_breakdown' => swapReasonVehicle,
        'schedule_conflict' => swapReasonSchedule,
        'medical' => swapReasonMedical,
        _ => swapReasonOther,
      };
  static String get swapOfferDetailHint => _t(
        'Toelichting (optioneel)',
        en: 'Details (optional)',
        es: 'Detalles (opcional)',
        ar: 'التفاصيل (اختياري)',
      );
  static String get swapOfferFailed => _t(
        'Mislukt',
        en: 'Failed',
        es: 'Falló',
        ar: 'فشل',
      );
  static String get swapOfferConfirm => _t(
        'Ja, rit aanbieden',
        en: 'Yes, offer ride',
        es: 'Sí, ofrecer viaje',
        ar: 'نعم، اعرض الرحلة',
      );
  static String get swapEmergencyWarn => _t(
        'Spoed: weinig tijd tot ophalen. Zorg dat de passagier op de hoogte is als niemand de rit overneemt.',
        en: 'Urgent: pickup is soon. Make sure the rider is informed if nobody takes the ride.',
        es: 'Urgente: queda poco para la recogida. Avisa al pasajero si nadie toma el viaje.',
        ar: 'عاجل: وقت الوصول قريب. تأكد من إبلاغ الراكب إذا لم يأخذ أحد الرحلة.',
      );
  static String get swapTooLate => _t(
        'Het is te laat om deze rit te wisselen. Bel de passagier en neem contact op met de ondersteuning.',
        en: 'It is too late to swap this ride. Call the rider and contact support.',
        es: 'Es demasiado tarde para cambiar este viaje. Llama al pasajero y contacta con soporte.',
        ar: 'فات الأوان لتبديل هذه الرحلة. اتصل بالراكب وتواصل مع الدعم.',
      );
  static String get swapListedBadge => _t(
        'Aangeboden voor wissel',
        en: 'Offered for swap',
        es: 'Ofrecido para cambio',
        ar: 'معروضة للتبديل',
      );
  static const String swapAction = 'Wisselen';
  static String get swapFeedEmpty => _t(
        'Momenteel zijn er geen actieve wisselritten beschikbaar.',
        en: 'There are no active swap rides available right now.',
        es: 'Ahora mismo no hay viajes de cambio activos disponibles.',
        ar: 'لا توجد رحلات تبديل نشطة متاحة حاليا.',
      );
  static const String swapClaim = 'Rit overnemen';
  static const String swapViewDetails = 'Bekijk details';
  static const String swapExpiresIn = 'Verloopt over';
  static const String swapUrgencyEmergency = 'SPOED';
  static const String swapUrgencyUrgent = 'URGENT';
  static const String swapUrgencyModerate = 'MATIG';
  static const String swapUrgencyStandard = 'STANDAARD';
  static const String swapDistanceToPickup = 'Jij bent';
  static const String swapKmFromPickup = 'km van ophaallocatie';
  static const String swapScheduleConflict =
      'Roosterconflict: deze wisselrit overlapt met jouw planning.';
  static const String swapConfirmTitle = 'Rit bevestigen';
  static const String swapConfirmBody =
      'Door te bevestigen neem jij deze rit volledig over. De rit staat meteen in jouw agenda.';
  static const String swapConfirmCta = 'Bevestigen';
  static const String swapCancelOffer = 'Annuleer wissel';
  static const String swapCancelledOk =
      'Wissel ingetrokken. De rit blijft bij jou.';
  static const String swapCancelConfirmTitle = 'Wissel intrekken?';
  static const String swapCancelConfirmBody =
      'De rit verdwijnt uit de wissellijst. Je houdt de rit zelf.';
  static const String swapCancelConfirmCta = 'Intrekken';
  static const String swapErrorNotCompliant =
      'Je profiel moet compliant zijn om een wisselrit over te nemen.';
  static const String swapErrorExpired = 'Deze wissel is verlopen.';
  static const String swapErrorNotAvailable =
      'Deze wissel is niet meer beschikbaar.';
  static const String swapErrorOwnSwap =
      'Je kunt je eigen aanbod niet overnemen.';
  static const String swapClaimSuccess = 'Rit overgenomen';
  static const String claimRide = 'Rit overnemen';
  static const String vehicle = 'Voertuig';
  static const String pickupDistance = 'Afstand tot ophalen';
  static const String acceptsCash = 'Contant geaccepteerd';
  static const String acceptsCard = 'Pinbetaling';
  static const String acceptsInvoice = 'Factuur (op rekening)';
  static const String acceptsTikkie = 'Tikkie geaccepteerd';
  static const String petFriendly = 'Huisdiervriendelijk';
  static const String wheelchairAccessible = 'Rolstoeltoegankelijk';
  static String get language => _t(
        'Taal',
        en: 'Language',
        es: 'Idioma',
        ar: 'اللغة',
      );
  static String get languageFollowDevice => _t(
        'Apparaattaal',
        en: 'Device language',
        es: 'Idioma del dispositivo',
        ar: 'لغة الجهاز',
      );
  static String get languageEnglish => _t(
        'Engels',
        en: 'English',
        es: 'Inglés',
        ar: 'الإنجليزية',
      );
  static String get languageDutch => _t(
        'Nederlands',
        en: 'Dutch',
        es: 'Neerlandés',
        ar: 'الهولندية',
      );
  static String get languageSpanish => _t(
        'Spaans',
        en: 'Spanish',
        es: 'Español',
        ar: 'الإسبانية',
      );
  static String get languageArabic => _t(
        'Arabisch',
        en: 'Arabic',
        es: 'Árabe',
        ar: 'العربية',
      );
  static const String theme = 'Thema';
  static String get preferences => _t(
        'Voorkeuren',
        en: 'Preferences',
        es: 'Preferencias',
        ar: 'التفضيلات',
      );
  static String get preferencesSubtitle => _t(
        'Voertuig, betalingen en hoe je in de app verschijnt.',
        en: 'Vehicle, payments, and how you appear in the app.',
        es: 'Vehículo, pagos y cómo apareces en la app.',
        ar: 'المركبة والمدفوعات وكيف تظهر في التطبيق.',
      );
  static const String hotspots = 'Hotspots';
  static const String hotspotsSubtitle =
      'Open Chauffeursradar en navigeer naar drukke zones';
  static const String hotspotsLiveMap = 'Live kaart';
  static const String hotspotsListView = 'Lijstweergave';
  static const String hotspotsFilterHigh = 'Hoge vraag';
  static const String hotspotsFilterMedium = 'Gemiddeld';
  static const String hotspotsFilterLow = 'Laag';
  static const String hotspotsFilters = 'Filters';
  static const String hotspotsFiltersReset = 'Alle gebieden tonen';
  static const String hotspotsBestAreaTitle = 'Beste gebied nu';
  static const String hotspotsLearnMore = 'Meer info';
  static const String hotspotsHighDemandBadge = 'Hoge vraag';
  static const String hotspotsSublineVeryBusy =
      'Hoge vraag • Korte wachttijden';
  static const String hotspotsSublineHighDemand =
      'Sterke vraag • Goede kans op ritten';
  static const String hotspotsSublineSteady = 'Gemiddelde activiteit';
  static const String hotspotsSublineQuiet = 'Lage vraag • Rustiger tempo';
  static String hotspotsOnlineDrivers(int n) => 'Chauffeurs online hier: $n';
  static String hotspotsRecentRides120m(int n) => 'Ritaanvragen (2 u): $n';
  static String hotspotsAvgOfferedFare(double v) =>
      'Gem. aangeboden tarief (2 u): €${v.toStringAsFixed(2)}';
  static const String hotspotsAvgFareUnavailable =
      'Gem. aangeboden tarief (2 u): —';
  static const String hotspotsRidersWaitingCaption =
      'Passagiers wachten (open aanvragen)';
  static const String hotspotsActivityCaption = 'Ritaanvragen';
  static const String hotspotsBestNow = 'Beste nu';
  static const String hotspotsNoData =
      'Nog geen hotspotdata. Trek om te vernieuwen als je online bent.';
  static const String hotspotsNavigateHere = 'Navigeer hierheen';
  static String hotspotsDemandLabel(String tier) => 'Vraag: $tier';
  static const String hotspotsDemandVeryHigh = 'Zeer hoog';
  static const String hotspotsDemandHigh = 'Hoog';
  static const String hotspotsDemandMedium = 'Gemiddeld';
  static const String hotspotsDemandLow = 'Laag';
  static const String hotspotsDemandVeryLow = 'Zeer laag';
  static const String hotspotsSmartTargetPrefix = 'Slim doel: ';
  static const String hotspotsTargetLogicPrefix = 'Doellogica: ';
  static const String hotspotsLearnTitle = 'Hoe hotspots werken';
  static const String hotspotsLearnBody =
      'Zones tonen live open ritaanvragen (passagiers die wachten), recente aanvragen, gemiddelde aangeboden tarieven '
      'en hoeveel chauffeurs er online zijn — allemaal uit HeyCaby-data. '
      'Gebruik rode en oranje zones voor de drukste gebieden.';
  static const String hotspotsLearnClose = 'Begrepen';
  static const String hotspotsGoogleMaps = 'Google Maps';
  static const String hotspotsWaze = 'Waze';
  static String get appSuggestion => _t(
        'Suggestie voor de app',
        en: 'Suggestion for the app',
        es: 'Sugerencia para la app',
        ar: 'اقتراح للتطبيق',
      );
  static String get appSuggestionSubtitle => _t(
        'Vertel ons welke functies je wilt zien',
        en: 'Tell us what features you want to see',
        es: 'Dinos qué funciones quieres ver',
        ar: 'أخبرنا بالميزات التي تريدها',
      );
  static String get appSuggestionIntro => _t(
        'Vertel ons welke functies je in de app wilt zien.\n\n'
        'Wij bouwen voor jou. Ons werk is om tools te maken waarmee je meer verdient, slimmer rijdt en elke dag controle voelt. '
        'Als iets jouw chauffeursleven makkelijker, sneller of winstgevender maakt, stuur het naar ons. '
        'Jouw stem bepaalt direct wat we hierna bouwen.',
        en: 'Tell us what features you want to see on the app.\n\n'
            'We work for you. Our job is to build the tools that help you earn more, drive smarter, and feel in control every day. '
            'If something would make your driver life easier, faster, or more profitable, send it to us. '
            'Your voice directly shapes what we build next.',
        es: 'Dinos qué funciones quieres ver en la app.\n\n'
            'Trabajamos para ti. Nuestro trabajo es crear herramientas que te ayuden a ganar más, conducir mejor y sentir control cada día. '
            'Si algo haría tu vida como conductor más fácil, rápida o rentable, envíanoslo. '
            'Tu voz influye directamente en lo que construimos.',
        ar: 'أخبرنا بالميزات التي تريد رؤيتها في التطبيق.\n\n'
            'نحن نعمل من أجلك. مهمتنا بناء أدوات تساعدك على كسب المزيد، والقيادة بذكاء، والشعور بالتحكم كل يوم. '
            'إذا كان هناك شيء يجعل حياة السائق أسهل أو أسرع أو أكثر ربحا، فأرسله لنا. '
            'صوتك يشكل مباشرة ما نبنيه بعد ذلك.',
      );
  static String get appSuggestionHint => _t(
        'Voorbeeld: voeg snelle tolweg-voorkeuren en spitsmeldingen toe in hotspot-navigatie.',
        en: 'Example: Add quick toll-road preference and city rush-hour alerts in hotspot navigation.',
        es: 'Ejemplo: añade preferencia rápida de peajes y alertas de hora punta en navegación a hotspots.',
        ar: 'مثال: أضف تفضيل طرق الرسوم السريع وتنبيهات أوقات الذروة في تنقل المناطق النشطة.',
      );
  static String get preferencesSectionVehicle => _t(
        'Voertuig & bereik',
        en: 'Vehicle & reach',
        es: 'Vehículo y alcance',
        ar: 'المركبة والنطاق',
      );
  static String get preferencesSectionPayments => _t(
        'Betalingen & toegankelijkheid',
        en: 'Payments & accessibility',
        es: 'Pagos y accesibilidad',
        ar: 'المدفوعات وإمكانية الوصول',
      );
  static String get preferencesSectionAppearance => _t(
        'Weergave',
        en: 'Appearance',
        es: 'Apariencia',
        ar: 'المظهر',
      );
  static String get preferencesSectionNavigation => _t(
        'Navigatie',
        en: 'Navigation',
        es: 'Navegación',
        ar: 'الملاحة',
      );
  static const String preferencesSectionSoundTest = 'Geluid testen';
  static const String preferencesSectionDebug = 'Debug (tijdelijk)';
  static const String preferencesSoundTestOnlineTitle =
      'Online-signaal voorbeeld';
  static const String preferencesSoundTestOnlineSubtitle =
      'Speel het geluid voor online status.';
  static const String preferencesSoundTestBreakTitle =
      'Pauze-signaal voorbeeld';
  static const String preferencesSoundTestBreakSubtitle =
      'Speel het geluid voor pauze-status.';
  static const String preferencesSoundTestOfflineTitle =
      'Offline-signaal voorbeeld';
  static const String preferencesSoundTestOfflineSubtitle =
      'Speel het geluid voor offline status.';
  static String get preferencesPlayPreviewTooltip => _t(
        'Speel voorbeeld van 10 seconden',
        en: 'Play 10s preview',
        es: 'Reproducir vista previa de 10 s',
        ar: 'تشغيل معاينة 10 ثوان',
      );
  static const String preferencesMolliePreviewTitle =
      'Mollie-checkout voorbeeld';
  static const String preferencesMolliePreviewSubtitle =
      'Open tijdelijk voorbeeldscherm voor checkout in de app.';
  static const String saveAction = 'Opslaan';
  static String get vehicleRdwTitle => _t(
        'Jouw voertuig',
        en: 'Your vehicle',
        es: 'Tu vehículo',
        ar: 'مركبتك',
      );
  static String get vehicleRdwSubtitle => _t(
        'Vul je kenteken in. We halen voertuiggegevens automatisch op bij RDW.',
        en: 'Enter your plate number. We automatically fetch vehicle details from RDW.',
        es: 'Introduce tu matrícula. Obtenemos automáticamente los datos del vehículo desde RDW.',
        ar: 'أدخل رقم اللوحة. سنجلب بيانات المركبة تلقائيا من RDW.',
      );
  static String get vehicleMake => _t(
        'Merk',
        en: 'Make',
        es: 'Marca',
        ar: 'الشركة',
      );
  static String get vehicleModel => _t(
        'Model',
        en: 'Model',
        es: 'Modelo',
        ar: 'الطراز',
      );
  static String get vehicleApk => _t(
        'APK',
        en: 'APK',
        es: 'APK',
        ar: 'APK',
      );
  static const String onboardingPlateFlowTitle = 'Start as a driver';
  static const String onboardingPlateTitle = 'Your taxi';
  static const String onboardingPlateSubtitle =
      'Enter your plate number — we fetch vehicle details from RDW. '
      'Then you continue to the terms.';
  static const String onboardingPlateContinue = 'Continue to terms';
  static const String onboardingPlateContinueGoOnline = 'Continue';
  static const String goOnlinePlateSubtitle =
      'Before you can go online, we verify your taxi plate with RDW.';
  static const String goOnlineOnboardingReadyHint =
      'Plate and terms are ready. Swipe again to go online.';
  static const String onboardingPlateSaveFailed =
      'Vehicle save failed. Try again or contact support.';
  static const String startShiftFlowTitle = 'Start shift';
  static const String startShiftVerifiedTitle = 'Taxi verified';
  static const String startShiftActiveTitle = 'This taxi is already active';
  static const String startShiftActiveBody =
      'This taxi is currently being used in HeyCaby. '
      'Only one driver can be active with the same taxi at a time.';
  static const String startShiftActiveFootnote =
      'Start your shift: we will start a Secure Shift Handover™. '
      'The current driver gets time to respond. After that you can continue.';

  static const String shiftHandoverBrandName = 'Secure Shift Handover™';
  static const String shiftHandoverWaitingTitle = 'Secure Shift Handover™';
  static const String shiftHandoverWaitingBody =
      'The current driver has been notified. '
      'Your shift starts automatically when the waiting time is over, '
      'unless they are still on a ride.';
  static const String shiftHandoverWaitingEta = 'Maximum wait';
  static const String shiftHandoverQueuedRideTitle = 'Your request is queued';
  static const String shiftHandoverQueuedRideBody =
      'The taxi is on a ride. Your shift starts automatically when that ride is complete.';
  static const String shiftHandoverQueuedRideSubtitle =
      'You do not need to request again.';
  static const String shiftHandoverDeniedMessage = 'This taxi is still in use.';
  static const String shiftHandoverActiveRideMessage =
      'This taxi is on a ride. Your request is queued until the ride is complete.';
  static const String shiftHandoverPrivateBlockedMessage =
      'This taxi is privately registered and cannot be activated by other drivers.';
  static const String shiftHandoverRateLimitedMessage =
      'You cannot request this taxi again yet. Wait a moment or contact support.';
  static const String shiftHandoverNotEligibleMessage =
      'Complete the missing requirements before taking over this taxi.';
  static const String shiftHandoverCheckingRequirements =
      'Checking requirements';
  static const String shiftHandoverCompleteRequirements =
      'Complete requirements';
  static const String shiftHandoverRequirementsTitle =
      'Before taking over this taxi';
  static const String shiftHandoverRequirementsBody =
      'Complete the missing trust and safety items below. Then come back and start the shift.';
  static const String shiftHandoverResolveFirstRequirement =
      'Fix first requirement';
  static const String shiftHandoverNotAllowlistedMessage =
      'You are not on the allowed driver list for this shared taxi. '
      'Contact your fleet manager.';
  static const String shiftHandoverStepUpTitle = 'Confirm your identity';
  static const String shiftHandoverStepUpBody =
      'For a safe Secure Shift Handover™, we confirm who you are. '
      'Use Face ID / Touch ID or a one-time email code.';
  static const String shiftHandoverBiometricReason =
      'Confirm your identity for Secure Shift Handover™';
  static const String shiftHandoverStepUpUseEmail = 'Email code';
  static const String shiftHandoverStepUpSendCode = 'Send code';
  static const String shiftHandoverStepUpConfirm = 'Confirm and continue';
  static const String shiftHandoverStepUpRequired =
      'Confirm your identity before requesting a shift handover.';
  static const String shiftHandoverStepUpNoEmail =
      'No email address found for your account.';
  static const String shiftHandoverStepUpFailed =
      'Verification failed. Try again.';
  static const String shiftHandoverPromptTitle = 'Secure Shift Handover™';
  static String shiftHandoverPromptLead(String name, String plate) =>
      '$name wil Taxi $plate besturen.';
  static const String shiftHandoverPromptVerified = 'Geverifieerd';
  static String shiftHandoverPromptMemberSince(int year) =>
      'Chauffeur sinds $year';
  static String shiftHandoverPromptTimeoutHint(int minutes) =>
      'Geen actie? Je dienst eindigt automatisch over maximaal $minutes minuten.';
  static const String shiftHandoverPromptUnexpected =
      'Verwacht je dit niet? Tik direct op Ik rij nog.';
  static const String shiftHandoverEndShift = 'Dienst beëindigen';
  static const String shiftHandoverStillDriving = 'Ik rij nog';
  static const String shiftHandoverEndShiftBiometricReason =
      'Bevestig dat je je dienst wilt beëindigen';
  static const String shiftHandoverEndShiftConfirmTitle = 'Dienst beëindigen?';
  static const String shiftHandoverEndShiftConfirmBody =
      'Een collega neemt deze taxi over. Je gaat offline en ontvangt geen ritten meer op dit kenteken.';
  static const String shiftHandoverFleetAlertTitle = 'Dienstwissel geweigerd';
  static const String shiftHandoverFleetAlertBody =
      'Een chauffeur probeerde deze taxi te starten. De huidige chauffeur rijdt nog. Was dit verwacht?';
  static const String shiftHandoverPrivateAlertTitle =
      'Poging tot taxi-activering';
  static const String shiftHandoverPrivateAlertBody =
      'Iemand probeerde je privé-taxi te activeren. Was dit verwacht? Neem contact op met ondersteuning als je dit verdacht vindt.';
  static const String shiftHandoverAuditNavTitle =
      'Secure Shift Handover — audit';
  static const String fleetAllowlistTitle = 'Fleet — toegestane chauffeurs';
  static const String fleetAllowlistNavTitle = 'Fleet chauffeurslijst';
  static const String fleetAllowlistEmpty =
      'Je beheert nog geen gedeelde taxi\'s in HeyCaby.';
  static const String fleetAllowlistForbidden =
      'Geen toegang om deze fleet-instellingen te beheren.';
  static const String fleetAllowlistOpenFleet =
      'Geen restrictie — elke geverifieerde chauffeur mag een dienstwissel aanvragen.';
  static String fleetAllowlistDriverCount(int count) =>
      '$count chauffeur${count == 1 ? '' : 's'} op de lijst';
  static const String fleetAllowlistVehicleBody =
      'Alleen chauffeurs op deze lijst kunnen Secure Shift Handover™ aanvragen voor deze taxi. '
      'Laat de lijst leeg om alle geverifieerde chauffeurs toe te staan.';
  static const String fleetAllowlistAddDriver = 'Chauffeur toevoegen';
  static const String fleetAllowlistSearchLabel = 'Naam of e-mail';
  static const String fleetAllowlistSearchHint =
      'Typ minimaal 3 tekens (naam of e-mail).';
  static const String fleetAllowlistSearchAction = 'Zoeken';
  static const String fleetAllowlistUpdateFailed =
      'Kon de chauffeurslijst niet bijwerken. Probeer het opnieuw.';
  static const String shiftHandoverWaitingSubtitle =
      'Geschatte dienstwissel — meestal 10–30 seconden';
  static const String shiftHandoverAuditTitle = 'Secure Shift Handover — audit';
  static const String shiftHandoverAuditEmpty =
      'Nog geen dienstwissel-aanvragen geregistreerd.';
  static const String shiftHandoverAuditForbidden =
      'Geen toegang. Alleen HeyCaby staff kan dit auditlog bekijken.';
  static const String taxiSessionRevokedTitle =
      'Taxi toegewezen aan andere chauffeur';
  static String taxiSessionRevokedBody(String plate) => plate.trim().isEmpty
      ? 'Je taxi-sessie is beëindigd. Een andere geverifieerde chauffeur neemt het over.'
      : 'Je taxi $plate is toegewezen aan een andere geverifieerde chauffeur. '
          'Je bent offline gezet.';
  static const String taxiSessionRevokedVoluntaryTitle = 'Dienst beëindigd';
  static String taxiSessionRevokedVoluntaryBody(String plate) => plate
          .trim()
          .isEmpty
      ? 'Je dienst is beëindigd. Een collega neemt de taxi over.'
      : 'Je dienst op taxi $plate is beëindigd. Een collega neemt de taxi over.';
  static const String taxiSessionRevokedCta = 'Naar home';
  static String get startShiftPrimary => _t(
        'Start mijn dienst',
        en: 'Start my shift',
        es: 'Iniciar mi turno',
        ar: 'ابدأ ورديتي',
      );

  @Deprecated('Use startShift* strings')
  static const String onboardingSharedFleetTitle = startShiftActiveTitle;
  @Deprecated('Use startShift* strings')
  static const String onboardingSharedFleetBody = startShiftActiveBody;
  @Deprecated('Use startShift* strings')
  static String get onboardingSharedFleetConfirm => startShiftPrimary;
  static String progressiveVerificationProgress(int rides, int milestone) =>
      'Progressieve verificatie: $rides/$milestone ritten';
  static const String progressiveVerificationMilestone10Hint =
      'Na 10 voltooide ritten vragen we extra verificatie zodat je online kunt blijven.';
  static const String progressiveVerificationMilestone20Hint =
      progressiveVerificationMilestone10Hint;
  static const String progressiveVerificationMilestone50Hint =
      'Na 50 ritten: volledige taxidocumentatie moet up-to-date blijven.';
  static const String progressiveVerificationCompleteDocs =
      'Documenten afronden';
  static String get runtimeGoOnlineEarlyOnboardingBody => _t(
        'Rond je verplichte profielstappen af voordat je online gaat.',
        en: 'Complete your required profile steps before going online.',
        es: 'Completa los pasos obligatorios de tu perfil antes de conectarte.',
        ar: 'أكمل خطوات ملفك المطلوبة قبل الاتصال.',
      );
  static const String lookupPlate = 'Look up plate';
  static const String plateNotFoundRdw =
      'Plate not found in RDW. Check for typos and try again.';
  static const String vehicleNotTaxiRdw =
      'This vehicle exists in RDW but is not registered as a taxi. Contact RDW or support.';
  static const String vehicleVerifiedTaxi = 'Vehicle verified as taxi';

  /// Shown when `drivers_vehicle_plate_unique` fires — plate exists on another driver row.
  static const String vehiclePlateDuplicate =
      'This plate is already registered. If this is your taxi, another account may have it — contact support.';
  static const String saveAndContinue = 'Save and continue';
  static const String vehiclePlateLockedSubtitle =
      'This plate is saved. Contact support if you want to change your vehicle.';
  static const String vehiclePlate = 'Plate';
  static const String vehicleApkExpiry = 'APK expiry date';
  static const String vehicleVerified = 'Verified taxi';
  static const String vehicleNotVerified = 'Not verified';
  static const String vehicleNotTaxi = 'Not a taxi';
  static const String vehicleExpandHint = 'Tap for more details';
  static const String vehicleCollapseHint = 'Tap to collapse';
  static const String viewAllPhotos = 'View all photos';
  static const String editVehicleDetails = 'Edit vehicle details';
  static const String contactSupportVehicle =
      'Contact support to change vehicle';
  static const String apkExpiringSoon = 'Expiring soon';
  static const String apkExpired = 'Expired';
  static const String vehiclePassengersSeeThis = 'RIDERS SEE THIS VEHICLE';
  static const String vehicleNoPhoto = 'No vehicle photo';
  static String vehiclePhotoNumber(int current, int total) =>
      'Foto $current/$total';
  static const String preferencesSectionAccessibility = 'Toegankelijkheid';
  static const String chauffeurspasSave = 'Chauffeurspas opslaan';
  static const String chauffeurspasSaved =
      'Opgeslagen. Ons team controleert je nummer handmatig.';
  static const String chauffeurspasExpiryLabel =
      'Vervaldatum op pas (verplicht)';
  static const String chauffeurspasExpiryRequired =
      'Vervaldatum op de chauffeurspas is verplicht.';
  static const String chauffeurspasExpiryInvalid =
      'Gebruik een geldige vervaldatum in formaat JJJJ-MM-DD.';
  static const String veriffStart = 'Rijbewijs verifiëren met Veriff';

  /// Full-screen Veriff entry (`/driver/veriff`).
  static const String veriffScreenTitle = 'Rijbewijsverificatie';
  static const String veriffScreenIntro =
      'Je bekijkt eerst de chauffeurvoorwaarden en opent daarna Veriff in je browser '
      'om je rijbewijs en identiteit te verifiëren.';

  /// Large callout on `/driver/veriff` — drivers must switch back manually from Safari/Chrome.
  static const String veriffScreenComeBackTitle = 'Kom terug naar HeyCaby';
  static const String veriffScreenComeBackBody =
      'Als je klaar bent in Veriff, schakel terug naar deze app (app-wisselaar of home, open HeyCaby). '
      'Je rijbewijsstatus wordt hier bijgewerkt — de browser kan je niet automatisch terugbrengen.';
  static const String veriffScreenContinue = 'Doorgaan';
  static const String veriffOpenFailed =
      'Veriff kon niet worden geopend. Controleer je verbinding en probeer het opnieuw.';
  static const String veriffProcessingHint =
      'Rond verificatie in de browser af. Status wordt hier bijgewerkt als je klaar bent.';

  /// Bottom sheet before opening Veriff (hosted flow + chauffeur terms art. 3).
  static String get veriffTermsGateTitle => _t(
        'Voorwaarden & identiteitscontrole',
        en: 'Terms & identity check',
        es: 'Condiciones y verificación de identidad',
        ar: 'الشروط والتحقق من الهوية',
      );
  static String get veriffTermsGateBody => _t(
        'Verificatie gebeurt door Veriff (zie chauffeurvoorwaarden, sectie 3). Lees de voorwaarden voordat je doorgaat.',
        en: 'Verification is handled by Veriff (see driver terms, section 3). Read the terms before you continue.',
        es: 'La verificación la realiza Veriff (consulta las condiciones para conductores, sección 3). Lee las condiciones antes de continuar.',
        ar: 'تتم عملية التحقق عبر Veriff (راجع شروط السائق، القسم 3). اقرأ الشروط قبل المتابعة.',
      );
  static String get veriffTermsDataControllerTitle => _t(
        'Hoe je rijbewijsgegevens worden verwerkt',
        en: 'How your license data is processed',
        es: 'Cómo se procesan los datos de tu licencia',
        ar: 'كيف تتم معالجة بيانات رخصتك',
      );
  static String get veriffTermsDataControllerBody => _t(
        'HeyCaby gebruikt Veriff als gespecialiseerde externe aanbieder voor identiteitsverificatie. Veriff verwerkt identiteits- en documentgegevens namens ons om echtheid en compliance te controleren.',
        en: 'HeyCaby uses Veriff as a specialist third-party identity verification provider. Veriff processes identity and document data on our behalf to check authenticity and compliance.',
        es: 'HeyCaby usa Veriff como proveedor externo especializado en verificación de identidad. Veriff procesa datos de identidad y documentos en nuestro nombre para comprobar autenticidad y cumplimiento.',
        ar: 'تستخدم HeyCaby خدمة Veriff كمزود خارجي متخصص للتحقق من الهوية. تعالج Veriff بيانات الهوية والمستندات نيابة عنا للتحقق من صحتها والامتثال.',
      );
  static String get veriffTermsDataMinimizationTitle => _t(
        'AVG en minimale gegevens',
        en: 'GDPR and data minimisation',
        es: 'RGPD y minimización de datos',
        ar: 'اللائحة العامة وحفظ أقل قدر من البيانات',
      );
  static String get veriffTermsDataMinimizationBody => _t(
        'Om risico te beperken en AVG-principes te volgen, slaat HeyCaby geen volledige kopieën van gevoelige ID-/rijbewijsbeelden op in de app-database. We bewaren alleen verificatiestatus en minimale metadata voor compliance en bedrijfsvoering.',
        en: 'To reduce risk and follow GDPR principles, HeyCaby does not store full copies of sensitive ID or license images in the app database. We keep only verification status and minimal metadata for compliance and operations.',
        es: 'Para reducir riesgos y seguir los principios del RGPD, HeyCaby no almacena copias completas de imágenes sensibles de identidad o licencia en la base de datos de la app. Solo guardamos el estado de verificación y metadatos mínimos para cumplimiento y operación.',
        ar: 'لتقليل المخاطر واتباع مبادئ حماية البيانات، لا تخزن HeyCaby نسخا كاملة من صور الهوية أو الرخصة الحساسة في قاعدة بيانات التطبيق. نحتفظ فقط بحالة التحقق وبيانات وصفية محدودة للامتثال والتشغيل.',
      );
  static String get veriffTermsSecurityLiabilityTitle => _t(
        'Beveiliging en verantwoordelijkheid van derden',
        en: 'Security and third-party responsibility',
        es: 'Seguridad y responsabilidad de terceros',
        ar: 'الأمان ومسؤولية الطرف الثالث',
      );
  static String get veriffTermsSecurityLiabilityBody => _t(
        'Veriff is verantwoordelijk voor de beveiliging en integriteit van zijn verificatie-infrastructuur. HeyCaby kan niet garanderen dat Veriff altijd beschikbaar is en is niet aansprakelijk voor storingen, vertraging of incidenten bij derden buiten onze controle.',
        en: 'Veriff is responsible for the security and integrity of its verification infrastructure. HeyCaby cannot guarantee that Veriff is always available and is not liable for third-party outages, delays, or incidents outside our control.',
        es: 'Veriff es responsable de la seguridad e integridad de su infraestructura de verificación. HeyCaby no puede garantizar que Veriff esté siempre disponible y no responde por interrupciones, retrasos o incidentes de terceros fuera de nuestro control.',
        ar: 'تتحمل Veriff مسؤولية أمان وسلامة بنية التحقق الخاصة بها. لا تستطيع HeyCaby ضمان توفر Veriff دائما ولا تتحمل مسؤولية الأعطال أو التأخير أو الحوادث لدى أطراف ثالثة خارج سيطرتنا.',
      );
  static String get veriffTermsLegalDisclosureTitle => _t(
        'Juridische verstrekking',
        en: 'Legal disclosure',
        es: 'Divulgación legal',
        ar: 'الإفصاح القانوني',
      );
  static String get veriffTermsLegalDisclosureBody => _t(
        'Waar de wet of bevoegde autoriteit dit vereist, kunnen relevante verificatiegegevens worden verstrekt conform wettelijke verplichtingen.',
        en: 'Where required by law or a competent authority, relevant verification data may be disclosed in line with legal obligations.',
        es: 'Cuando lo exija la ley o una autoridad competente, los datos de verificación pertinentes pueden divulgarse conforme a las obligaciones legales.',
        ar: 'عندما يطلب القانون أو جهة مختصة ذلك، قد يتم الإفصاح عن بيانات التحقق ذات الصلة وفقا للالتزامات القانونية.',
      );
  static String get veriffTermsReadFull => _t(
        'Volledige chauffeurvoorwaarden lezen',
        en: 'Read full driver terms',
        es: 'Leer condiciones completas para conductores',
        ar: 'قراءة شروط السائق كاملة',
      );
  static String get veriffTermsReadVeriffOnly => _t(
        'Alleen Veriff-sectie openen',
        en: 'Open Veriff section only',
        es: 'Abrir solo la sección de Veriff',
        ar: 'فتح قسم Veriff فقط',
      );
  static String get veriffTermsCheckbox => _t(
        'Ik heb de HeyCaby-chauffeurvoorwaarden en het Veriff-verificatieproces gelezen en ga ermee akkoord.',
        en: 'I have read and agree to the HeyCaby driver terms and the Veriff verification process.',
        es: 'He leído y acepto las condiciones para conductores de HeyCaby y el proceso de verificación de Veriff.',
        ar: 'قرأت وأوافق على شروط سائقي HeyCaby وعملية التحقق عبر Veriff.',
      );
  static String get veriffTermsCheckboxDataProcessing => _t(
        'Ik begrijp dat mijn verificatiegegevens door Veriff als verwerker worden verwerkt en dat HeyCaby alleen minimale compliance-metadata bewaart.',
        en: 'I understand that my verification data is processed by Veriff as a processor and that HeyCaby keeps only minimal compliance metadata.',
        es: 'Entiendo que Veriff procesa mis datos de verificación como encargado y que HeyCaby conserva solo metadatos mínimos de cumplimiento.',
        ar: 'أفهم أن بيانات التحقق الخاصة بي تعالجها Veriff كمعالج بيانات وأن HeyCaby تحتفظ فقط ببيانات وصفية محدودة للامتثال.',
      );
  static String get veriffTermsContinue => _t(
        'Doorgaan naar Veriff',
        en: 'Continue to Veriff',
        es: 'Continuar a Veriff',
        ar: 'المتابعة إلى Veriff',
      );
  static String get veriffTermsCancel => _t(
        'Annuleren',
        en: 'Cancel',
        es: 'Cancelar',
        ar: 'إلغاء',
      );

  /// After terms: explicit consent before opening Veriff in Safari/Chrome (App Review / transparency).
  static const String veriffExternalBrowserTitle = 'Verificatie buiten de app';
  static const String veriffExternalBrowserBody =
      'We openen Veriff in je browser (Safari of Chrome). Je verlaat daarmee kort de HeyCaby-app '
      'om je rijbewijs te verifiëren. Wil je doorgaan?';
  static const String veriffExternalBrowserContinue = 'Ja, openen';
  static const String veriffExternalBrowserCancel = 'Nee';
  static const String kvkSave = 'KvK-gegevens opslaan';
  static const String insurancePickPhoto = 'Verzekeringsfoto toevoegen';
  static const String insurancePickPhotoGreenCard =
      'Verzekeringsfoto toevoegen (groene kaart)';
  static const String insuranceUseCamera = 'Foto maken';
  static const String insuranceUseGallery = 'Kiezen uit galerij';
  static const String insuranceSave = 'Verzekering opslaan';
  static String get dateFormatHint => _t(
        'JJJJ-MM-DD',
        en: 'YYYY-MM-DD',
        es: 'AAAA-MM-DD',
        ar: 'YYYY-MM-DD',
      );
  static String get uploadFailed => _t(
        'Upload mislukt',
        en: 'Upload failed',
        es: 'La carga falló',
        ar: 'فشل الرفع',
      );
  static String get insurancePhotoUploadedMessage => _t(
        'Foto geüpload. Vul verzekeraar, polisnummer en vervaldatum in en tik op Opslaan.',
        en: 'Photo uploaded. Enter insurer, policy number, and expiry, then tap Save.',
        es: 'Foto cargada. Introduce aseguradora, número de póliza y vencimiento, y toca Guardar.',
        ar: 'تم رفع الصورة. أدخل شركة التأمين ورقم الوثيقة وتاريخ الانتهاء، ثم اضغط حفظ.',
      );
  static String get insurancePhotoUploadedSnack => _t(
        'Verzekeringsfoto geüpload.',
        en: 'Insurance photo uploaded.',
        es: 'Foto del seguro cargada.',
        ar: 'تم رفع صورة التأمين.',
      );
  static String get insuranceProviderMissingLabel => _t(
        'verzekeraar',
        en: 'insurer',
        es: 'aseguradora',
        ar: 'شركة التأمين',
      );
  static String get insuranceProviderLabel => _t(
        'Verzekeraar',
        en: 'Insurer',
        es: 'Aseguradora',
        ar: 'شركة التأمين',
      );
  static String get insurancePolicyLabel => _t(
        'Polisnummer',
        en: 'Policy number',
        es: 'Número de póliza',
        ar: 'رقم الوثيقة',
      );
  static String get insuranceExpiryLabel => _t(
        'Vervaldatum',
        en: 'Expiry date',
        es: 'Fecha de vencimiento',
        ar: 'تاريخ الانتهاء',
      );
  static String get insurancePhotoMissingLabel => _t(
        'verzekeringsfoto',
        en: 'insurance photo',
        es: 'foto del seguro',
        ar: 'صورة التأمين',
      );
  static String missingFieldsMessage(List<String> fields) => _t(
        'Ontbreekt: ${fields.join(', ')}.',
        en: 'Missing: ${fields.join(', ')}.',
        es: 'Falta: ${fields.join(', ')}.',
        ar: 'الحقول الناقصة: ${fields.join(', ')}.',
      );
  static const String paymentMethodRequired =
      'Houd minimaal één betaalmethode ingeschakeld.';
  static const String onlineBlockedCompliance =
      'Je kunt pas online als alle verplichte documenten zijn afgerond (chauffeurspas, verzekering, KvK, kenteken, akkoord met de voorwaarden, vrijwaring en korte quiz) en je rijbewijs handmatig is goedgekeurd.';
  static const String onlineBlockedPending = 'Je profiel wordt beoordeeld…';

  /// Veriff done; waiting for ops to set `rijbewijs_verified` in Supabase.
  static const String onlineBlockedLicenseReview =
      'Je rijbewijscontrole wordt door ons team afgerond. Je kunt online na bevestiging (meestal kort na Veriff).';
  static const String onlineChecklistTitle =
      'Je bent bijna klaar om online te gaan';
  static const String onlineChecklistMissingPrefix = 'Ontbreekt:';
  static const String onlineChecklistProfilePhoto = 'Chauffeursprofielfoto';
  static const String onlineChecklistVehiclePhoto = 'Voertuigfoto';
  static const String onlineChecklistChauffeurCard = 'Chauffeurspasnummer';
  static const String onlineChecklistChauffeurExpiry =
      'Vervaldatum chauffeurspas';
  static const String onlineChecklistInsuranceProvider = 'Taxiverzekeraar';
  static const String onlineChecklistInsurancePolicy =
      'Polisnummer taxiverzekering';
  static const String onlineChecklistInsuranceExpiry =
      'Vervaldatum taxiverzekering';
  static const String onlineChecklistInsurancePhoto =
      'Foto groene kaart verzekering';
  static const String onlineChecklistKvkNumber = 'KvK-nummer';
  static const String onlineChecklistKvkAddress = 'KvK-bedrijfsadres';
  static const String onlineChecklistVehiclePlate = 'Kenteken';
  static const String onlineChecklistTerms = 'Gebruiksvoorwaarden accepteren';
  static const String onlineChecklistShortQuiz = 'Korte juridische quiz halen';
  static const String onlineChecklistIndemnification =
      'Vrijwaring lezen en bevestigen';
  static const String onlineChecklistLicenceApproval =
      'Handmatige goedkeuring rijbewijs (na Veriff)';

  /// Legacy compatibility labels for the old platform-fee gate.
  /// Active UI should use Platform Balance wording.
  static const String platformFeeTitle = 'Platformbalans';
  static String platformFeeBody(String euros) =>
      'Je openstaande platformbalans is €$euros. Vereffen deze om weer nieuwe ritaanvragen te ontvangen.';
  static const String platformFeePay = 'Platformbalans vereffenen';
  static const String platformFeeCheckoutTitle = 'Platformbalans';
  static const String platformFeeStartingCheckout = 'Betaling voorbereiden…';
  static const String platformFeeInvalidUrl =
      'Ongeldige betaallink. Probeer opnieuw.';
  static const String platformFeeStatusError =
      'Kon je status niet ophalen. Controleer je verbinding.';
  static const String platformFeeStartError =
      'Betaling starten mislukt. Probeer opnieuw.';
  static String get goOnlineFailed => _t(
        'Online gaan mislukt. Controleer je verbinding en probeer opnieuw.',
        en: 'Could not go online. Check your connection and try again.',
        es: 'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
        ar: 'تعذر الاتصال. تحقق من اتصالك وحاول مرة أخرى.',
      );
  static String get goBreakFailed => _t(
        'Pauze starten mislukt. Controleer je verbinding en probeer opnieuw.',
        en: 'Could not start break. Check your connection and try again.',
        es: 'No se pudo iniciar el descanso. Revisa tu conexión e inténtalo de nuevo.',
        ar: 'تعذر بدء الاستراحة. تحقق من اتصالك وحاول مرة أخرى.',
      );
  static String get goOfflineFailed => _t(
        'Offline gaan mislukt. Controleer je verbinding en probeer opnieuw.',
        en: 'Could not go offline. Check your connection and try again.',
        es: 'No se pudo desconectar. Revisa tu conexión e inténtalo de nuevo.',
        ar: 'تعذر عدم الاتصال. تحقق من اتصالك وحاول مرة أخرى.',
      );
  static const String platformFeeStillPending =
      'Betaling nog niet bevestigd. Wacht even of probeer opnieuw.';
  static String get platformBalanceTitle => _t(
        'Platformbalans',
        en: 'Platform Balance',
        es: 'Balance de plataforma',
        ar: 'رصيد المنصة',
      );
  static String get platformBalanceOutstanding => _t(
        'Openstaand',
        en: 'Outstanding',
        es: 'Pendiente',
        ar: 'مستحق',
      );
  static String get platformBalanceNoOutstanding => _t(
        'Geen openstaand bedrag',
        en: 'No outstanding balance',
        es: 'Sin saldo pendiente',
        ar: 'لا يوجد رصيد مستحق',
      );
  static String get platformBalanceCurrent => _t(
        'Balans op orde',
        en: 'Balance current',
        es: 'Balance al día',
        ar: 'الرصيد محدث',
      );
  static String get platformBalanceRequestsPaused => _t(
        'Ritaanvragen tijdelijk gepauzeerd',
        en: 'Ride requests temporarily paused',
        es: 'Solicitudes de viaje pausadas temporalmente',
        ar: 'طلبات الرحلات متوقفة مؤقتا',
      );
  static String get platformBalanceCurrentBody => _t(
        'Je hebt geen openstaande platformbalans.',
        en: 'You have no outstanding platform balance.',
        es: 'No tienes saldo pendiente de plataforma.',
        ar: 'لا يوجد لديك رصيد مستحق للمنصة.',
      );
  static String get platformBalanceDueBody => _t(
        'Vereffen je balans binnen de betaaltermijn om nieuwe ritaanvragen te blijven ontvangen.',
        en: 'Settle your balance within the payment window to keep receiving new ride requests.',
        es: 'Liquida tu balance dentro del plazo para seguir recibiendo solicitudes de viaje.',
        ar: 'سوّ رصيدك ضمن مهلة الدفع للاستمرار في تلقي طلبات رحلات جديدة.',
      );
  static String get platformBalancePausedBody => _t(
        'Nieuwe ritaanvragen zijn tijdelijk gepauzeerd totdat je platformbalans is vereffend.',
        en: 'New ride requests are temporarily paused until your platform balance is settled.',
        es: 'Las nuevas solicitudes de viaje están pausadas temporalmente hasta que liquides tu balance de plataforma.',
        ar: 'طلبات الرحلات الجديدة متوقفة مؤقتا حتى تتم تسوية رصيد المنصة.',
      );
  static String get platformBalanceDueToday => _t(
        'Vereffen je balans vandaag om nieuwe ritaanvragen te blijven ontvangen.',
        en: 'Settle your balance today to keep receiving new ride requests.',
        es: 'Liquida tu balance hoy para seguir recibiendo solicitudes de viaje.',
        ar: 'سوّ رصيدك اليوم للاستمرار في تلقي طلبات رحلات جديدة.',
      );
  static String get platformBalanceDueTomorrow => _t(
        'Vereffen je balans uiterlijk morgen.',
        en: 'Settle your balance by tomorrow.',
        es: 'Liquida tu balance antes de mañana.',
        ar: 'سوّ رصيدك بحلول الغد.',
      );
  static String platformBalanceDueInDays(int days) => _t(
        'Vereffen je balans binnen $days dagen.',
        en: 'Settle your balance within $days days.',
        es: 'Liquida tu balance dentro de $days días.',
        ar: 'سوّ رصيدك خلال $days أيام.',
      );
  static String get platformBalanceExplainer => _t(
        'HeyCaby maakt na elke actieve week automatisch een platformbalans aan. Je houdt 100% van je ritopbrengst.',
        en: 'HeyCaby creates a platform balance after each active week. You keep 100% of your ride earnings.',
        es: 'HeyCaby crea un balance de plataforma después de cada semana activa. Conservas el 100% de tus ingresos por viajes.',
        ar: 'تنشئ HeyCaby رصيد منصة بعد كل أسبوع نشط. تحتفظ بنسبة 100% من أرباح رحلاتك.',
      );
  static String get platformBalancePausedExplainer => _t(
        'Je kunt geschiedenis, inkomsten, profiel, community en support blijven gebruiken. Alleen nieuwe ritaanvragen zijn gepauzeerd.',
        en: 'You can still use history, earnings, profile, community, and support. Only new ride requests are paused.',
        es: 'Puedes seguir usando historial, ingresos, perfil, comunidad y soporte. Solo las nuevas solicitudes de viaje están pausadas.',
        ar: 'يمكنك الاستمرار في استخدام السجل والأرباح والملف الشخصي والمجتمع والدعم. فقط طلبات الرحلات الجديدة متوقفة.',
      );
  static String get platformBalancePaymentPending => _t(
        'Betaling in behandeling',
        en: 'Payment Pending',
        es: 'Pago pendiente',
        ar: 'الدفع قيد المعالجة',
      );
  static String get platformBalancePaymentPendingBody => _t(
        'We wachten op bevestiging van je betaling. De meeste betalingen worden binnen enkele minuten bevestigd. Bankoverschrijvingen kunnen langer duren.',
        en: 'We are waiting for your payment confirmation. Most payments are confirmed within a few minutes. Bank transfers may take longer.',
        es: 'Estamos esperando la confirmación de tu pago. La mayoría de pagos se confirman en unos minutos. Las transferencias bancarias pueden tardar más.',
        ar: 'نحن ننتظر تأكيد دفعتك. يتم تأكيد معظم المدفوعات خلال دقائق. قد تستغرق التحويلات البنكية وقتًا أطول.',
      );
  static String get platformBalanceSettleBalance => _t(
        'Platformbalans vereffenen',
        en: 'Settle Platform Balance',
        es: 'Liquidar balance de plataforma',
        ar: 'تسوية رصيد المنصة',
      );
  static String get platformBalanceViewHistory => _t(
        'Platformactiviteit bekijken',
        en: 'View Platform Activity',
        es: 'Ver actividad de plataforma',
        ar: 'عرض نشاط المنصة',
      );
  static String get platformBalancePreparingSettlement => _t(
        'Betaling voorbereiden…',
        en: 'Preparing settlement…',
        es: 'Preparando liquidación…',
        ar: 'جار تحضير التسوية…',
      );
  static String get platformBalanceVerifyPayment => _t(
        'We verifiëren je betaling. De meeste betalingen worden binnen enkele minuten bevestigd.',
        en: 'We’ll verify your payment. Most payments are confirmed within a few minutes.',
        es: 'Verificaremos tu pago. La mayoría de pagos se confirman en unos minutos.',
        ar: 'سنتحقق من دفعتك. يتم تأكيد معظم المدفوعات خلال دقائق.',
      );
  static String get billingTitle => platformBalanceTitle;
  static const String billingCurrentPlan = 'Platformbalans';
  static const String billingFoundingMember = 'Founding Driver';
  static const String billingRegularMember = 'Chauffeur';
  static const String billingWeeklyFee = 'Wekelijkse platformbalans';
  static const String billingPerRideSuffix = 'per rit';
  static const String billingOutstandingLimit = 'Openstaand';
  static const String billingNextPayment = 'Volgende betaling';
  static const String billingPaymentStatus = 'Betalingsstatus';
  static const String billingStatusActive = 'Actief';
  static const String billingStatusPending = 'In afwachting';
  static const String billingStatusOverdue = 'Achterstallig';
  static const String billingViewHistory = 'Balansgeschiedenis bekijken';
  static const String billingPaymentMethods = 'Betaalmethoden';
  static const String billingPayNow = 'Platformbalans vereffenen';
  static const String billingChoosePlanTitle = 'Platformbalans vereffenen';
  static const String billingPlanUnknown = 'Platformbalans';
  static const String billingUseSelectedPlan = 'Platformbalans vereffenen';

  /// Shown when the server does not return usable Platform Balance pricing.
  static const String billingPlansUnavailable =
      'Prijzen zijn nu niet beschikbaar. Vernieuw of probeer het later opnieuw.';
  static const String billingHistoryTitle = 'Platformactiviteit';
  static const String billingHistoryEmpty = 'Nog geen platformactiviteit';
  static const String billingHistoryDate = 'Datum';
  static const String billingHistoryAmount = 'Bedrag';
  static const String billingHistoryStatus = 'Status';
  static const String billingHistoryMethod = 'Methode';
  static const String billingHistoryStatusPaid = 'Betaald';
  static const String billingHistoryStatusFailed = 'Mislukt';
  static const String billingHistoryStatusPending = 'In afwachting';
  static const String billingDash = '—';
  static const String billingWeeklyFeeUnknown =
      'Bedrag staat op de server; vernieuw als dit leeg blijft.';
  static const String billingStatusFromServer = 'Accountstatus';
  static const String billingStatusPaymentRequired = 'Betaling vereist';
  static const String billingStatusNoPaymentDue = 'Geen betaling verschuldigd';
  static const String billingStatusPaused = 'Gepauzeerd';
  static const String billingStatusCanceled = 'Geannuleerd';
  static const String billingPaymentMethodsPortalTitle = 'Betaalmethoden';
  static const String billingPaymentMethodsUnavailable =
      'Beheren van betaalmethoden is nog niet beschikbaar. Neem contact op met de ondersteuning als je je kaart wilt wijzigen.';
  static const String billingPayPreparing = 'Betaling voorbereiden…';
  static const String billingNextPaymentDueSoon = 'Binnenkort verschuldigd';

  static String get drawerSectionMain => _t(
        'Algemeen',
        en: 'General',
        es: 'General',
        ar: 'عام',
      );
  static String get drawerSectionLegal => _t(
        'Juridisch',
        en: 'Legal',
        es: 'Legal',
        ar: 'قانوني',
      );
  static String get drawerDefaultName => _t(
        'Chauffeur',
        en: 'Driver',
        es: 'Conductor',
        ar: 'السائق',
      );
  static String get drawerMember => member;
  static String drawerFoundingMemberLine(int? n) =>
      n == null ? billingFoundingMember : '$billingFoundingMember #$n';

  static const String drawerBillingStatusUnavailable =
      'Weekstatus niet beschikbaar';
  static const String drawerBillingWaitingLiveStatus =
      'Wachten op live status van de server';

  static const String licenceSubmittedPendingReview =
      'Ingediend — ons team bevestigt je rijbewijs na beoordeling van Veriff.';
  static const String docSavePermanentTitle = 'Permanent opslaan?';
  static const String docSavePermanentBody =
      'Na opslaan kun je dit niet meer in de app wijzigen. Onjuiste of frauduleuze gegevens kunnen tot een ban leiden. '
      'Voor latere correctie: neem contact op met klantenservice.';
  static const String docSaveInsuranceBody =
      'Na opslaan kun je deze gegevens niet meer in de app wijzigen. Taxiverzekering is verplicht; we kunnen invoeren controleren. '
      'Voor updates later: neem contact op met de ondersteuning.';
  static const String docSaveConfirm = 'Opslaan';
  static const String fieldLockedContactSupport =
      'Opgeslagen — neem contact op met de ondersteuning om dit te wijzigen.';
  static const String insuranceAccuracyWarning =
      'Vul verzekeraar, polisnummer en vervaldatum correct in. Upload een duidelijke foto van je verzekeringsdocument.';
  static const String insuranceLiabilityDisclaimer =
      'Deze upload bevestigt dat je taxiverzekering hebt (groene kaart). '
      'Jij blijft volledig verantwoordelijk om je verzekering actief, geldig en up-to-date te houden.';
  static const String insuranceCanEditAnytime =
      'Je kunt je taxiverzekeringsgegevens en document altijd bijwerken.';
  static const String indemnificationTitle =
      'Vrijwaringsovereenkomst chauffeur';
  static const String indemnificationSummary1 =
      'Voordat je online gaat, moet je de vrijwaring en aansprakelijkheidsverklaring lezen.';
  static const String indemnificationSummary2 =
      'Jij blijft volledig verantwoordelijk voor naleving van de wet, geldige vergunningen, verzekering en je eigen vervoersactiviteiten.';
  static const String indemnificationSummary3 =
      'Niet lezen van dit document maakt je aansprakelijkheid niet weg. Door verder te gaan bevestig je dit te begrijpen.';
  static const String indemnificationReadLabel =
      'Ik heb het vrijwaringsdocument gelezen en aanvaard verantwoordelijkheid.';
  static const String legalChecklistTitle = 'Verplichte juridische checks (3)';
  static const String legalChecklistOpenTerms = 'Gebruiksvoorwaarden openen';
  static const String legalChecklistOpenIndemnification =
      'Vrijwaringsverklaring openen';
  static const String legalChecklistTermsCheck =
      'Vink aan na het lezen van de gebruiksvoorwaarden';
  static const String legalChecklistIndemnificationCheck =
      'Vink aan na het lezen van de vrijwaringsverklaring';
  static const String legalChecklistQuizCheck =
      'Vink aan door de korte juridische quiz te halen';
  static const String legalChecklistSaved =
      'Juridische bevestiging opgeslagen.';
  static const String legalChecklistSaveFailed =
      'Juridische bevestiging opslaan mislukt. Probeer opnieuw.';
  static const String legalChecklistAllVerified = 'Alle 3 gecontroleerd';
  static String legalChecklistProgress(int done, int total) =>
      '$done/$total afgerond';
  static String get addManualRideTitle => _t(
        'Passagier toevoegen',
        en: 'Add passenger',
        es: 'Añadir pasajero',
        ar: 'إضافة راكب',
      );
  static String get addManualRideCardSubtitle => _t(
        'Straatrit vastleggen voor administratie en belasting',
        en: 'Log a street ride for records and tax',
        es: 'Registra un viaje de calle para administración e impuestos',
        ar: 'سجّل رحلة مباشرة للسجلات والضرائب',
      );
  static String get addManualRideExplainer => _t(
        'Voeg een passagier toe die je persoonlijk of op straat hebt opgepikt. De rit wordt in HeyCaby vastgelegd voor je administratie. Jij houdt 100% van dit tarief.',
        en: 'Add a passenger you picked up directly or on the street. The ride is logged in HeyCaby for your records. You keep 100% of this fare.',
        es: 'Añade un pasajero que recogiste directamente o en la calle. El viaje se guarda en HeyCaby para tu administración. Conservas el 100% de esta tarifa.',
        ar: 'أضف راكبا أقلته مباشرة أو من الشارع. يتم تسجيل الرحلة في HeyCaby لسجلاتك. تحتفظ بنسبة 100% من هذه الأجرة.',
      );
  static String get manualRideRouteSection => _t(
        'Route',
        en: 'Route',
        es: 'Ruta',
        ar: 'المسار',
      );
  static String get manualRideDetailsSection => _t(
        'Ritdetails',
        en: 'Trip details',
        es: 'Detalles del viaje',
        ar: 'تفاصيل الرحلة',
      );
  static String get manualRidePickupLabel => _t(
        'Ophaaladres (optioneel)',
        en: 'Pickup address (optional)',
        es: 'Dirección de recogida (opcional)',
        ar: 'عنوان الالتقاط (اختياري)',
      );
  static String get manualRideDropoffLabel => _t(
        'Afzetadres',
        en: 'Dropoff address',
        es: 'Dirección de destino',
        ar: 'عنوان الوصول',
      );
  static String get manualRideFareLabel => _t(
        'Door passagier betaald tarief',
        en: 'Fare paid by passenger',
        es: 'Tarifa pagada por el pasajero',
        ar: 'الأجرة التي دفعها الراكب',
      );
  static String get manualRidePassengerLabel => _t(
        'Naam passagier (optioneel)',
        en: 'Passenger name (optional)',
        es: 'Nombre del pasajero (opcional)',
        ar: 'اسم الراكب (اختياري)',
      );
  static String get manualRidePaymentMethodLabel => _t(
        'Betaalmethode',
        en: 'Payment method',
        es: 'Método de pago',
        ar: 'طريقة الدفع',
      );
  static String get manualRideSaveCta => _t(
        'Rit opslaan',
        en: 'Save ride',
        es: 'Guardar viaje',
        ar: 'حفظ الرحلة',
      );
  static String get manualRideDropoffRequired => _t(
        'Afzetadres is verplicht.',
        en: 'Dropoff address is required.',
        es: 'La dirección de destino es obligatoria.',
        ar: 'عنوان الوصول مطلوب.',
      );
  static String get manualRideFareRequired => _t(
        'Vul een geldig tarief in groter dan 0.',
        en: 'Enter a valid fare greater than 0.',
        es: 'Introduce una tarifa válida mayor que 0.',
        ar: 'أدخل أجرة صحيحة أكبر من 0.',
      );
  static String get manualRideSaveFailed => _t(
        'Deze rit opslaan mislukt. Probeer opnieuw.',
        en: 'Could not save this ride. Try again.',
        es: 'No se pudo guardar este viaje. Inténtalo de nuevo.',
        ar: 'تعذر حفظ هذه الرحلة. حاول مرة أخرى.',
      );
  static String get manualRideSuccessTitle => _t(
        'Rit vastgelegd',
        en: 'Ride logged',
        es: 'Viaje registrado',
        ar: 'تم تسجيل الرحلة',
      );
  static String manualRideSuccessBody(String fareLabel) {
    final amount = fareLabel.isEmpty ? null : 'EUR $fareLabel';
    return _t(
      'Passagiersrit opgeslagen (${amount ?? 'bedrag vastgelegd'}).',
      en: 'Passenger ride saved (${amount ?? 'amount recorded'}).',
      es: 'Viaje de pasajero guardado (${amount ?? 'importe registrado'}).',
      ar: 'تم حفظ رحلة الراكب (${amount ?? 'تم تسجيل المبلغ'}).',
    );
  }

  static String get manualRideFarePreviewEmpty => _t(
        'Vul een tarief in om de samenvatting te bekijken',
        en: 'Set fare to preview trip summary',
        es: 'Introduce la tarifa para ver el resumen',
        ar: 'أدخل الأجرة لمعاينة ملخص الرحلة',
      );
  static String manualRideFarePreview(String amount, String method) => _t(
        'Jij houdt 100%: EUR $amount • $method',
        en: 'You keep 100%: EUR $amount • $method',
        es: 'Conservas el 100%: EUR $amount • $method',
        ar: 'تحتفظ بنسبة 100%: EUR $amount • $method',
      );
  static String get done => _t(
        'Klaar',
        en: 'Done',
        es: 'Listo',
        ar: 'تم',
      );
  static const String indemnificationReadRequired =
      'Bevestig eerst dat je het vrijwaringsdocument hebt gelezen.';
  static const String indemnificationOpenDoc = 'Vrijwaringsdocument openen';
  static const String indemnificationStartQuiz = 'Start quiz van 5 vragen';
  static const String indemnificationPassed =
      'Gehaald. Vrijwaring is afgerond.';
  static const String indemnificationBadgePassed = 'Gehaald';
  static const String indemnificationSaveFailed =
      'Vrijwaring opslaan mislukt. Probeer opnieuw.';
  static const String indemnificationQuizTitle = 'Begripsquiz vrijwaring';
  static const String indemnificationQuizFail =
      'Quiz niet gehaald. Lees opnieuw en probeer nog eens.';
  static const String indemnificationQuizPassTitle =
      'Gefeliciteerd, je hebt de quiz gehaald';
  static const String indemnificationQuizPassBody =
      'Goed gedaan. Je juridische quiz staat nu als afgerond.';
  static const String indemnificationQuizPassCta = 'Doorgaan';
  static String get indemnificationQuizQuestion1 => _t(
        '1) Wie is verantwoordelijk voor vervoersverplichtingen tijdens ritten?',
        en: '1) Who is responsible for transport obligations during rides?',
        es: '1) ¿Quién es responsable de las obligaciones de transporte durante los viajes?',
        ar: '1) من المسؤول عن التزامات النقل أثناء الرحلات؟',
      );
  static List<String> get indemnificationQuizQuestion1Options => [
        'HeyCaby',
        _t(
          'De chauffeur',
          en: 'The Driver',
          es: 'El conductor',
          ar: 'السائق',
        ),
        _t(
          'Beiden evenveel',
          en: 'Both equally',
          es: 'Ambos por igual',
          ar: 'كلاهما بالتساوي',
        ),
      ];
  static String get indemnificationQuizQuestion2 => _t(
        '2) Als een chauffeur met verlopen verzekering rijdt, wie is aansprakelijk?',
        en: '2) If a driver has expired insurance, who is liable?',
        es: '2) Si un conductor tiene el seguro vencido, ¿quién es responsable?',
        ar: '2) إذا كان تأمين السائق منتهي الصلاحية، فمن المسؤول؟',
      );
  static List<String> get indemnificationQuizQuestion2Options => [
        'HeyCaby',
        _t(
          'De chauffeur',
          en: 'The Driver',
          es: 'El conductor',
          ar: 'السائق',
        ),
        _t(
          'Niemand',
          en: 'No one',
          es: 'Nadie',
          ar: 'لا أحد',
        ),
      ];
  static String get indemnificationQuizQuestion3 => _t(
        '3) Verwijdert niet lezen van de vrijwaring je aansprakelijkheid?',
        en: '3) Does not reading the indemnification remove your liability?',
        es: '3) ¿No leer la indemnización elimina tu responsabilidad?',
        ar: '3) هل عدم قراءة إقرار الإعفاء يزيل مسؤوليتك؟',
      );
  static List<String> get indemnificationQuizQuestion3Options => [
        _t(
          'Ja',
          en: 'Yes',
          es: 'Sí',
          ar: 'نعم',
        ),
        _t(
          'Nee',
          en: 'No',
          es: 'No',
          ar: 'لا',
        ),
        _t(
          'Alleen gedeeltelijk',
          en: 'Only partially',
          es: 'Solo parcialmente',
          ar: 'جزئيا فقط',
        ),
      ];
  static String get indemnificationQuizQuestion4 => _t(
        '4) Is HeyCaby partij bij de vervoersovereenkomst tussen chauffeur en passagier?',
        en: '4) Is HeyCaby a party to the Driver-Rider transport agreement?',
        es: '4) ¿HeyCaby es parte del acuerdo de transporte entre conductor y pasajero?',
        ar: '4) هل HeyCaby طرف في اتفاق النقل بين السائق والراكب؟',
      );
  static List<String> get indemnificationQuizQuestion4Options => [
        _t(
          'Ja',
          en: 'Yes',
          es: 'Sí',
          ar: 'نعم',
        ),
        _t(
          'Nee',
          en: 'No',
          es: 'No',
          ar: 'لا',
        ),
        _t(
          'Alleen bij geschillen',
          en: 'Only for disputes',
          es: 'Solo en disputas',
          ar: 'فقط في النزاعات',
        ),
      ];
  static String get indemnificationQuizQuestion5 => _t(
        '5) Wat moet geldig zijn voordat je gaat rijden?',
        en: '5) What must be valid before operating?',
        es: '5) ¿Qué debe estar vigente antes de operar?',
        ar: '5) ما الذي يجب أن يكون ساريا قبل العمل؟',
      );
  static List<String> get indemnificationQuizQuestion5Options => [
        _t(
          'Alleen app-login',
          en: 'Only app login',
          es: 'Solo iniciar sesión en la app',
          ar: 'تسجيل الدخول إلى التطبيق فقط',
        ),
        _t(
          'Vergunningen, verzekeringen en wettelijke naleving',
          en: 'Licences/permits/insurance and legal compliance',
          es: 'Licencias, permisos, seguro y cumplimiento legal',
          ar: 'التراخيص والتصاريح والتأمين والامتثال القانوني',
        ),
        _t(
          'Alleen voertuigfoto',
          en: 'Only vehicle photo',
          es: 'Solo foto del vehículo',
          ar: 'صورة المركبة فقط',
        ),
      ];
  static const String vehiclePlateRdwOpenSource =
      'APK- en taxistatus worden gecontroleerd via RDW-open data. We hebben alleen je kenteken nodig.';

  /// Home banner when `profile_status` is pending admin review.
  static const String verificationPendingTitle = 'Documenten in beoordeling';
  static const String verificationPendingBody =
      'Ons team controleert je chauffeurspas en KvK-gegevens. Je kunt online als je profiel is goedgekeurd.';
  static const String congratsTitle = 'Welkom bij HeyCaby!';
  static String congratsTitleWithName(String name) =>
      'Welkom bij HeyCaby, $name!';
  static const String congratsBody =
      'Je profiel is goedgekeurd. Je kunt nu ritaanvragen ontvangen.';
  static const String congratsStart = 'Start mijn eerste rit';
  static String get congratsInvite => _t(
        'Groei je stad',
        en: 'Grow Your City',
        es: 'Haz crecer tu ciudad',
        ar: 'نمّ مدينتك',
      );
  static const String recentPassengerComments =
      'Recente opmerkingen van passagiers';
  static const String whatReducedMyScore = 'Waardoor daalde mijn score?';
  static const String scoreFactorsDesc =
      'Je score is gebaseerd op passagiersbeoordelingen en je acceptatiegraad. Geweigerde aanvragen en lagere beoordelingen kunnen je score verlagen.';
  static String get ridesThisWeek => _t(
        'Ritten deze week',
        en: 'Rides this week',
        es: 'Viajes esta semana',
        ar: 'رحلات هذا الأسبوع',
      );
  static const String taxSummary = 'Belastingoverzicht';
  static const String viewDetails = 'Details bekijken';
  static const String goBackOnline = 'Weer online gaan';
  static String get locationRequired => _t(
        'Locatie vereist',
        en: 'Location required',
        es: 'Ubicación requerida',
        ar: 'الموقع مطلوب',
      );
  static String get locationRequiredMessage => _t(
        'HeyCaby heeft je locatie nodig voor de kaart, het vinden van ritten en navigatie. '
        'Zonder locatie kun je de chauffeursapp niet gebruiken.',
        en: 'HeyCaby needs your location for the map, ride matching, and navigation. '
            'Without location, you cannot use the driver app.',
        es: 'HeyCaby necesita tu ubicación para el mapa, encontrar viajes y navegar. '
            'Sin ubicación no puedes usar la app de conductor.',
        ar: 'يحتاج HeyCaby إلى موقعك للخريطة ومطابقة الرحلات والملاحة. '
            'بدون الموقع لا يمكنك استخدام تطبيق السائق.',
      );
  static const String connectivityOfflineBanner =
      'Geen internet. Acties wachten tot je weer online bent.';
  static const String connectivityRetry = 'Opnieuw';
  static const String connectivityBackOnline = 'Verbinding hersteld.';
  static String connectivityBackOnlineWithQueue(int count) =>
      'Verbinding hersteld. $count actie(s) opnieuw geprobeerd.';
  static const String connectivityOfflineActionBlocked =
      'Geen internetverbinding. Probeer opnieuw zodra je online bent.';
  static const String gpsLostBanner =
      'GPS-signaal zwak. Locatie wordt mogelijk niet bijgewerkt.';
  static const String nearPickupAssistBanner =
      'Je bent bijna bij het ophaalpunt — bevestig aankomst wanneer je er bent.';
  static const String nearDestinationAssistBanner =
      'Je bent bijna op de bestemming — voltooi de rit wanneer je veilig kunt stoppen.';
  static const String sessionRevokedTitle = 'Ingelogd op een ander apparaat';
  static const String sessionRevokedBody =
      'Je bent uitgelogd omdat er op een ander apparaat is ingelogd. Log opnieuw in op dit apparaat als dat de juiste is.';
  static const String sessionRevokedCta = 'Naar inloggen';
  static String get enableLocation => _t(
        'Locatie inschakelen',
        en: 'Enable location',
        es: 'Activar ubicación',
        ar: 'تفعيل الموقع',
      );
  static String get tryAgain => _t(
        'Opnieuw proberen',
        en: 'Try again',
        es: 'Intentar de nuevo',
        ar: 'حاول مرة أخرى',
      );
  static String get runtimeGateTitle => _t(
        'Accountstatus',
        en: 'Account status',
        es: 'Estado de cuenta',
        ar: 'حالة الحساب',
      );
  static String get runtimeGateBackHome => _t(
        'Terug naar start',
        en: 'Back home',
        es: 'Volver al inicio',
        ar: 'العودة للرئيسية',
      );
  static String get runtimeComplianceBlockedTitle => _t(
        'Maak je profiel compleet',
        en: 'Complete your profile',
        es: 'Completa tu perfil',
        ar: 'أكمل ملفك',
      );
  static String get runtimeComplianceBlockedBody => _t(
        'Rond de ontbrekende vereisten af voordat je online gaat.',
        en: 'Finish the missing requirements before going online.',
        es: 'Completa los requisitos pendientes antes de conectarte.',
        ar: 'أكمل المتطلبات الناقصة قبل الاتصال.',
      );
  static String get runtimePaymentBlockedTitle => _t(
        'Platform Balance vereist',
        en: 'Platform Balance required',
        es: 'Balance de plataforma requerido',
        ar: 'رصيد المنصة مطلوب',
      );
  static String get runtimePaymentBlockedBody => _t(
        'Vereffen je Platform Balance voordat je nieuwe ritten ontvangt.',
        en: 'Settle your Platform Balance before receiving new rides.',
        es: 'Liquida tu balance de plataforma antes de recibir nuevos viajes.',
        ar: 'سو رصيد المنصة قبل استقبال رحلات جديدة.',
      );
  static String get runtimeUnknownBlockedTitle => _t(
        'Actie vereist',
        en: 'Action required',
        es: 'Acción requerida',
        ar: 'إجراء مطلوب',
      );
  static String get runtimeUnknownBlockedBody => _t(
        'Controleer je profiel en probeer opnieuw.',
        en: 'Check your profile and try again.',
        es: 'Revisa tu perfil e inténtalo de nuevo.',
        ar: 'تحقق من ملفك وحاول مرة أخرى.',
      );
  static String get runtimeOpenDocuments => _t(
        'Documenten openen',
        en: 'Open documents',
        es: 'Abrir documentos',
        ar: 'افتح المستندات',
      );
  static String get runtimeOpenBilling => _t(
        'Platform Balance openen',
        en: 'Open Platform Balance',
        es: 'Abrir balance de plataforma',
        ar: 'افتح رصيد المنصة',
      );
  static String get runtimeOpenTariffs => _t(
        'Tarief instellen',
        en: 'Set tariff',
        es: 'Configurar tarifa',
        ar: 'اضبط التعرفة',
      );
  static String get runtimeMissingProfilePhoto => _t(
        'Voeg je profielfoto toe voordat je online gaat.',
        en: 'Complete your profile photo before going online.',
        es: 'Completa tu foto de perfil antes de conectarte.',
        ar: 'أكمل صورة ملفك قبل الاتصال.',
      );
  static String get runtimeMissingVehiclePhoto => _t(
        'Voeg een foto van je taxi toe voordat je online gaat.',
        en: 'Add a photo of your taxi before going online.',
        es: 'Añade una foto de tu taxi antes de conectarte.',
        ar: 'أضف صورة لسيارتك قبل الاتصال.',
      );
  static String get runtimeMissingTaxiVerification => _t(
        'Verifieer je taxi voordat je ritten ontvangt.',
        en: 'Verify your taxi before receiving rides.',
        es: 'Verifica tu taxi antes de recibir viajes.',
        ar: 'تحقق من التاكسي قبل استقبال الرحلات.',
      );
  static String get runtimeMissingTerms => _t(
        'Accepteer de verplichte chauffeursvoorwaarden voordat je online gaat.',
        en: 'Accept the required driver terms before going online.',
        es: 'Acepta los términos obligatorios del conductor antes de conectarte.',
        ar: 'اقبل شروط السائق المطلوبة قبل الاتصال.',
      );
  static String get runtimeMissingIdentity => _t(
        'Rond je identiteitsverificatie af.',
        en: 'Complete your identity verification.',
        es: 'Completa tu verificación de identidad.',
        ar: 'أكمل التحقق من هويتك.',
      );
  static String get runtimeMissingInitialTariff => _t(
        'Stel je eerste tarief in voordat je online gaat.',
        en: 'Set your first tariff before going online.',
        es: 'Configura tu primera tarifa antes de conectarte.',
        ar: 'اضبط أول تعرفة قبل الاتصال.',
      );
  static String runtimeMissingGeneric(String label) => _t(
        'Rond $label af voordat je online gaat.',
        en: 'Complete $label before going online.',
        es: 'Completa $label antes de conectarte.',
        ar: 'أكمل $label قبل الاتصال.',
      );
  static const String goOnlineGuidanceSubtitle =
      'Rond elke stap hieronder af en probeer daarna opnieuw online te gaan.';
  static String goOnlineGuidanceProgress(int pct) => 'Je bent $pct% onderweg';
  static const String goOnlineGuidanceOpenAction = 'Oplossen';
  static const String goOnlineGuidanceViewAll = 'Alle vereisten bekijken';
  static const String goOnlineGuidanceClose = 'Begrepen';

  // Rate profiles / Driver Hub
  static const String activeRates = 'Actieve tarieven';
  static const String activeRateProfile = 'Actief tariefprofiel';
  static const String manageProfiles = 'Profielen beheren';
  static const String editTariffs = 'Tarieven bewerken';
  static const String editTariffsHint =
      'Volledig scherm voor alle tariefprijzen.';
  static String get active => _t(
        'Actief',
        en: 'Active',
        es: 'Activo',
        ar: 'نشط',
      );
  static const String notSet = 'Not set';
  static const String rateProfileHint =
      'Kies het profiel dat je nu wilt gebruiken.';
  static const String standardProfileOnlyHint =
      'Je hebt nu alleen Standaard. Voeg profielen toe om per dagdeel te wisselen.';
  static const String tariffQuickSwitch = 'Snel tarief wisselen';
  static const String morningTariff = 'Ochtendtarief';
  static const String eveningTariff = 'Avondtarief';
  static const String lateNightTariff = 'Nachtarief';
  static const String standardTariff = 'Standaardtarief';
  static const String defaultRates = 'Standaardtarieven';
  static const String tariffSuffix = 'tarief';
  static const String dayShift = 'Dagdienst';
  static const String peakHours = 'Spitsuren';
  static const String afterDark = 'Na zonsondergang';
  static const String createDayPartProfiles =
      'Ochtend, avond & nacht instellen';
  static const String creatingDayPartProfiles = 'Profielen instellen…';
  static const String manageProfilesHint =
      'Open het tabblad Werk om alle profielen te beheren.';
  static const String tariffEditorTitle = 'Tarieveneditor';
  static const String tariffEditorSubtitle =
      'Stel prijzen per tarief in en sla globaal op.';
  static String get initialTariffTitle => _t(
        'Stel je eerste tarief in',
        en: 'Set your first tariff',
        es: 'Configura tu primera tarifa',
        ar: 'اضبط أول تعرفة',
      );
  static String get initialTariffBody => _t(
        'Rijders moeten je prijs zien voordat ze kunnen boeken. Voeg nu je basistarief toe; geavanceerde tarieven kun je later aanpassen in Driver Hub.',
        en: 'Riders need to see your price before they can book you. Add your basic taxi tariff now; you can edit advanced tariffs later in Driver Hub.',
        es: 'Los pasajeros necesitan ver tu precio antes de reservar. Añade ahora tu tarifa básica; puedes editar tarifas avanzadas después en Driver Hub.',
        ar: 'يحتاج الركاب إلى رؤية سعرك قبل الحجز. أضف تعرفة التاكسي الأساسية الآن؛ يمكنك تعديل التعرفات المتقدمة لاحقا في Driver Hub.',
      );
  static String get initialTariffPricePerKm => _t(
        'Prijs per km',
        en: 'Price per km',
        es: 'Precio por km',
        ar: 'السعر لكل كم',
      );
  static String get initialTariffPricePerMinute => _t(
        'Prijs per minuut',
        en: 'Price per minute',
        es: 'Precio por minuto',
        ar: 'السعر لكل دقيقة',
      );
  static String get initialTariffStartFee => _t(
        'Starttarief',
        en: 'Start fee',
        es: 'Tarifa inicial',
        ar: 'رسوم البداية',
      );
  static String get initialTariffVat => _t(
        'BTW %',
        en: 'VAT %',
        es: 'IVA %',
        ar: 'ضريبة القيمة المضافة %',
      );
  static String get initialTariffSave => _t(
        'Tarief opslaan',
        en: 'Save tariff',
        es: 'Guardar tarifa',
        ar: 'احفظ التعرفة',
      );
  static String get initialTariffSaving => _t(
        'Tarief opslaan...',
        en: 'Saving tariff...',
        es: 'Guardando tarifa...',
        ar: 'جار حفظ التعرفة...',
      );
  static String get initialTariffSaved => _t(
        'Tarief opgeslagen. Je kunt nu online gaan.',
        en: 'Tariff saved. You can now go online.',
        es: 'Tarifa guardada. Ahora puedes conectarte.',
        ar: 'تم حفظ التعرفة. يمكنك الاتصال الآن.',
      );
  static String get initialTariffInvalid => _t(
        'Vul geldige bedragen in voordat je opslaat.',
        en: 'Enter valid amounts before saving.',
        es: 'Introduce importes válidos antes de guardar.',
        ar: 'أدخل مبالغ صالحة قبل الحفظ.',
      );
  static String get initialTariffFailed => _t(
        'Tarief opslaan mislukt. Probeer opnieuw.',
        en: 'Tariff could not be saved. Try again.',
        es: 'No se pudo guardar la tarifa. Inténtalo de nuevo.',
        ar: 'تعذر حفظ التعرفة. حاول مرة أخرى.',
      );
  static const String tariffSuggestionCardTitle =
      'Voorgestelde tarieven per dagdeel';
  static const String tariffSuggestionCardBody =
      'Je mist nog profielen voor ochtend, avond en/of nacht. Tik op de knop hieronder om die toe te voegen met voorstellen op basis van je standaardtarief. Pas daarna gerust elk bedrag aan.';
  static const String tariffSuggestionCardButton =
      'Voorgestelde tarieven toevoegen';
  static String get activeTariffPricing => _t(
        'Actieve tariefprijzen',
        en: 'Active tariff pricing',
        es: 'Precios de la tarifa activa',
        ar: 'أسعار التعرفة النشطة',
      );
  static const String waitPerMin = 'Wacht / min';
  static const String saveAllTariffs = 'Alle tarieven opslaan';
  static const String savingTariffs = 'Tarieven opslaan…';
  static const String tariffsSaved = 'Tarieven opgeslagen.';
  static const String tariffsSaveFailed =
      'Tarieven opslaan mislukt. Probeer opnieuw.';
  static const String viewYourEarnings = 'Bekijk je verdiensten';
  static const String closeRateModalHint =
      'Veeg omhoog of tik op X om te sluiten';
  static const String manageRates = 'Tarieven beheren';
  static const String driverHub = 'Driver Hub';
  static const String driverHubHomeSubtitle = 'Manage your taxi business';
  static const String driverHubCurrentTariff = 'Current tariff';
  static const String driverHubToday = 'Today';
  static const String driverHubBusinessControls = 'Business controls';
  static const String driverHubBusinessControlsHint =
      'Preferences, availability, and ride settings';
  static const String driverHubReturnModeHint =
      'Return Mode distance and discount live on the Home card.';
  static const String recenterMap = 'My location';
  static const String mapDemandHigh = 'High demand';
  static const String mapDemandActive = 'Active demand';
  static String mapDemandWaiting(int n) => _t(
        '$n wachtend',
        en: '$n waiting',
        es: '$n esperando',
        ar: '$n ينتظرون',
      );
  static String mapEtaMinutes(int min) => '$min min';
  static const String mapEtaPickup = 'Pickup';
  static const String driverHubSubtitle =
      'Manage your goals, tariffs, and safety.';
  static const String goalsSectionTitle = 'Goals';
  static const String goalsSectionHelper =
      'Stel een doel in en zie hoeveel je nog nodig hebt.';
  static const String earnedLabel = 'earned';
  static String remainingToGoal(String amount) => 'Nog €$amount tot je doel';
  static const String setGoalButton = 'Doel instellen';
  static const String earningsTarget = 'Dagdoel';
  static const String setTarget = 'Doel instellen →';
  static const String daily = 'Dag';
  static const String weekly = 'Week';
  static const String dailyLong = 'Dagelijks';
  static const String weeklyLong = 'Wekelijks';
  static const String ratesSectionTitle = 'Jouw tarieven';
  static const String ratesSectionHelper =
      'Dit rekenen passagiers: start + per km + per minuut + wachten.';
  static const String rateStart = 'Start';
  static const String ratePerKm = 'Per km';
  static const String ratePerMin = 'Per min';
  static const String rateWaiting = 'Wachten';
  static const String manageRatesLink = 'Tarieven beheren →';
  static const String safetySectionTitle = 'Veiligheid';
  static const String call112 = '112 bellen';
  static const String safetyToolkit = 'Veiligheidskit';
  static const String emergencyCall = 'Alarmnummer bellen';
  static const String emergencyCallSubtitle = '112 — politie en ambulance';
  static const String shareTripDetails = 'Rit details delen';
  static const String shareTripSubtitleActive = 'Deel je huidige rit';
  static const String shareTripSubtitleInactive =
      'Beschikbaar tijdens actieve rit';
  static const String audioRecording = 'Audio opname';
  static const String audioRecordingSubtitleActive = 'Opname starten';
  static const String audioRecordingSubtitleInactive =
      'Beschikbaar tijdens actieve rit';
  static const String recordingInProgress = 'Opname loopt…';
  static const String helpSectionTitle = 'Hulp';
  static const String chatWithSupport = 'Chat met ondersteuning';
  static const String chatWithSupportHelper =
      'We reageren meestal binnen enkele uren.';
  static const String recentTickets = 'Recente meldingen';
  static const String helpAndSupport = 'Help & ondersteuning';
  static String get supportContactSection => _t(
        'Contact',
        en: 'Contact',
        es: 'Contacto',
        ar: 'التواصل',
      );
  static const String seeAllTickets = 'Alles zien →';
  static const String sendMessage = 'Stuur een bericht';
  static const String messages = 'Berichten';
  static const String helpArticles = 'Help-artikelen';
  static const String ticketStatusNoResponse = 'U heeft niet gereageerd';
  static const String ticketStatusInProgress = 'In behandeling';
  static const String ticketStatusResolved = 'Opgelost';
  static const String save = 'Opslaan';

  // Return trips
  static String get returnTrips => _t(
        'Retourritten',
        en: 'Return rides',
        es: 'Viajes de vuelta',
        ar: 'رحلات العودة',
      );
  static String get returnMode => _t(
        'Retourmodus',
        en: 'Return Mode',
        es: 'Modo de vuelta',
        ar: 'وضع العودة',
      );
  static String get returnModeOff => _t(
        'Uit',
        en: 'Off',
        es: 'Desactivado',
        ar: 'متوقف',
      );
  static String get returnModeOffBody => _t(
        'Op weg naar huis? Bekijk ritten die richting uw thuisgebied gaan.',
        en: 'Heading home? View rides that move toward your home area.',
        es: '¿Vuelves a casa? Mira viajes que van hacia tu zona.',
        ar: 'هل تتجه إلى المنزل؟ اعرض الرحلات المتجهة نحو منطقتك.',
      );
  static String returnModeHeadingTo(String destination) => _t(
        'Richting $destination',
        en: 'Heading to $destination',
        es: 'Hacia $destination',
        ar: 'متجه إلى $destination',
      );
  static String returnModeActiveBody({
    required double pickupRadiusKm,
    required double discountPct,
  }) =>
      _t(
        '${pickupRadiusKm.toStringAsFixed(0)} km ophaalgebied · ${discountPct.toStringAsFixed(0)}% korting',
        en: '${pickupRadiusKm.toStringAsFixed(0)} km pickup range · ${discountPct.toStringAsFixed(0)}% discount',
        es: '${pickupRadiusKm.toStringAsFixed(0)} km de recogida · ${discountPct.toStringAsFixed(0)}% de descuento',
        ar: 'نطاق التقاط ${pickupRadiusKm.toStringAsFixed(0)} كم · خصم ${discountPct.toStringAsFixed(0)}%',
      );
  static String get returnModeNoMatchesYet => _t(
        'Nog geen retourritten. We blijven zoeken terwijl u rijdt.',
        en: "No return rides yet. We'll keep looking while you drive.",
        es: 'Aún no hay viajes de vuelta. Seguiremos buscando mientras conduces.',
        ar: 'لا توجد رحلات عودة بعد. سنواصل البحث أثناء قيادتك.',
      );
  static String returnModeAvailableCount(int count) => _t(
        '$count geschikte retourritten beschikbaar',
        en: '$count suitable return rides available',
        es: '$count viajes de vuelta adecuados disponibles',
        ar: '$count رحلات عودة مناسبة متاحة',
      );
  static String get returnModeActivate => _t(
        'Activeren',
        en: 'Activate',
        es: 'Activar',
        ar: 'تفعيل',
      );
  static String get returnModeActivateFull => _t(
        'Retourmodus activeren',
        en: 'Activate Return Mode',
        es: 'Activar modo de vuelta',
        ar: 'تفعيل وضع العودة',
      );
  static String get returnModeManage => _t(
        'Beheren',
        en: 'Manage',
        es: 'Gestionar',
        ar: 'إدارة',
      );
  static String get returnModeDisable => _t(
        'Uitschakelen',
        en: 'Disable',
        es: 'Desactivar',
        ar: 'إيقاف',
      );
  static String get returnModeActivationFailed => _t(
        'Retourmodus kon niet worden geactiveerd.',
        en: 'Return Mode could not be activated.',
        es: 'No se pudo activar el modo de vuelta.',
        ar: 'تعذر تفعيل وضع العودة.',
      );
  static String get returnModeHeadingHomeTitle => _t(
        'Richting huis?',
        en: 'Heading home?',
        es: '¿Vuelves a casa?',
        ar: 'هل تتجه إلى المنزل؟',
      );
  static String returnModeHeadingHomeBody(String destination) => _t(
        'Wij kunnen ritten zoeken die u richting $destination brengen.',
        en: 'We can find rides that move you toward $destination.',
        es: 'Podemos buscar viajes que te acerquen a $destination.',
        ar: 'يمكننا العثور على رحلات تقربك من $destination.',
      );
  static String get notNow => _t(
        'Niet nu',
        en: 'Not now',
        es: 'Ahora no',
        ar: 'ليس الآن',
      );
  static String get returnTripsEmpty => _t(
        'Geen retourritten beschikbaar.',
        en: 'No return rides available.',
        es: 'No hay viajes de vuelta disponibles.',
        ar: 'لا توجد رحلات عودة متاحة.',
      );
  static const String yourReturnDiscount = 'Jouw retourkorting';
  static const String returnDiscountSharedCosts =
      'Reiskosten gedeeld met passagier';
  static String get matchChance => _t(
        'Match kans',
        en: 'Match chance',
        es: 'Probabilidad de match',
        ar: 'فرصة المطابقة',
      );
  static String get matchChanceLow => _t(
        'laag',
        en: 'low',
        es: 'baja',
        ar: 'منخفضة',
      );
  static String get matchChanceMedium => _t(
        'gemiddeld',
        en: 'medium',
        es: 'media',
        ar: 'متوسطة',
      );
  static String get matchChanceHigh => _t(
        'hoog',
        en: 'high',
        es: 'alta',
        ar: 'مرتفعة',
      );
  static String matchChanceSummary(double pct) {
    final label = pct <= 10
        ? matchChanceLow
        : pct <= 25
            ? matchChanceMedium
            : matchChanceHigh;
    return '$matchChance: $label';
  }

  static const String accept = 'Accepteren';

  // Status timestamps
  static const String onlineSince = 'Online · sinds';
  static const String onBreakSince = 'Pauze · sinds';

  // Support chat (our additions)
  static const String ondersteuning = 'Support';
  static const String nieuwBericht = 'New message';
  static const String berichten = 'Messages';
  static const String helpArtikelen = 'Help articles';
  static const String veelgesteldeVragen = 'Frequently asked questions';
  static const String recenteRitten = 'Recent rides with issues';
  static const String alleZien = 'See all';
  static const String versturen = 'Send';
  static const String geenBerichten = 'No messages';
  static const String berichtTypen = 'Type a message…';
  static const String supportChatSendFailed =
      'Bericht kon niet worden verstuurd. Probeer opnieuw.';
  static const String supportChatOfflineSaved =
      'Je bericht is opgeslagen. De assistent is offline — de ondersteuning kan het nog steeds lezen.';
  static const String supportAiAssistantName = 'Lee';
  static const String supportAiConsentTitle =
      'Maak kennis met Lee, je AI-ondersteuningsassistent';
  static const String supportAiConsentIntro =
      'Lee is de AI-klantenserviceassistent van HeyCaby voor chauffeurs. Hij helpt bij eenvoudige ondersteuningsvragen en klachten.';
  static const String supportAiConsentDataSent =
      'Om je te helpen sturen we: je bericht, ticketcategorie en beperkte accountcontext die nodig is voor een antwoord.';
  static const String supportAiConsentThirdParty =
      'AI-verwerking: Lee gebruikt OpenAI (ChatGPT)-modellen om antwoorden te genereren.';
  static const String supportAiConsentPolicy =
      'Bij serieuze of gevoelige kwesties: deel geen privégegevens in AI-chat. Mail de ondersteuning via hello@heycaby.nl.';
  static const String supportAiConsentEmailOption =
      'Deel geen wachtwoorden, volledige betaalkaartnummers, overheids-ID\'s of andere zeer gevoelige gegevens in AI-chat.';
  static const String supportAiConsentCheckbox =
      'Ik begrijp welke gegevens worden gedeeld, wie ze verwerkt, en geef HeyCaby toestemming om deze ondersteuningschatgegevens te delen met Lee AI-ondersteuning.';
  static const String supportAiConsentContinue = 'Ik ga akkoord en ga verder';
  static const String supportAiConsentSendEmail = 'Stuur liever een e-mail';
  static const String ritProbleem = 'Rit probleem';
  static const String betaling = 'Betaling';
  static const String account = 'Account';
  static const String overige = 'Overige';
  static const String open = 'Open';
  static String get notificationOpenAction => _t(
        'Openen',
        en: 'Open',
        es: 'Abrir',
        ar: 'فتح',
      );

  // Profile settings
  static const String mijnVoertuig = 'Mijn voertuig';
  static const String documenten = 'Documenten';
  static const String werkgebied = 'Werkgebied';
  static const String taal = 'Taal';
  static const String thema = 'Thema';
  static const String meldingen = 'Meldingen';
  static const String privacyBeleid = 'Privacy beleid';
  static const String gebruiksvoorwaarden = 'Gebruiksvoorwaarden';

  // FAQ / Terms / Privacy
  static String get faq => _t(
        'Veelgestelde vragen',
        en: 'Frequently asked questions',
        es: 'Preguntas frecuentes',
        ar: 'الأسئلة الشائعة',
      );
  static String get faqGettingStarted => _t(
        'Aan de slag',
        en: 'Getting started',
        es: 'Primeros pasos',
        ar: 'البدء',
      );
  static String get faqRidesEarnings => _t(
        'Ritten en verdiensten',
        en: 'Rides and earnings',
        es: 'Viajes y ganancias',
        ar: 'الرحلات والأرباح',
      );
  static String get faqBreaksShifts => _t(
        'Pauzes en diensten',
        en: 'Breaks and shifts',
        es: 'Descansos y turnos',
        ar: 'الاستراحات والورديات',
      );
  static String get faqSafety => _t(
        'Veiligheid',
        en: 'Safety',
        es: 'Seguridad',
        ar: 'السلامة',
      );
  static String get faqDocumentsCompliance => _t(
        'Documenten en compliance',
        en: 'Documents and compliance',
        es: 'Documentos y cumplimiento',
        ar: 'المستندات والامتثال',
      );
  static String get faqSupport => _t(
        'Ondersteuning',
        en: 'Support',
        es: 'Soporte',
        ar: 'الدعم',
      );
  static String get faqHowGoOnlineQuestion => _t(
        'Hoe ga ik online?',
        en: 'How do I go online?',
        es: '¿Cómo me conecto?',
        ar: 'كيف أصبح متصلا؟',
      );
  static String get faqHowGoOnlineAnswer => _t(
        'Gebruik de schuifknop op het startscherm om online te gaan. Veeg naar rechts om online te gaan, naar het midden voor pauze, en naar links om offline te gaan.',
        en: 'Use the status control on the home screen. Slide right to go online, to the middle for break, and left to go offline.',
        es: 'Usa el control de estado en la pantalla de inicio. Desliza a la derecha para conectarte, al centro para descanso y a la izquierda para desconectarte.',
        ar: 'استخدم زر الحالة في الشاشة الرئيسية. مرر يمينا للاتصال، وإلى الوسط للاستراحة، ويسارا لعدم الاتصال.',
      );
  static String get faqRatesQuestion => _t(
        'Hoe stel ik mijn tarieven in?',
        en: 'How do I set my rates?',
        es: '¿Cómo configuro mis tarifas?',
        ar: 'كيف أحدد أسعاري؟',
      );
  static String get faqRatesAnswer => _t(
        'Ga naar het Driver Hub-menu en tik op Tariefprofielen. Hier kunt u meerdere tariefprofielen aanmaken en schakelen tussen verschillende tarieven.',
        en: 'Open Driver Hub and tap tariff profiles. You can create multiple profiles and switch between rates.',
        es: 'Abre Driver Hub y toca perfiles de tarifa. Puedes crear varios perfiles y cambiar entre tarifas.',
        ar: 'افتح مركز السائق واضغط على ملفات التعرفة. يمكنك إنشاء عدة ملفات والتبديل بين الأسعار.',
      );
  static String get faqRideRequestsQuestion => _t(
        'Hoe ontvang ik ritaanvragen?',
        en: 'How do I receive ride requests?',
        es: '¿Cómo recibo solicitudes de viaje?',
        ar: 'كيف أستقبل طلبات الرحلات؟',
      );
  static String get faqRideRequestsAnswer => _t(
        'Zodra u online bent, ontvangt u automatisch ritaanvragen van passagiers in de buurt. U krijgt een melding met de ritdetails en kunt deze accepteren of weigeren.',
        en: 'Once you are online, nearby rider requests arrive automatically. You get a notification with ride details and can accept or decline.',
        es: 'Cuando estás en línea, las solicitudes cercanas llegan automáticamente. Recibirás una notificación con detalles y podrás aceptar o rechazar.',
        ar: 'عندما تكون متصلا، تصل طلبات الركاب القريبة تلقائيا. ستتلقى إشعارا بتفاصيل الرحلة ويمكنك القبول أو الرفض.',
      );
  static String get faqEarningsQuestion => _t(
        'Hoe berekent HeyCaby mijn verdiensten?',
        en: 'How does HeyCaby calculate my earnings?',
        es: '¿Cómo calcula HeyCaby mis ganancias?',
        ar: 'كيف يحسب HeyCaby أرباحي؟',
      );
  static String get faqEarningsAnswer => _t(
        'Uw verdiensten worden berekend op basis van het starttarief + prijs per kilometer + prijs per minuut. U stelt deze tarieven zelf in via uw tariefprofiel.',
        en: 'Your earnings are based on start price + price per kilometer + price per minute. You set these rates in your tariff profile.',
        es: 'Tus ganancias se basan en precio inicial + precio por kilómetro + precio por minuto. Tú configuras estas tarifas en tu perfil.',
        ar: 'تعتمد أرباحك على سعر البداية + السعر لكل كيلومتر + السعر لكل دقيقة. أنت تحدد هذه الأسعار في ملف التعرفة.',
      );
  static String get faqPaymentQuestion => _t(
        'Wanneer krijg ik betaald?',
        en: 'When do I get paid?',
        es: '¿Cuándo cobro?',
        ar: 'متى أحصل على الدفع؟',
      );
  static String get faqPaymentAnswer => _t(
        'Passagiers betalen direct aan u via contant geld, pin of Tikkie. HeyCaby rekent 0% commissie.',
        en: 'Riders pay you directly by cash, card, or Tikkie. HeyCaby charges 0% commission.',
        es: 'Los pasajeros te pagan directamente en efectivo, tarjeta o Tikkie. HeyCaby cobra 0% de comisión.',
        ar: 'يدفع لك الركاب مباشرة نقدا أو بالبطاقة أو عبر Tikkie. لا يأخذ HeyCaby أي عمولة.',
      );
  static String get faqReturnTripsQuestion => _t(
        'Wat zijn retourritten?',
        en: 'What are return rides?',
        es: '¿Qué son los viajes de vuelta?',
        ar: 'ما هي رحلات العودة؟',
      );
  static String get faqReturnTripsAnswer => _t(
        'Retourritten zijn ritten die terugkeren naar uw thuisgebied. Via de retourrittenmarktplaats kunt u ritten vinden die in uw richting gaan.',
        en: 'Return rides are trips heading back toward your home area. The return ride marketplace helps you find rides in your direction.',
        es: 'Los viajes de vuelta son trayectos que regresan hacia tu zona. El mercado de retorno te ayuda a encontrar viajes en tu dirección.',
        ar: 'رحلات العودة هي رحلات تتجه نحو منطقتك. يساعدك سوق رحلات العودة في العثور على رحلات باتجاهك.',
      );
  static String get faqMarketplaceQuestion => _t(
        'Hoe werkt de Marktplaats?',
        en: 'How does the marketplace work?',
        es: '¿Cómo funciona el mercado?',
        ar: 'كيف يعمل السوق؟',
      );
  static String get faqMarketplaceAnswer => _t(
        'Op de Marktplaats kunt u bieden op beschikbare ritten. Passagiers plaatsen een ritverzoek en u kunt hier op reageren met uw tarief.',
        en: 'In the marketplace you can respond to available ride requests with your own fare.',
        es: 'En el mercado puedes responder a solicitudes disponibles con tu propia tarifa.',
        ar: 'في السوق يمكنك الرد على طلبات الرحلات المتاحة بسعرك الخاص.',
      );
  static String get faqBreakLimitQuestion => _t(
        'Hoe lang mag ik rijden zonder pauze?',
        en: 'How long can I drive without a break?',
        es: '¿Cuánto puedo conducir sin descanso?',
        ar: 'كم يمكنني القيادة دون استراحة؟',
      );
  static String get faqBreakLimitAnswer => _t(
        'Volgens Nederlandse wet- en regelgeving mag u maximaal 4,5 uur achtereen rijden. Daarna is een pauze van minimaal 30 minuten verplicht.',
        en: 'Under Dutch rules, you may drive up to 4.5 hours continuously. After that, a break of at least 30 minutes is required.',
        es: 'Según las normas neerlandesas, puedes conducir hasta 4,5 horas seguidas. Después se requiere un descanso mínimo de 30 minutos.',
        ar: 'حسب القواعد الهولندية، يمكنك القيادة حتى 4.5 ساعات متواصلة. بعدها يلزم أخذ استراحة لا تقل عن 30 دقيقة.',
      );
  static String get faqTakeBreakQuestion => _t(
        'Hoe neem ik pauze?',
        en: 'How do I take a break?',
        es: '¿Cómo tomo un descanso?',
        ar: 'كيف آخذ استراحة؟',
      );
  static String get faqTakeBreakAnswer => _t(
        'Veeg de statusschakelaar naar het midden (pauze). Uw status verandert naar pauze en u ontvangt geen nieuwe ritaanvragen.',
        en: 'Slide the status control to the middle. Your status changes to break and you will not receive new ride requests.',
        es: 'Desliza el control de estado al centro. Tu estado cambia a descanso y no recibirás nuevas solicitudes.',
        ar: 'مرر زر الحالة إلى الوسط. ستتغير حالتك إلى استراحة ولن تستقبل طلبات جديدة.',
      );
  static String get faqEndShiftQuestion => _t(
        'Hoe beëindig ik mijn dienst?',
        en: 'How do I end my shift?',
        es: '¿Cómo termino mi turno?',
        ar: 'كيف أنهي ورديتي؟',
      );
  static String get faqEndShiftAnswer => _t(
        'Veeg de statusschakelaar naar links (offline). Als u langer dan 30 minuten online bent geweest, wordt er een bevestigingsdialoog getoond.',
        en: 'Slide the status control left to offline. If you were online for more than 30 minutes, a confirmation dialog appears.',
        es: 'Desliza el control a la izquierda para desconectarte. Si estuviste en línea más de 30 minutos, aparecerá una confirmación.',
        ar: 'مرر زر الحالة يسارا لعدم الاتصال. إذا كنت متصلا لأكثر من 30 دقيقة، ستظهر رسالة تأكيد.',
      );
  static String get faqSafetyKitQuestion => _t(
        'Wat is de veiligheidskit?',
        en: 'What is the safety kit?',
        es: '¿Qué es el kit de seguridad?',
        ar: 'ما هي حزمة السلامة؟',
      );
  static String get faqSafetyKitAnswer => _t(
        'De veiligheidskit bevat drie functies: noodoproep (112), rit delen met contactpersonen, en audio-opname tijdens ritten.',
        en: 'The safety kit includes emergency call, trip sharing with contacts, and ride audio recording.',
        es: 'El kit de seguridad incluye llamada de emergencia, compartir viaje con contactos y grabación de audio durante el viaje.',
        ar: 'تتضمن حزمة السلامة مكالمة طوارئ ومشاركة الرحلة مع جهات الاتصال وتسجيل الصوت أثناء الرحلات.',
      );
  static String get faqAudioQuestion => _t(
        'Hoe gebruik ik audio-opname?',
        en: 'How do I use audio recording?',
        es: '¿Cómo uso la grabación de audio?',
        ar: 'كيف أستخدم تسجيل الصوت؟',
      );
  static String get faqAudioAnswer => _t(
        'Audio-opname is alleen beschikbaar tijdens actieve ritten. Tik op Audio-opname in de veiligheidskit om te starten. De opname wordt lokaal opgeslagen.',
        en: 'Audio recording is available only during active rides. Tap audio recording in the safety kit to start. The recording is stored locally.',
        es: 'La grabación de audio solo está disponible durante viajes activos. Toca grabación en el kit de seguridad para iniciar. Se guarda localmente.',
        ar: 'تسجيل الصوت متاح فقط أثناء الرحلات النشطة. اضغط تسجيل الصوت في حزمة السلامة للبدء. يتم حفظ التسجيل محليا.',
      );
  static String get faqDocumentsQuestion => _t(
        'Welke documenten heb ik nodig?',
        en: 'Which documents do I need?',
        es: '¿Qué documentos necesito?',
        ar: 'ما المستندات التي أحتاجها؟',
      );
  static String get faqDocumentsAnswer => _t(
        'U heeft nodig: chauffeurspas, rijbewijs, VOG, taxidiploma en taxiverzekering.',
        en: 'You need your driver card, driving licence, VOG, taxi diploma, and taxi insurance.',
        es: 'Necesitas tarjeta de conductor, permiso de conducir, VOG, diploma de taxi y seguro de taxi.',
        ar: 'تحتاج إلى بطاقة السائق ورخصة القيادة وVOG ودبلوم التاكسي وتأمين التاكسي.',
      );
  static String get faqRenewDocumentsQuestion => _t(
        'Hoe verleng ik mijn documenten?',
        en: 'How do I renew my documents?',
        es: '¿Cómo renuevo mis documentos?',
        ar: 'كيف أجدد مستنداتي؟',
      );
  static String get faqRenewDocumentsAnswer => _t(
        'Neem contact op met het RDW of uw gemeente voor verlenging van uw chauffeurspas en rijbewijs. Voor de VOG kunt u terecht bij Justis.',
        en: 'Contact RDW or your municipality to renew your driver card and licence. For VOG, use Justis.',
        es: 'Contacta con RDW o tu municipio para renovar tu tarjeta de conductor y permiso. Para VOG, usa Justis.',
        ar: 'تواصل مع RDW أو بلديتك لتجديد بطاقة السائق والرخصة. بالنسبة إلى VOG استخدم Justis.',
      );
  static String get faqExpiredCardQuestion => _t(
        'Wat als mijn chauffeurspas verloopt?',
        en: 'What if my driver card expires?',
        es: '¿Qué pasa si caduca mi tarjeta de conductor?',
        ar: 'ماذا لو انتهت صلاحية بطاقة السائق؟',
      );
  static String get faqExpiredCardAnswer => _t(
        'Als uw chauffeurspas verloopt, wordt uw account opgeschort. Neem contact op met support via de in-app chat om uw documenten bij te werken.',
        en: 'If your driver card expires, your account is suspended. Contact support in the app chat to update your documents.',
        es: 'Si caduca tu tarjeta de conductor, tu cuenta se suspende. Contacta con soporte por el chat de la app para actualizar documentos.',
        ar: 'إذا انتهت صلاحية بطاقة السائق، سيتم تعليق حسابك. تواصل مع الدعم عبر دردشة التطبيق لتحديث المستندات.',
      );
  static String get faqContactSupportQuestion => _t(
        'Hoe neem ik contact op met support?',
        en: 'How do I contact support?',
        es: '¿Cómo contacto con soporte?',
        ar: 'كيف أتواصل مع الدعم؟',
      );
  static String get faqContactSupportAnswer => _t(
        'Ga naar Ondersteuning in het menu en tik op "Nieuw bericht" om een chatgesprek te starten met ons supportteam.',
        en: 'Go to Support in the menu and tap “New message” to start a chat with our support team.',
        es: 'Ve a Soporte en el menú y toca “Nuevo mensaje” para iniciar un chat con nuestro equipo.',
        ar: 'اذهب إلى الدعم في القائمة واضغط "رسالة جديدة" لبدء محادثة مع فريق الدعم.',
      );
  static String get faqCallSupportQuestion => _t(
        'Kan ik bellen met support?',
        en: 'Can I call support?',
        es: '¿Puedo llamar a soporte?',
        ar: 'هل يمكنني الاتصال بالدعم؟',
      );
  static String get faqCallSupportAnswer => _t(
        'Nee, communicatie met support verloopt uitsluitend via de in-app chat.',
        en: 'No. Support communication happens through the in-app chat.',
        es: 'No. La comunicación con soporte se realiza por el chat de la app.',
        ar: 'لا. يتم التواصل مع الدعم عبر دردشة التطبيق.',
      );
  static String get faqResponseTimeQuestion => _t(
        'Hoe lang duurt het voor ik antwoord krijg?',
        en: 'How long does it take to get a reply?',
        es: '¿Cuánto tardan en responder?',
        ar: 'كم يستغرق الحصول على رد؟',
      );
  static String get faqResponseTimeAnswer => _t(
        'Ons supportteam streeft ernaar binnen 24 uur te reageren op uw bericht.',
        en: 'Our support team aims to reply within 24 hours.',
        es: 'Nuestro equipo de soporte intenta responder en 24 horas.',
        ar: 'يسعى فريق الدعم للرد خلال 24 ساعة.',
      );
  static const String termsOfService = 'Gebruiksvoorwaarden';
  static const String privacyPolicy = 'Privacy beleid';
  static const String indemnification = 'Vrijwaring';
  static const String copiedToClipboard = 'Gekopieerd naar klembord';
  static String get actionFailedPrefix => _t(
        'Mislukt:',
        en: 'Failed:',
        es: 'Error:',
        ar: 'فشل:',
      );
  static const String requestsResumed = 'Nieuwe aanvragen hervat.';
  static const String requestsPaused = 'Nieuwe aanvragen gepauzeerd.';
  static const String requestStatusUpdateFailed =
      'Aanvraagstatus bijwerken mislukt:';
  static String get cancelOrder => _t(
        'Rit annuleren',
        en: 'Cancel ride',
        es: 'Cancelar viaje',
        ar: 'إلغاء الرحلة',
      );
  static String get optionalReason => _t(
        'Optionele reden',
        en: 'Optional reason',
        es: 'Motivo opcional',
        ar: 'سبب اختياري',
      );
  static String get back => _t(
        'Terug',
        en: 'Back',
        es: 'Atrás',
        ar: 'رجوع',
      );
  static String get cancelRide => _t(
        'Rit annuleren',
        en: 'Cancel ride',
        es: 'Cancelar viaje',
        ar: 'إلغاء الرحلة',
      );
  static String get cancelRideSheetTitle => _t(
        'Waarom annuleer je?',
        en: 'Why are you cancelling?',
        es: '¿Por qué cancelas?',
        ar: 'لماذا تلغي؟',
      );
  static String get cancelRideSheetBody => _t(
        'Kies een reden zodat support en de reiziger begrijpen wat er gebeurde.',
        en: 'Choose a reason so support and the rider understand what happened.',
        es: 'Elige un motivo para que soporte y el pasajero entiendan qué pasó.',
        ar: 'اختر سببا حتى يفهم الدعم والراكب ما حدث.',
      );
  static String get cancelRideReasonRiderUnavailable => _t(
        'Reiziger niet beschikbaar',
        en: 'Rider unavailable',
        es: 'Pasajero no disponible',
        ar: 'الراكب غير متاح',
      );
  static String get cancelRideReasonPickupIssue => _t(
        'Probleem bij ophaalpunt',
        en: 'Pickup issue',
        es: 'Problema en recogida',
        ar: 'مشكلة في نقطة الانطلاق',
      );
  static String get cancelRideReasonWrongDetails => _t(
        'Ritgegevens kloppen niet',
        en: 'Trip details are wrong',
        es: 'Los detalles del viaje son incorrectos',
        ar: 'تفاصيل الرحلة غير صحيحة',
      );
  static String get cancelRideReasonSafetyConcern => _t(
        'Veiligheidsprobleem',
        en: 'Safety concern',
        es: 'Preocupación de seguridad',
        ar: 'مشكلة سلامة',
      );
  static String get cancelRideReasonOther => _t(
        'Anders',
        en: 'Other',
        es: 'Otro',
        ar: 'أخرى',
      );
  static String get cancelRideReasonDetailsHint => _t(
        'Voeg details toe als dat helpt',
        en: 'Add details if helpful',
        es: 'Añade detalles si ayuda',
        ar: 'أضف تفاصيل إذا كان ذلك مفيدا',
      );
  static String get cancelRideReasonRequired => _t(
        'Kies een reden om te annuleren.',
        en: 'Choose a reason to cancel.',
        es: 'Elige un motivo para cancelar.',
        ar: 'اختر سببا للإلغاء.',
      );
  static String get rideCancelled => _t(
        'Rit geannuleerd.',
        en: 'Ride cancelled.',
        es: 'Viaje cancelado.',
        ar: 'تم إلغاء الرحلة.',
      );
  static const String riderCancelledTitle = 'Reiziger heeft geannuleerd';
  static const String riderCancelledBody =
      'De reiziger heeft deze rit geannuleerd. Je bent weer beschikbaar voor nieuwe ritten.';
  static const String riderCancelledCta = 'Terug naar home';
  static const String rideCancelFailed = 'Rit annuleren mislukt:';
  static const String pickupCoordinatesUnavailable =
      'Ophaalcoördinaten niet beschikbaar.';
  static const String destinationCoordinatesUnavailable =
      'Bestemmingscoördinaten niet beschikbaar.';
  static const String noNavigationAppAvailable =
      'Geen navigatie-app beschikbaar.';
  static const String noShowReported = 'No-show gemeld.';
  static String get selectRatingPrompt => _t(
        'Selecteer een beoordeling.',
        en: 'Select a rating.',
        es: 'Selecciona una valoración.',
        ar: 'اختر تقييما.',
      );
  static String get thanksForRating => _t(
        'Bedankt voor je beoordeling!',
        en: 'Thanks for your rating!',
        es: '¡Gracias por tu valoración!',
        ar: 'شكرا على تقييمك!',
      );
  static const String acceptRideFailedCode = 'Accepteren mislukt:';
  static const String acceptRideFailed = 'Rit accepteren mislukt:';
  static String get rideActionFailedMessage => _t(
        'Actie mislukt. Controleer je verbinding en probeer opnieuw.',
        en: 'Action failed. Check your connection and try again.',
        es: 'La acción falló. Revisa tu conexión e inténtalo de nuevo.',
        ar: 'فشل الإجراء. تحقق من اتصالك وحاول مرة أخرى.',
      );
  static String get rideRequestLoadFailedMessage => _t(
        'Ritaanvraag laden mislukt. Controleer je verbinding.',
        en: 'Could not load the ride request. Check your connection.',
        es: 'No se pudo cargar la solicitud de viaje. Revisa tu conexión.',
        ar: 'تعذر تحميل طلب الرحلة. تحقق من اتصالك.',
      );
  static String get acceptRideFailedMessage => _t(
        'Rit accepteren mislukt. De aanvraag is mogelijk al verlopen.',
        en: 'Could not accept the ride. The request may have expired.',
        es: 'No se pudo aceptar el viaje. Es posible que la solicitud haya caducado.',
        ar: 'تعذر قبول الرحلة. ربما انتهت صلاحية الطلب.',
      );
  static String get requestStatusUpdateFailedMessage => _t(
        'Aanvraagstatus bijwerken mislukt. Probeer opnieuw.',
        en: 'Could not update request status. Try again.',
        es: 'No se pudo actualizar el estado de solicitudes. Inténtalo de nuevo.',
        ar: 'تعذر تحديث حالة الطلبات. حاول مرة أخرى.',
      );
  static const String enterValidPaidAmount =
      'Voer een geldig betaald bedrag in.';
  static String get appSuggestionTooShort => _t(
        'Voeg meer details toe (minimaal 10 tekens).',
        en: 'Add more detail (at least 10 characters).',
        es: 'Añade más detalles (mínimo 10 caracteres).',
        ar: 'أضف تفاصيل أكثر (10 أحرف على الأقل).',
      );
  static String get appSuggestionReceived => _t(
        'Bedankt! Suggestie ontvangen. We beoordelen deze intern.',
        en: 'Thanks! Suggestion received. We’ll review it internally.',
        es: '¡Gracias! Sugerencia recibida. La revisaremos internamente.',
        ar: 'شكرا! تم استلام الاقتراح. سنراجعه داخليا.',
      );
  static String get appSuggestionSendFailed => _t(
        'Suggestie versturen mislukt. Probeer opnieuw.',
        en: 'Could not send the suggestion. Try again.',
        es: 'No se pudo enviar la sugerencia. Inténtalo de nuevo.',
        ar: 'تعذر إرسال الاقتراح. حاول مرة أخرى.',
      );
  static const String communityPostCreateFailed = 'Plaatsen mislukt.';
  static const String rideNotFound = 'Rit niet gevonden';
  static const String missedRequestTitle = 'Aanvraag gemist';
  static const String missedRequestBody =
      'Je hebt niet op je volgende ritaanvraag gereageerd.';
  static const String close = 'Sluiten';
  static const String rideCompleteTitle = 'Rit afgerond';
  static const String rideCompleted = 'Rit voltooid';
  static const String destination = 'Bestemming';
  static String get navigateToPickup => _t(
        'Navigeer naar ophaalpunt',
        en: 'Navigate to pickup',
        es: 'Navegar a la recogida',
        ar: 'التنقل إلى نقطة الالتقاط',
      );
  static String get enRouteToPickupTitle => _t(
        'Onderweg naar reiziger',
        en: 'On your way to the rider',
        es: 'De camino al pasajero',
        ar: 'في الطريق إلى الراكب',
      );
  static String get enRouteToPickupBody => _t(
        'Navigeer, stuur een ping of open de communicatie voordat je aankomt.',
        en: 'Navigate, send a ping, or open communication before you arrive.',
        es: 'Navega, envía un ping o abre la comunicación antes de llegar.',
        ar: 'تنقل أو أرسل تنبيها أو افتح التواصل قبل وصولك.',
      );
  static String get pingRiderAction => _t(
        'Ping reiziger',
        en: 'Ping rider',
        es: 'Enviar ping',
        ar: 'تنبيه الراكب',
      );
  static String get pickupLiveMeterTitle => _t(
        'Live wachttijd',
        en: 'Live waiting time',
        es: 'Espera en vivo',
        ar: 'وقت الانتظار المباشر',
      );
  static String get pickupLiveMeterBody => _t(
        'Jij en de reiziger zien dezelfde timer.',
        en: 'You and the rider see the same timer.',
        es: 'Tú y el pasajero veis el mismo temporizador.',
        ar: 'أنت والراكب تريان نفس المؤقت.',
      );
  static const String pickupAddress = 'Ophaaladres';
  static const String riderPrefix = 'Reiziger:';
  static const String rider = 'Reiziger';
  static const String contactRider = 'Chat met reiziger';
  static const String batteryOptimizationTitle = 'Achtergrond toestaan?';
  static const String batteryOptimizationBody =
      'Zonder uitzondering kan Android je locatie en ritmeldingen beperken terwijl je online bent.';
  static const String batteryOptimizationAllow = 'Instellingen openen';
  static const String batteryOptimizationLater = 'Later';
  static const String navigate = 'Navigeren';
  static const String avgPerRide = 'Gemiddeld per rit';
  static String get activeTariff => _t(
        'Actief tarief',
        en: 'Active tariff',
        es: 'Tarifa activa',
        ar: 'التعرفة النشطة',
      );
  static String get atPickup => _t(
        'Bij ophaalpunt',
        en: 'At pickup',
        es: 'En recogida',
        ar: 'عند نقطة الالتقاط',
      );
  static String get waiting => _t(
        'Wachten',
        en: 'Waiting',
        es: 'Esperando',
        ar: 'انتظار',
      );
  static String get riderDidNotShow => _t(
        'Reiziger niet verschenen',
        en: 'Rider did not show',
        es: 'El pasajero no apareció',
        ar: 'لم يظهر الراكب',
      );
  static const String noShowConfirmTitle = 'Reiziger niet verschenen?';
  static const String noShowConfirmBody =
      'Bevestig alleen als de reiziger na 5 minuten wachten niet is verschenen.';
  static const String noShowConfirmAction = 'No-show melden';
  static String get newRideRequest => _t(
        'Nieuwe ritaanvraag',
        en: 'New ride request',
        es: 'Nueva solicitud de viaje',
        ar: 'طلب رحلة جديد',
      );
  static String get opportunityIncomingBadge => _t(
        'Nieuwe aanvraag',
        en: 'New request',
        es: 'Nueva solicitud',
        ar: 'طلب جديد',
      );
  static String get opportunityDecideFast => _t(
        'Je hebt kort de tijd om deze rit te beoordelen.',
        en: 'You have a short window to review this trip.',
        es: 'Tienes poco tiempo para revisar este viaje.',
        ar: 'لديك وقت قصير لمراجعة هذه الرحلة.',
      );
  static String get incomingRideOpenFare => _t(
        'Open tarief',
        en: 'Open fare',
        es: 'Tarifa abierta',
        ar: 'أجرة مفتوحة',
      );
  static String get incomingRideEstimatedEarnings => _t(
        'Geschatte opbrengst',
        en: 'Estimated earnings',
        es: 'Ingresos estimados',
        ar: 'الأرباح المقدرة',
      );
  static String get incomingRideSkipHint => _t(
        'Overslaan heeft geen invloed op deze rit. Kies alleen ritten die bij jouw bedrijf passen.',
        en: 'Skipping will not affect this trip. Choose only rides that fit your business.',
        es: 'Omitir no afectará este viaje. Elige solo viajes que encajen con tu negocio.',
        ar: 'التخطي لن يؤثر على هذه الرحلة. اختر فقط الرحلات المناسبة لعملك.',
      );
  static String get incomingRideDeclineSafe => _t(
        'Kies de ritten die bij jouw bedrijf passen.',
        en: 'Choose the trips that work best for your business.',
        es: 'Elige los viajes que mejor funcionen para tu negocio.',
        ar: 'اختر الرحلات الأنسب لعملك.',
      );
  static String get incomingRideReviewTrip => _t(
        'Beoordeel de rit en beslis of deze past.',
        en: 'Review the trip and decide if it fits.',
        es: 'Revisa el viaje y decide si te conviene.',
        ar: 'راجع الرحلة وقرر إن كانت مناسبة لك.',
      );
  static String get incomingRideRoute => _t(
        'Route',
        en: 'Route',
        es: 'Ruta',
        ar: 'المسار',
      );
  static String get incomingRidePickup => _t(
        'Ophalen',
        en: 'Pickup',
        es: 'Recogida',
        ar: 'نقطة الانطلاق',
      );
  static String get incomingRideDropoff => _t(
        'Afzetten',
        en: 'Drop-off',
        es: 'Destino',
        ar: 'نقطة الوصول',
      );
  static String get incomingRideDemand => _t(
        'vraag',
        en: 'demand',
        es: 'demanda',
        ar: 'طلب',
      );
  static String get incomingRideRoutePreview => _t(
        'Rit in het kort',
        en: 'Trip at a glance',
        es: 'Viaje de un vistazo',
        ar: 'لمحة عن الرحلة',
      );
  static String get incomingRidePaymentFlexible => _t(
        'Flexibele betaling',
        en: 'Flexible payment',
        es: 'Pago flexible',
        ar: 'دفع مرن',
      );
  static String get paymentCash => _t(
        'Contant',
        en: 'Cash',
        es: 'Efectivo',
        ar: 'نقدا',
      );
  static String get paymentCard => _t(
        'Pin',
        en: 'Card',
        es: 'Tarjeta',
        ar: 'بطاقة',
      );
  static String get paymentInvoice => _t(
        'Factuur',
        en: 'Invoice',
        es: 'Factura',
        ar: 'فاتورة',
      );
  static String get decline => _t(
        'Overslaan',
        en: 'Skip',
        es: 'Omitir',
        ar: 'تخطي',
      );
  static String get rideInProgress => _t(
        'Rit bezig',
        en: 'Ride in progress',
        es: 'Viaje en curso',
        ar: 'الرحلة قيد التنفيذ',
      );
  static String get inProgressHeroTitle => _t(
        'Naar bestemming',
        en: 'Heading to destination',
        es: 'Hacia el destino',
        ar: 'في الطريق إلى الوجهة',
      );
  static String get inProgressHeroBody => _t(
        'Hou de kaart centraal. Alleen de belangrijkste acties blijven zichtbaar.',
        en: 'Keep the map central. Only the key actions stay visible.',
        es: 'Mantén el mapa al centro. Solo quedan las acciones clave.',
        ar: 'أبق الخريطة في الوسط. تبقى الإجراءات الأساسية فقط ظاهرة.',
      );
  static String get startRide => _t(
        'Rit starten',
        en: 'Start ride',
        es: 'Iniciar viaje',
        ar: 'بدء الرحلة',
      );
  static String get completeRide => _t(
        'Rit voltooien',
        en: 'Complete ride',
        es: 'Completar viaje',
        ar: 'إكمال الرحلة',
      );
  static String get rateRider => _t(
        'Reiziger beoordelen',
        en: 'Rate rider',
        es: 'Valorar pasajero',
        ar: 'تقييم الراكب',
      );
  static String get rateRiderHeadline => _t(
        'Hoe was je reiziger?',
        en: 'How was your rider?',
        es: '¿Cómo fue tu pasajero?',
        ar: 'كيف كان الراكب؟',
      );
  static String get rateRiderCommentHint => _t(
        'Optionele opmerking',
        en: 'Optional note',
        es: 'Nota opcional',
        ar: 'ملاحظة اختيارية',
      );
  static String get rateRiderSubmit => _t(
        'Versturen',
        en: 'Submit',
        es: 'Enviar',
        ar: 'إرسال',
      );
  static String get rateRiderSkip => skip;
  static String get skip => _t(
        'Overslaan',
        en: 'Skip',
        es: 'Omitir',
        ar: 'تخطي',
      );
  static String get createAccount => _t(
        'Account aanmaken',
        en: 'Create account',
        es: 'Crear cuenta',
        ar: 'إنشاء حساب',
      );
  static String get sendSuggestion => _t(
        'Suggestie versturen',
        en: 'Send suggestion',
        es: 'Enviar sugerencia',
        ar: 'إرسال الاقتراح',
      );
  static String get topRequestedIdeas => _t(
        'Meest gevraagde ideeën',
        en: 'Top requested ideas',
        es: 'Ideas más solicitadas',
        ar: 'أكثر الأفكار طلبا',
      );
  static String get noPublicIdeasYet => _t(
        'Nog geen publieke ideeën. Wees de eerste met een suggestie.',
        en: 'No public ideas yet. Be the first to suggest one.',
        es: 'Aún no hay ideas públicas. Sé el primero en sugerir una.',
        ar: 'لا توجد أفكار عامة بعد. كن أول من يقترح.',
      );
  static String get topIdeasLoadFailed => _t(
        'Topideeën laden nu niet. Probeer later opnieuw.',
        en: 'Top ideas are not loading right now. Try again later.',
        es: 'Las ideas principales no cargan ahora. Inténtalo más tarde.',
        ar: 'لا يمكن تحميل أهم الأفكار الآن. حاول لاحقا.',
      );
  static String votesCount(int count) => _t(
        '$count stemmen',
        en: '$count votes',
        es: '$count votos',
        ar: '$count أصوات',
      );
  static const String messageCategory = 'Categorie';
  static const String supportMessageSentTitle = 'Bericht verzonden';
  static const String supportMessageSentBody =
      'Bedankt voor je bericht. Ons ondersteuningsteam bekijkt het en reageert zo snel mogelijk.\n\nVoor urgente zaken kun je chatten met Lee (AI-ondersteuningsassistent).';
  static const String supportMessageSendFailedTitle =
      'Bericht verzenden mislukt';
  static const String supportMessageSendFailedBody =
      'We konden je ondersteuningsbericht nu niet verzenden. Probeer het straks opnieuw, of gebruik Chat met Lee bij spoed.';
  static const String leeSupportAssistant = 'Lee AI-ondersteuningsassistent';
  static const String leeSupportPrompt =
      'Stel vragen over ritten, account of uitbetalingen.';
  static const String submit = 'Versturen';
  static const String resumeRequests = 'Aanvragen hervatten';
  static const String stopNewRequests = 'Nieuwe aanvragen stoppen';
  static const String iHaveArrived = 'Ik ben gearriveerd';
  static const String preferencesLoadFailed = 'Voorkeuren laden mislukt';
  static const String financeAndTax = 'Financiën en belastingen';
  static String get profileLoadFailed => _t(
        'Profiel laden mislukt',
        en: 'Could not load profile',
        es: 'No se pudo cargar el perfil',
        ar: 'تعذر تحميل الملف',
      );
  static String get statusVerified => _t(
        'Geverifieerd',
        en: 'Verified',
        es: 'Verificado',
        ar: 'تم التحقق',
      );
  static String get profileCompletionTitle => _t(
        'Maak je profiel compleet',
        en: 'Complete your profile',
        es: 'Completa tu perfil',
        ar: 'أكمل ملفك',
      );
  static String profileCompletionProgress(int complete, int total) => _t(
        '$complete van $total afgerond',
        en: '$complete of $total completed',
        es: '$complete de $total completados',
        ar: 'اكتمل $complete من $total',
      );
  static String get profileCompletionReady => _t(
        'Je profiel is klaar voor ritaanvragen.',
        en: 'Your profile is ready for ride requests.',
        es: 'Tu perfil está listo para solicitudes de viaje.',
        ar: 'ملفك جاهز لطلبات الرحلات.',
      );
  static String get profileRequirementPlate => _t(
        'Taxi geverifieerd',
        en: 'Taxi verified',
        es: 'Taxi verificado',
        ar: 'تم التحقق من التاكسي',
      );
  static String get profileRequirementTerms => _t(
        'Voorwaarden geaccepteerd',
        en: 'Terms accepted',
        es: 'Términos aceptados',
        ar: 'تم قبول الشروط',
      );
  static String get profileRequirementDriverPhoto => _t(
        'Profielfoto chauffeur',
        en: 'Driver photo',
        es: 'Foto del conductor',
        ar: 'صورة السائق',
      );
  static String get profileRequirementVehiclePhoto => _t(
        'Voertuigfoto',
        en: 'Vehicle photo',
        es: 'Foto del vehículo',
        ar: 'صورة المركبة',
      );
  static String get vehiclePhotoMissingCta => _t(
        'Voertuigfoto toevoegen',
        en: 'Add taxi photo',
        es: 'Añadir foto del vehículo',
        ar: 'أضف صورة المركبة',
      );
  static String get driverPhotoMissingCta => _t(
        'Profielfoto toevoegen',
        en: 'Add driver photo',
        es: 'Añadir foto del conductor',
        ar: 'أضف صورة السائق',
      );
  static String get vehicleVerifiedTaxiEnglish => _t(
        'Geverifieerde taxi',
        en: 'Verified Taxi',
        es: 'Taxi verificado',
        ar: 'تاكسي موثق',
      );
  static String get vehicleSeatsLabel => _t(
        'zitplaatsen',
        en: 'seats',
        es: 'asientos',
        ar: 'مقاعد',
      );
  static const String statusSubmitted = 'Ingediend';
  static const String statusInReview = 'In behandeling';
  static const String statusRequired = 'Vereist';
  static const String statusNotTaxiVehicle = 'Niet-taxi voertuig';
  static const String statusManualReview = 'Handmatige beoordeling';
  static const String statusChecking = 'Controleren...';
  static String get pricingEditorActiveProfile => _t(
        'Actieve profielprijzen',
        en: 'Active profile pricing',
        es: 'Precios del perfil activo',
        ar: 'أسعار الملف النشط',
      );
  static String get pricingBase => _t(
        'Starttarief',
        en: 'Start price',
        es: 'Precio inicial',
        ar: 'سعر البداية',
      );
  static String get pricingPerKm => _t(
        'Per km',
        en: 'Per kilometer',
        es: 'Por kilómetro',
        ar: 'لكل كيلومتر',
      );
  static String get pricingPerMin => _t(
        'Per min',
        en: 'Per minute',
        es: 'Por minuto',
        ar: 'لكل دقيقة',
      );
  static String get pricingWaitPerMin => _t(
        'Wachten / min',
        en: 'Wait time / min',
        es: 'Espera / min',
        ar: 'الانتظار / دقيقة',
      );
  static String get pricingReturnTripDiscount => _t(
        'Retourritkorting',
        en: 'Return trip discount',
        es: 'Descuento de viaje de vuelta',
        ar: 'خصم رحلة العودة',
      );
  static String get pricingSwitchTariff => _t(
        'Tarief wisselen',
        en: 'Switch tariff',
        es: 'Cambiar tarifa',
        ar: 'تغيير التعرفة',
      );
  static String get pricingEditThisTariff => _t(
        'Dit tarief bewerken',
        en: 'Edit this tariff',
        es: 'Editar esta tarifa',
        ar: 'تعديل هذه التعرفة',
      );
  static const String pricingSaving = 'Opslaan...';
  static const String pricingSaveRates = 'Tarieven opslaan';
  static String get loginEnterValidEmail => _t(
        'Voer een geldig e-mailadres in.',
        en: 'Enter a valid email address.',
        es: 'Introduce un correo electrónico válido.',
        ar: 'أدخل بريدا إلكترونيا صالحا.',
      );
  static String get loginEnterSixDigitCode => _t(
        'Voer de 6-cijferige code in.',
        en: 'Enter the 6-digit code.',
        es: 'Introduce el código de 6 dígitos.',
        ar: 'أدخل الرمز المكون من 6 أرقام.',
      );
  static const String loginBrandLabel = 'HeyCaby Driver';
  static String get loginTrustTagline => _t(
        'Veilig inloggen voor professionele chauffeurs.',
        en: 'Secure sign-in for professional drivers.',
        es: 'Inicio de sesión seguro para conductores profesionales.',
        ar: 'تسجيل دخول آمن للسائقين المحترفين.',
      );
  static String get loginFormTitle => _t(
        'Welkom terug',
        en: 'Welcome back',
        es: 'Bienvenido de nuevo',
        ar: 'مرحبا بعودتك',
      );
  static String get registerDriverTitle => createAccount;
  static String get registerDriverSubtitle => _t(
        'Registreer je als chauffeur',
        en: 'Register as a driver',
        es: 'Regístrate como conductor',
        ar: 'سجل كسائق',
      );
  static String get loginFormTitleOtp => _t(
        'Code',
        en: 'Code',
        es: 'Código',
        ar: 'الرمز',
      );
  static String get loginEmailSubtitle => _t(
        'We sturen een veilige code naar je e-mail.',
        en: 'We’ll send a secure code to your email.',
        es: 'Te enviaremos un código seguro por correo.',
        ar: 'سنرسل رمزا آمنا إلى بريدك الإلكتروني.',
      );
  static String get loginOtpSubtitle => _t(
        '6 cijfers uit je e-mail.',
        en: '6 digits from your email.',
        es: '6 dígitos de tu correo.',
        ar: '6 أرقام من بريدك الإلكتروني.',
      );
  static String get loginEmailHint => _t(
        'E-mailadres',
        en: 'Email address',
        es: 'Correo electrónico',
        ar: 'البريد الإلكتروني',
      );
  static String get passwordMinSixHint => _t(
        'Wachtwoord (min. 6 tekens)',
        en: 'Password (min 6 characters)',
        es: 'Contraseña (mín. 6 caracteres)',
        ar: 'كلمة المرور (6 أحرف على الأقل)',
      );
  static String get loginCtaStart => _t(
        'Doorgaan',
        en: 'Continue',
        es: 'Continuar',
        ar: 'متابعة',
      );
  static String get loginCtaConfirm => _t(
        'Bevestigen',
        en: 'Confirm',
        es: 'Confirmar',
        ar: 'تأكيد',
      );
  static String get loginNewHere => _t(
        'Nieuw? Verificatie volgt na je eerste login.',
        en: 'New here? Verification follows after your first sign-in.',
        es: '¿Nuevo aquí? La verificación sigue tras tu primer inicio.',
        ar: 'جديد هنا؟ يتم التحقق بعد أول تسجيل دخول.',
      );
  static String get loginOtpCheckEmail => _t(
        'Controleer je e-mail voor de 6-cijferige code',
        en: 'Check your email for the 6-digit code',
        es: 'Revisa tu correo para el código de 6 dígitos',
        ar: 'تحقق من بريدك للرمز المكون من 6 أرقام',
      );
  static String get loginResendCode => _t(
        'Opnieuw',
        en: 'Resend',
        es: 'Reenviar',
        ar: 'إعادة الإرسال',
      );
  static String get loginChangeEmail => _t(
        'Ander e-mailadres',
        en: 'Change email',
        es: 'Cambiar correo',
        ar: 'تغيير البريد',
      );
  static String get loginPasteCode => _t(
        'Plakken',
        en: 'Paste',
        es: 'Pegar',
        ar: 'لصق',
      );
  static String get loginOtpExpired => _t(
        'Deze code is verlopen. Vraag een nieuwe 6-cijferige code aan.',
        en: 'This code expired. Request a new 6-digit code.',
        es: 'Este código caducó. Solicita uno nuevo de 6 dígitos.',
        ar: 'انتهت صلاحية هذا الرمز. اطلب رمزا جديدا من 6 أرقام.',
      );
  static String get loginFailed => _t(
        'Inloggen mislukt. Probeer opnieuw.',
        en: 'Sign-in failed. Try again.',
        es: 'No se pudo iniciar sesión. Inténtalo de nuevo.',
        ar: 'فشل تسجيل الدخول. حاول مرة أخرى.',
      );
  static String get loginInvalidEmailFirst => _t(
        'Vul eerst een geldig e-mailadres in.',
        en: 'Enter a valid email address first.',
        es: 'Primero introduce un correo válido.',
        ar: 'أدخل بريدا إلكترونيا صالحا أولا.',
      );
  static String get loginNewCodeSent => _t(
        'Nieuwe code verstuurd. Gebruik de nieuwste e-mailcode.',
        en: 'New code sent. Use the latest email code.',
        es: 'Nuevo código enviado. Usa el último correo.',
        ar: 'تم إرسال رمز جديد. استخدم أحدث رمز في البريد.',
      );
  static const String loginConfigError =
      'Supabase-sleutel ontbreekt of is ongeldig. Stop de app volledig en start opnieuw via ./scripts/run_driver_ios_debug.sh (of flutter run --dart-define-from-file=ios/.ipa_dart_defines.json).';
  static const String reactionFailedMigration =
      'Reactie mislukt. Controleer of de nieuwste database-migratie is toegepast.';
  static const String couldNotLoadEarnings = 'Verdiensten laden mislukt.';
  static const String couldNotLoadRides = 'Ritten laden mislukt.';
  static String get failedToUpdateStatus => _t(
        'Status bijwerken mislukt. Probeer opnieuw.',
        en: 'Status update failed. Try again.',
        es: 'No se pudo actualizar el estado. Inténtalo de nuevo.',
        ar: 'فشل تحديث الحالة. حاول مرة أخرى.',
      );
  static String serverErrorMessage(String message) => _t(
        'Server: $message',
        en: 'Server: $message',
        es: 'Servidor: $message',
        ar: 'الخادم: $message',
      );
  static String get driverProfileIncompleteForStatus => _t(
        'Server heeft de aanvraag geweigerd. Controleer of je chauffeursprofiel compleet is.',
        en: 'Server rejected the request. Check that your driver profile is complete.',
        es: 'El servidor rechazó la solicitud. Comprueba que tu perfil de conductor esté completo.',
        ar: 'رفض الخادم الطلب. تحقق من اكتمال ملفك الشخصي كسائق.',
      );
  static const String failedToGoOnline =
      'Online gaan mislukt. Probeer opnieuw.';
  static const String couldNotReportComment =
      'Opmerking melden mislukt. Probeer opnieuw.';
  static const String announcementsLoadFailed = 'Aankondigingen laden mislukt.';
  static const String newRiderDemandNearby =
      'Nieuwe vraag van reizigers in de buurt. Goede kans om nu te verdienen.';
  static const String chatWithLee = 'Chat met Lee';
  static const String preferencesSounds = 'Geluid';
  static String get english => _t(
        'Engels',
        en: 'English',
        es: 'Inglés',
        ar: 'الإنجليزية',
      );
  static String get dutch => _t(
        'Nederlands',
        en: 'Dutch',
        es: 'Neerlandés',
        ar: 'الهولندية',
      );
  static String get cash => _t(
        'Contant',
        en: 'Cash',
        es: 'Efectivo',
        ar: 'نقدا',
      );
  static String get card => _t(
        'Kaart',
        en: 'Card',
        es: 'Tarjeta',
        ar: 'بطاقة',
      );
  static const String other = 'Overig';
  static const String report = 'Melden';
  static const String dismiss = 'Sluiten';
  static const String invalidExpiryDateFormat =
      'Ontbrekende of ongeldige verloopdatum-indeling.';

  // Today's rides
  static const String geenRittenVandaag = 'Geen ritten vandaag';

  static String scheduledRidesCount(int count) =>
      count == 1 ? '1 $ride' : '$count $rides';

  static String endShiftBody(String hours, String minutes, int rideCount) =>
      'Je hebt $hours uur $minutes minuten gereden en $rideCount ritten voltooid vandaag.';
  static const String dienstBeeindigen = 'Dienst beëindigen';

  // Pre-ride confirmation (scheduled rides, optional €1–5 via Tikkie)
  static const String prerideReliabilityNew = 'Nieuw';
  static const String prerideReliabilityReliable = 'Betrouwbaar';
  static const String prerideReliabilityAmber = 'Weinig historie';
  static const String prerideReliabilityRisk = 'Let op: annuleringen';
  static const String prerideAskWithFee = 'Bevestiging vragen →';
  static const String prerideAskNoFee = 'Bevestig zonder bijdrage';
  static const String prerideReleaseRide = 'Rit vrijgeven';
  static const String prerideMarkTikkieReceived = 'Tikkie ontvangen';
  static const String prerideAwaitingRider = 'Wacht op reiziger';
  static const String prerideRiderConfirmed = 'Reiziger bevestigd';
  static const String prerideModalTitle = 'Bevestigingsverzoek';
  static const String prerideModalTikkieHint =
      'Je ontvangt een Tikkie-link om te delen met de reiziger in de chat.';
  static const String prerideTikkieUrlLabel = 'Tikkie-link (plakken)';
  static const String prerideTikkieLinkCopied = 'Tikkie-link gekopieerd';
  static const String prerideSendRequest = 'Stuur bevestigingsverzoek';
  static const String prerideFeeLabel = 'Bijdrage (max €5)';
  static const String prerideErrorGeneric =
      'Kon actie niet uitvoeren. Probeer opnieuw.';
  static const String prerideErrorOutsideWindow =
      'Alleen ongeveer 16–40 minuten voor de rit kun je dit versturen.';
  static const String prerideErrorDeadlineNotPassed =
      'Je kunt pas vrijgeven na de deadline van de reiziger.';
  static const String myAssignedScheduled = 'Mijn geplande ritten';
  static const String openScheduledRequests = 'Open aanvragen';

  // Finance hub & export (NL, accountant-friendly)
  static const String financeHubTitle = 'Financiën en belastingen';
  static const String financeExportSheetTitle = 'Rapport exporteren';
  static const String financeExportPdf = 'PDF downloaden';
  static const String financeExportPdfSubtitle = 'Opslaan op dit toestel';
  static const String financeExportEmail = 'Versturen via e-mail';
  static const String financeExportEmailSubtitle = 'Naar accountant';
  static const String financeExportWhatsapp = 'Delen via WhatsApp';
  static const String financeExportWhatsappSubtitle =
      'PDF — kies WhatsApp in het deelmenu';
  static const String financeWhatsappSharePdfCaption =
      'Financieel overzicht als PDF (HeyCaby chauffeur).';

  static const String financeRangeToday = 'Vandaag';
  static const String financeRangeThisWeek = 'Deze week';
  static const String financeRangeThisMonth = 'Deze maand';
  static const String financeRangeThisQuarter = 'Dit kwartaal';
  static const String financeRangeThisYear = 'Dit jaar';
  static const String financeRangeCustom = 'Aangepast';

  static const String financeReportTitle =
      'HeyCaby — chauffeur financieel overzicht';
  static const String financeReportPeriodHeading = 'Weergave';
  static const String financeReportDatesHeading = 'Datumbereik';
  static const String financeReportGenerated = 'Aangemaakt';
  static const String financeReportSectionSummary = 'Samenvatting';
  static const String financeReportGross = 'Bruto inkomsten';
  static const String financeReportNet = 'Netto inkomsten';
  static const String financeReportTotalRides = 'Ritten totaal';
  static const String financeReportKm = 'Kilometers';
  static const String financeReportPlatformFees = 'Platformkosten';
  static const String financeReportTips = 'Fooien';
  static const String financeReportCompleted = 'Voltooide ritten';
  static const String financeReportCancelled = 'Geannuleerde ritten';
  static const String financeReportCancellationFees = 'Annuleringsvergoedingen';
  static const String financeReportFooter =
      'Bron: HeyCaby Driver-app. Controleer de bedragen in je eigen administratie.';

  static const String financeEmailSubject =
      'HeyCaby financieel overzicht chauffeur';
  static const String financePdfShareCaption = 'Financieel overzicht (PDF)';

  static const String financeMetricsTotalEarnings = 'Totale inkomsten';
  static const String financeMetricsNetEarnings = 'Netto inkomsten';
  static const String financeMetricsTotalRides = 'Ritten totaal';
  static const String financeMetricsKm = 'Kilometers';
  static const String financeMetricsPlatformFees = 'Platformkosten';
  static const String financeMetricsTips = 'Fooien';

  static const String financeBreakdownTitle = 'Ritoverzicht';
  static const String financeBreakdownCompleted = 'Voltooide ritten';
  static const String financeBreakdownCancelled = 'Geannuleerde ritten';
  static const String financeBreakdownCancelFees = 'Annuleringsvergoedingen';
  static const String financeViewAllRides = 'Alle ritten bekijken';

  static const String financePaymentReconciliationTitle =
      'Betalingen en afstemming';
  static const String financeNoPaymentRecords = 'Nog geen betalingsregels.';
  static const String financePaymentRecordsError =
      'Betalingsregels laden mislukt.';

  static const String financeDataUnavailable =
      'Financiële gegevens tijdelijk niet beschikbaar. Getoond: nulwaarden.';

  static const String financeAccountantTitle = 'Accountant';
  static const String financeAccountantEmptyHint =
      'Bewaar het e-mailadres van je accountant voor snel delen.';
  static const String financeAccountantCurrentPrefix = 'Huidig e-mailadres:';
  static const String financeAccountantAdd = 'E-mailadres toevoegen';
  static const String financeAccountantEdit = 'E-mailadres wijzigen';

  static const String financeAccountantDialogTitle = 'E-mailadres accountant';
  static const String financeAccountantDialogHint = 'accountant@voorbeeld.nl';
  static const String financeAccountantDialogCancel = 'Annuleren';
  static const String financeAccountantDialogSave = 'Opslaan';

  static const String financePdfSaved = 'PDF opgeslagen:';
  static const String financePdfExportError = 'PDF exporteren mislukt:';
  static const String financeEmailNoApp = 'Geen e-mailapp op dit toestel.';
  static const String financeEmailOpenError = 'E-mailprogramma openen mislukt.';
  static const String financeShareError = 'Rapport delen mislukt.';
  static const String financeEmailBodyTooLongHint =
      'Dit rapport is te lang om automatisch in de mailapp te openen. Kies Mail (of een andere app) in het deelmenu en controleer het bericht voordat je verzendt.';
  static const String financeEmailMailtoFailedHint =
      'De mailapp opende niet automatisch. Kies Mail in het deelmenu en controleer het bericht.';
  static const String financeEmailRecipientCopied =
      'E-mailadres accountant staat op het klembord — plak bij Aan:.';
  static const String financeEmailNoRecipientHint =
      'Tip: sla het e-mailadres van je accountant op dit scherm op; dan wordt Aan: automatisch ingevuld.';

  // Community hub (NL default)
  static String get communityHubSubtitle => _t(
        'Verbind, deel en groei samen.',
        en: 'Connect, share, and grow together.',
        es: 'Conecta, comparte y crece junto a otros.',
        ar: 'تواصل وشارك وانم مع الآخرين.',
      );
  static String get communityAnnouncementsSubtitle => _t(
        'Nieuws, updates en peilingen',
        en: 'News, updates and polls',
        es: 'Noticias, novedades y encuestas',
        ar: 'أخبار وتحديثات واستطلاعات',
      );
  static String get communityDriverTalkSubtitle => _t(
        'Deel, vraag en help',
        en: 'Share, ask and help',
        es: 'Comparte, pregunta y ayuda',
        ar: 'شارك واسأل وساعد',
      );
  static String get communityNotificationsTitle => _t(
        'Meldingen',
        en: 'Notifications',
        es: 'Notificaciones',
        ar: 'الإشعارات',
      );
  static String get communityMarkAllRead => _t(
        'Alles gelezen',
        en: 'Mark all read',
        es: 'Marcar todo como leído',
        ar: 'تحديد الكل كمقروء',
      );
  static String get communityClearRead => _t(
        'Gelezen wissen',
        en: 'Clear read',
        es: 'Borrar leídas',
        ar: 'مسح المقروء',
      );
  static String get communityNotificationsEmpty => _t(
        'Nog geen meldingen.',
        en: 'No notifications yet.',
        es: 'Aún no hay notificaciones.',
        ar: 'لا توجد إشعارات بعد.',
      );
  static String get communitySearchHint => _t(
        'Zoek berichten, onderwerpen of chauffeurs...',
        en: 'Search posts, topics, or users...',
        es: 'Buscar publicaciones, temas o usuarios...',
        ar: 'ابحث في المنشورات أو المواضيع أو المستخدمين...',
      );
  static String get communityEmptyPosts => _t(
        'Nog geen berichten',
        en: 'No posts yet',
        es: 'Aún no hay publicaciones',
        ar: 'لا توجد منشورات بعد',
      );
  static String get communityCategoryEmptyPosts => _t(
        'Geen berichten in deze categorie.',
        en: 'No posts for this category.',
        es: 'No hay publicaciones en esta categoría.',
        ar: 'لا توجد منشورات في هذه الفئة.',
      );
  static const String communityNewPost = 'Nieuw bericht';
  static const String communityWelcomeDisclaimerTitle =
      'Welkom bij de gemeenschap';
  static const String communityWelcomeDisclaimerSubtitle =
      'Lees dit voordat je deelneemt';
  static const String communityDisclaimerChannelsTitle = 'Kanalen';
  static const String communityDisclaimerChannelsItem1 =
      'Aankondigingen: officiële HeyCaby-updates';
  static const String communityDisclaimerChannelsItem2 =
      'Chauffeurpraat: gesprekken tussen chauffeurs';
  static const String communityDisclaimerVisibilityTitle = 'Zichtbaarheid';
  static const String communityDisclaimerVisibilityItem1 =
      'Berichten zijn zichtbaar voor andere chauffeurs';
  static const String communityDisclaimerVisibilityItem2 =
      'Dit is geen privéchat met medewerkers';
  static const String communityDisclaimerVisibilityItem3 =
      'Gebruik Ondersteuning voor directe hulp';
  static const String communityDisclaimerDataTitle = 'Data en privacy';
  static const String communityDisclaimerDataItem1 =
      'Berichten worden verwerkt voor moderatie en veiligheid';
  static const String communityDisclaimerDataItem2 =
      'Inhoud kan worden gemodereerd of verwijderd';
  static const String communityDisclaimerDataItem3 =
      'Er geldt een rollend bewaartermijn';
  static const String communityDisclaimerConductTitle = 'Gedrag';
  static const String communityDisclaimerConductItem1 =
      'Geen intimidatie, haatzaaien of bedreigingen';
  static const String communityDisclaimerConductItem2 =
      'Geen fraude of onveilige adviezen';
  static const String communityDisclaimerConductItem3 =
      'Spam of misbruik kan tot beperkingen leiden';
  static const String communityDisclaimerAgreeCheckbox =
      'Ik ga akkoord met de Algemene voorwaarden en het privacybeleid';
  static const String communityContactSupport = 'Contact ondersteuning';
  static const String communityJoin = 'Deelnemen';
  static const String communityOpeningEmailClient = 'E-mailapp openen…';
  static const String communityEditPostTitle = 'Bericht bewerken';
  static const String communityEditPostHint = 'Pas je bericht aan';
  static const String communityDeletePostTitle = 'Bericht verwijderen?';
  static const String communityDeletePostBody =
      'Hiermee wordt je bericht uit de chauffeursgemeenschap gehaald.';
  static const String communityDeleteAction = 'Verwijderen';
  static const String communityClose = 'Sluiten';
  static const String communityViewAll = 'Bekijk alles';
  static const String communityFeedLoadFailed = 'Berichten laden mislukt.';
  static const String communityFeedEmptyAnnouncements =
      'Nog geen aankondigingen.';
  static const String communityFeedEmptyTalk =
      'Nog geen berichten in Chauffeurpraat.';
  static const String communityNotificationsLoadFailed =
      'Meldingen laden mislukt.';
  static String get communityNewPostTitle => _t(
        'Nieuw bericht',
        en: 'New post',
        es: 'Nueva publicación',
        ar: 'منشور جديد',
      );
  static String get communityPostComposerHint => _t(
        'Deel een tip, update of vraag...',
        en: 'Share a tip, update, or question...',
        es: 'Comparte un consejo, una novedad o una pregunta...',
        ar: 'شارك نصيحة أو تحديثا أو سؤالا...',
      );
  static String get communityPostButton => _t(
        'Plaatsen',
        en: 'Post',
        es: 'Publicar',
        ar: 'نشر',
      );

  /// Create-post sheet chips (also used as card heading for compact posts).
  static const String communityPostChipTraffic = 'Verkeer melden';
  static const String communityPostChipTip = 'Tip delen';
  static const String communityPostChipHelp = 'Hulp vragen';
  static const String communityPostChipGeneral = 'Algemeen';
  static const String communityCreateKindText = 'Bericht';
  static const String communityCreateKindPoll = 'Peiling';
  static const String communityPostMessageHint = 'Schrijf je bericht…';
  static const String communityPostMessageRequired = 'Schrijf een bericht.';
  static const String communityPollLabel = 'Peiling';
  static const String communityPollWeightedHint =
      'Founding-leden: jouw stem telt zwaarder (×3 gewicht). Punten zijn gewogen.';
  static const String communityPollQuestionHint = 'Je vraag of stelling…';
  static const String communityPollOptionHint = 'Antwoord…';
  static const String communityPollAddOption = 'Antwoord toevoegen';
  static const String communityPollNeedTwoOptions =
      'Voeg minimaal twee antwoorden toe.';
  static const String communityPollVoteFailed = 'Stem opslaan mislukt.';
  static String communityPollVoteCount(int n) =>
      n == 1 ? '1 stem' : '$n stemmen';
  static const String communityPostLegacyUntitled = 'Bericht';
  static const String communityPostLegacyNearby = 'Locatie onbekend';

  /// Heading line on feed cards from stored category key.
  static String communityPostTypeHeading(String key) {
    switch (key.toLowerCase()) {
      case 'traffic':
        return communityPostChipTraffic;
      case 'tip':
        return communityPostChipTip;
      case 'help':
        return communityPostChipHelp;
      case 'general':
        return communityPostChipGeneral;
      case 'poll':
        return communityPollLabel;
      default:
        return communityCategoryGeneral;
    }
  }

  static const String communityMenuEdit = 'Bewerken';
  static const String communityMenuDelete = 'Verwijderen';
  static const String communityPostNotSentSnack =
      'Bericht niet verzonden. Strikte limiet tegen spam.';
  static const String communitySearchNoLiveResults = 'Geen live resultaten.';
  static const String communitySearchNoCategoryResults =
      'Geen resultaten voor deze categorie.';
  static const String communityPostPreviewFallback = 'Gemeenschapsbericht';
  static const String communityCategoryAll = 'Alle';
  static const String communityCategoryTraffic = 'Verkeer';
  static const String communityCategoryTips = 'Tips';
  static const String communityCategorySafety = 'Veiligheid';
  static const String communityCategoryHelp = 'Hulp';
  static const String communityCategoryGeneral = 'Algemeen';
  static const String timeJustNow = 'Nu';
  static String timeMinutesAgo(int m) => '$m min geleden';
  static String timeHoursAgo(int h) => '$h u geleden';
  static String timeDaysAgo(int d) => '$d d geleden';

  static String communitySearchFoundSnack(String channel, String firstLine) {
    final ch = communityChannelLabel(channel);
    return 'Gevonden in $ch: $firstLine';
  }

  /// Short channel label for UI (search, subtitles).
  static String communityChannelLabel(String channel) {
    return switch (channel.toLowerCase()) {
      'announcements' => announcements,
      'general' => communityCategoryGeneral,
      'traffic' => communityCategoryTraffic,
      'tip' => communityCategoryTips,
      'safety' => communityCategorySafety,
      'help' => communityCategoryHelp,
      _ => channel,
    };
  }

  /// Hub quick link to return-trip list.
  static const String openReturnRides = 'Open terugritten';

  // Feature tour (first-run sheet, NL default)
  static const String featureTourSkip = 'Overslaan';
  static const String featureTourNext = 'Volgende';
  static const String featureTourStartNow = 'Nu starten';
  static const String featureTour1Kicker = 'Welkom';
  static const String featureTour1Heading = 'Jij bent eindelijk de baas';
  static const String featureTour1Body =
      'Werk wanneer jij wilt, pauzeer wanneer jij wilt, en bouw jouw eigen zaak op jouw manier.';
  static const String featureTour2Kicker = 'Tarieven';
  static const String featureTour2Heading = 'Stel je vier eigen prijzen in';
  static const String featureTour2Body =
      'Jij bepaalt alles: basistarief, prijs per kilometer, prijs per minuut en wachttijdprijs.';
  static const String featureTour3Kicker = 'Gemeenschap';
  static const String featureTour3Heading = 'Deel met collega-chauffeurs';
  static const String featureTour3Body =
      'Nodig andere chauffeurs uit. Hoe meer chauffeurs op het platform, hoe meer passagiers het vertrouwen en gebruiken.';
  static const String featureTour4Kicker = 'Platformbalans';
  static const String featureTour4Heading = 'Werk eerst, vereffen later';
  static const String featureTour4Body =
      'HeyCaby toont alleen een openstaand platformsaldo wanneer er echt iets te vereffenen is. '
      'Nieuwe ritverzoeken pauzeren pas als dat saldo na de betaaltermijn open blijft.';
  static const String featureTour5Kicker = 'Founding-leden';
  static const String featureTour5Heading = 'Foundingplaatsen zijn beperkt';
  static const String featureTour5Body =
      'Founding-lidmaatschap is beperkt. Activeer je account, vul je profiel aan en claim vroegtijdig je plek.';
  static const String featureTour6Kicker = 'Belangrijk';
  static const String featureTour6Heading =
      'Lees eerst de voorwaarden en privacy';
  static const String featureTour6Body =
      'Lees en begrijp alle algemene voorwaarden en privacyteksten voordat je het platform gebruikt. '
      'Verifieer daarna je documenten en ga online.';
}
