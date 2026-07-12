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
  static String get acceptanceRate => _t(
        'Acceptatiegraad',
        en: 'Acceptance rate',
        es: 'Tasa de aceptación',
        ar: 'معدل القبول',
      );
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
  static String get ratingSheetTitle => _t(
        'Jouw chauffeursreputatie',
        en: 'Your driver reputation',
        es: 'Tu reputación como conductor',
        ar: 'سمعتك كسائق',
      );
  static String get ratingDistributionTitle => _t(
        'Verdeling van beoordelingen',
        en: 'Ratings breakdown',
        es: 'Desglose de valoraciones',
        ar: 'تفصيل التقييمات',
      );
  static String ratingBasedOn(int count) => _t(
        'Gebaseerd op $count beoordelingen van passagiers.',
        en: 'Based on $count passenger ratings.',
        es: 'Basado en $count valoraciones de pasajeros.',
        ar: 'استنادًا إلى $count من تقييمات الركاب.',
      );
  static String get ratingLoadFailed => _t(
        'De verdeling kon niet worden geladen.',
        en: 'The rating breakdown could not be loaded.',
        es: 'No se pudo cargar el desglose de valoraciones.',
        ar: 'تعذر تحميل تفصيل التقييمات.',
      );
  static String get noPassengerComments => _t(
        'Nog geen geschreven feedback.',
        en: 'No written feedback yet.',
        es: 'Aún no hay comentarios escritos.',
        ar: 'لا توجد ملاحظات مكتوبة بعد.',
      );
  static String get passengerFeedback => _t(
        'Feedback van passagier',
        en: 'Passenger feedback',
        es: 'Comentarios del pasajero',
        ar: 'ملاحظات الراكب',
      );
  static String get moreActions => _t(
        'Meer acties',
        en: 'More actions',
        es: 'Más acciones',
        ar: 'المزيد من الإجراءات',
      );

  /// Migration 040 — shown on score screen when `drivers.avg_*` columns exist.
  static String get ratingBreakdownTitle => _t(
        'Jouw gemiddelden per gebied',
        en: 'Your averages per area',
        es: 'Tus promedios por zona',
        ar: 'متوسطاتك لكل منطقة',
      );
  static String get ratingPunctuality => _t(
        'Stiptheid',
        en: 'Punctuality',
        es: 'Puntualidad',
        ar: 'الالتزام بالمواعيد',
      );
  static String get ratingCleanliness => _t(
        'Netheid',
        en: 'Cleanliness',
        es: 'Limpieza',
        ar: 'النظافة',
      );
  static String get ratingAttitude => _t(
        'Houding',
        en: 'Attitude',
        es: 'Actitud',
        ar: 'السلوك',
      );
  static String get ratingDrivingSafety => _t(
        'Rijveiligheid',
        en: 'Driving safety',
        es: 'Seguridad al conducir',
        ar: 'سلامة القيادة',
      );
  static String get ratingCommunication => _t(
        'Communicatie',
        en: 'Communication',
        es: 'Comunicación',
        ar: 'التواصل',
      );
  static String get trustScoreLabel => _t(
        'Vertrouwensscore',
        en: 'Trust score',
        es: 'Puntuación de confianza',
        ar: 'درجة الثقة',
      );
  static String get trustScoreHint => _t(
        'Interne kwaliteitsscore (0–100). Passagiers zien je openbare sterren.',
        en: 'Internal quality score (0–100). Passengers see your public star rating.',
        es: 'Puntuación de calidad interna (0–100). Los pasajeros ven tus estrellas públicas.',
        ar: 'درجة الجودة الداخلية (0–100). يرى الركاب تقييمك العام بالنجوم.',
      );
  static String get reviewFlagTitle => _t(
        'Beoordeling aangevraagd',
        en: 'Review requested',
        es: 'Reseña solicitada',
        ar: 'تم طلب التقييم',
      );
  static String get reviewFlagBody => _t(
        'Ons team kan recente beoordelingen bekijken. Je hoeft niets te doen tenzij wij contact met je opnemen.',
        en: 'Our team can review recent ratings. You don\'t need to do anything unless we contact you.',
        es: 'Nuestro equipo puede revisar calificaciones recientes. No necesitas hacer nada a menos que te contactemos.',
        ar: 'فريقنا يمكنه مراجعة التقييمات الأخيرة. لا تحتاج لفعل شيء ما لم نتواصل معك.',
      );
  static String get newDriverShieldActive => _t(
        'Bescherming nieuwe chauffeur actief',
        en: 'New driver protection active',
        es: 'Protección de conductor nuevo activa',
        ar: 'حماية السائق الجديد نشطة',
      );
  static String get newDriverShieldBody => _t(
        'Eerste beoordelingen krijgen extra bescherming zodat één moeilijke rit je niet definieert.',
        en: 'Early ratings get extra protection so one difficult ride doesn\'t define you.',
        es: 'Las primeras calificaciones tienen protección extra para que un viaje difícil no te defina.',
        ar: 'تحصل التقييمات الأولى على حماية إضافية حتى لا يحددك رحلة واحدة صعبة.',
      );
  static String get ratingBadges => _t(
        'Prestaties',
        en: 'Achievements',
        es: 'Logros',
        ar: 'الإنجازات',
      );
  static String get ratingsInScore => _t(
        'beoordelingen in je score',
        en: 'ratings in your score',
        es: 'valoraciones en tu puntuación',
        ar: 'تقييمات في نقاطك',
      );
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
  static String get shiftWorkdayActive => _t(
        'Werkdag actief',
        en: 'Workday active',
        es: 'Jornada activa',
        ar: 'يوم العمل نشط',
      );
  static String get shiftBreakActive => _t(
        'Pauze actief',
        en: 'Break active',
        es: 'Descanso activo',
        ar: 'الاستراحة نشطة',
      );
  static String get shiftTodaySummary => today;
  static String get shiftStatDriving => _t(
        'Rijden',
        en: 'Driving',
        es: 'Conduciendo',
        ar: 'قيادة',
      );
  static String get shiftStatBreak => _t(
        'Pauze',
        en: 'Break',
        es: 'Descanso',
        ar: 'استراحة',
      );
  static String get shiftStatRides => _t(
        'Ritten',
        en: 'Rides',
        es: 'Viajes',
        ar: 'رحلات',
      );
  static String get shiftStatEarnings => _t(
        'Verdiensten',
        en: 'Earnings',
        es: 'Ganancias',
        ar: 'الأرباح',
      );
  static String get shiftHoursShort => _t(
        'uur',
        en: 'hours',
        es: 'horas',
        ar: 'ساعات',
      );
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
  static String get breakConfirmTitle => _t(
        'Even pauze?',
        en: 'Need a break?',
        es: '¿Necesitas un descanso?',
        ar: 'بحاجة إلى استراحة؟',
      );
  static String get breakConfirmBodyActiveRide => _t(
        'Na je huidige rit krijg je geen nieuwe aanvragen meer.',
        en: 'After your current ride you will stop receiving new requests.',
        es: 'Después de tu viaje actual dejarás de recibir nuevas solicitudes.',
        ar: 'بعد رحلتك الحالية ستتوقف عن تلقي طلبات جديدة.',
      );
  static String get breakConfirmBodyIdle => _t(
        'Je krijgt geen nieuwe aanvragen meer totdat je weer online gaat.',
        en: 'You will stop receiving new requests until you go back online.',
        es: 'Dejarás de recibir nuevas solicitudes hasta que vuelvas a estar disponible.',
        ar: 'ستتوقف عن تلقي طلبات جديدة حتى تعود متصلا.',
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
  static String get pauze => _t(
        'Pauze',
        en: 'Break',
        es: 'Descanso',
        ar: 'استراحة',
      );
  static String get hervat => _t(
        'Hervat',
        en: 'Resume',
        es: 'Reanudar',
        ar: 'استئناف',
      );
  static String get stop => _t(
        'Stop',
        en: 'Stop',
        es: 'Detener',
        ar: 'إيقاف',
      );
  static String get shiftArcHint => _t(
        '8 uur dienst',
        en: '8 hour shift',
        es: 'Jornada de 8 horas',
        ar: 'وردية 8 ساعات',
      );
  static String get endShift => _t(
        'Dienst beëindigen',
        en: 'End shift',
        es: 'Terminar turno',
        ar: 'إنهاء الوردية',
      );
  static String get endShiftConfirm => _t(
        'Dienst beëindigen?',
        en: 'End shift?',
        es: '¿Terminar turno?',
        ar: 'إنهاء الوردية؟',
      );
  static String get endShiftDetail => _t(
        'Je hebt vandaag X uur gereden en Y ritten voltooid.',
        en: 'You drove X hours and completed Y rides today.',
        es: 'Condujiste X horas y completaste Y viajes hoy.',
        ar: 'قدت لمدة X ساعات وأكملت Y رحلة اليوم.',
      );
  static String get cancel => _t(
        'Annuleren',
        en: 'Cancel',
        es: 'Cancelar',
        ar: 'إلغاء',
      );
  static String get readyToGoBackOnline => _t(
        'Klaar om weer online te gaan?',
        en: 'Ready to go back online?',
        es: '¿Listo para volver a estar en línea?',
        ar: 'هل أنت مستعد للعودة للاتصال؟',
      );
  static String get zoneView => _t(
        'Zone-weergave',
        en: 'Zone view',
        es: 'Vista de zonas',
        ar: 'عرض المناطق',
      );
  static String get demandZones => _t(
        'Vraagzones',
        en: 'Demand zones',
        es: 'Zonas de demanda',
        ar: 'مناطق الطلب',
      );
  static String get demandZonesDesc => _t(
        'Zie gouden cirkels met het aantal passagiers.',
        en: 'See golden circles with passenger counts.',
        es: 'Ver círculos dorados con el número de pasajeros.',
        ar: 'شاهد الدوائر الذهبية مع أعداد الركاب.',
      );
  static String get clearMap => _t(
        'Kaart wissen',
        en: 'Clear map',
        es: 'Limpiar mapa',
        ar: 'مسح الخريطة',
      );
  static String get clearMapDesc => _t(
        'Verberg zone-overlays voor een rustig beeld.',
        en: 'Hide zone overlays for a cleaner view.',
        es: 'Ocultar superposiciones de zona para una vista más limpia.',
        ar: 'إخفاء طبقات المناطق للحصول على عرض أنظف.',
      );
  static String get dutchBreakNotice => _t(
        'Je rijdt al X uur. Nederlandse regels vereisen een pauze van 30 minuten na 4,5 uur rijden.',
        en: 'You\'ve been driving for X hours. Dutch regulations require a 30-minute break after 4.5 hours of driving.',
        es: 'Conduces desde hace X horas. Las regulaciones neerlandesas requieren un descanso de 30 minutos después de 4.5 horas de conducción.',
        ar: 'لقد كنت تقود لمدة X ساعات. تنص اللوائح الهولندية على استراحة 30 دقيقة بعد 4.5 ساعات من القيادة.',
      );
  static String get breakRecommended => _t(
        'Pauze aanbevolen over X minuten',
        en: 'Break recommended in X minutes',
        es: 'Descanso recomendado en X minutos',
        ar: 'استراحة موصى بها خلال X دقيقة',
      );
  static String get breakRequired => _t(
        'Wettelijke pauze vereist',
        en: 'Legal break required',
        es: 'Descanso legal obligatorio',
        ar: 'استراحة قانونية مطلوبة',
      );
  static String get setUpRates => _t(
        'Stel je tarieven in →',
        en: 'Set your rates →',
        es: 'Configura tus tarifas →',
        ar: 'حدد أسعارك ←',
      );
  static String get home => _t(
        'Start',
        en: 'Home',
        es: 'Inicio',
        ar: 'الرئيسية',
      );
  static String get work => _t(
        'Werk',
        en: 'Work',
        es: 'Trabajo',
        ar: 'عمل',
      );
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
  static String get rideDetails => _t(
        'Ritdetails',
        en: 'Ride details',
        es: 'Detalles del viaje',
        ar: 'تفاصيل الرحلة',
      );
  static String get rideDetailsNotFound => _t(
        'Rit niet gevonden.',
        en: 'Ride not found.',
        es: 'Viaje no encontrado.',
        ar: 'الرحلة غير موجودة.',
      );
  static String get rideDetailFinished => _t(
        'Voltooid',
        en: 'Finished',
        es: 'Finalizado',
        ar: 'مكتملة',
      );
  static String get rideDetailBreakdown => _t(
        'Specificatie',
        en: 'Breakdown',
        es: 'Desglose',
        ar: 'التفاصيل',
      );
  static String get rideDetailTripFare => _t(
        'Ritprijs',
        en: 'Trip fare',
        es: 'Tarifa del viaje',
        ar: 'أجرة الرحلة',
      );
  static String get rideDetailGetHelp => _t(
        'Hulp bij deze rit',
        en: 'Get help with this trip',
        es: 'Ayuda con este viaje',
        ar: 'مساعدة بشأن هذه الرحلة',
      );
  static String get rideDetailContactWindowClosed => _t(
        'Contact met de reiziger is niet meer beschikbaar (meer dan 2 uur na de rit).',
        en: 'Rider contact is no longer available (more than 2 hours after the trip).',
        es: 'El contacto con el pasajero ya no está disponible (más de 2 horas después del viaje).',
        ar: 'لم يعد التواصل مع الراكب متاحًا (أكثر من ساعتين بعد الرحلة).',
      );
  static String rideDetailDistanceKm(String km) => _t(
        '$km km',
        en: '$km km',
        es: '$km km',
        ar: '$km كم',
      );
  static String rideDetailDurationMin(String minutes) => _t(
        '$minutes min',
        en: '$minutes min',
        es: '$minutes min',
        ar: '$minutes د',
      );
  static String get noRidesYet => _t(
        'Nog geen ritten.',
        en: 'No rides yet.',
        es: 'Aún no hay viajes.',
        ar: 'لا توجد رحلات بعد.',
      );
  static String get myRidesLoadFailed => _t(
        'Ritten laden mislukt.',
        en: 'Could not load rides.',
        es: 'No se pudieron cargar los viajes.',
        ar: 'تعذر تحميل الرحلات.',
      );
  static String get manualRideTag => _t(
        'Handmatige rit',
        en: 'Manual ride',
        es: 'Viaje manual',
        ar: 'رحلة يدوية',
      );
  static String get standardRideTag => _t(
        'Standaardrit',
        en: 'Standard ride',
        es: 'Viaje estándar',
        ar: 'رحلة قياسية',
      );
  static String get date => _t(
        'Datum',
        en: 'Date',
        es: 'Fecha',
        ar: 'التاريخ',
      );
  static String get status => _t(
        'Status',
        en: 'Status',
        es: 'Estado',
        ar: 'الحالة',
      );
  static String get type => _t(
        'Type',
        en: 'Type',
        es: 'Tipo',
        ar: 'النوع',
      );
  static String get pickup => _t(
        'Ophaalpunt',
        en: 'Pickup',
        es: 'Recogida',
        ar: 'نقطة الانطلاق',
      );
  static String get dropoff => _t(
        'Afzet',
        en: 'Drop-off',
        es: 'Destino',
        ar: 'نقطة الوصول',
      );
  static String get fare => _t(
        'Tarief',
        en: 'Fare',
        es: 'Tarifa',
        ar: 'الأجرة',
      );
  static String get paymentMethod => _t(
        'Betaalmethode',
        en: 'Payment method',
        es: 'Método de pago',
        ar: 'طريقة الدفع',
      );
  static String get driverEarnings => _t(
        'Jouw verdiensten',
        en: 'Your earnings',
        es: 'Tus ganancias',
        ar: 'أرباحك',
      );
  static String get platformFee => _t(
        'Platformfee',
        en: 'Platform fee',
        es: 'Cuota de plataforma',
        ar: 'رسوم المنصة',
      );
  static String get earnings => _t(
        'Verdiensten',
        en: 'Earnings',
        es: 'Ganancias',
        ar: 'الأرباح',
      );
  static String get availableRides => _t(
        'Beschikbare ritten',
        en: 'Available rides',
        es: 'Viajes disponibles',
        ar: 'الرحلات المتاحة',
      );
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
        'Gebruik je huidige foto als voorbeeld: fotografeer de taxi schuin van voren of achteren, zodat passagiers hem snel herkennen.',
        en: 'Use your current photo as a reference: photograph the taxi from a front or rear angle so riders can recognize it quickly.',
        es: 'Usa tu foto actual como referencia: fotografía el taxi en ángulo frontal o trasero para que sea fácil reconocerlo.',
        ar: 'استخدم صورتك الحالية كمرجع: صوّر سيارة الأجرة بزاوية أمامية أو خلفية ليسهل على الركاب التعرف عليها.',
      );
  static String get vehiclePhotoGoodExample => _t(
        'Goed voorbeeld',
        en: 'Good example',
        es: 'Buen ejemplo',
        ar: 'مثال جيد',
      );
  static String get vehiclePhotoTipWholeCar => _t(
        'Zorg dat de hele taxi in beeld staat.',
        en: 'Keep the whole taxi inside the frame.',
        es: 'Mantén todo el taxi dentro del encuadre.',
        ar: 'اجعل سيارة الأجرة كاملة داخل الإطار.',
      );
  static String get vehiclePhotoTipPlate => _t(
        'Laat het kenteken duidelijk en leesbaar zien.',
        en: 'Make the licence plate clear and readable.',
        es: 'Haz que la matrícula se vea clara y legible.',
        ar: 'اجعل لوحة المركبة واضحة وسهلة القراءة.',
      );
  static String get vehiclePhotoTipLighting => _t(
        'Gebruik daglicht, houd de lens stil en zorg dat niemand de auto bedekt.',
        en: 'Use daylight, hold steady, and keep people from blocking the car.',
        es: 'Usa luz natural, mantén el móvil firme y evita que alguien tape el coche.',
        ar: 'استخدم ضوء النهار وثبّت الهاتف ولا تدع أحدًا يحجب السيارة.',
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
  static String get foundingDriverWelcomeTitle => _t(
        'Founding Driver',
        en: 'Founding Driver',
        es: 'Conductor fundador',
        ar: 'سائق مؤسس',
      );
  static String get foundingDriverWelcomeBody => _t(
        'Welkom terug! Je chauffeur-account is gekoppeld aan je aanmelding op heycaby.nl.',
        en: 'Welcome back! Your driver account is linked to your registration on heycaby.nl.',
        es: '¡Bienvenido de nuevo! Tu cuenta de conductor está vinculada a tu registro en heycaby.nl.',
        ar: 'مرحبا بعودتك! حساب السائق الخاص بك مرتبط بتسجيلك في heycaby.nl.',
      );
  static String foundingDriverWelcomeNumber(int n) => _t(
      'Je Founding Driver-nummer is #$n. Je gegevens uit het formulier staan al in je profiel.',
      en: 'Your Founding Driver number is #$n. Your details from the form are already in your profile.',
      es: 'Tu número de Founding Driver es #$n. Tus datos del formulario ya están en tu perfil.',
      ar: 'رقمك كـ Founding Driver هو #$n. تفاصيلك من النموذج موجودة بالفعل في ملفك.');
  static String get foundingDriverWelcomeNext => _t(
        'Voeg nog een profielfoto en een foto van je voertuig toe om klaar te zijn.',
        en: 'Add a profile photo and a photo of your vehicle to be ready.',
        es: 'Añade una foto de perfil y una foto de tu vehículo para estar listo.',
        ar: 'أضف صورة ملف شخصي وصورة لمركبتك لتكون جاهزا.',
      );
  static String get foundingDriverProfilePhotoCta => _t(
        'Profielfoto',
        en: 'Profile photo',
        es: 'Foto de perfil',
        ar: 'صورة الملف',
      );
  static String get foundingDriverVehiclePhotoCta => _t(
        'Voertuigfoto',
        en: 'Vehicle photo',
        es: 'Foto del vehículo',
        ar: 'صورة المركبة',
      );
  static String get foundingDriverClose => _t(
        'Sluiten',
        en: 'Close',
        es: 'Cerrar',
        ar: 'إغلاق',
      );
  static String get foundingMember => _t(
        'Founding Member',
        en: 'Founding Member',
        es: 'Miembro fundador',
        ar: 'عضو مؤسس',
      );
  static String get member => _t(
        'Lid',
        en: 'Member',
        es: 'Miembro',
        ar: 'عضو',
      );
  static String foundingMemberNumber(int n) => _t('Founding Member #$n',
      en: 'Founding Member #$n',
      es: 'Miembro fundador #$n',
      ar: 'عضو مؤسس #$n');
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
  static String get goOnlineChecklistRefresh => _t(
        'Status vernieuwen',
        en: 'Refresh status',
        es: 'Actualizar estado',
        ar: 'تحديث الحالة',
      );
  static String get complianceSubtitle => _t(
        'De Nederlandse taxiwet (Wpv 2000) vereist deze onderdelen. HeyCaby controleert ze via ILT, RDW, KvK of handmatige beoordeling.',
        en: 'The Dutch taxi law (Wpv 2000) requires these components. HeyCaby verifies them via ILT, RDW, KvK or manual review.',
        es: 'La ley de taxis neerlandesa (Wpv 2000) requiere estos componentes. HeyCaby los verifica a través de ILT, RDW, KvK o revisión manual.',
        ar: 'يتطلب قانون سيارات الأجرة الهولندي (Wpv 2000) هذه المكونات. يتحقق منها HeyCaby عبر ILT أو RDW أو KvK أو مراجعة يدوية.',
      );
  static String get complianceSubtitleV2 => _t(
        'Rond alleen de vereisten af die nodig zijn om te starten. Aanvullende documenten blijven beschikbaar voor je professionele profiel.',
        en: 'Complete only what is needed to start. Additional documents stay available for your professional profile.',
        es: 'Completa solo lo necesario para empezar. Los documentos adicionales siguen disponibles para tu perfil profesional.',
        ar: 'أكمل فقط المطلوب للبدء. تبقى المستندات الإضافية متاحة لملفك المهني.',
      );
  static String get complianceFooterV2 => _t(
        'Aanvullende documenten kunnen later gevraagd worden naarmate je meer ritten rijdt. APK volgt uit je kenteken (RDW).',
        en: 'Additional documents may be requested later as you complete more rides. MOT follows from your plate number (RDW).',
        es: 'Documentos adicionales pueden solicitarse más adelante a medida que completes más viajes. La ITV se deriva de tu matrícula (RDW).',
        ar: 'قد يُطلب مستندات إضافية لاحقا كلما أكملت رحلات أكثر. يتبع الفحص التقني من لوحة أرقامك (RDW).',
      );
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
  static String get chauffeurspasHintV2 => _t(
        'Chauffeurspasnummer (8–12 cijfers)',
        en: 'Driver pass number (8–12 digits)',
        es: 'Número de pase de conductor (8–12 dígitos)',
        ar: 'رقم بطاقة السائق (8–12 رقما)',
      );
  static String get insurancePhotoOnFile => _t(
        'Verzekeringsdocument aanwezig',
        en: 'Insurance document on file',
        es: 'Documento de seguro en archivo',
        ar: 'وثيقة التأمين متوفرة',
      );
  static String get insurancePhotoTapToView => _t(
        'Verzekeringsdocument aanwezig · Tik om te bekijken',
        en: 'Insurance document on file · Tap to view',
        es: 'Documento de seguro en archivo · Toca para ver',
        ar: 'مستند التأمين موجود · انقر للعرض',
      );
  static String get insurancePreviewTitle => _t(
        'Voorbeeld verzekeringsdocument',
        en: 'Insurance document preview',
        es: 'Vista previa del seguro',
        ar: 'معاينة وثيقة التأمين',
      );
  static String get insurancePreviewFailed => _t(
        'Voorbeeld van verzekeringsdocument laden mislukt.',
        en: 'Failed to load insurance document preview.',
        es: 'Error al cargar la vista previa del documento de seguro.',
        ar: 'فشل تحميل معاينة مستند التأمين.',
      );
  static String get kvkManualVerifyHint => _t(
        'We controleren KvK-gegevens handmatig nadat je ze opslaat.',
        en: 'We manually verify KvK details after you save them.',
        es: 'Verificamos manualmente los datos KvK después de que los guardes.',
        ar: 'نتحقق يدويا من بيانات KvK بعد حفظها.',
      );
  static String get kvkManualVerifyDetailed => _t(
        'Vul je juiste KvK-nummer en geregistreerde bedrijfsadres in. Ons team controleert dit handmatig na indiening.',
        en: 'Enter your correct KvK number and registered business address. Our team manually verifies this after submission.',
        es: 'Introduce tu número KvK correcto y dirección comercial registrada. Nuestro equipo lo verifica manualmente tras el envío.',
        ar: 'أدخل رقم KvK الصحيح وعنوان عملك المسجل. يتحقق فريقنا يدويا بعد الإرسال.',
      );
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
  static String get complianceOverall => _t(
        'Profielstatus',
        en: 'Profile status',
        es: 'Estado del perfil',
        ar: 'حالة الملف',
      );
  static String get complianceProgressTitle => _t(
        'Professioneel profiel',
        en: 'Professional profile',
        es: 'Perfil profesional',
        ar: 'الملف المهني',
      );
  static String complianceProgressCount(int done, int total) =>
      _t('$done/$total afgerond',
          en: '$done/$total completed',
          es: '$done/$total completados',
          ar: 'اكتمل $done/$total');
  static String complianceProgressPercent(int percent) =>
      _t('$percent%', en: '$percent%', es: '$percent%', ar: '$percent%');
  static String get complianceManualLicensePending => _t(
        'Rijbewijs wacht op handmatige goedkeuring door beheer.',
        en: 'License pending manual approval by admin.',
        es: 'Licencia pendiente de aprobación manual por el administrador.',
        ar: 'الرخصة بانتظار الموافقة اليدوية من المسؤول.',
      );
  static String get docChauffeurspas => _t(
        'Chauffeurspas',
        en: 'Driver card',
        es: 'Tarjeta de conductor',
        ar: 'بطاقة السائق',
      );
  static String get docRijbewijs => _t(
        'Rijbewijs',
        en: 'Driving licence',
        es: 'Permiso de conducir',
        ar: 'رخصة القيادة',
      );
  static String get docVog => _t(
        'VOG (verklaring omtrent gedrag)',
        en: 'VOG (certificate of conduct)',
        es: 'VOG (certificado de conducta)',
        ar: 'شهادة حسن السيرة VOG',
      );
  static String get docTaxidiploma => _t(
        'Taxidiploma',
        en: 'Taxi diploma',
        es: 'Diploma de taxi',
        ar: 'دبلوم التاكسي',
      );
  static String get docTaxiInsurance => _t(
        'Taxiverzekering',
        en: 'Taxi insurance',
        es: 'Seguro de taxi',
        ar: 'تأمين التاكسي',
      );
  static String get docKvk => _t(
        'KvK-inschrijving',
        en: 'Chamber of Commerce registration',
        es: 'Registro en Cámara de Comercio',
        ar: 'تسجيل الغرفة التجارية',
      );
  static String get docApkVehicle => _t(
        'Voertuig & APK',
        en: 'Vehicle & MOT',
        es: 'Vehículo e ITV',
        ar: 'المركبة والفحص',
      );
  static String get statusPending => _t(
        'In beoordeling',
        en: 'Under review',
        es: 'En revisión',
        ar: 'قيد المراجعة',
      );
  static String get statusActionNeeded => _t(
        'Actie nodig',
        en: 'Action needed',
        es: 'Acción necesaria',
        ar: 'إجراء مطلوب',
      );
  static String get statusExpired => _t(
        'Verlopen',
        en: 'Expired',
        es: 'Caducado',
        ar: 'منتهي الصلاحية',
      );
  static String get statusImplied => _t(
        'Gedekt door chauffeurspas',
        en: 'Covered by driver card',
        es: 'Cubierto por tarjeta de conductor',
        ar: 'مغطى ببطاقة السائق',
      );
  static String get statusNotSet => _t(
        'Niet ingediend',
        en: 'Not submitted',
        es: 'No enviado',
        ar: 'غير مقدم',
      );
  static String get expiresOn => _t(
        'Verloopt',
        en: 'Expires',
        es: 'Caduca',
        ar: 'تنتهي',
      );
  static String get chauffeurspasHint => _t(
        '8-cijferig chauffeurspasnummer',
        en: '8-digit driver card number',
        es: 'Número de tarjeta de 8 dígitos',
        ar: 'رقم بطاقة السائق من 8 أرقام',
      );
  static String get verifyWithIlt => _t(
        'Verifiëren via ILT',
        en: 'Verify via ILT',
        es: 'Verificar vía ILT',
        ar: 'تحقق عبر ILT',
      );
  static String get verifying => _t(
        'Controleren bij ILT…',
        en: 'Checking with ILT…',
        es: 'Verificando con ILT…',
        ar: 'جاري التحقق عبر ILT…',
      );
  static String get chauffeurspasInvalidLength => _t(
        'Vul het 8-cijferige nummer op je chauffeurspas in.',
        en: 'Enter the 8-digit number on your driver pass.',
        es: 'Introduce el número de 8 dígitos de tu pase de conductor.',
        ar: 'أدخل الرقم المكون من 8 أرقام على بطاقة السائق.',
      );
  static String get chauffeurspasVerifiedOk => _t(
        'Chauffeurspas geverifieerd.',
        en: 'Driver card verified.',
        es: 'Tarjeta de conductor verificada.',
        ar: 'تم التحقق من بطاقة السائق.',
      );
  static String get chauffeurspasVerifyFailed => _t(
        'Verificatie mislukt. Probeer opnieuw of neem contact op met de ondersteuning.',
        en: 'Verification failed. Try again or contact support.',
        es: 'Verificación fallida. Inténtalo de nuevo o contacta con soporte.',
        ar: 'فشل التحقق. حاول مرة أخرى أو تواصل مع الدعم.',
      );
  static String get complianceUploadPortal => _t(
        'Rond verificatie hieronder met Veriff af, of uploads worden door de ondersteuning afgehandeld indien ingeschakeld.',
        en: 'Complete verification below with Veriff, or uploads will be handled by support if enabled.',
        es: 'Completa la verificación a continuación con Veriff, o las subidas serán gestionadas por soporte si está habilitado.',
        ar: 'أكمل التحقق أدناه مع Veriff، أو ستتم معالجة التحميلات بواسطة الدعم إذا تم تفعيله.',
      );
  static String get vehiclePlateRdw => _t(
        'Kenteken wordt gecontroleerd bij RDW (taxiregistratie & APK).',
        en: 'Plate number is verified with RDW (taxi registration & MOT).',
        es: 'La matrícula se verifica con RDW (registro de taxi e ITV).',
        ar: 'يتم التحقق من لوحة الأرقام عبر RDW (تسجيل سيارات الأجرة والفحص التقني).',
      );
  static String get complianceCompliant => _t(
        'Compliant',
        en: 'Compliant',
        es: 'Conforme',
        ar: 'متوافق',
      );
  static String get complianceIncomplete => _t(
        'Onvolledig',
        en: 'Incomplete',
        es: 'Incompleto',
        ar: 'غير مكتمل',
      );
  static String get compliancePending => _t(
        'In beoordeling',
        en: 'Under review',
        es: 'En revisión',
        ar: 'قيد المراجعة',
      );
  static String get complianceSuspended => _t(
        'Geschorst',
        en: 'Suspended',
        es: 'Suspendido',
        ar: 'معلق',
      );
  static String get complianceRejected => _t(
        'Afgewezen',
        en: 'Rejected',
        es: 'Rechazado',
        ar: 'مرفوض',
      );
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
  static String get instellingen => _t(
        'Instellingen',
        en: 'Settings',
        es: 'Ajustes',
        ar: 'الإعدادات',
      );
  static String get tarieven => _t(
        'Tarieven',
        en: 'Rates',
        es: 'Tarifas',
        ar: 'الأسعار',
      );
  static String get uitloggen => _t(
        'Uitloggen',
        en: 'Log out',
        es: 'Cerrar sesión',
        ar: 'تسجيل الخروج',
      );
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
  static String get deleteAccountConfirmTitle => _t(
        'Account permanent verwijderen?',
        en: 'Permanently delete account?',
        es: '¿Eliminar cuenta permanentemente?',
        ar: 'حذف الحساب نهائيا؟',
      );
  static String get deleteAccountConfirmBody => _t(
        'Je account wordt direct gedeactiveerd. Persoonsgegevens die we niet wettelijk hoeven te bewaren worden verwijderd. Bepaalde transactie-, veiligheids-, fraudepreventie- en boekhoudgegevens kunnen gedurende de vereiste periode worden bewaard.',
        en: 'Your account will be deactivated immediately. Personal information that we are not legally required to retain will be deleted. Certain transaction, safety, fraud-prevention and accounting records may be retained for the required period.',
        es: 'Tu cuenta se desactivará de inmediato. Se eliminará la información personal que no estemos legalmente obligados a conservar. Determinados registros de transacciones, seguridad, prevención del fraude y contabilidad podrán conservarse durante el período requerido.',
        ar: 'سيتم تعطيل حسابك فورًا. ستحذف المعلومات الشخصية التي لا يلزمنا القانون بالاحتفاظ بها. وقد يتم الاحتفاظ ببعض سجلات المعاملات والسلامة ومنع الاحتيال والمحاسبة للمدة المطلوبة.',
      );
  static String get deleteAccountTypeDeleteHint => _t(
        'Typ DELETE om te bevestigen',
        en: 'Type DELETE to confirm',
        es: 'Escribe DELETE para confirmar',
        ar: 'اكتب DELETE للتأكيد',
      );
  static String get deleteAccountTypeDeleteError => _t(
        'Typ het woord DELETE (hoofdletters maakt niet uit) en tik daarna opnieuw op Account verwijderen.',
        en: 'Type the word DELETE (case insensitive) then tap Delete account again.',
        es: 'Escribe la palabra DELETE (sin importar mayúsculas) luego toca Eliminar cuenta de nuevo.',
        ar: 'اكتب كلمة DELETE (بغض النظر عن حالة الأحرف) ثم انقر على حذف الحساب مرة أخرى.',
      );
  static String get deleteAccountFailed => _t(
        'Account verwijderen mislukt. Probeer opnieuw of neem contact op met de ondersteuning.',
        en: 'Account deletion failed. Try again or contact support.',
        es: 'Error al eliminar cuenta. Inténtalo de nuevo o contacta con soporte.',
        ar: 'فشل حذف الحساب. حاول مرة أخرى أو تواصل مع الدعم.',
      );
  static String get deleteAccountSuccessModalTitle => _t(
        'Verwijdering aangevraagd',
        en: 'Deletion requested',
        es: 'Eliminación solicitada',
        ar: 'تم طلب الحذف',
      );
  static String get deleteAccountSuccessModalBody => _t(
        'Je account is gedeactiveerd en je verwijderingsverzoek wordt verwerkt volgens de toepasselijke bewaartermijnen. Je kunt niet meer online gaan of ritten ontvangen.',
        en: 'Your account is deactivated and your deletion request will be processed according to the applicable retention periods. You can no longer go online or receive rides.',
        es: 'Tu cuenta está desactivada y tu solicitud de eliminación se procesará conforme a los períodos de conservación aplicables. Ya no puedes conectarte ni recibir viajes.',
        ar: 'تم تعطيل حسابك وستتم معالجة طلب الحذف وفق فترات الاحتفاظ المعمول بها. لم يعد بإمكانك الاتصال أو تلقي الرحلات.',
      );
  static String get deleteAccountSuccessModalCta => _t(
        'Verder',
        en: 'Continue',
        es: 'Continuar',
        ar: 'متابعة',
      );
  static String get chatWithRiderTitle => _t(
        'Chat met passagier',
        en: 'Chat with rider',
        es: 'Chatear con el pasajero',
        ar: 'الدردشة مع الراكب',
      );
  static String get chatTypeMessageHint => _t(
        'Typ een bericht…',
        en: 'Type a message…',
        es: 'Escribe un mensaje…',
        ar: 'اكتب رسالة…',
      );
  static String get blockRider => _t(
        'Passagier blokkeren',
        en: 'Block rider',
        es: 'Bloquear pasajero',
        ar: 'حظر الراكب',
      );
  static String get blockRiderConfirm => _t(
        'Je ziet geen nieuwe berichten meer van deze passagier in deze rit-chat.',
        en: 'You won\'t see new messages from this passenger in this ride chat anymore.',
        es: 'Ya no verás nuevos mensajes de este pasajero en este chat de viaje.',
        ar: 'لن ترى رسائل جديدة من هذا الراكب في دردشة هذه الرحلة بعد الآن.',
      );
  static String get reportRider => _t(
        'Passagier melden',
        en: 'Report rider',
        es: 'Reportar pasajero',
        ar: 'الإبلاغ عن الراكب',
      );
  static String get reportRiderTitle => _t(
        'Deze passagier melden?',
        en: 'Report this rider?',
        es: '¿Reportar a este pasajero?',
        ar: 'الإبلاغ عن هذا الراكب؟',
      );
  static String get reportRiderBody => _t(
        'HeyCaby beoordeelt deze rit-chat. Je kunt hieronder details toevoegen (optioneel).',
        en: 'HeyCaby reviews this ride chat. You can add details below (optional).',
        es: 'HeyCaby revisa este chat de viaje. Puedes añadir detalles a continuación (opcional).',
        ar: 'يراجع HeyCaby دردشة هذه الرحلة. يمكنك إضافة تفاصيل أدناه (اختياري).',
      );
  static String get reportReasonHint => _t(
        'Wat is er gebeurd? (optioneel)',
        en: 'What happened? (optional)',
        es: '¿Qué ocurrió? (opcional)',
        ar: 'ماذا حدث؟ (اختياري)',
      );
  static String get reportSubmitted => _t(
        'Bedankt — we hebben je melding ontvangen.',
        en: 'Thank you — we\'ve received your report.',
        es: 'Gracias — hemos recibido tu informe.',
        ar: 'شكرا — لقد تلقينا بلاغك.',
      );
  static String get chatBlockFailed => _t(
        'Blokkeerlijst bijwerken mislukt.',
        en: 'Failed to update blocklist.',
        es: 'Error al actualizar lista de bloqueo.',
        ar: 'فشل تحديث قائمة الحظر.',
      );
  static String get chatReportFailed => _t(
        'Melding versturen mislukt. Probeer opnieuw.',
        en: 'Failed to send report. Try again.',
        es: 'Error al enviar informe. Inténtalo de nuevo.',
        ar: 'فشل إرسال البلاغ. حاول مرة أخرى.',
      );
  static String get chatOnlyDuringActiveRideTitle => _t(
        'Chat beschikbaar tijdens actieve ritten',
        en: 'Chat available during active rides',
        es: 'Chat disponible durante viajes activos',
        ar: 'الدردشة متاحة أثناء الرحلات النشطة',
      );
  static String get chatOnlyDuringActiveRideBody => _t(
        'Je kunt de passagier alleen berichten zolang deze rit actief is.',
        en: 'You can only message the passenger while this ride is active.',
        es: 'Solo puedes enviar mensajes al pasajero mientras este viaje esté activo.',
        ar: 'يمكنك مراسلة الراكب فقط طالما هذه الرحلة نشطة.',
      );
  static String get notifyRiderOutside => _t(
        'Ping: ik sta buiten',
        en: 'Ping: I\'m outside',
        es: 'Ping: estoy fuera',
        ar: 'تنبيه: أنا بالخارج',
      );
  static String get notifyRiderNearby => _t(
        'Ping: onderweg',
        en: 'Ping: on my way',
        es: 'Ping: de camino',
        ar: 'تنبيه: في الطريق',
      );
  static String get notifyRiderSent => _t(
        'Ping verstuurd.',
        en: 'Ping sent.',
        es: 'Ping enviado.',
        ar: 'تم إرسال التنبيه.',
      );
  static String get notifyRiderFailed => _t(
        'Ping versturen mislukt. Probeer opnieuw.',
        en: 'Failed to send ping. Try again.',
        es: 'Error al enviar ping. Inténtalo de nuevo.',
        ar: 'فشل إرسال التنبيه. حاول مرة أخرى.',
      );
  static String get pingRiderSent => _t(
        'Ping verzonden',
        en: 'Ping sent',
        es: 'Ping enviado',
        ar: 'تم إرسال التنبيه',
      );
  static String get pingRiderFailed => _t(
        'Ping versturen mislukt',
        en: 'Failed to send ping',
        es: 'Error al enviar ping',
        ar: 'فشل إرسال التنبيه',
      );
  static String get pingRideNotActive => _t(
        'Deze rit is nog niet actief. Vernieuw de rit en probeer opnieuw.',
        en: 'This ride is not active yet. Refresh the ride and try again.',
        es: 'Este viaje aún no está activo. Actualiza el viaje e inténtalo de nuevo.',
        ar: 'هذه الرحلة غير نشطة بعد. حدث الرحلة وحاول مرة أخرى.',
      );
  static String get pingRideContextMissing => _t(
        'Ritcontext ontbreekt. Open de actieve rit en probeer opnieuw.',
        en: 'Ride context missing. Open the active ride and try again.',
        es: 'Falta contexto del viaje. Abre el viaje activo e inténtalo de nuevo.',
        ar: 'سياق الرحلة مفقود. افتح الرحلة النشطة وحاول مرة أخرى.',
      );
  static String get pingUnauthorized => _t(
        'Je sessie is verlopen. Log opnieuw in en probeer opnieuw.',
        en: 'Your session has expired. Log in again and try again.',
        es: 'Tu sesión ha expirado. Inicia sesión de nuevo e inténtalo de nuevo.',
        ar: 'انتهت جلستك. سجل الدخول مرة أخرى وحاول مرة أخرى.',
      );
  static String get pingServerRejected => _t(
        'Ping geweigerd. Controleer de ritstatus en probeer opnieuw.',
        en: 'Ping rejected. Check the ride status and try again.',
        es: 'Ping rechazado. Comprueba el estado del viaje e inténtalo de nuevo.',
        ar: 'تم رفض التنبيه. تحقق من حالة الرحلة وحاول مرة أخرى.',
      );
  static String pingCooldownMessage(int seconds) =>
      _t('Even wachten — ping opnieuw over ${seconds}s.',
          en: 'Please wait — ping again in ${seconds}s.',
          es: 'Espera — ping de nuevo en ${seconds}s.',
          ar: 'انتظر — تنبيه مرة أخرى خلال ${seconds}s.');
  static String pingCooldownButton(int seconds) => _t('Wacht ${seconds}s…',
      en: 'Wait ${seconds}s…',
      es: 'Espera ${seconds}s…',
      ar: 'انتظر ${seconds}s…');
  static String get communicationCenterTitle => _t(
        'Communicatie',
        en: 'Communication',
        es: 'Comunicación',
        ar: 'التواصل',
      );
  static String get communicationCenterSubtitle => _t(
        'Geen telefoonnummers — chat of stuur een snelle status.',
        en: 'No phone numbers — chat or send a quick status.',
        es: 'Sin números de teléfono — chatea o envía un estado rápido.',
        ar: 'لا أرقام هواتف — دردش أو أرسل حالة سريعة.',
      );
  static String get communicationChat => _t(
        'Chat met reiziger',
        en: 'Chat with rider',
        es: 'Chatear con el pasajero',
        ar: 'الدردشة مع الراكب',
      );
  static String get communicationQuickActions => _t(
        'Snelle acties',
        en: 'Quick actions',
        es: 'Acciones rápidas',
        ar: 'إجراءات سريعة',
      );
  static String get communicationOpen => _t(
        'Communicatie',
        en: 'Communication',
        es: 'Comunicación',
        ar: 'التواصل',
      );
  static String get pingOnMyWay => _t(
        'Onderweg',
        en: 'On my way',
        es: 'De camino',
        ar: 'في الطريق',
      );
  static String get pingOutside => _t(
        'Ik sta buiten',
        en: 'I\'m outside',
        es: 'Estoy fuera',
        ar: 'أنا بالخارج',
      );
  static String get pingArrived => _t(
        'Aangekomen',
        en: 'Arrived',
        es: 'He llegado',
        ar: 'وصلت',
      );
  static String get pingRunningLate => _t(
        'Ik heb vertraging',
        en: 'I\'m running late',
        es: 'Llego tarde',
        ar: 'سأتأخر',
      );
  static String get pingTrafficDelay => _t(
        'Vertraging door verkeer',
        en: 'Delayed by traffic',
        es: 'Retrasado por tráfico',
        ar: 'تأخر بسبب الزحام',
      );
  static String get pingCantFindRider => _t(
        'Kan je niet vinden',
        en: 'Can\'t find you',
        es: 'No te encuentro',
        ar: 'لا أستطيع العثور عليك',
      );
  static String get pingThanks => _t(
        'Bedankt!',
        en: 'Thanks!',
        es: '¡Gracias!',
        ar: 'شكرا!',
      );
  static String get communicationNearPickupHint => _t(
        'Je bent in de buurt van het ophaalpunt — snelle acties aangepast.',
        en: 'You\'re near the pickup point — quick actions adjusted.',
        es: 'Estás cerca del punto de recogida — acciones rápidas ajustadas.',
        ar: 'أنت قرب نقطة الالتقاط — تم تعديل الإجراءات السريعة.',
      );
  static String get communicationPingHistory => _t(
        'Ping geschiedenis',
        en: 'Ping history',
        es: 'Historial de pings',
        ar: 'سجل التنبيهات',
      );
  static String get pingHistoryEmpty => _t(
        'Nog geen pings voor deze rit.',
        en: 'No pings yet for this ride.',
        es: 'Aún no hay pings para este viaje.',
        ar: 'لا توجد تنبيهات لهذه الرحلة بعد.',
      );
  static String get pingDeliverySent => _t(
        'Verzonden',
        en: 'Sent',
        es: 'Enviado',
        ar: 'تم الإرسال',
      );
  static String get pingDeliveryDelivered => _t(
        'Bezorgd op telefoon',
        en: 'Delivered to phone',
        es: 'Entregado al teléfono',
        ar: 'تم التسليم للهاتف',
      );
  static String get pingDeliveryOpened => _t(
        'Geopend door reiziger',
        en: 'Opened by rider',
        es: 'Abierto por el pasajero',
        ar: 'فتحه الراكب',
      );
  static String get pingAutomaticBadge => _t(
        'Automatisch',
        en: 'Automatic',
        es: 'Automático',
        ar: 'تلقائي',
      );
  static String get smartPingOnMyWayTitle => _t(
        'Onderweg ping sturen?',
        en: 'Send on-my-way ping?',
        es: '¿Enviar ping de camino?',
        ar: 'إرسال تنبيه في الطريق؟',
      );
  static String get smartPingOnMyWayBody => _t(
        'Laat je passagier weten dat je onderweg bent — één tik.',
        en: 'Let your passenger know you\'re on your way — one tap.',
        es: 'Avisa al pasajero que vas en camino — un toque.',
        ar: 'أبلغ راكبك أنك في الطريق — بنقرة واحدة.',
      );
  static String get smartPingOutsideTitle => _t(
        'Je bent bij het ophaalpunt',
        en: 'You\'re at the pickup',
        es: 'Estás en la recogida',
        ar: 'أنت عند نقطة الالتقاط',
      );
  static String get smartPingOutsideBody => _t(
        'Passagier informeren dat je buiten staat?',
        en: 'Let passenger know you\'re waiting outside?',
        es: '¿Avisar al pasajero que estás esperando fuera?',
        ar: 'إبلاغ الراكب أنك تنتظر بالخارج؟',
      );
  static String get smartPingSend => _t(
        'Versturen',
        en: 'Send',
        es: 'Enviar',
        ar: 'إرسال',
      );
  static String get smartPingDismiss => _t(
        'Niet nu',
        en: 'Not now',
        es: 'Ahora no',
        ar: 'ليس الآن',
      );
  static String get sendOutsideMessage => _t(
        'Bericht sturen: ik sta buiten',
        en: 'Send message: I\'m outside',
        es: 'Enviar mensaje: estoy fuera',
        ar: 'إرسال رسالة: أنا بالخارج',
      );
  static String get outsideMessageSent => _t(
        'Bericht naar passagier verstuurd.',
        en: 'Message sent to rider.',
        es: 'Mensaje enviado al pasajero.',
        ar: 'تم إرسال الرسالة للراكب.',
      );
  static String get outsideMessageFailed => _t(
        'Bericht versturen mislukt.',
        en: 'Failed to send message.',
        es: 'Error al enviar mensaje.',
        ar: 'فشل إرسال الرسالة.',
      );
  static String get collectPaymentTitle => _t(
        'Tarief innen bij je passagier',
        en: 'Collect fare from passenger',
        es: 'Cobra la tarifa al pasajero',
        ar: 'احصل على الأجرة من الراكب',
      );
  static String get collectPaymentBody => _t(
        'Rond de rit pas af nadat je passagier het tarief hieronder heeft betaald.',
        en: 'Only complete the ride after your passenger has paid the fare below.',
        es: 'Solo completa el viaje cuando el pasajero haya pagado la tarifa indicada.',
        ar: 'أكمل الرحلة فقط بعد أن يدفع الراكب الأجرة أدناه.',
      );
  static String get collectPaymentAmountCaption => _t(
        'Te innen',
        en: 'Amount to collect',
        es: 'A cobrar',
        ar: 'المبلغ المطلوب',
      );
  static String collectPaymentAmount(String amountLabel) {
    final normalized = amountLabel.replaceFirst('EUR ', '€');
    return _t(
      'Te innen: $normalized',
      en: 'Amount to collect: $normalized',
      es: 'A cobrar: $normalized',
      ar: 'المبلغ المطلوب: $normalized',
    );
  }

  static String get collectPaymentContinue => _t(
        'Passagier heeft betaald',
        en: 'Passenger has paid',
        es: 'El pasajero ya pagó',
        ar: 'الراكب دفع',
      );
  static String get collectPaymentBack => _t(
        'Nog niet',
        en: 'Not yet',
        es: 'Aún no',
        ar: 'ليس بعد',
      );
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
  static String get accountingNoteLabel => _t(
        'Administratieve notitie (optioneel)',
        en: 'Administrative note (optional)',
        es: 'Nota administrativa (opcional)',
        ar: 'ملاحظة إدارية (اختياري)',
      );
  static String get sendReceipt => _t(
        'Bon versturen',
        en: 'Send receipt',
        es: 'Enviar recibo',
        ar: 'إرسال الإيصال',
      );
  static String get sendingReceipt => _t(
        'Versturen…',
        en: 'Sending…',
        es: 'Enviando…',
        ar: 'جاري الإرسال…',
      );
  static String get receiptSent => _t(
        'Bon verstuurd.',
        en: 'Receipt sent.',
        es: 'Recibo enviado.',
        ar: 'تم إرسال الإيصال.',
      );
  static String get receiptSendFailed => _t(
        'Bon versturen mislukt.',
        en: 'Failed to send receipt.',
        es: 'Error al enviar recibo.',
        ar: 'فشل إرسال الإيصال.',
      );
  static String get logoutConfirm => _t(
        'Weet u zeker dat u wilt uitloggen?',
        en: 'Are you sure you want to log out?',
        es: '¿Seguro que quieres cerrar sesión?',
        ar: 'هل أنت متأكد من تسجيل الخروج؟',
      );

  /// Destructive confirm in logout dialog.
  static String get logoutConfirmAction => _t(
        'Uitloggen',
        en: 'Log out',
        es: 'Cerrar sesión',
        ar: 'تسجيل الخروج',
      );
  static String get menu => _t(
        'Menu',
        en: 'Menu',
        es: 'Menú',
        ar: 'القائمة',
      );
  static String get ride => _t(
        'rit',
        en: 'ride',
        es: 'viaje',
        ar: 'رحلة',
      );
  static String get rides => _t(
        'ritten',
        en: 'rides',
        es: 'viajes',
        ar: 'رحلات',
      );
  static String get now => _t(
        'Nu',
        en: 'Now',
        es: 'Ahora',
        ar: 'الآن',
      );
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
  static String homeUpcomingCount(int count) => count == 1
      ? _t(
          '1 aankomende rit',
          en: '1 upcoming ride',
          es: '1 viaje próximo',
          ar: '1 رحلة قادمة',
        )
      : _t(
          '$count aankomende ritten',
          en: '$count upcoming rides',
          es: '$count viajes próximos',
          ar: '$count رحلات قادمة',
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
  static String get scheduled => _t(
        'Gepland',
        en: 'Scheduled',
        es: 'Programados',
        ar: 'مجدولة',
      );
  static String get requests => _t(
        'Aanvragen',
        en: 'Requests',
        es: 'Solicitudes',
        ar: 'الطلبات',
      );
  static String get confirmed => _t(
        'Bevestigd',
        en: 'Confirmed',
        es: 'Confirmados',
        ar: 'مؤكدة',
      );
  static String get marketplace => _t(
        'Marktplaats',
        en: 'Marketplace',
        es: 'Mercado',
        ar: 'السوق',
      );
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
  static String get rideSwapHowTitle => _t(
        'Hoe Ritwissel werkt',
        en: 'How Ride Swap works',
        es: 'Cómo funciona el intercambio de viajes',
        ar: 'كيف يعمل تبادل الرحلات',
      );
  static String get rideSwapHowParagraph1 => _t(
        'Ritwissel maakt het mogelijk om ritten soepel door te laten gaan wanneer plannen veranderen.',
        en: 'Ride Swap makes it possible to keep rides going smoothly when plans change.',
        es: 'Intercambio de Viajes permite que los viajes continúen sin problemas cuando cambian los planes.',
        ar: 'تبديل الرحلة يجعل من الممكن استمرار الرحلات بسلاسة عند تغير الخطط.',
      );
  static String get rideSwapHowParagraph2 => _t(
        'Wanneer een chauffeur een geboekte rit niet kan uitvoeren door tijdgebrek, vertraging of roosterwijzigingen, kan hij deze rit aanbieden zodat een andere beschikbare chauffeur deze eenvoudig kan overnemen.',
        en: 'When a driver can\'t complete a booked ride due to time constraints, delays or schedule changes, they can offer it so another available driver can easily take it over.',
        es: 'Cuando un conductor no puede completar un viaje reservado por falta de tiempo, retrasos o cambios de horario, puede ofrecerlo para que otro conductor disponible lo tome fácilmente.',
        ar: 'عندما لا يتمكن السائق من إكمال رحلة محجوزة بسبب قيود الوقت أو التأخير أو تغييرات الجدول، يمكنه عرضها ليأخذها سائق متاح آخر بسهولة.',
      );
  static String get rideSwapWhatYouCanDoHeading => _t(
        'Wat je hier kunt doen',
        en: 'What you can do here',
        es: 'Qué puedes hacer aquí',
        ar: 'ما يمكنك القيام به هنا',
      );
  static String get rideSwapBulletViewSwaps => _t(
        'Beschikbare wisselritten in jouw omgeving bekijken',
        en: 'View available swap rides in your area',
        es: 'Ver viajes de intercambio disponibles en tu área',
        ar: 'عرض رحلات التبديل المتاحة في منطقتك',
      );
  static String get rideSwapBulletCheckDetails => _t(
        'Details zoals ophaaltijd, route, urgentie en afstand controleren',
        en: 'Check details like pickup time, route, urgency and distance',
        es: 'Comprobar detalles como hora de recogida, ruta, urgencia y distancia',
        ar: 'تحقق من التفاصيل مثل وقت الالتقاط والمسار والإلحاح والمسافة',
      );
  static String get rideSwapBulletTakeRide => _t(
        'Een rit overnemen die je met zekerheid kunt uitvoeren',
        en: 'Take over a ride you can confidently complete',
        es: 'Tomar un viaje que puedas completar con seguridad',
        ar: 'خذ رحلة يمكنك إكمالها بثقة',
      );
  static String get rideSwapBulletSupportColleague => _t(
        'Een collega ondersteunen en zorgen dat de passagier geholpen blijft',
        en: 'Support a colleague and ensure the passenger stays served',
        es: 'Apoyar a un colega y asegurar que el pasajero siga siendo atendido',
        ar: 'ادعم زميلا وتأكد من استمرار خدمة الراكب',
      );
  static String get rideSwapPullToRefreshHint => _t(
        'Trek naar beneden om te vernieuwen.',
        en: 'Pull down to refresh.',
        es: 'Desliza hacia abajo para actualizar.',
        ar: 'اسحب للأسفل للتحديث.',
      );

  /// Empty-feed info sheet — line below the “how it works” copy.
  static String get rideSwapInfoModalFooter => _t(
        'Tip: trek de lijst omlaag om te vernieuwen als er straks wél ritten zijn.',
        en: 'Tip: pull the list down to refresh if there are rides later.',
        es: 'Consejo: desliza la lista hacia abajo para actualizar si hay viajes más tarde.',
        ar: 'نصيحة: اسحب القائمة للأسفل للتحديث إذا كانت هناك رحلات لاحقا.',
      );
  static String get rideSwapDontShowAgain => _t(
        'Niet meer tonen',
        en: 'Don\'t show again',
        es: 'No mostrar más',
        ar: 'عدم الإظهار مجددا',
      );
  static String get rideSwapGotIt => _t(
        'Begrepen',
        en: 'Got it',
        es: 'Entendido',
        ar: 'فهمت',
      );
  static String get rideSwapHowButton => _t(
        'Hoe werkt Ritwissel?',
        en: 'How does Ride Swap work?',
        es: '¿Cómo funciona Intercambio de Viajes?',
        ar: 'كيف يعمل تبديل الرحلة؟',
      );
  static String get swapFeedLoadFailed => _t(
        'Kon wisselritten niet laden',
        en: 'Could not load swap rides',
        es: 'No se pudieron cargar los intercambios',
        ar: 'تعذر تحميل رحلات التبادل',
      );
  static String get swapDetailPickupPrefix => _t(
        'Ophaal:',
        en: 'Pickup:',
        es: 'Recogida:',
        ar: 'الالتقاط:',
      );
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
  static String get swapAction => _t(
        'Wisselen',
        en: 'Swap',
        es: 'Intercambiar',
        ar: 'تبادل',
      );
  static String get swapFeedEmpty => _t(
        'Momenteel zijn er geen actieve wisselritten beschikbaar.',
        en: 'There are no active swap rides available right now.',
        es: 'Ahora mismo no hay viajes de cambio activos disponibles.',
        ar: 'لا توجد رحلات تبديل نشطة متاحة حاليا.',
      );
  static String get swapClaim => _t(
        'Rit overnemen',
        en: 'Take over ride',
        es: 'Tomar el viaje',
        ar: 'استلام الرحلة',
      );
  static String get swapViewDetails => _t(
        'Bekijk details',
        en: 'View details',
        es: 'Ver detalles',
        ar: 'عرض التفاصيل',
      );
  static String get swapExpiresIn => _t(
        'Verloopt over',
        en: 'Expires in',
        es: 'Caduca en',
        ar: 'تنتهي خلال',
      );
  static String get swapUrgencyEmergency => _t(
        'SPOED',
        en: 'EMERGENCY',
        es: 'URGENCIA',
        ar: 'طارئ',
      );
  static String get swapUrgencyUrgent => _t(
        'URGENT',
        en: 'URGENT',
        es: 'URGENTE',
        ar: 'عاجل',
      );
  static String get swapUrgencyModerate => _t(
        'MATIG',
        en: 'MODERATE',
        es: 'MODERADO',
        ar: 'متوسط',
      );
  static String get swapUrgencyStandard => _t(
        'STANDAARD',
        en: 'STANDARD',
        es: 'ESTÁNDAR',
        ar: 'قياسي',
      );
  static String get swapDistanceToPickup => _t(
        'Jij bent',
        en: 'You are',
        es: 'Estás a',
        ar: 'أنت على بعد',
      );
  static String get swapKmFromPickup => _t(
        'km van ophaallocatie',
        en: 'km from pickup',
        es: 'km de la recogida',
        ar: 'كم من نقطة الالتقاط',
      );
  static String get swapScheduleConflict => _t(
        'Roosterconflict: deze wisselrit overlapt met jouw planning.',
        en: 'Schedule conflict: this swap ride overlaps with your schedule.',
        es: 'Conflicto de horario: este viaje de intercambio se superpone con tu agenda.',
        ar: 'تعارض في الجدول: رحلة التبديل هذه تتداخل مع جدولك.',
      );
  static String get swapConfirmTitle => _t(
        'Rit bevestigen',
        en: 'Confirm ride',
        es: 'Confirmar viaje',
        ar: 'تأكيد الرحلة',
      );
  static String get swapConfirmBody => _t(
        'Door te bevestigen neem jij deze rit volledig over. De rit staat meteen in jouw agenda.',
        en: 'By confirming you fully take over this ride. The ride is immediately in your schedule.',
        es: 'Al confirmar asumes completamente este viaje. El viaje aparece inmediatamente en tu agenda.',
        ar: 'بالتأكيد تتولى هذه الرحلة بالكامل. تظهر الرحلة فورا في جدولك.',
      );
  static String get swapConfirmCta => _t(
        'Bevestigen',
        en: 'Confirm',
        es: 'Confirmar',
        ar: 'تأكيد',
      );
  static String get swapCancelOffer => _t(
        'Annuleer wissel',
        en: 'Cancel swap',
        es: 'Cancelar intercambio',
        ar: 'إلغاء التبادل',
      );
  static String get swapCancelledOk => _t(
        'Wissel ingetrokken. De rit blijft bij jou.',
        en: 'Swap withdrawn. The ride stays with you.',
        es: 'Intercambio retirado. El viaje sigue contigo.',
        ar: 'تم سحب التبديل. الرحلة تبقى معك.',
      );
  static String get swapCancelConfirmTitle => _t(
        'Wissel intrekken?',
        en: 'Withdraw swap?',
        es: '¿Retirar intercambio?',
        ar: 'سحب التبادل؟',
      );
  static String get swapCancelConfirmBody => _t(
        'De rit verdwijnt uit de wissellijst. Je houdt de rit zelf.',
        en: 'The ride disappears from the swap list. You keep the ride.',
        es: 'El viaje desaparece de la lista de intercambio. Te quedas con el viaje.',
        ar: 'تختفي الرحلة من قائمة التبديل. تحتفظ بالرحلة.',
      );
  static String get swapCancelConfirmCta => _t(
        'Intrekken',
        en: 'Withdraw',
        es: 'Retirar',
        ar: 'سحب',
      );
  static String get swapErrorNotCompliant => _t(
        'Je profiel moet compliant zijn om een wisselrit over te nemen.',
        en: 'Your profile must be compliant to take over a swap ride.',
        es: 'Tu perfil debe cumplir los requisitos para tomar un viaje de intercambio.',
        ar: 'يجب أن يكون ملفك الشخصي متوافقا لأخذ رحلة تبديل.',
      );
  static String get swapErrorExpired => _t(
        'Deze wissel is verlopen.',
        en: 'This swap has expired.',
        es: 'Este intercambio ha caducado.',
        ar: 'انتهت صلاحية هذا التبادل.',
      );
  static String get swapErrorNotAvailable => _t(
        'Deze wissel is niet meer beschikbaar.',
        en: 'This swap is no longer available.',
        es: 'Este intercambio ya no está disponible.',
        ar: 'هذا التبديل لم يعد متاحا.',
      );
  static String get swapErrorOwnSwap => _t(
        'Je kunt je eigen aanbod niet overnemen.',
        en: 'You can\'t take over your own offer.',
        es: 'No puedes tomar tu propia oferta.',
        ar: 'لا يمكنك تولي عرضك الخاص.',
      );
  static String get swapClaimSuccess => _t(
        'Rit overgenomen',
        en: 'Ride taken over',
        es: 'Viaje asumido',
        ar: 'تم استلام الرحلة',
      );
  static String get claimRide => _t(
        'Rit overnemen',
        en: 'Take over ride',
        es: 'Tomar el viaje',
        ar: 'استلام الرحلة',
      );
  static String get vehicle => _t(
        'Voertuig',
        en: 'Vehicle',
        es: 'Vehículo',
        ar: 'المركبة',
      );
  static String get pickupDistance => _t(
        'Afstand tot ophalen',
        en: 'Distance to pickup',
        es: 'Distancia a recogida',
        ar: 'المسافة إلى الالتقاط',
      );
  static String get acceptsCash => _t(
        'Contant geaccepteerd',
        en: 'Cash accepted',
        es: 'Efectivo aceptado',
        ar: 'يُقبل النقد',
      );
  static String get acceptsCard => _t(
        'Pinbetaling',
        en: 'Card payment',
        es: 'Pago con tarjeta',
        ar: 'دفع بالبطاقة',
      );
  static String get acceptsInvoice => _t(
        'Factuur (op rekening)',
        en: 'Invoice (on account)',
        es: 'Factura (a cuenta)',
        ar: 'فاتورة (على الحساب)',
      );
  static String get acceptsTikkie => _t(
        'Tikkie geaccepteerd',
        en: 'Tikkie accepted',
        es: 'Tikkie aceptado',
        ar: 'يُقبل Tikkie',
      );
  static String get petFriendly => _t(
        'Huisdiervriendelijk',
        en: 'Pet friendly',
        es: 'Admite mascotas',
        ar: 'صديق للحيوانات الأليفة',
      );
  static String get wheelchairAccessible => _t(
        'Rolstoeltoegankelijk',
        en: 'Wheelchair accessible',
        es: 'Accesible en silla de ruedas',
        ar: 'متاح للكراسي المتحركة',
      );
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
  static String get theme => _t(
        'Thema',
        en: 'Theme',
        es: 'Tema',
        ar: 'السمة',
      );
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
  static String get hotspots => _t(
        'Hotspots',
        en: 'Hotspots',
        es: 'Puntos calientes',
        ar: 'نقاط نشاط',
      );
  static String get hotspotsSubtitle => _t(
        'Open Chauffeursradar en navigeer naar drukke zones',
        en: 'Open Driver Radar and navigate to busy zones',
        es: 'Abre el Radar de Conductores y navega a zonas concurridas',
        ar: 'افتح رادار السائقين وانتقل إلى المناطق المزدحمة',
      );
  static String get hotspotsLiveMap => _t(
        'Live kaart',
        en: 'Live map',
        es: 'Mapa en vivo',
        ar: 'خريطة مباشرة',
      );
  static String get hotspotsListView => _t(
        'Lijstweergave',
        en: 'List view',
        es: 'Vista de lista',
        ar: 'عرض القائمة',
      );
  static String get hotspotsFilterHigh => _t(
        'Hoge vraag',
        en: 'High demand',
        es: 'Alta demanda',
        ar: 'طلب مرتفع',
      );
  static String get hotspotsFilterMedium => _t(
        'Gemiddeld',
        en: 'Medium',
        es: 'Media',
        ar: 'متوسط',
      );
  static String get hotspotsFilterLow => _t(
        'Laag',
        en: 'Low',
        es: 'Baja',
        ar: 'منخفض',
      );
  static String get hotspotsFilters => _t(
        'Filters',
        en: 'Filters',
        es: 'Filtros',
        ar: 'مرشحات',
      );
  static String get hotspotsFiltersReset => _t(
        'Alle gebieden tonen',
        en: 'Show all areas',
        es: 'Mostrar todas las zonas',
        ar: 'عرض جميع المناطق',
      );
  static String get hotspotsBestAreaTitle => _t(
        'Beste gebied nu',
        en: 'Best area now',
        es: 'Mejor zona ahora',
        ar: 'أفضل منطقة الآن',
      );
  static String get hotspotsLearnMore => _t(
        'Meer info',
        en: 'Learn more',
        es: 'Más información',
        ar: 'مزيد من المعلومات',
      );
  static String get hotspotsHighDemandBadge => _t(
        'Hoge vraag',
        en: 'High demand',
        es: 'Alta demanda',
        ar: 'طلب مرتفع',
      );
  static String get hotspotsSublineVeryBusy => _t(
        'Hoge vraag • Korte wachttijden',
        en: 'High demand • Short wait times',
        es: 'Alta demanda • Tiempos de espera cortos',
        ar: 'طلب مرتفع • أوقات انتظار قصيرة',
      );
  static String get hotspotsSublineHighDemand => _t(
        'Sterke vraag • Goede kans op ritten',
        en: 'Strong demand • Good chance of rides',
        es: 'Demanda fuerte • Buena posibilidad de viajes',
        ar: 'طلب قوي • فرصة جيدة للرحلات',
      );
  static String get hotspotsSublineSteady => _t(
        'Gemiddelde activiteit',
        en: 'Steady activity',
        es: 'Actividad estable',
        ar: 'نشاط مستقر',
      );
  static String get hotspotsSublineQuiet => _t(
        'Lage vraag • Rustiger tempo',
        en: 'Low demand • Quieter pace',
        es: 'Demanda baja • Ritmo más tranquilo',
        ar: 'طلب منخفض • وتيرة أهدأ',
      );
  static String hotspotsOnlineDrivers(int n) => _t('Chauffeurs online hier: $n',
      en: 'Drivers online here: $n',
      es: 'Conductores en línea aquí: $n',
      ar: 'سائقون متصلون هنا: $n');
  static String hotspotsRecentRides120m(int n) => _t('Ritaanvragen (2 u): $n',
      en: 'Ride requests (2 h): $n',
      es: 'Solicitudes (2 h): $n',
      ar: 'طلبات الرحلات (2 س): $n');
  static String hotspotsAvgOfferedFare(double v) =>
      _t('Gem. aangeboden tarief (2 u): €${v.toStringAsFixed(2)}',
          en: 'Avg. offered fare (2 h): €${v.toStringAsFixed(2)}',
          es: 'Tarifa media ofertada (2 h): €${v.toStringAsFixed(2)}',
          ar: 'متوسط الأجرة المعروضة (2 س): €${v.toStringAsFixed(2)}');
  static String get hotspotsAvgFareUnavailable => _t(
        'Gem. aangeboden tarief (2 u): —',
        en: 'Avg. offered fare (2 h): —',
        es: 'Tarifa media ofertada (2 h): —',
        ar: 'متوسط الأجرة المعروضة (2 س): —',
      );
  static String get hotspotsRidersWaitingCaption => _t(
        'Passagiers wachten (open aanvragen)',
        en: 'Passengers waiting (open requests)',
        es: 'Pasajeros esperando (solicitudes abiertas)',
        ar: 'ركاب ينتظرون (طلبات مفتوحة)',
      );
  static String get hotspotsActivityCaption => _t(
        'Ritaanvragen',
        en: 'Ride requests',
        es: 'Solicitudes de viaje',
        ar: 'طلبات الرحلات',
      );
  static String get hotspotsBestNow => _t(
        'Beste nu',
        en: 'Best now',
        es: 'Mejor ahora',
        ar: 'الأفضل الآن',
      );
  static String get hotspotsNoData => _t(
        'Nog geen hotspotdata. Trek om te vernieuwen als je online bent.',
        en: 'No hotspot data yet. Pull to refresh when you\'re online.',
        es: 'Aún sin datos de zonas activas. Desliza para actualizar cuando estés en línea.',
        ar: 'لا توجد بيانات مناطق نشطة بعد. اسحب للتحديث عندما تكون متصلا.',
      );
  static String get hotspotsNavigateHere => _t(
        'Navigeer hierheen',
        en: 'Navigate here',
        es: 'Navegar aquí',
        ar: 'انتقل إلى هنا',
      );
  static String hotspotsDemandLabel(String tier) => _t('Vraag: $tier',
      en: 'Demand: $tier', es: 'Demanda: $tier', ar: 'الطلب: $tier');
  static String get hotspotsDemandVeryHigh => _t(
        'Zeer hoog',
        en: 'Very high',
        es: 'Muy alta',
        ar: 'مرتفع جدا',
      );
  static String get hotspotsDemandHigh => _t(
        'Hoog',
        en: 'High',
        es: 'Alta',
        ar: 'مرتفع',
      );
  static String get hotspotsDemandMedium => _t(
        'Gemiddeld',
        en: 'Medium',
        es: 'Media',
        ar: 'متوسط',
      );
  static String get hotspotsDemandLow => _t(
        'Laag',
        en: 'Low',
        es: 'Baja',
        ar: 'منخفض',
      );
  static String get hotspotsDemandVeryLow => _t(
        'Zeer laag',
        en: 'Very low',
        es: 'Muy baja',
        ar: 'منخفض جدا',
      );
  static String get hotspotsSmartTargetPrefix => _t(
        'Slim doel: ',
        en: 'Smart target: ',
        es: 'Objetivo inteligente: ',
        ar: 'هدف ذكي: ',
      );
  static String get hotspotsTargetLogicPrefix => _t(
        'Doellogica: ',
        en: 'Target logic: ',
        es: 'Lógica de objetivo: ',
        ar: 'منطق الهدف: ',
      );
  static String get hotspotsLearnTitle => _t(
        'Hoe hotspots werken',
        en: 'How hotspots work',
        es: 'Cómo funcionan los puntos calientes',
        ar: 'كيف تعمل نقاط النشاط',
      );
  static String get hotspotsLearnBody => _t(
        'Zones tonen live open ritaanvragen (passagiers die wachten), recente aanvragen, gemiddelde aangeboden tarieven en hoeveel chauffeurs er online zijn — allemaal uit HeyCaby-data. Gebruik rode en oranje zones voor de drukste gebieden.',
        en: 'Zones show live open ride requests (passengers waiting), recent requests, average offered fares and how many drivers are online — all from HeyCaby data. Use red and orange zones for the busiest areas.',
        es: 'Las zonas muestran solicitudes de viaje abiertas en vivo (pasajeros esperando), solicitudes recientes, tarifas ofertadas promedio y cuántos conductores están en línea — todo desde datos HeyCaby. Usa zonas rojas y naranjas para las áreas más concurridas.',
        ar: 'تعرض المناطق طلبات الرحلات المفتوحة المباشرة (الركاب الذين ينتظرون) والطلبات الأخيرة ومتوسط الأجور المعروضة وعدد السائقين المتصلين — كل ذلك من بيانات HeyCaby. استخدم المناطق الحمراء والبرتقالية للأماكن الأكثر ازدحاما.',
      );
  static String get hotspotsLearnClose => _t(
        'Begrepen',
        en: 'Got it',
        es: 'Entendido',
        ar: 'فهمت',
      );
  static String get hotspotsGoogleMaps => _t(
        'Google Maps',
        en: 'Google Maps',
        es: 'Google Maps',
        ar: 'خرائط جوجل',
      );
  static String get hotspotsWaze => _t(
        'Waze',
        en: 'Waze',
        es: 'Waze',
        ar: 'Waze',
      );
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
  static String get preferencesSectionSoundTest => _t(
        'Geluid testen',
        en: 'Test sound',
        es: 'Probar sonido',
        ar: 'اختبار الصوت',
      );
  static String get preferencesSectionDebug => _t(
        'Debug (tijdelijk)',
        en: 'Debug (temporary)',
        es: 'Depuración (temporal)',
        ar: 'تصحيح (مؤقت)',
      );
  static String get preferencesSoundTestOnlineTitle => _t(
        'Online-signaal voorbeeld',
        en: 'Online signal sample',
        es: 'Muestra de señal en línea',
        ar: 'عينة إشارة الاتصال',
      );
  static String get preferencesSoundTestOnlineSubtitle => _t(
        'Speel het geluid voor online status.',
        en: 'Play the sound for online status.',
        es: 'Reproduce el sonido para estado en línea.',
        ar: 'تشغيل الصوت لحالة الاتصال.',
      );
  static String get preferencesSoundTestBreakTitle => _t(
        'Pauze-signaal voorbeeld',
        en: 'Break signal sample',
        es: 'Muestra de señal de pausa',
        ar: 'عينة إشارة الاستراحة',
      );
  static String get preferencesSoundTestBreakSubtitle => _t(
        'Speel het geluid voor pauze-status.',
        en: 'Play the sound for break status.',
        es: 'Reproduce el sonido para estado de pausa.',
        ar: 'تشغيل الصوت لحالة الاستراحة.',
      );
  static String get preferencesSoundTestOfflineTitle => _t(
        'Offline-signaal voorbeeld',
        en: 'Offline signal sample',
        es: 'Muestra de señal sin conexión',
        ar: 'عينة إشارة عدم الاتصال',
      );
  static String get preferencesSoundTestOfflineSubtitle => _t(
        'Speel het geluid voor offline status.',
        en: 'Play the sound for offline status.',
        es: 'Reproduce el sonido para estado sin conexión.',
        ar: 'تشغيل الصوت لحالة عدم الاتصال.',
      );
  static String get preferencesPlayPreviewTooltip => _t(
        'Speel voorbeeld van 10 seconden',
        en: 'Play 10s preview',
        es: 'Reproducir vista previa de 10 s',
        ar: 'تشغيل معاينة 10 ثوان',
      );
  static String get preferencesMolliePreviewTitle => _t(
        'Mollie-checkout voorbeeld',
        en: 'Mollie checkout sample',
        es: 'Muestra de checkout Mollie',
        ar: 'عينة الدفع عبر Mollie',
      );
  static String get preferencesMolliePreviewSubtitle => _t(
        'Open tijdelijk voorbeeldscherm voor checkout in de app.',
        en: 'Open temporary preview screen for in-app checkout.',
        es: 'Abre pantalla temporal de vista previa para checkout en la app.',
        ar: 'افتح شاشة معاينة مؤقتة للدفع داخل التطبيق.',
      );
  static String get saveAction => _t(
        'Opslaan',
        en: 'Save',
        es: 'Guardar',
        ar: 'حفظ',
      );
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
  static String get onboardingPlateFlowTitle => _t(
        'Start as a driver',
        en: 'Start as a driver',
        es: 'Empezar como conductor',
        ar: 'البدء كسائق',
      );
  static String get onboardingPlateTitle => _t(
        'Your taxi',
        en: 'Your taxi',
        es: 'Tu taxi',
        ar: 'تاكسيك',
      );
  static String get onboardingPlateSubtitle => _t(
        'Voer je kenteken in — we halen voertuiggegevens op bij RDW. Ga daarna door naar de voorwaarden.',
        en: 'Enter your plate number — we fetch vehicle details from RDW. Then you continue to the terms.',
        es: 'Introduce tu matrícula — obtenemos los datos del vehículo desde RDW. Luego continúas a los términos.',
        ar: 'أدخل لوحة الأرقام — نحصل على تفاصيل المركبة من RDW. ثم تتابع إلى الشروط.',
      );
  static String get onboardingPlateContinue => _t(
        'Continue to terms',
        en: 'Continue to terms',
        es: 'Continuar a términos',
        ar: 'متابعة إلى الشروط',
      );
  static String get onboardingPlateContinueGoOnline => _t(
        'Continue',
        en: 'Continue',
        es: 'Continuar',
        ar: 'متابعة',
      );
  static String get goOnlinePlateSubtitle => _t(
        'Voordat je online kunt, verifiëren we je taxikenteken bij RDW.',
        en: 'Before you can go online, we verify your taxi plate with RDW.',
        es: 'Antes de conectarte, verificamos tu matrícula de taxi con RDW.',
        ar: 'قبل أن تتصل، نتحقق من لوحة سيارة الأجرة الخاصة بك عبر RDW.',
      );
  static String get goOnlineOnboardingReadyHint => _t(
        'Kenteken en voorwaarden zijn klaar. Veeg opnieuw om online te gaan.',
        en: 'Plate and terms are ready. Swipe again to go online.',
        es: 'Matrícula y términos listos. Desliza de nuevo para conectarte.',
        ar: 'لوحة الأرقام والشروط جاهزة. اسحب مرة أخرى للاتصال.',
      );
  static String get goOnlineLegalStepTitle => _t(
        'Nog één stap',
        en: 'One more step',
        es: 'Un paso más',
        ar: 'خطوة واحدة أخرى',
      );
  static String get goOnlineLegalStepSubtitle => _t(
        'Lees en bevestig de voorwaarden en vrijwaringsverklaring. Daarna controleren we direct of je online kunt gaan.',
        en: 'Read and confirm the terms and indemnification statement. Then we immediately check whether you can go online.',
        es: 'Lee y confirma los términos y la declaración de indemnización. Después comprobaremos inmediatamente si puedes conectarte.',
        ar: 'اقرأ وأكد الشروط وبيان التعويض. بعد ذلك نتحقق فورًا مما إذا كان بإمكانك الاتصال.',
      );
  static String get goOnlinePlateVerified => _t(
        'Taxikenteken geverifieerd via RDW',
        en: 'Taxi plate verified with RDW',
        es: 'Matrícula de taxi verificada con RDW',
        ar: 'تم التحقق من لوحة سيارة الأجرة عبر RDW',
      );
  static String get onboardingPlateSaveFailed => _t(
        'Voertuig opslaan mislukt. Probeer opnieuw of neem contact op met de ondersteuning.',
        en: 'Vehicle save failed. Try again or contact support.',
        es: 'Error al guardar vehículo. Inténtalo de nuevo o contacta con soporte.',
        ar: 'فشل حفظ المركبة. حاول مرة أخرى أو تواصل مع الدعم.',
      );
  static String get startShiftFlowTitle => _t(
        'Start shift',
        en: 'Start shift',
        es: 'Iniciar turno',
        ar: 'بدء الوردية',
      );
  static String get startShiftVerifiedTitle => _t(
        'Taxi verified',
        en: 'Taxi verified',
        es: 'Taxi verificado',
        ar: 'تم التحقق من التاكسي',
      );
  static String get startShiftActiveTitle => _t(
        'This taxi is already active',
        en: 'This taxi is already active',
        es: 'Este taxi ya está activo',
        ar: 'هذا التاكسي نشط بالفعل',
      );
  static String get startShiftActiveBody => _t(
        'Deze taxi is momenteel in gebruik bij HeyCaby. Er kan maar één chauffeur tegelijk actief zijn op dezelfde taxi.',
        en: 'This taxi is currently being used in HeyCaby. Only one driver can be active with the same taxi at a time.',
        es: 'Este taxi está actualmente en uso en HeyCaby. Solo un conductor puede estar activo con el mismo taxi a la vez.',
        ar: 'سيارة الأجرة هذه قيد الاستخدام حاليا في HeyCaby. يمكن لسائق واحد فقط أن يكون نشطا بنفس سيارة الأجرة في كل مرة.',
      );
  static String get startShiftActiveFootnote => _t(
        'Start je dienst: we starten een Secure Shift Handover™. De huidige chauffeur krijgt tijd om te reageren. Daarna kun je verder.',
        en: 'Start your shift: we will start a Secure Shift Handover™. The current driver gets time to respond. After that you can continue.',
        es: 'Inicia tu turno: iniciaremos un Secure Shift Handover™. El conductor actual tiene tiempo para responder. Después puedes continuar.',
        ar: 'ابدأ مناوبتك: سنبدل Secure Shift Handover™. يحصل السائق الحالي على وقت للرد. بعد ذلك يمكنك المتابعة.',
      );
  static String get startShiftFinishSetupTitle => _t(
        'Rond je setup af',
        en: 'Finish your setup',
        es: 'Completa tu configuración',
        ar: 'أكمل إعدادك',
      );
  static String startShiftFinishSetupBody(int count) => _t(
        'Rond $count snelle ${count == 1 ? 'stap' : 'stappen'} af voordat je deze taxi overneemt.',
        en: 'Complete $count quick ${count == 1 ? 'step' : 'steps'} before taking over this taxi.',
        es: 'Completa $count ${count == 1 ? 'paso rápido' : 'pasos rápidos'} antes de tomar este taxi.',
        ar: 'أكمل $count من الخطوات السريعة قبل استلام سيارة الأجرة هذه.',
      );
  static String startShiftSetupProgress(int complete, int total) => _t(
        '$complete van $total klaar',
        en: '$complete of $total complete',
        es: '$complete de $total completados',
        ar: 'اكتمل $complete من $total',
      );
  static String get startShiftSetupInfo => _t(
        'Na je setup starten we Secure Shift Handover™. Er kan maar één chauffeur tegelijk actief zijn op deze taxi.',
        en: 'After setup, we will start Secure Shift Handover™. Only one driver can use this taxi at a time.',
        es: 'Después de la configuración, iniciaremos Secure Shift Handover™. Solo un conductor puede usar este taxi a la vez.',
        ar: 'بعد الإعداد، سنبدأ تسليم الوردية الآمن™. يمكن لسائق واحد فقط استخدام سيارة الأجرة في كل مرة.',
      );
  static String get startShiftAdditionalVerificationTitle => _t(
        'Aanvullende verificatie nodig',
        en: 'Additional verification required',
        es: 'Se requiere verificación adicional',
        ar: 'مطلوب تحقق إضافي',
      );
  static String get startShiftAdditionalVerificationBody => _t(
        'We hebben enkele gegevens nodig voordat je nieuwe ritten kunt ontvangen.',
        en: 'We need a few account details before you can receive new rides.',
        es: 'Necesitamos algunos datos de la cuenta antes de que puedas recibir nuevos viajes.',
        ar: 'نحتاج إلى بعض تفاصيل الحساب قبل أن تتمكن من تلقي رحلات جديدة.',
      );
  static String startShiftVerificationReason(String reason) => _t(
        'Reden: $reason',
        en: 'Reason: $reason',
        es: 'Motivo: $reason',
        ar: 'السبب: $reason',
      );
  static String get startShiftReviewInProgress => _t(
        'Je gegevens worden beoordeeld. Je krijgt bericht zodra de controle klaar is.',
        en: 'Your details are being reviewed. We will notify you when the review is complete.',
        es: 'Estamos revisando tus datos. Te avisaremos cuando termine la revisión.',
        ar: 'تتم مراجعة بياناتك. سنبلغك عند اكتمال المراجعة.',
      );
  static String get startShiftReviewPendingCta => _t(
        'Beoordeling loopt',
        en: 'Review in progress',
        es: 'Revisión en curso',
        ar: 'المراجعة جارية',
      );
  static String get startShiftStartSecureHandover => _t(
        'Start veilige dienstoverdracht',
        en: 'Start secure handover',
        es: 'Iniciar traspaso seguro',
        ar: 'ابدأ تسليم الوردية الآمن',
      );
  static String get startShiftUseAnotherTaxi => _t(
        'Gebruik een andere taxi',
        en: 'Use another taxi',
        es: 'Usar otro taxi',
        ar: 'استخدم سيارة أجرة أخرى',
      );
  static String get readinessTaxiPlate => _t(
        'Verifieer je taxikenteken',
        en: 'Verify your taxi plate',
        es: 'Verifica la matrícula del taxi',
        ar: 'تحقق من لوحة سيارة الأجرة',
      );
  static String get readinessDriverPhoto => _t(
        'Voeg je chauffeursfoto toe',
        en: 'Add your driver photo',
        es: 'Añade tu foto de conductor',
        ar: 'أضف صورة السائق',
      );
  static String get readinessVehiclePhoto => _t(
        'Voeg een foto van je taxi toe',
        en: 'Add a photo of your taxi',
        es: 'Añade una foto de tu taxi',
        ar: 'أضف صورة لسيارة الأجرة',
      );
  static String get readinessDriverTerms => _t(
        'Accepteer de chauffeursvoorwaarden',
        en: 'Accept the driver terms',
        es: 'Acepta los términos del conductor',
        ar: 'وافق على شروط السائق',
      );
  static String get readinessPlatformQuiz => _t(
        'Voltooi de platformquiz',
        en: 'Complete the platform quiz',
        es: 'Completa el cuestionario de la plataforma',
        ar: 'أكمل اختبار المنصة',
      );
  static String get readinessInitialTariff => _t(
        'Stel je eerste tarief in',
        en: 'Set your first tariff',
        es: 'Configura tu primera tarifa',
        ar: 'حدد تعريفتك الأولى',
      );

  static String get shiftHandoverBrandName => _t(
        'Secure Shift Handover™',
        en: 'Secure Shift Handover™',
        es: 'Secure Shift Handover™',
        ar: 'تسليم الوردية الآمن™',
      );
  static String get shiftHandoverWaitingTitle => _t(
        'Secure Shift Handover™',
        en: 'Secure Shift Handover™',
        es: 'Secure Shift Handover™',
        ar: 'تسليم الوردية الآمن™',
      );
  static String get shiftHandoverWaitingBody => _t(
        'De huidige chauffeur is op de hoogte. Je dienst start automatisch wanneer de wachttijd voorbij is, tenzij ze nog op een rit zijn.',
        en: 'The current driver has been notified. Your shift starts automatically when the waiting time is over, unless they are still on a ride.',
        es: 'El conductor actual ha sido notificado. Tu turno comienza automáticamente cuando termine el tiempo de espera, a menos que estén en un viaje.',
        ar: 'تم إبلاغ السائق الحالي. تبدأ مناوبتك تلقائيا عند انتهاء وقت الانتظار، ما لم يكونوا لا يزالون في رحلة.',
      );
  static String get shiftHandoverWaitingEta => _t(
        'Maximum wait',
        en: 'Maximum wait',
        es: 'Espera máxima',
        ar: 'الحد الأقصى للانتظار',
      );
  static String get shiftHandoverQueuedRideTitle => _t(
        'Your request is queued',
        en: 'Your request is queued',
        es: 'Tu solicitud está en cola',
        ar: 'طلبك في قائمة الانتظار',
      );
  static String get shiftHandoverQueuedRideBody => _t(
        'De taxi is op een rit. Je dienst start automatisch wanneer die rit is voltooid.',
        en: 'The taxi is on a ride. Your shift starts automatically when that ride is complete.',
        es: 'El taxi está en un viaje. Tu turno comienza automáticamente cuando ese viaje termine.',
        ar: 'سيارة الأجرة في رحلة. تبدأ مناوبتك تلقائيا عند اكتمال تلك الرحلة.',
      );
  static String get shiftHandoverQueuedRideSubtitle => _t(
        'Je hoeft niet opnieuw aan te vragen.',
        en: 'You do not need to request again.',
        es: 'No necesitas solicitar de nuevo.',
        ar: 'لا تحتاج إلى الطلب مرة أخرى.',
      );
  static String get shiftHandoverDeniedMessage => _t(
        'This taxi is still in use.',
        en: 'This taxi is still in use.',
        es: 'Este taxi sigue en uso.',
        ar: 'هذا التاكسي لا يزال قيد الاستخدام.',
      );
  static String get shiftHandoverActiveRideMessage => _t(
        'Deze taxi is op een rit. Je aanvraag staat in de wachtrij tot de rit is voltooid.',
        en: 'This taxi is on a ride. Your request is queued until the ride is complete.',
        es: 'Este taxi está en un viaje. Tu solicitud está en cola hasta que el viaje termine.',
        ar: 'سيارة الأجرة هذه في رحلة. طلبك في قائمة الانتظار حتى تكتمل الرحلة.',
      );
  static String get shiftHandoverPrivateBlockedMessage => _t(
        'Deze taxi is privé geregistreerd en kan niet door andere chauffeurs worden geactiveerd.',
        en: 'This taxi is privately registered and cannot be activated by other drivers.',
        es: 'Este taxi está registrado como privado y no puede ser activado por otros conductores.',
        ar: 'سيارة الأجرة هذه مسجلة كخصوصية ولا يمكن تفعيلها من قبل سائقين آخرين.',
      );
  static String get shiftHandoverRateLimitedMessage => _t(
        'Je kunt deze taxi nog niet opnieuw aanvragen. Wacht even of neem contact op met de ondersteuning.',
        en: 'You cannot request this taxi again yet. Wait a moment or contact support.',
        es: 'No puedes solicitar este taxi de nuevo aún. Espera un momento o contacta con soporte.',
        ar: 'لا يمكنك طلب سيارة الأجرة هذه مرة أخرى بعد. انتظر لحظة أو تواصل مع الدعم.',
      );
  static String get shiftHandoverNotEligibleMessage => _t(
        'Rond de ontbrekende vereisten af voordat je deze taxi overneemt.',
        en: 'Complete the missing requirements before taking over this taxi.',
        es: 'Completa los requisitos faltantes antes de tomar este taxi.',
        ar: 'أكمل المتطلبات الناقصة قبل تولي سيارة الأجرة هذه.',
      );
  static String get shiftHandoverCheckingRequirements => _t(
        'Vereisten controleren',
        en: 'Checking requirements',
        es: 'Comprobando requisitos',
        ar: 'جاري التحقق من المتطلبات',
      );
  static String get shiftHandoverCompleteRequirements => _t(
        'Vereisten afronden',
        en: 'Complete requirements',
        es: 'Completar requisitos',
        ar: 'إكمال المتطلبات',
      );
  static String get shiftHandoverRequirementsTitle => _t(
        'Voordat je deze taxi overneemt',
        en: 'Before taking over this taxi',
        es: 'Antes de tomar este taxi',
        ar: 'قبل تولي سيارة الأجرة هذه',
      );
  static String get shiftHandoverRequirementsBody => _t(
        'Rond de ontbrekende vertrouwens- en veiligheidsitems hieronder af. Kom daarna terug en start de dienst.',
        en: 'Complete the missing trust and safety items below. Then come back and start the shift.',
        es: 'Completa los elementos de confianza y seguridad faltantes a continuación. Luego vuelve e inicia el turno.',
        ar: 'أكمل عناصر الثقة والسلامة الناقصة أدناه. ثم عد وابدأ المناوبة.',
      );
  static String get shiftHandoverResolveFirstRequirement => _t(
        'Eerste vereiste oplossen',
        en: 'Fix first requirement',
        es: 'Resolver primer requisito',
        ar: 'إصلاح المتطلب الأول',
      );
  static String get shiftHandoverNotAllowlistedMessage => _t(
        'Je staat niet op de toegestane chauffeurslijst voor deze gedeelde taxi. Neem contact op met je fleetbeheerder.',
        en: 'You are not on the allowed driver list for this shared taxi. Contact your fleet manager.',
        es: 'No estás en la lista de conductores permitidos para este taxi compartido. Contacta a tu administrador de flota.',
        ar: 'أنت لست في قائمة السائقين المسموح لهم بهذه سيارة الأجرة المشتركة. تواصل مع مدير الأسطول.',
      );
  static String get shiftHandoverStepUpTitle => _t(
        'Confirm your identity',
        en: 'Confirm your identity',
        es: 'Confirma tu identidad',
        ar: 'تأكيد هويتك',
      );
  static String get shiftHandoverStepUpBody => _t(
        'Voor een veilige Secure Shift Handover™ bevestigen we wie je bent. Gebruik Face ID / Touch ID of een eenmalige e-mailcode.',
        en: 'For a safe Secure Shift Handover™, we confirm who you are. Use Face ID / Touch ID or a one-time email code.',
        es: 'Para un Secure Shift Handover™ seguro, confirmamos quién eres. Usa Face ID / Touch ID o un código de email de un solo uso.',
        ar: 'لإجراء Secure Shift Handover™ آمن، نؤكد هويتك. استخدم Face ID / Touch ID أو رمز بريد إلكتروني لمرة واحدة.',
      );
  static String get shiftHandoverBiometricReason => _t(
        'Bevestig je identiteit voor Secure Shift Handover™',
        en: 'Confirm your identity for Secure Shift Handover™',
        es: 'Confirma tu identidad para Secure Shift Handover™',
        ar: 'أكد هويتك لـ Secure Shift Handover™',
      );
  static String get shiftHandoverStepUpUseEmail => _t(
        'Email code',
        en: 'Email code',
        es: 'Código por correo',
        ar: 'رمز البريد الإلكتروني',
      );
  static String get shiftHandoverStepUpSendCode => _t(
        'Send code',
        en: 'Send code',
        es: 'Enviar código',
        ar: 'إرسال الرمز',
      );
  static String get shiftHandoverStepUpConfirm => _t(
        'Confirm and continue',
        en: 'Confirm and continue',
        es: 'Confirmar y continuar',
        ar: 'تأكيد ومتابعة',
      );
  static String get shiftHandoverStepUpRequired => _t(
        'Bevestig je identiteit voordat je een dienstwissel aanvraagt.',
        en: 'Confirm your identity before requesting a shift handover.',
        es: 'Confirma tu identidad antes de solicitar un cambio de turno.',
        ar: 'أكد هويتك قبل طلب تبديل المناوبة.',
      );
  static String get shiftHandoverStepUpNoEmail => _t(
        'Geen e-mailadres gevonden voor je account.',
        en: 'No email address found for your account.',
        es: 'No se encontró dirección de email para tu cuenta.',
        ar: 'لم يتم العثور على عنوان بريد إلكتروني لحسابك.',
      );
  static String get shiftHandoverStepUpFailed => _t(
        'Verificatie mislukt. Probeer opnieuw.',
        en: 'Verification failed. Try again.',
        es: 'Verificación fallida. Inténtalo de nuevo.',
        ar: 'فشل التحقق. حاول مرة أخرى.',
      );
  static String get shiftHandoverPromptTitle => _t(
        'Secure Shift Handover™',
        en: 'Secure Shift Handover™',
        es: 'Secure Shift Handover™',
        ar: 'تسليم الوردية الآمن™',
      );
  static String shiftHandoverPromptLead(String name, String plate) =>
      _t('$name wil Taxi $plate besturen.',
          en: '$name wants to drive Taxi $plate.',
          es: '$name quiere conducir Taxi $plate.',
          ar: '$name يريد قيادة سيارة الأجرة $plate.');
  static String get shiftHandoverPromptVerified => _t(
        'Geverifieerd',
        en: 'Verified',
        es: 'Verificado',
        ar: 'تم التحقق',
      );
  static String shiftHandoverPromptMemberSince(int year) =>
      _t('Chauffeur sinds $year',
          en: 'Driver since $year',
          es: 'Conductor desde $year',
          ar: 'سائق منذ $year');
  static String shiftHandoverPromptTimeoutHint(int minutes) => _t(
      'Geen actie? Je dienst eindigt automatisch over maximaal $minutes minuten.',
      en: 'No action? Your shift ends automatically in at most $minutes minutes.',
      es: '¿Sin acción? Tu turno termina automáticamente en máximo $minutes minutos.',
      ar: 'لا إجراء؟ تنتهي مناوبتك تلقائيا خلال $minutes دقيقة كحد أقصى.');
  static String get shiftHandoverPromptUnexpected => _t(
        'Verwacht je dit niet? Tik direct op Ik rij nog.',
        en: 'Didn\'t expect this? Tap I\'m still driving right away.',
        es: '¿No esperabas esto? Toca Sigo conduciendo ahora mismo.',
        ar: 'لم تتوقع هذا؟ انقر على ما زلت أقود فورا.',
      );
  static String get shiftHandoverEndShift => _t(
        'Dienst beëindigen',
        en: 'End shift',
        es: 'Terminar turno',
        ar: 'إنهاء الوردية',
      );
  static String get shiftHandoverStillDriving => _t(
        'Ik rij nog',
        en: 'I\'m still driving',
        es: 'Sigo conduciendo',
        ar: 'ما زلت أقود',
      );
  static String get shiftHandoverEndShiftBiometricReason => _t(
        'Bevestig dat je je dienst wilt beëindigen',
        en: 'Confirm you want to end your shift',
        es: 'Confirma que quieres terminar tu turno',
        ar: 'أكد أنك تريد إنهاء مناوبتك',
      );
  static String get shiftHandoverEndShiftConfirmTitle => _t(
        'Dienst beëindigen?',
        en: 'End shift?',
        es: '¿Terminar turno?',
        ar: 'إنهاء الوردية؟',
      );
  static String get shiftHandoverEndShiftConfirmBody => _t(
        'Een collega neemt deze taxi over. Je gaat offline en ontvangt geen ritten meer op dit kenteken.',
        en: 'A colleague is taking over this taxi. You go offline and receive no more rides for this plate.',
        es: 'Un colega toma este taxi. Te desconectas y no recibes más viajes para esta matrícula.',
        ar: 'يتولى زميل سيارة الأجرة هذه. تتوقف عن الاتصال ولا تتلقى المزيد من الرحلات لهذه اللوحة.',
      );
  static String get shiftHandoverFleetAlertTitle => _t(
        'Dienstwissel geweigerd',
        en: 'Shift handover denied',
        es: 'Cambio de turno denegado',
        ar: 'تم رفض تسليم الوردية',
      );
  static String get shiftHandoverFleetAlertBody => _t(
        'Een chauffeur probeerde deze taxi te starten. De huidige chauffeur rijdt nog. Was dit verwacht?',
        en: 'A driver tried to start this taxi. The current driver is still driving. Was this expected?',
        es: 'Un conductor intentó iniciar este taxi. El conductor actual sigue conduciendo. ¿Era esto esperado?',
        ar: 'حاول سائق تشغيل سيارة الأجرة هذه. السائق الحالي لا يزال يقود. هل كان هذا متوقعا؟',
      );
  static String get shiftHandoverPrivateAlertTitle => _t(
        'Poging tot taxi-activering',
        en: 'Taxi activation attempt',
        es: 'Intento de activación de taxi',
        ar: 'محاولة تفعيل سيارة الأجرة',
      );
  static String get shiftHandoverPrivateAlertBody => _t(
        'Iemand probeerde je privé-taxi te activeren. Was dit verwacht? Neem contact op met ondersteuning als je dit verdacht vindt.',
        en: 'Someone tried to activate your private taxi. Was this expected? Contact support if you find this suspicious.',
        es: 'Alguien intentó activar tu taxi privado. ¿Era esto esperado? Contacta con soporte si te parece sospechoso.',
        ar: 'حاول شخص ما تفعيل سيارة الأجرة الخاصة بك. هل كان هذا متوقعا؟ تواصل مع الدعم إذا وجدت هذا مشبوها.',
      );
  static String get shiftHandoverAuditNavTitle => _t(
        'Secure Shift Handover — audit',
        en: 'Secure Shift Handover — audit',
        es: 'Secure Shift Handover — auditoría',
        ar: 'Secure Shift Handover — تدقيق',
      );
  static String get fleetAllowlistTitle => _t(
        'Fleet — toegestane chauffeurs',
        en: 'Fleet — allowed drivers',
        es: 'Flota — conductores autorizados',
        ar: 'الأسطول — السائقون المصرح لهم',
      );
  static String get fleetAllowlistNavTitle => _t(
        'Fleet chauffeurslijst',
        en: 'Fleet driver list',
        es: 'Lista de conductores de flota',
        ar: 'قائمة سائقي الأسطول',
      );
  static String get fleetAllowlistEmpty => _t(
        'Je beheert nog geen gedeelde taxi\'s in HeyCaby.',
        en: 'You don\'t manage any shared taxis in HeyCaby yet.',
        es: 'Aún no gestionas taxis compartidos en HeyCaby.',
        ar: 'لا تدير أي سيارات أجرة مشتركة في HeyCaby بعد.',
      );
  static String get fleetAllowlistForbidden => _t(
        'Geen toegang om deze fleet-instellingen te beheren.',
        en: 'No access to manage these fleet settings.',
        es: 'Sin acceso para gestionar estos ajustes de flota.',
        ar: 'لا يوجد وصول لإدارة هذه إعدادات الأسطول.',
      );
  static String get fleetAllowlistOpenFleet => _t(
        'Geen restrictie — elke geverifieerde chauffeur mag een dienstwissel aanvragen.',
        en: 'No restriction — any verified driver can request a shift handover.',
        es: 'Sin restricción — cualquier conductor verificado puede solicitar cambio de turno.',
        ar: 'بدون قيود — أي سائق موثق يمكنه طلب تبديل المناوبة.',
      );
  static String fleetAllowlistDriverCount(int count) =>
      '$count chauffeur${count == 1 ? '' : 's'} op de lijst';
  static String get fleetAllowlistVehicleBody => _t(
        'Alleen chauffeurs op deze lijst kunnen Secure Shift Handover™ aanvragen voor deze taxi. Laat de lijst leeg om alle geverifieerde chauffeurs toe te staan.',
        en: 'Only drivers on this list can request Secure Shift Handover™ for this taxi. Leave the list empty to allow all verified drivers.',
        es: 'Solo los conductores en esta lista pueden solicitar Secure Shift Handover™ para este taxi. Deja la lista vacía para permitir todos los conductores verificados.',
        ar: 'فقط السائقون في هذه القائمة يمكنهم طلب Secure Shift Handover™ لسيارة الأجرة هذه. اترك القائمة فارغة للسماح لجميع السائقين الموثقين.',
      );
  static String get fleetAllowlistAddDriver => _t(
        'Chauffeur toevoegen',
        en: 'Add driver',
        es: 'Añadir conductor',
        ar: 'إضافة سائق',
      );
  static String get fleetAllowlistSearchLabel => _t(
        'Naam of e-mail',
        en: 'Name or email',
        es: 'Nombre o correo',
        ar: 'الاسم أو البريد الإلكتروني',
      );
  static String get fleetAllowlistSearchHint => _t(
        'Typ minimaal 3 tekens (naam of e-mail).',
        en: 'Type at least 3 characters (name or email).',
        es: 'Escribe al menos 3 caracteres (nombre o email).',
        ar: 'اكتب 3 أحرف على الأقل (الاسم أو البريد الإلكتروني).',
      );
  static String get fleetAllowlistSearchAction => _t(
        'Zoeken',
        en: 'Search',
        es: 'Buscar',
        ar: 'بحث',
      );
  static String get fleetAllowlistUpdateFailed => _t(
        'Kon de chauffeurslijst niet bijwerken. Probeer het opnieuw.',
        en: 'Failed to update the driver list. Try again.',
        es: 'Error al actualizar la lista de conductores. Inténtalo de nuevo.',
        ar: 'فشل تحديث قائمة السائقين. حاول مرة أخرى.',
      );
  static String get shiftHandoverWaitingSubtitle => _t(
        'Geschatte dienstwissel — meestal 10–30 seconden',
        en: 'Estimated shift handover — usually 10–30 seconds',
        es: 'Cambio de turno estimado — normalmente 10–30 segundos',
        ar: 'تبديل المناوبة المقدر — عادة 10–30 ثانية',
      );
  static String get shiftHandoverAuditTitle => _t(
        'Secure Shift Handover — audit',
        en: 'Secure Shift Handover — audit',
        es: 'Secure Shift Handover — auditoría',
        ar: 'تسليم الوردية الآمن — تدقيق',
      );
  static String get shiftHandoverAuditEmpty => _t(
        'Nog geen dienstwissel-aanvragen geregistreerd.',
        en: 'No shift handover requests registered yet.',
        es: 'Aún no hay solicitudes de cambio de turno registradas.',
        ar: 'لا توجد طلبات تبديل مناوبة مسجلة بعد.',
      );
  static String get shiftHandoverAuditForbidden => _t(
        'Geen toegang. Alleen HeyCaby staff kan dit auditlog bekijken.',
        en: 'No access. Only HeyCaby staff can view this audit log.',
        es: 'Sin acceso. Solo el personal de HeyCaby puede ver este registro de auditoría.',
        ar: 'لا يوجد وصول. فقط موظفو HeyCaby يمكنهم عرض سجل التدقيق هذا.',
      );
  static String get taxiSessionRevokedTitle => _t(
        'Taxi toegewezen aan andere chauffeur',
        en: 'Taxi assigned to another driver',
        es: 'Taxi asignado a otro conductor',
        ar: 'تم تعيين سيارة الأجرة لسائق آخر',
      );
  static String taxiSessionRevokedBody(String plate) => plate.trim().isEmpty
      ? 'Je taxi-sessie is beëindigd. Een andere geverifieerde chauffeur neemt het over.'
      : 'Je taxi $plate is toegewezen aan een andere geverifieerde chauffeur. '
          'Je bent offline gezet.';
  static String get taxiSessionRevokedVoluntaryTitle => _t(
        'Dienst beëindigd',
        en: 'Shift ended',
        es: 'Turno finalizado',
        ar: 'انتهت الوردية',
      );
  static String taxiSessionRevokedVoluntaryBody(String plate) => plate
          .trim()
          .isEmpty
      ? 'Je dienst is beëindigd. Een collega neemt de taxi over.'
      : 'Je dienst op taxi $plate is beëindigd. Een collega neemt de taxi over.';
  static String get taxiSessionRevokedCta => _t(
        'Naar home',
        en: 'Go home',
        es: 'Ir al inicio',
        ar: 'الذهاب للرئيسية',
      );
  static String get startShiftPrimary => _t(
        'Start mijn dienst',
        en: 'Start my shift',
        es: 'Iniciar mi turno',
        ar: 'ابدأ ورديتي',
      );

  @Deprecated('Use startShift* strings')
  static String get onboardingSharedFleetTitle => _t(
        'Gedeelde taxi',
        en: 'Shared taxi',
        es: 'Taxi compartido',
        ar: 'سيارة أجرة مشتركة',
      );
  @Deprecated('Use startShift* strings')
  static String get onboardingSharedFleetBody => _t(
        'Deze taxi wordt gedeeld met andere chauffeurs via Secure Shift Handover™.',
        en: 'This taxi is shared with other drivers via Secure Shift Handover™.',
        es: 'Este taxi se comparte con otros conductores vía Secure Shift Handover™.',
        ar: 'سيارة الأجرة هذه مشتركة مع سائقين آخرين عبر Secure Shift Handover™.',
      );
  @Deprecated('Use startShift* strings')
  static String get onboardingSharedFleetConfirm => startShiftPrimary;
  static String progressiveVerificationProgress(int rides, int milestone) =>
      _t('Progressieve verificatie: $rides/$milestone ritten',
          en: 'Progressive verification: $rides/$milestone rides',
          es: 'Verificación progresiva: $rides/$milestone viajes',
          ar: 'تحقق تدريجي: $rides/$milestone رحلة');
  static String get progressiveVerificationMilestone10Hint => _t(
        'Na 10 voltooide ritten vragen we extra verificatie zodat je online kunt blijven.',
        en: 'After 10 completed rides we ask for extra verification so you can stay online.',
        es: 'Tras 10 viajes completados pedimos verificación extra para que puedas seguir en línea.',
        ar: 'بعد 10 رحلات مكتملة نطلب تحقق إضافي لكي تبقى متصلا.',
      );
  static String get progressiveVerificationMilestone20Hint => _t(
        'Na 20 ritten: aanvullende documenten kunnen vereist zijn.',
        en: 'After 20 rides: additional documents may be required.',
        es: 'Tras 20 viajes: pueden requerirse documentos adicionales.',
        ar: 'بعد 20 رحلة: قد يُطلب مستندات إضافية.',
      );
  static String get progressiveVerificationMilestone50Hint => _t(
        'Na 50 ritten: volledige taxidocumentatie moet up-to-date blijven.',
        en: 'After 50 rides: full taxi documentation must stay up-to-date.',
        es: 'Tras 50 viajes: la documentación completa del taxi debe mantenerse actualizada.',
        ar: 'بعد 50 رحلة: يجب أن تبقى مستندات سيارة الأجرة الكاملة محدثة.',
      );
  static String get progressiveVerificationCompleteDocs => _t(
        'Documenten afronden',
        en: 'Complete documents',
        es: 'Completar documentos',
        ar: 'إكمال المستندات',
      );
  static String get runtimeGoOnlineEarlyOnboardingBody => _t(
        'Rond je verplichte profielstappen af voordat je online gaat.',
        en: 'Complete your required profile steps before going online.',
        es: 'Completa los pasos obligatorios de tu perfil antes de conectarte.',
        ar: 'أكمل خطوات ملفك المطلوبة قبل الاتصال.',
      );
  static String get lookupPlate => _t(
        'Look up plate',
        en: 'Look up plate',
        es: 'Buscar matrícula',
        ar: 'البحث عن اللوحة',
      );
  static String get plateNotFoundRdw => _t(
        'Kenteken niet gevonden bij RDW. Controleer op typefouten en probeer opnieuw.',
        en: 'Plate not found in RDW. Check for typos and try again.',
        es: 'Matrícula no encontrada en RDW. Comprueba errores e inténtalo de nuevo.',
        ar: 'لم يتم العثور على لوحة الأرقام في RDW. تحقق من الأخطاء المطبعية وحاول مرة أخرى.',
      );
  static String get vehicleNotTaxiRdw => _t(
        'Dit voertuig bestaat bij RDW maar is niet geregistreerd als taxi. Neem contact op met RDW of ondersteuning.',
        en: 'This vehicle exists in RDW but is not registered as a taxi. Contact RDW or support.',
        es: 'Este vehículo existe en RDW pero no está registrado como taxi. Contacta con RDW o soporte.',
        ar: 'هذه المركبة موجودة في RDW لكنها غير مسجلة كسيارة أجرة. تواصل مع RDW أو الدعم.',
      );
  static String get vehicleVerifiedTaxi => _t(
        'Vehicle verified as taxi',
        en: 'Vehicle verified as taxi',
        es: 'Vehículo verificado como taxi',
        ar: 'تم التحقق من المركبة كتاكسي',
      );

  /// Shown when `drivers_vehicle_plate_unique` fires — plate exists on another driver row.
  static String get vehiclePlateDuplicate => _t(
        'Dit kenteken is al geregistreerd. Als dit jouw taxi is, heeft mogelijk een ander account deze — neem contact op met de ondersteuning.',
        en: 'This plate is already registered. If this is your taxi, another account may have it — contact support.',
        es: 'Esta matrícula ya está registrada. Si es tu taxi, otra cuenta puede tenerla — contacta con soporte.',
        ar: 'لوحة الأرقام هذه مسجلة بالفعل. إذا كانت سيارة الأجرة هذه ملكك، فقد يكون حساب آخر يمتلكها — تواصل مع الدعم.',
      );
  static String get saveAndContinue => _t(
        'Save and continue',
        en: 'Save and continue',
        es: 'Guardar y continuar',
        ar: 'حفظ ومتابعة',
      );
  static String get vehiclePlateLockedSubtitle => _t(
        'Dit kenteken is opgeslagen. Neem contact op met de ondersteuning als je je voertuig wilt wijzigen.',
        en: 'This plate is saved. Contact support if you want to change your vehicle.',
        es: 'Esta matrícula está guardada. Contacta con soporte si quieres cambiar tu vehículo.',
        ar: 'لوحة الأرقام هذه محفوظة. تواصل مع الدعم إذا كنت تريد تغيير مركبتك.',
      );
  static String get vehiclePlate => _t(
        'Plate',
        en: 'Plate',
        es: 'Matrícula',
        ar: 'اللوحة',
      );
  static String get vehicleApkExpiry => _t(
        'APK expiry date',
        en: 'MOT expiry date',
        es: 'Fecha de vencimiento ITV',
        ar: 'تاريخ انتهاء الفحص',
      );
  static String get vehicleVerified => _t(
        'Verified taxi',
        en: 'Verified taxi',
        es: 'Taxi verificado',
        ar: 'تاكسي موثق',
      );
  static String get vehicleNotVerified => _t(
        'Not verified',
        en: 'Not verified',
        es: 'No verificado',
        ar: 'غير موثق',
      );
  static String get vehicleNotTaxi => _t(
        'Not a taxi',
        en: 'Not a taxi',
        es: 'No es taxi',
        ar: 'ليس تاكسي',
      );
  static String get vehicleExpandHint => _t(
        'Tap for more details',
        en: 'Tap for more details',
        es: 'Toca para más detalles',
        ar: 'اضغط للمزيد من التفاصيل',
      );
  static String get vehicleCollapseHint => _t(
        'Tap to collapse',
        en: 'Tap to collapse',
        es: 'Toca para contraer',
        ar: 'اضغط للطي',
      );
  static String get viewAllPhotos => _t(
        'View all photos',
        en: 'View all photos',
        es: 'Ver todas las fotos',
        ar: 'عرض جميع الصور',
      );
  static String get editVehicleDetails => _t(
        'Edit vehicle details',
        en: 'Edit vehicle details',
        es: 'Editar detalles del vehículo',
        ar: 'تعديل تفاصيل المركبة',
      );
  static String get contactSupportVehicle => _t(
        'Contact ondersteuning om voertuig te wijzigen',
        en: 'Contact support to change vehicle',
        es: 'Contactar soporte para cambiar vehículo',
        ar: 'تواصل مع الدعم لتغيير المركبة',
      );
  static String get apkExpiringSoon => _t(
        'Expiring soon',
        en: 'Expiring soon',
        es: 'Caduca pronto',
        ar: 'تنتهي قريبا',
      );
  static String get apkExpired => _t(
        'Expired',
        en: 'Expired',
        es: 'Caducado',
        ar: 'منتهي الصلاحية',
      );
  static String get vehiclePassengersSeeThis => _t(
        'RIDERS SEE THIS VEHICLE',
        en: 'RIDERS SEE THIS VEHICLE',
        es: 'LOS PASAJEROS VEN ESTE VEHÍCULO',
        ar: 'الركاب يرون هذه المركبة',
      );
  static String get vehicleNoPhoto => _t(
        'No vehicle photo',
        en: 'No vehicle photo',
        es: 'Sin foto del vehículo',
        ar: 'لا توجد صورة للمركبة',
      );
  static String vehiclePhotoNumber(int current, int total) =>
      _t('Foto $current/$total',
          en: 'Photo $current/$total',
          es: 'Foto $current/$total',
          ar: 'صورة $current/$total');
  static String get preferencesSectionAccessibility => _t(
        'Toegankelijkheid',
        en: 'Accessibility',
        es: 'Accesibilidad',
        ar: 'إمكانية الوصول',
      );
  static String get chauffeurspasSave => _t(
        'Chauffeurspas opslaan',
        en: 'Save driver card',
        es: 'Guardar tarjeta de conductor',
        ar: 'حفظ بطاقة السائق',
      );
  static String get chauffeurspasSaved => _t(
        'Opgeslagen. Ons team controleert je nummer handmatig.',
        en: 'Saved. Our team manually verifies your number.',
        es: 'Guardado. Nuestro equipo verifica tu número manualmente.',
        ar: 'تم الحفظ. يتحقق فريقنا من رقمك يدويا.',
      );
  static String get chauffeurspasExpiryLabel => _t(
        'Vervaldatum op pas (verplicht)',
        en: 'Expiry date on pass (required)',
        es: 'Fecha de caducidad en pase (obligatorio)',
        ar: 'تاريخ انتهاء البطاقة (مطلوب)',
      );
  static String get chauffeurspasExpiryRequired => _t(
        'Vervaldatum op de chauffeurspas is verplicht.',
        en: 'Expiry date on the driver pass is required.',
        es: 'La fecha de caducidad del pase de conductor es obligatoria.',
        ar: 'تاريخ انتهاء بطاقة السائق مطلوب.',
      );
  static String get chauffeurspasExpiryInvalid => _t(
        'Gebruik een geldige vervaldatum in formaat JJJJ-MM-DD.',
        en: 'Use a valid expiry date in YYYY-MM-DD format.',
        es: 'Usa una fecha de caducidad válida en formato AAAA-MM-DD.',
        ar: 'استخدم تاريخ انتهاء صالح بتنسيق YYYY-MM-DD.',
      );
  static String get veriffStart => _t(
        'Rijbewijs verifiëren met Veriff',
        en: 'Verify licence with Veriff',
        es: 'Verificar licencia con Veriff',
        ar: 'التحقق من الرخصة عبر Veriff',
      );

  /// Full-screen Veriff entry (`/driver/veriff`).
  static String get veriffScreenTitle => _t(
        'Rijbewijsverificatie',
        en: 'Licence verification',
        es: 'Verificación de licencia',
        ar: 'التحقق من الرخصة',
      );
  static String get veriffScreenIntro => _t(
        'Je bekijkt eerst de chauffeurvoorwaarden en opent daarna Veriff in je browser om je rijbewijs en identiteit te verifiëren.',
        en: 'You first review the driver terms then open Veriff in your browser to verify your license and identity.',
        es: 'Primero revisas los términos del conductor y luego abres Veriff en tu navegador para verificar tu licencia e identidad.',
        ar: 'تقوم أولا بمراجعة شروط السائق ثم تفتح Veriff في متصفحك للتحقق من رخصتك وهويتك.',
      );

  /// Large callout on `/driver/veriff` — drivers must switch back manually from Safari/Chrome.
  static String get veriffScreenComeBackTitle => _t(
        'Kom terug naar HeyCaby',
        en: 'Come back to HeyCaby',
        es: 'Vuelve a HeyCaby',
        ar: 'عُد إلى HeyCaby',
      );
  static String get veriffScreenComeBackBody => _t(
        'Als je klaar bent in Veriff, schakel terug naar deze app (app-wisselaar of home, open HeyCaby). Je rijbewijsstatus wordt hier bijgewerkt — de browser kan je niet automatisch terugbrengen.',
        en: 'When done in Veriff, switch back to this app (app switcher or home, open HeyCaby). Your license status updates here — the browser can\'t bring you back automatically.',
        es: 'Al terminar en Veriff, vuelve a esta app (cambiador de apps o inicio, abre HeyCaby). Tu estado de licencia se actualiza aquí — el navegador no puede devolverte automáticamente.',
        ar: 'عند الانتهاء من Veriff، عودة إلى هذا التطبيق (مبدل التطبيقات أو الرئيسية، افتح HeyCaby). يتم تحديث حالة رخصتك هنا — لا يمكن للمتصفح إعادتك تلقائيا.',
      );
  static String get veriffScreenContinue => _t(
        'Doorgaan',
        en: 'Continue',
        es: 'Continuar',
        ar: 'متابعة',
      );
  static String get veriffOpenFailed => _t(
        'Veriff kon niet worden geopend. Controleer je verbinding en probeer het opnieuw.',
        en: 'Veriff could not be opened. Check your connection and try again.',
        es: 'No se pudo abrir Veriff. Comprueba tu conexión e inténtalo de nuevo.',
        ar: 'تعذر فتح Veriff. تحقق من اتصالك وحاول مرة أخرى.',
      );
  static String get veriffProcessingHint => _t(
        'Rond verificatie in de browser af. Status wordt hier bijgewerkt als je klaar bent.',
        en: 'Complete verification in the browser. Status updates here when you\'re done.',
        es: 'Completa la verificación en el navegador. El estado se actualiza aquí cuando termines.',
        ar: 'أكمل التحقق في المتصفح. يتم تحديث الحالة هنا عند الانتهاء.',
      );

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
  static String get veriffExternalBrowserTitle => _t(
        'Verificatie buiten de app',
        en: 'Verification outside the app',
        es: 'Verificación fuera de la app',
        ar: 'التحقق خارج التطبيق',
      );
  static String get veriffExternalBrowserBody => _t(
        'We openen Veriff in je browser (Safari of Chrome). Je verlaat daarmee kort de HeyCaby-app om je rijbewijs te verifiëren. Wil je doorgaan?',
        en: 'We open Veriff in your browser (Safari or Chrome). You briefly leave the HeyCaby app to verify your license. Do you want to continue?',
        es: 'Abrimos Veriff en tu navegador (Safari o Chrome). Sales brevemente de la app HeyCaby para verificar tu licencia. ¿Quieres continuar?',
        ar: 'نفتح Veriff في متصفحك (Safari أو Chrome). تغادر HeyCaby مؤقتا للتحقق من رخصتك. هل تريد المتابعة؟',
      );
  static String get veriffExternalBrowserContinue => _t(
        'Ja, openen',
        en: 'Yes, open',
        es: 'Sí, abrir',
        ar: 'نعم، افتح',
      );
  static String get veriffExternalBrowserCancel => _t(
        'Nee',
        en: 'No',
        es: 'No',
        ar: 'لا',
      );
  static String get kvkSave => _t(
        'KvK-gegevens opslaan',
        en: 'Save KvK details',
        es: 'Guardar datos KvK',
        ar: 'حفظ بيانات الغرفة التجارية',
      );
  static String get insurancePickPhoto => _t(
        'Verzekeringsfoto toevoegen',
        en: 'Add insurance photo',
        es: 'Añadir foto de seguro',
        ar: 'إضافة صورة التأمين',
      );
  static String get insurancePickPhotoGreenCard => _t(
        'Verzekeringsfoto toevoegen (groene kaart)',
        en: 'Add insurance photo (green card)',
        es: 'Añadir foto de seguro (tarjeta verde)',
        ar: 'إضافة صورة التأمين (البطاقة الخضراء)',
      );
  static String get insuranceUseCamera => _t(
        'Foto maken',
        en: 'Take photo',
        es: 'Tomar foto',
        ar: 'التقاط صورة',
      );
  static String get insuranceUseGallery => _t(
        'Kiezen uit galerij',
        en: 'Choose from gallery',
        es: 'Elegir de galería',
        ar: 'اختيار من المعرض',
      );
  static String get insuranceSave => _t(
        'Verzekering opslaan',
        en: 'Save insurance',
        es: 'Guardar seguro',
        ar: 'حفظ التأمين',
      );
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
  static String get paymentMethodRequired => _t(
        'Houd minimaal één betaalmethode ingeschakeld.',
        en: 'Keep at least one payment method enabled.',
        es: 'Mantén al menos un método de pago activo.',
        ar: 'احتفظ بطريقة دفع واحدة على الأقل مفعلة.',
      );
  static String get onlineBlockedCompliance => _t(
        'Je kunt pas online als alle verplichte documenten zijn afgerond (chauffeurspas, verzekering, KvK, kenteken, akkoord met de voorwaarden, vrijwaring en korte quiz) en je rijbewijs handmatig is goedgekeurd.',
        en: 'You can only go online once all required documents are completed (driver pass, insurance, KvK, plate, terms agreement, indemnification and short quiz) and your license is manually approved.',
        es: 'Solo puedes conectarte cuando todos los documentos obligatorios estén completos (pase de conductor, seguro, KvK, matrícula, acuerdo de términos, indemnización y quiz corto) y tu licencia sea aprobada manualmente.',
        ar: 'يمكنك الاتصال فقط عند إكمال جميع المستندات المطلوبة (بطاقة السائق والتأمين وKvK ولوحة الأرقام والموافقة على الشروط والتعويض والاختبار القصير) والموافقة اليدوية على رخصتك.',
      );
  static String get onlineBlockedPending => _t(
        'Je profiel wordt beoordeeld…',
        en: 'Your profile is under review…',
        es: 'Tu perfil está en revisión…',
        ar: 'ملفك قيد المراجعة…',
      );

  /// Veriff done; waiting for ops to set `rijbewijs_verified` in Supabase.
  static String get onlineBlockedLicenseReview => _t(
        'Je rijbewijscontrole wordt door ons team afgerond. Je kunt online na bevestiging (meestal kort na Veriff).',
        en: 'Your license check is being completed by our team. You can go online after confirmation (usually shortly after Veriff).',
        es: 'La verificación de tu licencia la completa nuestro equipo. Puedes conectarte tras la confirmación (normalmente poco después de Veriff).',
        ar: 'يتم إكمال فحص رخصتك من قبل فريقنا. يمكنك الاتصال بعد التأكيد (عادة بعد Veriff بوقت قصير).',
      );
  static String get onlineChecklistTitle => _t(
        'Je bent bijna klaar om online te gaan',
        en: 'You\'re almost ready to go online',
        es: 'Casi listo para conectarte',
        ar: 'أنت على وشك الاستعداد للاتصال',
      );
  static String get onlineChecklistMissingPrefix => _t(
        'Ontbreekt:',
        en: 'Missing:',
        es: 'Falta:',
        ar: 'ناقص:',
      );
  static String get onlineChecklistProfilePhoto => _t(
        'Chauffeursprofielfoto',
        en: 'Driver profile photo',
        es: 'Foto de perfil del conductor',
        ar: 'صورة ملف السائق',
      );
  static String get onlineChecklistVehiclePhoto => _t(
        'Voertuigfoto',
        en: 'Vehicle photo',
        es: 'Foto del vehículo',
        ar: 'صورة المركبة',
      );
  static String get onlineChecklistChauffeurCard => _t(
        'Chauffeurspasnummer',
        en: 'Driver card number',
        es: 'Número de tarjeta de conductor',
        ar: 'رقم بطاقة السائق',
      );
  static String get onlineChecklistChauffeurExpiry => _t(
        'Vervaldatum chauffeurspas',
        en: 'Driver pass expiry date',
        es: 'Fecha de caducidad del pase de conductor',
        ar: 'تاريخ انتهاء بطاقة السائق',
      );
  static String get onlineChecklistInsuranceProvider => _t(
        'Taxiverzekeraar',
        en: 'Taxi insurer',
        es: 'Aseguradora de taxi',
        ar: 'مؤمن التاكسي',
      );
  static String get onlineChecklistInsurancePolicy => _t(
        'Polisnummer taxiverzekering',
        en: 'Taxi insurance policy number',
        es: 'Número de póliza de seguro de taxi',
        ar: 'رقم وثيقة تأمين سيارة الأجرة',
      );
  static String get onlineChecklistInsuranceExpiry => _t(
        'Vervaldatum taxiverzekering',
        en: 'Taxi insurance expiry date',
        es: 'Fecha de caducidad del seguro de taxi',
        ar: 'تاريخ انتهاء تأمين سيارة الأجرة',
      );
  static String get onlineChecklistInsurancePhoto => _t(
        'Foto groene kaart verzekering',
        en: 'Insurance green card photo',
        es: 'Foto de tarjeta verde de seguro',
        ar: 'صورة البطاقة الخضراء للتأمين',
      );
  static String get onlineChecklistKvkNumber => _t(
        'KvK-nummer',
        en: 'KvK number',
        es: 'Número KvK',
        ar: 'رقم الغرفة التجارية',
      );
  static String get onlineChecklistKvkAddress => _t(
        'KvK-bedrijfsadres',
        en: 'KvK business address',
        es: 'Dirección comercial KvK',
        ar: 'عنوان عمل الغرفة التجارية',
      );
  static String get onlineChecklistVehiclePlate => _t(
        'Kenteken',
        en: 'License plate',
        es: 'Matrícula',
        ar: 'لوحة الأرقام',
      );
  static String get onlineChecklistTerms => _t(
        'Gebruiksvoorwaarden accepteren',
        en: 'Accept terms of service',
        es: 'Aceptar términos de servicio',
        ar: 'قبول شروط الخدمة',
      );
  static String get onlineChecklistShortQuiz => _t(
        'Korte juridische quiz halen',
        en: 'Pass short legal quiz',
        es: 'Aprobar cuestionario legal',
        ar: 'اجتياز اختبار قانوني قصير',
      );
  static String get onlineChecklistIndemnification => _t(
        'Vrijwaring lezen en bevestigen',
        en: 'Read and confirm indemnification',
        es: 'Leer y confirmar indemnización',
        ar: 'قراءة وتأكيد التعويض',
      );
  static String get onlineChecklistLicenceApproval => _t(
        'Handmatige goedkeuring rijbewijs (na Veriff)',
        en: 'Manual license approval (after Veriff)',
        es: 'Aprobación manual de licencia (tras Veriff)',
        ar: 'الموافقة اليدوية على الرخصة (بعد Veriff)',
      );

  /// Legacy compatibility labels for the old platform-fee gate.
  /// Active UI should use Platform Balance wording.
  static String get platformFeeTitle => _t(
        'Platformbalans',
        en: 'Platform balance',
        es: 'Saldo de plataforma',
        ar: 'رصيد المنصة',
      );
  static String platformFeeBody(String euros) => _t(
      'Je openstaande platformbalans is €$euros. Vereffen deze om weer nieuwe ritaanvragen te ontvangen.',
      en: 'Your outstanding platform balance is €$euros. Settle it to receive new ride requests again.',
      es: 'Tu saldo de plataforma pendiente es €$euros. Liquídalo para recibir nuevas solicitudes de viaje.',
      ar: 'رصيد منصتك المستحق هو €$euros. ساوِه لتلقي طلبات رحلة جديدة مرة أخرى.');
  static String get platformFeePay => _t(
        'Platformbalans vereffenen',
        en: 'Settle platform balance',
        es: 'Saldar balance de plataforma',
        ar: 'تسوية رصيد المنصة',
      );
  static String get platformFeeCheckoutTitle => _t(
        'Platformbalans',
        en: 'Platform balance',
        es: 'Saldo de plataforma',
        ar: 'رصيد المنصة',
      );
  static String get platformFeeStartingCheckout => _t(
        'Betaling voorbereiden…',
        en: 'Preparing payment…',
        es: 'Preparando pago…',
        ar: 'جاري تحضير الدفع…',
      );
  static String get platformFeeInvalidUrl => _t(
        'Ongeldige betaallink. Probeer opnieuw.',
        en: 'Invalid payment link. Try again.',
        es: 'Enlace de pago inválido. Inténtalo de nuevo.',
        ar: 'رابط دفع غير صالح. حاول مرة أخرى.',
      );
  static String get platformFeeStatusError => _t(
        'Kon je status niet ophalen. Controleer je verbinding.',
        en: 'Could not fetch your status. Check your connection.',
        es: 'No se pudo obtener tu estado. Comprueba tu conexión.',
        ar: 'تعذر جلب حالتك. تحقق من اتصالك.',
      );
  static String get platformFeeStartError => _t(
        'Betaling starten mislukt. Probeer opnieuw.',
        en: 'Failed to start payment. Try again.',
        es: 'Error al iniciar pago. Inténtalo de nuevo.',
        ar: 'فشل بدء الدفع. حاول مرة أخرى.',
      );
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
  static String get platformFeeStillPending => _t(
        'Betaling nog niet bevestigd. Wacht even of probeer opnieuw.',
        en: 'Payment not confirmed yet. Wait a moment or try again.',
        es: 'Pago aún no confirmado. Espera un momento o inténtalo de nuevo.',
        ar: 'لم يتم تأكيد الدفع بعد. انتظر لحظة أو حاول مرة أخرى.',
      );
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
  static String get platformRidesPausedTitle => _t(
        'Platformritten gepauzeerd',
        en: 'Platform rides paused',
        es: 'Viajes de plataforma pausados',
        ar: 'رحلات المنصة متوقفة مؤقتا',
      );
  static String get platformRidesPausedBody => _t(
        'Je Platformbalans is achterstallig. Je kunt online blijven en HeyCaby gebruiken, maar je ontvangt geen nieuwe Directe, Geplande of Taxi Terug-ritten totdat de balans is vereffend.',
        en: 'Your Platform Balance is overdue. You can remain online and use HeyCaby, but you will not receive new Instant, Scheduled or Taxi Terug rides until the balance is settled.',
        es: 'Tu Balance de plataforma está vencido. Puedes seguir en línea y usar HeyCaby, pero no recibirás nuevos viajes Instantáneos, Programados o Taxi Terug hasta liquidarlo.',
        ar: 'رصيد المنصة متأخر. يمكنك البقاء متصلا واستخدام HeyCaby، لكنك لن تتلقى رحلات فورية أو مجدولة أو Taxi Terug جديدة حتى تتم تسوية الرصيد.',
      );
  static String get platformRidesPausedCta => _t(
        'Vereffeningsgegevens bekijken',
        en: 'View settlement details',
        es: 'Ver datos de liquidación',
        ar: 'عرض تفاصيل التسوية',
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
  static String get platformBalanceViewSettlementDetails => _t(
        'Vereffeningsgegevens bekijken',
        en: 'View settlement details',
        es: 'Ver datos de liquidación',
        ar: 'عرض تفاصيل التسوية',
      );
  static String get platformBalanceBrowserOpened => _t(
        'Vereffeningsgegevens geopend in je browser.',
        en: 'Settlement details opened in your browser.',
        es: 'Los datos de liquidación se abrieron en tu navegador.',
        ar: 'تم فتح تفاصيل التسوية في المتصفح.',
      );
  static String get platformBalanceBrowserOpenFailed => _t(
        'De vereffeningspagina kon niet worden geopend. Probeer opnieuw.',
        en: 'Could not open the settlement page. Try again.',
        es: 'No se pudo abrir la página de liquidación. Inténtalo de nuevo.',
        ar: 'تعذر فتح صفحة التسوية. حاول مرة أخرى.',
      );
  static String get platformBalanceBankTransferTitle => _t(
        'Betalen via bankoverschrijving',
        en: 'Pay by bank transfer',
        es: 'Pagar por transferencia bancaria',
        ar: 'الدفع عن طريق التحويل البنكي',
      );
  static String get platformBalanceBankTransferSubtitle => _t(
        'Gebruik deze gegevens om je platformbalans te vereffenen.',
        en: 'Use these details to settle your Platform Balance.',
        es: 'Usa estos datos para liquidar tu balance de plataforma.',
        ar: 'استخدم هذه البيانات لتسوية رصيد المنصة.',
      );
  static String get platformBalanceTransferAmount => _t(
        'Over te maken bedrag',
        en: 'Amount to transfer',
        es: 'Importe a transferir',
        ar: 'المبلغ المراد تحويله',
      );
  static String get platformBalanceAccountHolder => _t(
        'Rekeninghouder',
        en: 'Account holder',
        es: 'Titular de la cuenta',
        ar: 'صاحب الحساب',
      );
  static String get platformBalanceIban => 'IBAN';
  static String get platformBalanceBankName => _t(
        'Bank',
        en: 'Bank',
        es: 'Banco',
        ar: 'البنك',
      );
  static String get platformBalanceBic => 'BIC';
  static String get platformBalancePaymentReference => _t(
        'Betalingskenmerk',
        en: 'Payment reference',
        es: 'Referencia de pago',
        ar: 'مرجع الدفع',
      );
  static String get platformBalanceReferenceWarning => _t(
        'Vermeld altijd het exacte betalingskenmerk. Zonder dit kenmerk kan je betaling niet automatisch worden verwerkt.',
        en: 'Always include the exact payment reference. Without it, your payment cannot be matched automatically.',
        es: 'Incluye siempre la referencia de pago exacta. Sin ella, tu pago no puede identificarse automáticamente.',
        ar: 'أدرج دائما مرجع الدفع الدقيق. بدونه لا يمكن مطابقة دفعتك تلقائيا.',
      );
  static String get platformBalanceBankTransferTiming => _t(
        'Je platformbalans wordt bijgewerkt zodra de bankbetaling is ontvangen. Dit kan tot één werkdag duren.',
        en: 'Your Platform Balance updates after the bank transfer is received. This can take up to one business day.',
        es: 'Tu balance de plataforma se actualiza cuando se recibe la transferencia. Puede tardar hasta un día laborable.',
        ar: 'يتم تحديث رصيد المنصة بعد استلام التحويل البنكي. قد يستغرق ذلك يوم عمل واحدا.',
      );
  static String get platformBalancePayOnlineInstead => _t(
        'Liever online betalen',
        en: 'Pay online instead',
        es: 'Pagar en línea',
        ar: 'الدفع عبر الإنترنت بدلا من ذلك',
      );
  static String get platformBalanceCopy => _t(
        'Kopieer',
        en: 'Copy',
        es: 'Copiar',
        ar: 'نسخ',
      );
  static String platformBalanceCopied(String field) => _t(
        '$field gekopieerd',
        en: '$field copied',
        es: '$field copiado',
        ar: 'تم نسخ $field',
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
  static String get billingCurrentPlan => _t(
        'Platformbalans',
        en: 'Platform balance',
        es: 'Saldo de plataforma',
        ar: 'رصيد المنصة',
      );
  static String get billingFoundingMember => _t(
        'Founding Driver',
        en: 'Founding Driver',
        es: 'Conductor fundador',
        ar: 'سائق مؤسس',
      );
  static String get billingRegularMember => _t(
        'Chauffeur',
        en: 'Driver',
        es: 'Conductor',
        ar: 'سائق',
      );
  static String get billingWeeklyFee => _t(
        'Wekelijkse platformbalans',
        en: 'Weekly platform balance',
        es: 'Saldo semanal de plataforma',
        ar: 'رصيد المنصة الأسبوعي',
      );
  static String get billingPerRideSuffix => _t(
        'per rit',
        en: 'per ride',
        es: 'por viaje',
        ar: 'لكل رحلة',
      );
  static String get billingOutstandingLimit => _t(
        'Openstaand',
        en: 'Outstanding',
        es: 'Pendiente',
        ar: 'المستحق',
      );
  static String get billingNextPayment => _t(
        'Volgende betaling',
        en: 'Next payment',
        es: 'Próximo pago',
        ar: 'الدفعة القادمة',
      );
  static String get billingPaymentStatus => _t(
        'Betalingsstatus',
        en: 'Payment status',
        es: 'Estado de pago',
        ar: 'حالة الدفع',
      );
  static String get billingStatusActive => _t(
        'Actief',
        en: 'Active',
        es: 'Activo',
        ar: 'نشط',
      );
  static String get billingStatusPending => _t(
        'In afwachting',
        en: 'Pending',
        es: 'Pendiente',
        ar: 'قيد الانتظار',
      );
  static String get billingStatusOverdue => _t(
        'Achterstallig',
        en: 'Overdue',
        es: 'Atrasado',
        ar: 'متأخر',
      );
  static String get billingViewHistory => _t(
        'Balansgeschiedenis bekijken',
        en: 'View balance history',
        es: 'Ver historial de saldo',
        ar: 'عرض سجل الرصيد',
      );
  static String get billingPaymentMethods => _t(
        'Betaalmethoden',
        en: 'Payment methods',
        es: 'Métodos de pago',
        ar: 'طرق الدفع',
      );
  static String get billingPayNow => _t(
        'Platformbalans vereffenen',
        en: 'Settle platform balance',
        es: 'Saldar balance de plataforma',
        ar: 'تسوية رصيد المنصة',
      );
  static String get billingChoosePlanTitle => _t(
        'Platformbalans vereffenen',
        en: 'Settle platform balance',
        es: 'Saldar balance de plataforma',
        ar: 'تسوية رصيد المنصة',
      );
  static String get billingPlanUnknown => _t(
        'Platformbalans',
        en: 'Platform balance',
        es: 'Saldo de plataforma',
        ar: 'رصيد المنصة',
      );
  static String get billingUseSelectedPlan => _t(
        'Platformbalans vereffenen',
        en: 'Settle platform balance',
        es: 'Saldar balance de plataforma',
        ar: 'تسوية رصيد المنصة',
      );

  /// Shown when the server does not return usable Platform Balance pricing.
  static String get billingPlansUnavailable => _t(
        'Prijzen zijn nu niet beschikbaar. Vernieuw of probeer het later opnieuw.',
        en: 'Pricing not available right now. Refresh or try again later.',
        es: 'Los precios no están disponibles ahora. Actualiza o inténtalo más tarde.',
        ar: 'التسعير غير متاح الآن. حدث أو حاول لاحقا.',
      );
  static String get billingHistoryTitle => _t(
        'Platformactiviteit',
        en: 'Platform activity',
        es: 'Actividad de plataforma',
        ar: 'نشاط المنصة',
      );
  static String get billingHistoryEmpty => _t(
        'Nog geen platformactiviteit',
        en: 'No platform activity yet',
        es: 'Sin actividad de plataforma',
        ar: 'لا يوجد نشاط للمنصة بعد',
      );
  static String get billingHistoryDate => _t(
        'Datum',
        en: 'Date',
        es: 'Fecha',
        ar: 'التاريخ',
      );
  static String get billingHistoryAmount => _t(
        'Bedrag',
        en: 'Amount',
        es: 'Importe',
        ar: 'المبلغ',
      );
  static String get billingHistoryStatus => _t(
        'Status',
        en: 'Status',
        es: 'Estado',
        ar: 'الحالة',
      );
  static String get billingHistoryMethod => _t(
        'Methode',
        en: 'Method',
        es: 'Método',
        ar: 'الطريقة',
      );
  static String get billingHistoryStatusPaid => _t(
        'Betaald',
        en: 'Paid',
        es: 'Pagado',
        ar: 'مدفوع',
      );
  static String get billingHistoryStatusFailed => _t(
        'Mislukt',
        en: 'Failed',
        es: 'Fallido',
        ar: 'فشل',
      );
  static String get billingHistoryStatusPending => _t(
        'In afwachting',
        en: 'Pending',
        es: 'Pendiente',
        ar: 'قيد الانتظار',
      );
  static String get billingDash => _t(
        '—',
        en: '—',
        es: '—',
        ar: '—',
      );
  static String get billingWeeklyFeeUnknown => _t(
        'Bedrag staat op de server; vernieuw als dit leeg blijft.',
        en: 'Amount is on the server; refresh if this stays empty.',
        es: 'El importe está en el servidor; actualiza si sigue vacío.',
        ar: 'المبلغ على الخادم؛ حدث إذا بقي فارغا.',
      );
  static String get billingStatusFromServer => _t(
        'Accountstatus',
        en: 'Account status',
        es: 'Estado de cuenta',
        ar: 'حالة الحساب',
      );
  static String get billingStatusPaymentRequired => _t(
        'Betaling vereist',
        en: 'Payment required',
        es: 'Pago requerido',
        ar: 'الدفعة مطلوبة',
      );
  static String get billingStatusNoPaymentDue => _t(
        'Geen betaling verschuldigd',
        en: 'No payment due',
        es: 'Sin pago pendiente',
        ar: 'لا توجد دفعة مستحقة',
      );
  static String get billingStatusPaused => _t(
        'Gepauzeerd',
        en: 'Paused',
        es: 'Pausado',
        ar: 'متوقف مؤقتا',
      );
  static String get billingStatusCanceled => _t(
        'Geannuleerd',
        en: 'Cancelled',
        es: 'Cancelado',
        ar: 'ملغى',
      );
  static String get billingPaymentMethodsPortalTitle => _t(
        'Betaalmethoden',
        en: 'Payment methods',
        es: 'Métodos de pago',
        ar: 'طرق الدفع',
      );
  static String get billingPaymentMethodsUnavailable => _t(
        'Beheren van betaalmethoden is nog niet beschikbaar. Neem contact op met de ondersteuning als je je kaart wilt wijzigen.',
        en: 'Managing payment methods is not yet available. Contact support if you want to change your card.',
        es: 'Gestionar métodos de pago aún no está disponible. Contacta con soporte si quieres cambiar tu tarjeta.',
        ar: 'إدارة طرق الدفع غير متاحة بعد. تواصل مع الدعم إذا كنت تريد تغيير بطاقتك.',
      );
  static String get billingPayPreparing => _t(
        'Betaling voorbereiden…',
        en: 'Preparing payment…',
        es: 'Preparando pago…',
        ar: 'جاري تحضير الدفع…',
      );
  static String get billingNextPaymentDueSoon => _t(
        'Binnenkort verschuldigd',
        en: 'Due soon',
        es: 'Vence pronto',
        ar: 'مستحق قريبا',
      );

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

  static String get drawerBillingStatusUnavailable => _t(
        'Weekstatus niet beschikbaar',
        en: 'Weekly status unavailable',
        es: 'Estado semanal no disponible',
        ar: 'الحالة الأسبوعية غير متاحة',
      );
  static String get drawerBillingWaitingLiveStatus => _t(
        'Wachten op live status van de server',
        en: 'Waiting for live status from server',
        es: 'Esperando estado en vivo del servidor',
        ar: 'بانتظار الحالة المباشرة من الخادم',
      );

  static String get licenceSubmittedPendingReview => _t(
        'Ingediend — ons team bevestigt je rijbewijs na beoordeling van Veriff.',
        en: 'Submitted — our team confirms your license after Veriff review.',
        es: 'Enviado — nuestro equipo confirma tu licencia tras la revisión de Veriff.',
        ar: 'تم الإرسال — فريقنا يؤكد رخصتك بعد مراجعة Veriff.',
      );
  static String get docSavePermanentTitle => _t(
        'Permanent opslaan?',
        en: 'Save permanently?',
        es: '¿Guardar permanentemente?',
        ar: 'حفظ دائم؟',
      );
  static String get docSavePermanentBody => _t(
        'Na opslaan kun je dit niet meer in de app wijzigen. Onjuiste of frauduleuze gegevens kunnen tot een ban leiden. Voor latere correctie: neem contact op met klantenservice.',
        en: 'After saving you can\'t change this in the app. Incorrect or fraudulent data may lead to a ban. For later corrections: contact customer service.',
        es: 'Tras guardar no puedes cambiar esto en la app. Datos incorrectos o fraudulentos pueden llevar a una prohibición. Para correcciones posteriores: contacta con servicio al cliente.',
        ar: 'بعد الحفظ لا يمكنك تغيير هذا في التطبيق. البيانات غير الصحيحة أو الاحتيالية قد تؤدي إلى حظر. للتصحيحات لاحقا: تواصل مع خدمة العملاء.',
      );
  static String get docSaveInsuranceBody => _t(
        'Na opslaan kun je deze gegevens niet meer in de app wijzigen. Taxiverzekering is verplicht; we kunnen invoeren controleren. Voor updates later: neem contact op met de ondersteuning.',
        en: 'After saving you can\'t change this data in the app. Taxi insurance is required; we may verify entries. For later updates: contact support.',
        es: 'Tras guardar no puedes cambiar estos datos en la app. El seguro de taxi es obligatorio; podemos verificar los datos. Para actualizaciones posteriores: contacta con soporte.',
        ar: 'بعد الحفظ لا يمكنك تغيير هذه البيانات في التطبيق. تأمين سيارة الأجرة إلزامي؛ قد نتحقق من الإدخالات. للتحديثات لاحقا: تواصل مع الدعم.',
      );
  static String get docSaveConfirm => _t(
        'Opslaan',
        en: 'Save',
        es: 'Guardar',
        ar: 'حفظ',
      );
  static String get fieldLockedContactSupport => _t(
        'Opgeslagen — neem contact op met de ondersteuning om dit te wijzigen.',
        en: 'Saved — contact support to change this.',
        es: 'Guardado — contacta con soporte para cambiar esto.',
        ar: 'محفوظ — تواصل مع الدعم لتغيير هذا.',
      );
  static String get insuranceAccuracyWarning => _t(
        'Vul verzekeraar, polisnummer en vervaldatum correct in. Upload een duidelijke foto van je verzekeringsdocument.',
        en: 'Enter insurer, policy number and expiry date correctly. Upload a clear photo of your insurance document.',
        es: 'Introduce aseguradora, número de póliza y fecha de caducidad correctamente. Sube una foto clara de tu documento de seguro.',
        ar: 'أدخل اسم شركة التأمين ورقم الوثيقة وتاريخ الانتهاء بشكل صحيح. ارفع صورة واضحة لمستند التأمين.',
      );
  static String get insuranceLiabilityDisclaimer => _t(
        'Deze upload bevestigt dat je taxiverzekering hebt (groene kaart). Jij blijft volledig verantwoordelijk om je verzekering actief, geldig en up-to-date te houden.',
        en: 'This upload confirms you have taxi insurance (green card). You remain fully responsible for keeping your insurance active, valid and up-to-date.',
        es: 'Esta subida confirma que tienes seguro de taxi (tarjeta verde). Sigues siendo totalmente responsable de mantener tu seguro activo, válido y actualizado.',
        ar: 'هذا التحميل يؤكد أن لديك تأمين سيارة أجرة (بطاقة خضراء). تظل مسؤولا بالكامل عن الحفاظ على تأمينك نشطا وصالحا ومحدثا.',
      );
  static String get insuranceCanEditAnytime => _t(
        'Je kunt je taxiverzekeringsgegevens en document altijd bijwerken.',
        en: 'You can update your taxi insurance details and document anytime.',
        es: 'Puedes actualizar tus datos y documento de seguro de taxi en cualquier momento.',
        ar: 'يمكنك تحديث بيانات تأمين سيارة الأجرة ومستندك في أي وقت.',
      );
  static String get indemnificationTitle => _t(
        'Vrijwaringsovereenkomst chauffeur',
        en: 'Driver indemnification agreement',
        es: 'Acuerdo de indemnización del conductor',
        ar: 'اتفاقية تعويض السائق',
      );
  static String get indemnificationSummary1 => _t(
        'Voordat je online gaat, moet je de vrijwaring en aansprakelijkheidsverklaring lezen.',
        en: 'Before going online, you must read the indemnification and liability statement.',
        es: 'Antes de conectarte, debes leer la indemnización y declaración de responsabilidad.',
        ar: 'قبل الاتصال، يجب عليك قراءة التعويض وإقرار المسؤولية.',
      );
  static String get indemnificationSummary2 => _t(
        'Jij blijft volledig verantwoordelijk voor naleving van de wet, geldige vergunningen, verzekering en je eigen vervoersactiviteiten.',
        en: 'You remain fully responsible for compliance with the law, valid permits, insurance and your own transport activities.',
        es: 'Sigues siendo totalmente responsable del cumplimiento de la ley, permisos válidos, seguro y tus propias actividades de transporte.',
        ar: 'تظل مسؤولا بالكامل عن الامتثال للقانون والتصاريح الصالحة والتأمين وأنشطة النقل الخاصة بك.',
      );
  static String get indemnificationSummary3 => _t(
        'Niet lezen van dit document maakt je aansprakelijkheid niet weg. Door verder te gaan bevestig je dit te begrijpen.',
        en: 'Not reading this document does not remove your liability. By proceeding you confirm you understand this.',
        es: 'No leer este documento no elimina tu responsabilidad. Al continuar confirmas que entiendes esto.',
        ar: 'عدم قراءة هذا المستند لا يزيل مسؤوليتك. بالمتابعة تؤكد أنك تفهم ذلك.',
      );
  static String get indemnificationReadLabel => _t(
        'Ik heb het vrijwaringsdocument gelezen en aanvaard verantwoordelijkheid.',
        en: 'I have read the indemnification document and accept responsibility.',
        es: 'He leído el documento de indemnización y acepto la responsabilidad.',
        ar: 'لقد قرأت مستند التعويض وأقبل المسؤولية.',
      );
  static String get legalChecklistTitle => _t(
        'Verplichte juridische checks (3)',
        en: 'Mandatory legal checks (3)',
        es: 'Controles legales obligatorios (3)',
        ar: 'الفحوصات القانونية الإلزامية (3)',
      );
  static String get legalChecklistOpenTerms => _t(
        'Gebruiksvoorwaarden openen',
        en: 'Open terms of service',
        es: 'Abrir términos de servicio',
        ar: 'فتح شروط الخدمة',
      );
  static String get legalChecklistOpenIndemnification => _t(
        'Vrijwaringsverklaring openen',
        en: 'Open indemnification statement',
        es: 'Abrir declaración de indemnización',
        ar: 'فتح إقرار التعويض',
      );
  static String get legalChecklistTermsCheck => _t(
        'Vink aan na het lezen van de gebruiksvoorwaarden',
        en: 'Check after reading the terms of use',
        es: 'Marca tras leer los términos de uso',
        ar: 'حدد بعد قراءة شروط الاستخدام',
      );
  static String get legalChecklistIndemnificationCheck => _t(
        'Vink aan na het lezen van de vrijwaringsverklaring',
        en: 'Check after reading the indemnification statement',
        es: 'Marca tras leer la declaración de indemnización',
        ar: 'حدد بعد قراءة إقرار التعويض',
      );
  static String get legalChecklistQuizCheck => _t(
        'Vink aan door de korte juridische quiz te halen',
        en: 'Check by passing the short legal quiz',
        es: 'Marca superando el quiz legal corto',
        ar: 'حدد بتجاوز الاختبار القانوني القصير',
      );
  static String get legalChecklistSaved => _t(
        'Juridische bevestiging opgeslagen.',
        en: 'Legal confirmation saved.',
        es: 'Confirmación legal guardada.',
        ar: 'تم حفظ التأكيد القانوني.',
      );
  static String get legalChecklistSaveFailed => _t(
        'Juridische bevestiging opslaan mislukt. Probeer opnieuw.',
        en: 'Failed to save legal confirmation. Try again.',
        es: 'Error al guardar confirmación legal. Inténtalo de nuevo.',
        ar: 'فشل حفظ التأكيد القانوني. حاول مرة أخرى.',
      );
  static String get legalChecklistAllVerified => _t(
        'Alle 3 gecontroleerd',
        en: 'All 3 checked',
        es: 'Los 3 verificados',
        ar: 'تم فحص الثلاثة',
      );
  static String legalChecklistProgress(int done, int total) =>
      _t('$done/$total afgerond',
          en: '$done/$total completed',
          es: '$done/$total completados',
          ar: 'اكتمل $done/$total');
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
  static String get indemnificationReadRequired => _t(
        'Bevestig eerst dat je het vrijwaringsdocument hebt gelezen.',
        en: 'First confirm you have read the indemnification document.',
        es: 'Primero confirma que has leído el documento de indemnización.',
        ar: 'أكد أولا أنك قرأت مستند التعويض.',
      );
  static String get indemnificationOpenDoc => _t(
        'Vrijwaringsdocument openen',
        en: 'Open indemnification document',
        es: 'Abrir documento de indemnización',
        ar: 'فتح وثيقة التعويض',
      );
  static String get indemnificationStartQuiz => _t(
        'Start quiz van 5 vragen',
        en: 'Start 5-question quiz',
        es: 'Iniciar cuestionario de 5 preguntas',
        ar: 'بدء اختبار من 5 أسئلة',
      );
  static String get indemnificationPassed => _t(
        'Gehaald. Vrijwaring is afgerond.',
        en: 'Passed. Indemnification is complete.',
        es: 'Aprobado. La indemnización está completa.',
        ar: 'نجحت. اكتمل التعويض.',
      );
  static String get indemnificationBadgePassed => _t(
        'Gehaald',
        en: 'Passed',
        es: 'Aprobado',
        ar: 'اجتاز',
      );
  static String get indemnificationSaveFailed => _t(
        'Vrijwaring opslaan mislukt. Probeer opnieuw.',
        en: 'Failed to save indemnification. Try again.',
        es: 'Error al guardar indemnización. Inténtalo de nuevo.',
        ar: 'فشل حفظ التعويض. حاول مرة أخرى.',
      );
  static String get indemnificationQuizTitle => _t(
        'Begripsquiz vrijwaring',
        en: 'Indemnification comprehension quiz',
        es: 'Cuestionario de indemnización',
        ar: 'اختبار فهم التعويض',
      );
  static String get indemnificationQuizFail => _t(
        'Quiz niet gehaald. Lees opnieuw en probeer nog eens.',
        en: 'Quiz not passed. Read again and try once more.',
        es: 'Quiz no aprobado. Lee de nuevo e inténtalo otra vez.',
        ar: 'لم تجتز الاختبار. اقرأ مرة أخرى وحاول مرة أخرى.',
      );
  static String get indemnificationQuizPassTitle => _t(
        'Gefeliciteerd, je hebt de quiz gehaald',
        en: 'Congratulations, you passed the quiz',
        es: 'Felicidades, has aprobado el quiz',
        ar: 'تهانينا، لقد اجتزت الاختبار',
      );
  static String get indemnificationQuizPassBody => _t(
        'Goed gedaan. Je juridische quiz staat nu als afgerond.',
        en: 'Well done. Your legal quiz is now marked as completed.',
        es: 'Bien hecho. Tu quiz legal ahora está marcado como completado.',
        ar: 'أحسنت. الاختبار القانوني الخاص بك الآن محدد كمكتمل.',
      );
  static String get indemnificationQuizPassCta => _t(
        'Doorgaan',
        en: 'Continue',
        es: 'Continuar',
        ar: 'متابعة',
      );
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
  static String get vehiclePlateRdwOpenSource => _t(
        'APK- en taxistatus worden gecontroleerd via RDW-open data. We hebben alleen je kenteken nodig.',
        en: 'MOT and taxi status are verified via RDW open data. We only need your plate number.',
        es: 'ITV y estado de taxi se verifican via datos abiertos RDW. Solo necesitamos tu matrícula.',
        ar: 'يتم التحقق من الفحص التقني وحالة سيارة الأجرة عبر بيانات RDW المفتوحة. نحتاج فقط لوحة أرقامك.',
      );

  /// Home banner when `profile_status` is pending admin review.
  static String get verificationPendingTitle => _t(
        'Documenten in beoordeling',
        en: 'Documents under review',
        es: 'Documentos en revisión',
        ar: 'المستندات قيد المراجعة',
      );
  static String get verificationPendingBody => _t(
        'Ons team controleert je chauffeurspas en KvK-gegevens. Je kunt online als je profiel is goedgekeurd.',
        en: 'Our team verifies your driver pass and KvK details. You can go online once your profile is approved.',
        es: 'Nuestro equipo verifica tu pase de conductor y datos KvK. Puedes conectarte cuando tu perfil sea aprobado.',
        ar: 'يتحقق فريقنا من بطاقة السائق وبيانات KvK. يمكنك الاتصال عند الموافقة على ملفك.',
      );
  static String get congratsTitle => _t(
        'Welkom bij HeyCaby!',
        en: 'Welcome to HeyCaby!',
        es: '¡Bienvenido a HeyCaby!',
        ar: 'مرحبا بك في HeyCaby!',
      );
  static String congratsTitleWithName(String name) =>
      _t('Welkom bij HeyCaby, $name!',
          en: 'Welcome to HeyCaby, $name!',
          es: '¡Bienvenido a HeyCaby, $name!',
          ar: 'مرحبا بك في HeyCaby يا $name!');
  static String get congratsBody => _t(
        'Je profiel is goedgekeurd. Je kunt nu ritaanvragen ontvangen.',
        en: 'Your profile is approved. You can now receive ride requests.',
        es: 'Tu perfil ha sido aprobado. Ya puedes recibir solicitudes de viaje.',
        ar: 'تمت الموافقة على ملفك. يمكنك الآن تلقي طلبات الرحلة.',
      );
  static String get congratsStart => _t(
        'Start mijn eerste rit',
        en: 'Start my first ride',
        es: 'Iniciar mi primer viaje',
        ar: 'ابدأ رحلتي الأولى',
      );
  static String get congratsInvite => _t(
        'Groei je stad',
        en: 'Grow Your City',
        es: 'Haz crecer tu ciudad',
        ar: 'نمّ مدينتك',
      );
  static String get recentPassengerComments => _t(
        'Recente opmerkingen van passagiers',
        en: 'Recent passenger comments',
        es: 'Comentarios recientes de pasajeros',
        ar: 'تعليقات الركاب الأخيرة',
      );
  static String get whatReducedMyScore => _t(
        'Waardoor daalde mijn score?',
        en: 'What reduced my score?',
        es: '¿Qué redujo mi puntuación?',
        ar: 'ما الذي خفض نقاطي؟',
      );
  static String get scoreFactorsDesc => _t(
        'Je score is gebaseerd op passagiersbeoordelingen en je acceptatiegraad. Geweigerde aanvragen en lagere beoordelingen kunnen je score verlagen.',
        en: 'Your score is based on passenger ratings and your acceptance rate. Rejected requests and lower ratings can lower your score.',
        es: 'Tu puntuación se basa en calificaciones de pasajeros y tu tasa de aceptación. Solicitudes rechazadas y calificaciones más bajas pueden bajar tu puntuación.',
        ar: 'درجتك مبنية على تقييمات الركاب ومعدل قبولك. الطلبات المرفوضة والتقييمات الأقل يمكن أن تخفض درجتك.',
      );
  static String get ridesThisWeek => _t(
        'Ritten deze week',
        en: 'Rides this week',
        es: 'Viajes esta semana',
        ar: 'رحلات هذا الأسبوع',
      );
  static String get taxSummary => _t(
        'Belastingoverzicht',
        en: 'Tax summary',
        es: 'Resumen fiscal',
        ar: 'ملخص الضرائب',
      );
  static String get viewDetails => _t(
        'Details bekijken',
        en: 'View details',
        es: 'Ver detalles',
        ar: 'عرض التفاصيل',
      );
  static String get goBackOnline => _t(
        'Weer online gaan',
        en: 'Go back online',
        es: 'Volver a estar en línea',
        ar: 'العودة للاتصال',
      );
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
  static String get connectivityOfflineBanner => _t(
        'Geen internet. Acties wachten tot je weer online bent.',
        en: 'No internet. Actions wait until you\'re back online.',
        es: 'Sin internet. Las acciones esperan hasta que vuelvas a estar en línea.',
        ar: 'لا إنترنت. تنتظر الإجراءات حتى تتصل مرة أخرى.',
      );
  static String get connectivityRetry => _t(
        'Opnieuw',
        en: 'Retry',
        es: 'Reintentar',
        ar: 'إعادة المحاولة',
      );
  static String get connectivityBackOnline => _t(
        'Verbinding hersteld.',
        en: 'Connection restored.',
        es: 'Conexión restaurada.',
        ar: 'تم استعادة الاتصال.',
      );
  static String connectivityBackOnlineWithQueue(int count) =>
      _t('Verbinding hersteld. $count actie(s) opnieuw geprobeerd.',
          en: 'Connection restored. $count action(s) retried.',
          es: 'Conexión restaurada. $count acción(es) reintentada(s).',
          ar: 'تم استعادة الاتصال. تمت إعادة محاولة $count إجراء.');
  static String get connectivityOfflineActionBlocked => _t(
        'Geen internetverbinding. Probeer opnieuw zodra je online bent.',
        en: 'No internet connection. Try again once you\'re online.',
        es: 'Sin conexión a internet. Inténtalo de nuevo cuando estés en línea.',
        ar: 'لا يوجد اتصال بالإنترنت. حاول مرة أخرى بمجرد الاتصال.',
      );
  static String get gpsLostBanner => _t(
        'GPS-signaal zwak. Locatie wordt mogelijk niet bijgewerkt.',
        en: 'GPS signal weak. Location may not be updating.',
        es: 'Señal GPS débil. La ubicación puede no actualizarse.',
        ar: 'إشارة GPS ضعيفة. قد لا يتم تحديث الموقع.',
      );
  static String get nearPickupAssistBanner => _t(
        'Je bent bijna bij het ophaalpunt — bevestig aankomst wanneer je er bent.',
        en: 'You\'re almost at the pickup point — confirm arrival when you arrive.',
        es: 'Casi en el punto de recogida — confirma la llegada cuando llegues.',
        ar: 'أنت تقريبا عند نقطة الالتقاط — أكد الوصول عند وصولك.',
      );
  static String get nearDestinationAssistBanner => _t(
        'Je bent bijna op de bestemming — voltooi de rit wanneer je veilig kunt stoppen.',
        en: 'You\'re almost at the destination — complete the ride when you can safely stop.',
        es: 'Casi en el destino — completa el viaje cuando puedas parar con seguridad.',
        ar: 'أنت تقريبا عند الوجهة — أكمل الرحلة عندما يمكنك التوقف بأمان.',
      );
  static String get sessionRevokedTitle => _t(
        'Ingelogd op een ander apparaat',
        en: 'Signed in on another device',
        es: 'Sesión iniciada en otro dispositivo',
        ar: 'تم تسجيل الدخول على جهاز آخر',
      );
  static String get sessionRevokedBody => _t(
        'Je bent uitgelogd omdat er op een ander apparaat is ingelogd. Log opnieuw in op dit apparaat als dat de juiste is.',
        en: 'You\'ve been logged out because another device logged in. Log in again on this device if it\'s the right one.',
        es: 'Has sido desconectado porque otro dispositivo inició sesión. Inicia sesión de nuevo en este dispositivo si es el correcto.',
        ar: 'تم تسجيل خروجك لأن جهازا آخر سجل الدخول. سجل الدخول مرة أخرى على هذا الجهاز إذا كان الصحيح.',
      );
  static String get sessionRevokedCta => _t(
        'Naar inloggen',
        en: 'Go to sign in',
        es: 'Ir a iniciar sesión',
        ar: 'الذهاب لتسجيل الدخول',
      );
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
  static String get goOnlineGuidanceSubtitle => _t(
        'Rond elke stap hieronder af en probeer daarna opnieuw online te gaan.',
        en: 'Complete each step below then try going online again.',
        es: 'Completa cada paso a continuación e inténtalo de nuevo para conectarte.',
        ar: 'أكمل كل خطوة أدناه ثم حاول الاتصال مرة أخرى.',
      );
  static String goOnlineGuidanceProgress(int pct) =>
      _t('Je bent $pct% onderweg',
          en: 'You\'re $pct% on your way',
          es: 'Vas $pct% en camino',
          ar: 'أنت $pct% في الطريق');
  static String get goOnlineGuidanceOpenAction => _t(
        'Oplossen',
        en: 'Resolve',
        es: 'Resolver',
        ar: 'حل',
      );
  static String get goOnlineGuidanceViewAll => _t(
        'Alle vereisten bekijken',
        en: 'View all requirements',
        es: 'Ver todos los requisitos',
        ar: 'عرض جميع المتطلبات',
      );
  static String get goOnlineGuidanceClose => _t(
        'Begrepen',
        en: 'Got it',
        es: 'Entendido',
        ar: 'فهمت',
      );

  // Rate profiles / Driver Hub
  static String get activeRates => _t(
        'Actieve tarieven',
        en: 'Active rates',
        es: 'Tarifas activas',
        ar: 'الأسعار النشطة',
      );
  static String get activeRateProfile => _t(
        'Actief tariefprofiel',
        en: 'Active rate profile',
        es: 'Perfil de tarifa activo',
        ar: 'ملف التعرفة النشط',
      );
  static String get manageProfiles => _t(
        'Profielen beheren',
        en: 'Manage profiles',
        es: 'Gestionar perfiles',
        ar: 'إدارة الملفات',
      );
  static String get editTariffs => _t(
        'Tarieven bewerken',
        en: 'Edit tariffs',
        es: 'Editar tarifas',
        ar: 'تعديل الأسعار',
      );
  static String get editTariffsHint => _t(
        'Volledig scherm voor alle tariefprijzen.',
        en: 'Full screen for all fare prices.',
        es: 'Pantalla completa para todos los precios de tarifa.',
        ar: 'شاشة كاملة لجميع أسعار الأجرة.',
      );
  static String get active => _t(
        'Actief',
        en: 'Active',
        es: 'Activo',
        ar: 'نشط',
      );
  static String get notSet => _t(
        'Not set',
        en: 'Not set',
        es: 'No establecido',
        ar: 'غير محدد',
      );
  static String get rateProfileHint => _t(
        'Kies het profiel dat je nu wilt gebruiken.',
        en: 'Choose the profile you want to use now.',
        es: 'Elige el perfil que quieres usar ahora.',
        ar: 'اختر الملف الشخصي الذي تريد استخدامه الآن.',
      );
  static String get standardProfileOnlyHint => _t(
        'Je hebt nu alleen Standaard. Voeg profielen toe om per dagdeel te wisselen.',
        en: 'You currently only have Standard. Add profiles to switch by time of day.',
        es: 'Ahora solo tienes Estándar. Añade perfiles para cambiar por franja horaria.',
        ar: 'لديك فقط القياسي حاليا. أضف ملفات شخصية للتبديل حسب وقت اليوم.',
      );
  static String get tariffQuickSwitch => _t(
        'Snel tarief wisselen',
        en: 'Quick tariff switch',
        es: 'Cambio rápido de tarifa',
        ar: 'تبديل سريع للتعرفة',
      );
  static String get morningTariff => _t(
        'Ochtendtarief',
        en: 'Morning tariff',
        es: 'Tarifa de mañana',
        ar: 'تعرفة الصباح',
      );
  static String get eveningTariff => _t(
        'Avondtarief',
        en: 'Evening tariff',
        es: 'Tarifa de tarde',
        ar: 'تعرفة المساء',
      );
  static String get lateNightTariff => _t(
        'Nachtarief',
        en: 'Late night tariff',
        es: 'Tarifa nocturna',
        ar: 'تعرفة الليل',
      );
  static String get standardTariff => _t(
        'Standaardtarief',
        en: 'Standard tariff',
        es: 'Tarifa estándar',
        ar: 'التعرفة القياسية',
      );
  static String get defaultRates => _t(
        'Standaardtarieven',
        en: 'Default rates',
        es: 'Tarifas predeterminadas',
        ar: 'الأسعار الافتراضية',
      );
  static String get tariffSuffix => _t(
        'tarief',
        en: 'tariff',
        es: 'tarifa',
        ar: 'تعرفة',
      );
  static String get dayShift => _t(
        'Dagdienst',
        en: 'Day shift',
        es: 'Turno de día',
        ar: 'وردية نهارية',
      );
  static String get peakHours => _t(
        'Spitsuren',
        en: 'Peak hours',
        es: 'Horas pico',
        ar: 'ساعات الذروة',
      );
  static String get afterDark => _t(
        'Na zonsondergang',
        en: 'After sunset',
        es: 'Después del atardecer',
        ar: 'بعد غروب الشمس',
      );
  static String get createDayPartProfiles => _t(
        'Ochtend, avond & nacht instellen',
        en: 'Set up morning, evening & night',
        es: 'Configurar mañana, tarde y noche',
        ar: 'إعداد الصباح والمساء والليل',
      );
  static String get creatingDayPartProfiles => _t(
        'Profielen instellen…',
        en: 'Setting up profiles…',
        es: 'Configurando perfiles…',
        ar: 'جاري إعداد الملفات…',
      );
  static String get manageProfilesHint => _t(
        'Open het tabblad Werk om alle profielen te beheren.',
        en: 'Open the Work tab to manage all profiles.',
        es: 'Abre la pestaña Trabajo para gestionar todos los perfiles.',
        ar: 'افتح علامة تبويب العمل لإدارة جميع الملفات الشخصية.',
      );
  static String get tariffEditorTitle => _t(
        'Tarieveneditor',
        en: 'Tariff editor',
        es: 'Editor de tarifas',
        ar: 'محرر الأسعار',
      );
  static String get tariffEditorSubtitle => _t(
        'Stel prijzen per tarief in en sla globaal op.',
        en: 'Set prices per tariff and save globally.',
        es: 'Configura precios por tarifa y guarda globalmente.',
        ar: 'حدد الأسعار لكل تعريفة واحفظ عالميا.',
      );
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
  static String get initialTariffWaitingRate => _t(
        'Wachttarief per minuut',
        en: 'Wait time price',
        es: 'Precio por tiempo de espera',
        ar: 'سعر وقت الانتظار',
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
  static String get tariffSuggestionCardTitle => _t(
        'Voorgestelde tarieven per dagdeel',
        en: 'Suggested tariffs by time of day',
        es: 'Tarifas sugeridas por franja horaria',
        ar: 'تعريفات مقترحة حسب وقت اليوم',
      );
  static String get tariffSuggestionCardBody => _t(
        'Je mist nog profielen voor ochtend, avond en/of nacht. Tik op de knop hieronder om die toe te voegen met voorstellen op basis van je standaardtarief. Pas daarna gerust elk bedrag aan.',
        en: 'You\'re still missing profiles for morning, evening and/or night. Tap the button below to add them with suggestions based on your standard tariff. Then adjust any amount as you like.',
        es: 'Todavía te faltan perfiles para mañana, tarde y/o noche. Toca el botón de abajo para añadirlos con sugerencias basadas en tu tarifa estándar. Luego ajusta cualquier importe.',
        ar: 'لا يزال ينقصك ملفات شخصية للصباح والمساء و/أو الليل. انقر على الزر أدناه لإضافتها مع اقتراحات مبنية على تعريفتك القياسية. ثم اضبط أي مبلغ كما تريد.',
      );
  static String get tariffSuggestionCardButton => _t(
        'Voorgestelde tarieven toevoegen',
        en: 'Add suggested tariffs',
        es: 'Añadir tarifas sugeridas',
        ar: 'إضافة التعريفات المقترحة',
      );
  static String get activeTariffPricing => _t(
        'Actieve tariefprijzen',
        en: 'Active tariff pricing',
        es: 'Precios de la tarifa activa',
        ar: 'أسعار التعرفة النشطة',
      );
  static String get waitPerMin => _t(
        'Wacht / min',
        en: 'Wait / min',
        es: 'Espera / min',
        ar: 'الانتظار / دقيقة',
      );
  static String get saveAllTariffs => _t(
        'Alle tarieven opslaan',
        en: 'Save all tariffs',
        es: 'Guardar todas las tarifas',
        ar: 'حفظ جميع الأسعار',
      );
  static String get savingTariffs => _t(
        'Tarieven opslaan…',
        en: 'Saving tariffs…',
        es: 'Guardando tarifas…',
        ar: 'جاري حفظ الأسعار…',
      );
  static String get tariffsSaved => _t(
        'Tarieven opgeslagen.',
        en: 'Tariffs saved.',
        es: 'Tarifas guardadas.',
        ar: 'تم حفظ الأسعار.',
      );
  static String get tariffsSaveFailed => _t(
        'Tarieven opslaan mislukt. Probeer opnieuw.',
        en: 'Failed to save tariffs. Try again.',
        es: 'Error al guardar tarifas. Inténtalo de nuevo.',
        ar: 'فشل حفظ التعريفات. حاول مرة أخرى.',
      );
  static String get viewYourEarnings => _t(
        'Bekijk je verdiensten',
        en: 'View your earnings',
        es: 'Ver tus ganancias',
        ar: 'عرض أرباحك',
      );
  static String get closeRateModalHint => _t(
        'Veeg omhoog of tik op X om te sluiten',
        en: 'Swipe up or tap X to close',
        es: 'Desliza hacia arriba o toca X para cerrar',
        ar: 'اسحب للأعلى أو انقر على X للإغلاق',
      );
  static String get manageRates => _t(
        'Tarieven beheren',
        en: 'Manage rates',
        es: 'Gestionar tarifas',
        ar: 'إدارة الأسعار',
      );
  static String get driverHub => _t(
        'Driver Hub',
        en: 'Driver Hub',
        es: 'Centro del conductor',
        ar: 'مركز السائق',
      );
  static String get driverHubHomeSubtitle => _t(
        'Manage your taxi business',
        en: 'Manage your taxi business',
        es: 'Gestiona tu negocio de taxi',
        ar: 'أدر عملك في التاكسي',
      );
  static String get driverHubCurrentTariff => _t(
        'Current tariff',
        en: 'Current tariff',
        es: 'Tarifa actual',
        ar: 'التعرفة الحالية',
      );
  static String get driverHubToday => _t(
        'Today',
        en: 'Today',
        es: 'Hoy',
        ar: 'اليوم',
      );
  static String get driverHubBusinessControls => _t(
        'Business controls',
        en: 'Business controls',
        es: 'Controles de negocio',
        ar: 'ضوابط العمل',
      );
  static String get driverHubBusinessControlsHint => _t(
        'Voorkeuren, beschikbaarheid en ritinstellingen',
        en: 'Preferences, availability, and ride settings',
        es: 'Preferencias, disponibilidad y ajustes de viaje',
        ar: 'التفضيلات والتوافر وإعدادات الرحلة',
      );
  static String get driverHubReturnModeHint => _t(
        'Return Mode-afstand en korting live op de Home-kaart.',
        en: 'Return Mode distance and discount live on the Home card.',
        es: 'Distancia y descuento de Return Mode en vivo en la tarjeta Home.',
        ar: 'مسافة وخصم Return Mode مباشرة على بطاقة Home.',
      );
  static String get recenterMap => _t(
        'My location',
        en: 'My location',
        es: 'Mi ubicación',
        ar: 'موقعي',
      );
  static String get mapDemandHigh => _t(
        'High demand',
        en: 'High demand',
        es: 'Alta demanda',
        ar: 'طلب مرتفع',
      );
  static String get mapDemandActive => _t(
        'Active demand',
        en: 'Active demand',
        es: 'Demanda activa',
        ar: 'طلب نشط',
      );
  static String mapDemandWaiting(int n) => _t(
        '$n wachtend',
        en: '$n waiting',
        es: '$n esperando',
        ar: '$n ينتظرون',
      );
  static String mapEtaMinutes(int min) =>
      _t('$min min', en: '$min min', es: '$min min', ar: '$min دقيقة');
  static String get mapEtaPickup => _t(
        'Pickup',
        en: 'Pickup',
        es: 'Recogida',
        ar: 'الالتقاط',
      );
  static String get driverHubSubtitle => _t(
        'Beheer je doelen, tarieven en veiligheid.',
        en: 'Manage your goals, tariffs, and safety.',
        es: 'Gestiona tus objetivos, tarifas y seguridad.',
        ar: 'أدر أهدافك وتعريفاتك وسلامتك.',
      );
  static String get goalsSectionTitle => _t(
        'Goals',
        en: 'Goals',
        es: 'Objetivos',
        ar: 'الأهداف',
      );
  static String get goalsSectionHelper => _t(
        'Stel een doel in en zie hoeveel je nog nodig hebt.',
        en: 'Set a goal and see how much more you need.',
        es: 'Establece un objetivo y ve cuánto más necesitas.',
        ar: 'حدد هدفا واعرف كم تحتاج أكثر.',
      );
  static String get earnedLabel => _t(
        'earned',
        en: 'earned',
        es: 'ganado',
        ar: 'مكتسب',
      );
  static String remainingToGoal(String amount) => _t('Nog €$amount tot je doel',
      en: '€$amount left to your goal',
      es: 'Faltan €$amount para tu objetivo',
      ar: 'بقى €$amount لهدفك');
  static String get setGoalButton => _t(
        'Doel instellen',
        en: 'Set goal',
        es: 'Establecer objetivo',
        ar: 'تحديد هدف',
      );
  static String get earningsTarget => _t(
        'Dagdoel',
        en: 'Daily target',
        es: 'Objetivo diario',
        ar: 'الهدف اليومي',
      );
  static String get setTarget => _t(
        'Doel instellen →',
        en: 'Set target →',
        es: 'Establecer objetivo →',
        ar: 'تحديد الهدف ←',
      );
  static String get daily => _t(
        'Dag',
        en: 'Daily',
        es: 'Diario',
        ar: 'يومي',
      );
  static String get weekly => _t(
        'Week',
        en: 'Weekly',
        es: 'Semanal',
        ar: 'أسبوعي',
      );
  static String get dailyLong => _t(
        'Dagelijks',
        en: 'Daily',
        es: 'Diario',
        ar: 'يومي',
      );
  static String get weeklyLong => _t(
        'Wekelijks',
        en: 'Weekly',
        es: 'Semanal',
        ar: 'أسبوعي',
      );
  static String get ratesSectionTitle => _t(
        'Jouw tarieven',
        en: 'Your rates',
        es: 'Tus tarifas',
        ar: 'أسعارك',
      );
  static String get ratesSectionHelper => _t(
        'Dit rekenen passagiers: start + per km + per minuut + wachten.',
        en: 'This is what passengers pay: start + per km + per minute + waiting.',
        es: 'Esto es lo que pagan los pasajeros: inicio + por km + por minuto + espera.',
        ar: 'هذا ما يدفعه الركاب: البداية + لكل كم + لكل دقيقة + الانتظار.',
      );
  static String get rateStart => _t(
        'Start',
        en: 'Start',
        es: 'Inicio',
        ar: 'البداية',
      );
  static String get ratePerKm => _t(
        'Per km',
        en: 'Per km',
        es: 'Por km',
        ar: 'لكل كم',
      );
  static String get ratePerMin => _t(
        'Per min',
        en: 'Per min',
        es: 'Por min',
        ar: 'لكل دقيقة',
      );
  static String get rateWaiting => _t(
        'Wachten',
        en: 'Waiting',
        es: 'Espera',
        ar: 'الانتظار',
      );
  static String get manageRatesLink => _t(
        'Tarieven beheren →',
        en: 'Manage rates →',
        es: 'Gestionar tarifas →',
        ar: 'إدارة الأسعار ←',
      );
  static String get safetySectionTitle => _t(
        'Veiligheid',
        en: 'Safety',
        es: 'Seguridad',
        ar: 'السلامة',
      );
  static String get call112 => _t(
        '112 bellen',
        en: 'Call 112',
        es: 'Llamar 112',
        ar: 'اتصل بـ 112',
      );
  static String get safetyToolkit => _t(
        'Veiligheidskit',
        en: 'Safety toolkit',
        es: 'Kit de seguridad',
        ar: 'أدوات السلامة',
      );
  static String get emergencyCall => _t(
        'Alarmnummer bellen',
        en: 'Call emergency number',
        es: 'Llamar emergencias',
        ar: 'اتصل بالطوارئ',
      );
  static String get emergencyCallSubtitle => _t(
        '112 — politie en ambulance',
        en: '112 — police and ambulance',
        es: '112 — policía y ambulancia',
        ar: '112 — الشرطة والإسعاف',
      );
  static String get shareTripDetails => _t(
        'Rit details delen',
        en: 'Share trip details',
        es: 'Compartir detalles del viaje',
        ar: 'مشاركة تفاصيل الرحلة',
      );
  static String get shareTripSubtitleActive => _t(
        'Deel je huidige rit',
        en: 'Share your current trip',
        es: 'Comparte tu viaje actual',
        ar: 'شارك رحلتك الحالية',
      );
  static String get shareTripSubtitleInactive => _t(
        'Beschikbaar tijdens actieve rit',
        en: 'Available during active ride',
        es: 'Disponible durante viaje activo',
        ar: 'متاح أثناء الرحلة النشطة',
      );
  static String get audioRecording => _t(
        'Audio opname',
        en: 'Audio recording',
        es: 'Grabación de audio',
        ar: 'تسجيل الصوت',
      );
  static String get audioRecordingSubtitleActive => _t(
        'Opname starten',
        en: 'Start recording',
        es: 'Iniciar grabación',
        ar: 'بدء التسجيل',
      );
  static String get audioRecordingSubtitleInactive => _t(
        'Beschikbaar tijdens actieve rit',
        en: 'Available during active ride',
        es: 'Disponible durante viaje activo',
        ar: 'متاح أثناء الرحلة النشطة',
      );
  static String get recordingInProgress => _t(
        'Opname loopt…',
        en: 'Recording in progress…',
        es: 'Grabando…',
        ar: 'جاري التسجيل…',
      );
  static String get helpSectionTitle => _t(
        'Hulp',
        en: 'Help',
        es: 'Ayuda',
        ar: 'المساعدة',
      );
  static String get chatWithSupport => _t(
        'Chat met ondersteuning',
        en: 'Chat with support',
        es: 'Chatear con soporte',
        ar: 'الدردشة مع الدعم',
      );
  static String get chatWithSupportHelper => _t(
        'We reageren meestal binnen enkele uren.',
        en: 'We usually respond within a few hours.',
        es: 'Normalmente respondemos en pocas horas.',
        ar: 'نرد عادة خلال ساعات قليلة.',
      );
  static String get recentTickets => _t(
        'Recente meldingen',
        en: 'Recent tickets',
        es: 'Tickets recientes',
        ar: 'التذاكر الأخيرة',
      );
  static String get helpAndSupport => _t(
        'Help & ondersteuning',
        en: 'Help & support',
        es: 'Ayuda y soporte',
        ar: 'المساعدة والدعم',
      );
  static String get supportContactSection => _t(
        'Contact',
        en: 'Contact',
        es: 'Contacto',
        ar: 'التواصل',
      );
  static String get seeAllTickets => _t(
        'Alles zien →',
        en: 'See all →',
        es: 'Ver todo →',
        ar: 'عرض الكل ←',
      );
  static String get sendMessage => _t(
        'Stuur een bericht',
        en: 'Send a message',
        es: 'Enviar un mensaje',
        ar: 'إرسال رسالة',
      );
  static String get messages => _t(
        'Berichten',
        en: 'Messages',
        es: 'Mensajes',
        ar: 'الرسائل',
      );
  static String get helpArticles => _t(
        'Help-artikelen',
        en: 'Help articles',
        es: 'Artículos de ayuda',
        ar: 'مقالات المساعدة',
      );
  static String get ticketStatusNoResponse => _t(
        'U heeft niet gereageerd',
        en: 'You have not responded',
        es: 'No has respondido',
        ar: 'لم تستجب',
      );
  static String get ticketStatusInProgress => _t(
        'In behandeling',
        en: 'In progress',
        es: 'En progreso',
        ar: 'قيد التقدم',
      );
  static String get ticketStatusResolved => _t(
        'Opgelost',
        en: 'Resolved',
        es: 'Resuelto',
        ar: 'تم الحل',
      );
  static String get save => _t(
        'Opslaan',
        en: 'Save',
        es: 'Guardar',
        ar: 'حفظ',
      );

  // Return trips
  static String get returnTrips => _t(
        'Taxi Terug',
        en: 'Taxi Terug',
        es: 'Taxi Terug',
        ar: 'Taxi Terug',
      );
  static String get returnMode => _t(
        'Taxi Terug',
        en: 'Taxi Terug',
        es: 'Taxi Terug',
        ar: 'Taxi Terug',
      );
  static String get returnModeOff => _t(
        'Uit',
        en: 'Off',
        es: 'Desactivado',
        ar: 'متوقف',
      );
  static String get returnModeOffBody => _t(
        'Op weg naar huis? Verdien onderweg met Taxi Terug.',
        en: 'Heading home? Earn on the way with Taxi Terug.',
        es: '¿Vuelves a casa? Gana en el camino con Taxi Terug.',
        ar: 'هل تتجه إلى المنزل؟ اربح في الطريق مع Taxi Terug.',
      );
  static String returnModeHeadingTo(String destination) => _t(
        'Richting $destination',
        en: 'Heading to $destination',
        es: 'Hacia $destination',
        ar: 'متجه إلى $destination',
      );
  static String returnModeActiveBody({
    required double pickupRadiusKm,
  }) =>
      _t(
        'Ophaalradius ${pickupRadiusKm.toStringAsFixed(0)} km',
        en: 'Pickup radius ${pickupRadiusKm.toStringAsFixed(0)} km',
        es: 'Radio de recogida ${pickupRadiusKm.toStringAsFixed(0)} km',
        ar: 'نطاق الالتقاط ${pickupRadiusKm.toStringAsFixed(0)} كم',
      );
  static String get returnModeNoMatchesYet => _t(
        'Nog geen Taxi Terug ritten. We blijven zoeken terwijl u rijdt.',
        en: "No Taxi Terug rides yet. We'll keep looking while you drive.",
        es: 'Aún no hay viajes Taxi Terug. Seguiremos buscando mientras conduces.',
        ar: 'لا توجد رحلات Taxi Terug بعد. سنواصل البحث أثناء قيادتك.',
      );
  static String returnModeAvailableCount(int count) => _t(
        '$count Taxi Terug ritten beschikbaar',
        en: '$count Taxi Terug rides available',
        es: '$count viajes Taxi Terug disponibles',
        ar: '$count رحلات Taxi Terug متاحة',
      );
  static String get returnModeActivate => _t(
        'Activeren',
        en: 'Activate',
        es: 'Activar',
        ar: 'تفعيل',
      );
  static String get returnModeActivateFull => _t(
        'Taxi Terug activeren',
        en: 'Activate Taxi Terug',
        es: 'Activar Taxi Terug',
        ar: 'تفعيل Taxi Terug',
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
  static String get returnModeDisableTitle => _t(
        'Taxi Terug uitschakelen?',
        en: 'Turn off Taxi Terug?',
        es: '¿Desactivar Taxi Terug?',
        ar: 'إيقاف Taxi Terug؟',
      );
  static String get returnModeDisableBody => _t(
        'U ontvangt geen nieuwe Taxi Terug-matches meer voor deze reis. Bevestigde ritten blijven staan.',
        en: 'You will stop receiving new Taxi Terug matches for this journey. Confirmed rides stay in place.',
        es: 'Dejarás de recibir nuevas coincidencias de Taxi Terug para este viaje. Los viajes confirmados se mantienen.',
        ar: 'ستتوقف عن تلقي مطابقات Taxi Terug الجديدة لهذه الرحلة. تبقى الرحلات المؤكدة كما هي.',
      );
  static String get returnModeDisableConfirm => _t(
        'Uitschakelen',
        en: 'Turn off',
        es: 'Desactivar',
        ar: 'إيقاف',
      );
  static String get journeyIntentDeparturePassed => _t(
        'Kies een vertrektijd in de toekomst.',
        en: 'Choose a departure time in the future.',
        es: 'Elige una hora de salida futura.',
        ar: 'اختر وقت مغادرة في المستقبل.',
      );
  static String get returnModeActivationFailed => _t(
        'Taxi Terug kon niet worden geactiveerd.',
        en: 'Taxi Terug could not be activated.',
        es: 'No se pudo activar Taxi Terug.',
        ar: 'تعذر تفعيل Taxi Terug.',
      );
  static String returnModeDestinationCooldown(int hours) => _t(
        'Bestemming kan over $hours uur opnieuw worden gewijzigd.',
        en: 'Destination can be changed again in $hours hours.',
        es: 'El destino se puede cambiar de nuevo en $hours horas.',
        ar: 'يمكن تغيير الوجهة مرة أخرى خلال $hours ساعة.',
      );
  static String returnModeDailyDestinationLimit(int maxPerDay) => _t(
        'Maximaal $maxPerDay bestemmingswijzigingen per dag.',
        en: 'Maximum $maxPerDay destination changes per day.',
        es: 'Máximo $maxPerDay cambios de destino por día.',
        ar: 'حد أقصى $maxPerDay تغييرات للوجهة يومياً.',
      );
  static String get returnModeMissingDestination => _t(
        'Stel eerst uw thuisbestemming in.',
        en: 'Set your home destination first.',
        es: 'Configura primero tu destino de casa.',
        ar: 'حدد وجهة منزلك أولاً.',
      );
  static String get returnModeDriverNotFound => _t(
        'Chauffeursprofiel niet gevonden. Log opnieuw in of rond onboarding af.',
        en: 'Driver profile not found. Sign in again or finish onboarding.',
        es: 'Perfil de conductor no encontrado. Inicia sesión de nuevo o completa el registro.',
        ar: 'لم يتم العثور على ملف السائق. سجّل الدخول مرة أخرى أو أكمل التسجيل.',
      );
  static String get returnModeBackendNotReady => _t(
        'Taxi Terug is nog niet beschikbaar op de server. Probeer later opnieuw.',
        en: 'Taxi Terug is not available on the server yet. Try again later.',
        es: 'Taxi Terug aún no está disponible en el servidor. Inténtalo más tarde.',
        ar: 'Taxi Terug غير متاح على الخادم بعد. حاول مرة أخرى لاحقاً.',
      );
  static String returnModeKmFromHome(double km) => _t(
        '$km km van huis',
        en: '$km km from home',
        es: '$km km de casa',
        ar: '$km كم من المنزل',
      );
  static String returnModeSuggestBody(double km, String destination) => _t(
        'U bent $km km van $destination. Activeer Taxi Terug om ritten mee te nemen.',
        en: 'You are $km km from $destination. Activate Taxi Terug to pick up rides on the way.',
        es: 'Estás a $km km de $destination. Activa Taxi Terug para recoger viajes de camino.',
        ar: 'أنت على بعد $km كم من $destination. فعّل Taxi Terug لالتقاط الرحلات في الطريق.',
      );
  static String get returnModeHeadingHomeTitle => _t(
        'Taxi Terug?',
        en: 'Taxi Terug?',
        es: '¿Taxi Terug?',
        ar: 'Taxi Terug؟',
      );
  static String returnModeHeadingHomeBody(String destination) => _t(
        'We zoeken ritten richting $destination terwijl u rijdt.',
        en: 'We can find rides toward $destination while you drive.',
        es: 'Buscamos viajes hacia $destination mientras conduces.',
        ar: 'نبحث عن رحلات باتجاه $destination أثناء قيادتك.',
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
  static String get yourReturnDiscount => _t(
        'Jouw retourkorting',
        en: 'Your return discount',
        es: 'Tu descuento de retorno',
        ar: 'خصم عودتك',
      );
  static String get returnDiscountSharedCosts => _t(
        'Reiskosten gedeeld met passagier',
        en: 'Travel costs shared with passenger',
        es: 'Costos de viaje compartidos con el pasajero',
        ar: 'تكاليف السفر المشتركة مع الراكب',
      );
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

  static String get accept => _t(
        'Accepteren',
        en: 'Accept',
        es: 'Aceptar',
        ar: 'قبول',
      );

  // Status timestamps
  static String get onlineSince => _t(
        'Online · sinds',
        en: 'Online · since',
        es: 'En línea · desde',
        ar: 'متصل · منذ',
      );
  static String get onBreakSince => _t(
        'Pauze · sinds',
        en: 'Break · since',
        es: 'Descanso · desde',
        ar: 'استراحة · منذ',
      );

  // Support chat (our additions)
  static String get ondersteuning => _t(
        'Support',
        en: 'Support',
        es: 'Soporte',
        ar: 'الدعم',
      );
  static String get nieuwBericht => _t(
        'New message',
        en: 'New message',
        es: 'Nuevo mensaje',
        ar: 'رسالة جديدة',
      );
  static String get berichten => _t(
        'Messages',
        en: 'Messages',
        es: 'Mensajes',
        ar: 'الرسائل',
      );
  static String get helpArtikelen => _t(
        'Help articles',
        en: 'Help articles',
        es: 'Artículos de ayuda',
        ar: 'مقالات المساعدة',
      );
  static String get veelgesteldeVragen => _t(
        'Frequently asked questions',
        en: 'Frequently asked questions',
        es: 'Preguntas frecuentes',
        ar: 'الأسئلة الشائعة',
      );
  static String get recenteRitten => _t(
        'Recent rides with issues',
        en: 'Recent rides with issues',
        es: 'Viajes recientes con problemas',
        ar: 'رحلات حديثة بها مشاكل',
      );
  static String get alleZien => _t(
        'See all',
        en: 'See all',
        es: 'Ver todo',
        ar: 'عرض الكل',
      );
  static String get versturen => _t(
        'Send',
        en: 'Send',
        es: 'Enviar',
        ar: 'إرسال',
      );
  static String get geenBerichten => _t(
        'No messages',
        en: 'No messages',
        es: 'Sin mensajes',
        ar: 'لا توجد رسائل',
      );
  static String get berichtTypen => _t(
        'Type a message…',
        en: 'Type a message…',
        es: 'Escribe un mensaje…',
        ar: 'اكتب رسالة…',
      );
  static String get supportChatSendFailed => _t(
        'Bericht kon niet worden verstuurd. Probeer opnieuw.',
        en: 'Message could not be sent. Try again.',
        es: 'No se pudo enviar el mensaje. Inténtalo de nuevo.',
        ar: 'تعذر إرسال الرسالة. حاول مرة أخرى.',
      );
  static String get supportChatOfflineSaved => _t(
        'Je bericht is opgeslagen. De assistent is offline — de ondersteuning kan het nog steeds lezen.',
        en: 'Your message has been saved. The assistant is offline — support can still read it.',
        es: 'Tu mensaje ha sido guardado. El asistente está sin conexión — el soporte aún puede leerlo.',
        ar: 'تم حفظ رسالتك. المساعد غير متصل — لا يزال الدعم قادرا على قراءتها.',
      );
  static String get supportAiAssistantName => _t(
        'Lee',
        en: 'Lee',
        es: 'Lee',
        ar: 'لي',
      );
  static String get supportAiConsentTitle => _t(
        'Maak kennis met Lee, je AI-ondersteuningsassistent',
        en: 'Meet Lee, your AI support assistant',
        es: 'Conoce a Lee, tu asistente de soporte IA',
        ar: 'تعرف على Lee، مساعد الدعم بالذكاء الاصطناعي',
      );
  static String get supportAiConsentIntro => _t(
        'Lee is de AI-klantenserviceassistent van HeyCaby voor chauffeurs. Hij helpt bij eenvoudige ondersteuningsvragen en klachten.',
        en: 'Lee is HeyCaby\'s AI customer service assistant for drivers. Helps with simple support questions and complaints.',
        es: 'Lee es el asistente de servicio al cliente por IA de HeyCaby para conductores. Ayuda con preguntas simples de soporte y quejas.',
        ar: 'Lee هو مساعد خدمة العملاء بالذكاء الاصطناعي من HeyCaby للسائقين. يساعد في أسئلة الدعم البسيطة والشكاوى.',
      );
  static String get supportAiConsentDataSent => _t(
        'Om je te helpen sturen we: je bericht, ticketcategorie en beperkte accountcontext die nodig is voor een antwoord.',
        en: 'To help you we send: your message, ticket category and limited account context needed for a response.',
        es: 'Para ayudarte enviamos: tu mensaje, categoría de ticket y contexto limitado de cuenta necesario para responder.',
        ar: 'لمساعدتك نرسل: رسالتك وفئة التذكرة وسياق حساب محدود ضروري للرد.',
      );
  static String get supportAiConsentThirdParty => _t(
        'AI-verwerking: Lee gebruikt OpenAI (ChatGPT)-modellen om antwoorden te genereren.',
        en: 'AI processing: Lee uses OpenAI (ChatGPT) models to generate responses.',
        es: 'Procesamiento IA: Lee usa modelos OpenAI (ChatGPT) para generar respuestas.',
        ar: 'معالجة الذكاء الاصطناعي: يستخدم Lee نماذج OpenAI (ChatGPT) لإنشاء الردود.',
      );
  static String get supportAiConsentPolicy => _t(
        'Bij serieuze of gevoelige kwesties: deel geen privégegevens in AI-chat. Mail de ondersteuning via hello@heycaby.nl.',
        en: 'For serious or sensitive issues: don\'t share private data in AI chat. Email support at hello@heycaby.nl.',
        es: 'Para temas serios o sensibles: no compartas datos privados en chat IA. Escribe a soporte a hello@heycaby.nl.',
        ar: 'للقضايا الجادة أو الحساسة: لا تشارك بيانات خاصة في دردشة الذكاء الاصطناعي. راسل الدعم على hello@heycaby.nl.',
      );
  static String get supportAiConsentEmailOption => _t(
        'Deel geen wachtwoorden, volledige betaalkaartnummers, overheids-ID\'s of andere zeer gevoelige gegevens in AI-chat.',
        en: 'Don\'t share passwords, full payment card numbers, government IDs or other highly sensitive data in AI chat.',
        es: 'No compartas contraseñas, números completos de tarjetas, IDs gubernamentales u otros datos muy sensibles en chat IA.',
        ar: 'لا تشارك كلمات المرور أو أرقام بطاقات الدفع الكاملة أو الهويات الحكومية أو البيانات الحساسة جدا في دردشة الذكاء الاصطناعي.',
      );
  static String get supportAiConsentCheckbox => _t(
        'Ik begrijp welke gegevens worden gedeeld, wie ze verwerkt, en geef HeyCaby toestemming om deze ondersteuningschatgegevens te delen met Lee AI-ondersteuning.',
        en: 'I understand what data is shared, who processes it, and give HeyCaby permission to share this support chat data with Lee AI support.',
        es: 'Entiendo qué datos se comparten, quién los procesa, y doy permiso a HeyCaby para compartir estos datos de chat de soporte con Lee AI support.',
        ar: 'أفهم البيانات التي تتم مشاركتها ومن يعالجها، وأأذن لـ HeyCaby بمشاركة بيانات دردشة الدعم هذه مع Lee AI support.',
      );
  static String get supportAiConsentContinue => _t(
        'Ik ga akkoord en ga verder',
        en: 'I agree and continue',
        es: 'Estoy de acuerdo y continúo',
        ar: 'أوافق وأتابع',
      );
  static String get supportAiConsentSendEmail => _t(
        'Stuur liever een e-mail',
        en: 'Send an email instead',
        es: 'Enviar un correo en su lugar',
        ar: 'إرسال بريد إلكتروني بدلا من ذلك',
      );
  static String get ritProbleem => _t(
        'Rit probleem',
        en: 'Ride problem',
        es: 'Problema de viaje',
        ar: 'مشكلة رحلة',
      );
  static String get betaling => _t(
        'Betaling',
        en: 'Payment',
        es: 'Pago',
        ar: 'الدفع',
      );
  static String get account => _t(
        'Account',
        en: 'Account',
        es: 'Cuenta',
        ar: 'الحساب',
      );
  static String get overige => _t(
        'Overige',
        en: 'Other',
        es: 'Otros',
        ar: 'أخرى',
      );
  static String get open => _t(
        'Open',
        en: 'Open',
        es: 'Abrir',
        ar: 'فتح',
      );
  static String get notificationOpenAction => _t(
        'Openen',
        en: 'Open',
        es: 'Abrir',
        ar: 'فتح',
      );

  // Profile settings
  static String get mijnVoertuig => _t(
        'Mijn voertuig',
        en: 'My vehicle',
        es: 'Mi vehículo',
        ar: 'مركبتي',
      );
  static String get documenten => _t(
        'Documenten',
        en: 'Documents',
        es: 'Documentos',
        ar: 'المستندات',
      );
  static String get werkgebied => _t(
        'Werkgebied',
        en: 'Work area',
        es: 'Zona de trabajo',
        ar: 'منطقة العمل',
      );
  static String get taal => _t(
        'Taal',
        en: 'Language',
        es: 'Idioma',
        ar: 'اللغة',
      );
  static String get thema => _t(
        'Thema',
        en: 'Theme',
        es: 'Tema',
        ar: 'السمة',
      );
  static String get meldingen => _t(
        'Meldingen',
        en: 'Notifications',
        es: 'Notificaciones',
        ar: 'الإشعارات',
      );
  static String get privacyBeleid => _t(
        'Privacy beleid',
        en: 'Privacy policy',
        es: 'Política de privacidad',
        ar: 'سياسة الخصوصية',
      );
  static String get gebruiksvoorwaarden => _t(
        'Gebruiksvoorwaarden',
        en: 'Terms of service',
        es: 'Términos de servicio',
        ar: 'شروط الخدمة',
      );

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
  static String get termsOfService => _t(
        'Gebruiksvoorwaarden',
        en: 'Terms of service',
        es: 'Términos de servicio',
        ar: 'شروط الخدمة',
      );
  static String get privacyPolicy => _t(
        'Privacy beleid',
        en: 'Privacy policy',
        es: 'Política de privacidad',
        ar: 'سياسة الخصوصية',
      );
  static String get indemnification => _t(
        'Vrijwaring',
        en: 'Indemnification',
        es: 'Indemnización',
        ar: 'التعويض',
      );
  static String get copiedToClipboard => _t(
        'Gekopieerd naar klembord',
        en: 'Copied to clipboard',
        es: 'Copiado al portapapeles',
        ar: 'تم النسخ إلى الحافظة',
      );
  static String get actionFailedPrefix => _t(
        'Mislukt:',
        en: 'Failed:',
        es: 'Error:',
        ar: 'فشل:',
      );
  static String get requestsResumed => _t(
        'Nieuwe aanvragen hervat.',
        en: 'New requests resumed.',
        es: 'Solicitudes reanudadas.',
        ar: 'تم استئناف الطلبات الجديدة.',
      );
  static String get requestsPaused => _t(
        'Nieuwe aanvragen gepauzeerd.',
        en: 'New requests paused.',
        es: 'Solicitudes pausadas.',
        ar: 'تم إيقاف الطلبات الجديدة.',
      );
  static String get requestStatusUpdateFailed => _t(
        'Aanvraagstatus bijwerken mislukt:',
        en: 'Failed to update request status:',
        es: 'Error al actualizar estado de solicitud:',
        ar: 'فشل تحديث حالة الطلب:',
      );
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
  static String get riderCancelledTitle => _t(
        'Reiziger heeft geannuleerd',
        en: 'Rider has cancelled',
        es: 'El pasajero ha cancelado',
        ar: 'ألغى الراكب',
      );
  static String get riderCancelledBody => _t(
        'De reiziger heeft deze rit geannuleerd. Je bent weer beschikbaar voor nieuwe ritten.',
        en: 'The rider cancelled this ride. You\'re available for new rides again.',
        es: 'El pasajero canceló este viaje. Estás disponible para nuevos viajes de nuevo.',
        ar: 'ألغى الراكب هذه الرحلة. أنت متاح لرحلات جديدة مرة أخرى.',
      );
  static String get riderCancelledCta => _t(
        'Terug naar home',
        en: 'Back to home',
        es: 'Volver al inicio',
        ar: 'العودة للرئيسية',
      );
  static String get rideCancelFailed => _t(
        'Rit annuleren mislukt:',
        en: 'Cancel ride failed:',
        es: 'Error al cancelar viaje:',
        ar: 'فشل إلغاء الرحلة:',
      );
  static String get pickupCoordinatesUnavailable => _t(
        'Ophaalcoördinaten niet beschikbaar.',
        en: 'Pickup coordinates unavailable.',
        es: 'Coordenadas de recogida no disponibles.',
        ar: 'إحداثيات الالتقاط غير متاحة.',
      );
  static String get destinationCoordinatesUnavailable => _t(
        'Bestemmingscoördinaten niet beschikbaar.',
        en: 'Destination coordinates unavailable.',
        es: 'Coordenadas de destino no disponibles.',
        ar: 'إحداثيات الوجهة غير متاحة.',
      );
  static String get noNavigationAppAvailable => _t(
        'Geen navigatie-app beschikbaar.',
        en: 'No navigation app available.',
        es: 'No hay app de navegación disponible.',
        ar: 'لا يوجد تطبيق ملاحة متاح.',
      );
  static String get noShowReported => _t(
        'No-show gemeld.',
        en: 'No-show reported.',
        es: 'No-show reportado.',
        ar: 'تم الإبلاغ عن عدم الحضور.',
      );
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
  static String get acceptRideFailedCode => _t(
        'Accepteren mislukt:',
        en: 'Accept failed:',
        es: 'Error al aceptar:',
        ar: 'فشل القبول:',
      );
  static String get acceptRideFailed => _t(
        'Rit accepteren mislukt:',
        en: 'Accept ride failed:',
        es: 'Error al aceptar viaje:',
        ar: 'فشل قبول الرحلة:',
      );
  static String get rideActionFailedMessage => _t(
        'Actie mislukt. Controleer je verbinding en probeer opnieuw.',
        en: 'Action failed. Check your connection and try again.',
        es: 'La acción falló. Revisa tu conexión e inténtalo de nuevo.',
        ar: 'فشل الإجراء. تحقق من اتصالك وحاول مرة أخرى.',
      );

  static String rideLifecycleErrorMessage(String code) {
    final normalized = code.split(':').first.trim();
    switch (normalized) {
      case 'too_far_from_pickup':
        return _t(
          'Je bent te ver van het ophaalpunt (max. 500 m). Rijd dichterbij en tik opnieuw op Ik ben gearriveerd.',
          en: 'You\'re too far from the pickup (max 500 m). Move closer, then tap I\'ve arrived again.',
          es: 'Estás demasiado lejos del punto de recogida (máx. 500 m). Acércate y pulsa He llegado de nuevo.',
          ar: 'أنت بعيد جدا عن نقطة الالتقاط (500 م كحد أقصى). اقترب ثم اضغط وصلت مرة أخرى.',
        );
      case 'invalid_transition':
        return _t(
          'Deze actie is nu niet mogelijk voor deze rit. Vernieuw het scherm en probeer opnieuw.',
          en: 'This action is not available for this ride right now. Refresh the screen and try again.',
          es: 'Esta acción no está disponible para este viaje ahora. Actualiza la pantalla e inténtalo de nuevo.',
          ar: 'هذا الإجراء غير متاح لهذه الرحلة الآن. حدّث الشاشة وحاول مرة أخرى.',
        );
      case 'not_a_driver':
        return _t(
          'Je chauffeursprofiel kon niet worden gevonden. Log opnieuw in.',
          en: 'Your driver profile could not be found. Sign in again.',
          es: 'No se encontró tu perfil de conductor. Inicia sesión de nuevo.',
          ar: 'تعذر العثور على ملف السائق. سجّل الدخول مرة أخرى.',
        );
      case 'rpc_unavailable':
        return rideActionFailedMessage;
      default:
        return rideActionFailedMessage;
    }
  }

  static String get rideRequestLoadFailedMessage => _t(
        'Ritaanvraag laden mislukt. Controleer je verbinding.',
        en: 'Could not load the ride request. Check your connection.',
        es: 'No se pudo cargar la solicitud de viaje. Revisa tu conexión.',
        ar: 'تعذر تحميل طلب الرحلة. تحقق من اتصالك.',
      );
  static String get acceptRideFailedMessage => _t(
        'Rit accepteren mislukt. Probeer opnieuw of controleer je verbinding.',
        en: 'Could not accept the ride. Try again or check your connection.',
        es: 'No se pudo aceptar el viaje. Inténtalo de nuevo o revisa tu conexión.',
        ar: 'تعذر قبول الرحلة. حاول مرة أخرى أو تحقق من اتصالك.',
      );

  static String get rideAlertsTitle => _t(
        'Ritmeldingen',
        en: 'Ride alerts',
        es: 'Alertas de viajes',
        ar: 'تنبيهات الرحلات',
      );
  static String get rideAlertsReady => _t(
        'Klaar voor ritverzoeken',
        en: 'Ready for ride requests',
        es: 'Listo para solicitudes',
        ar: 'جاهز لطلبات الرحلات',
      );
  static String get rideAlertsWarning => _t(
        'Je kunt ritverzoeken missen op de achtergrond.',
        en: 'You may miss ride requests in the background.',
        es: 'Puedes perder solicitudes en segundo plano.',
        ar: 'قد تفوتك طلبات الرحلات في الخلفية.',
      );
  static String get rideAlertsNotifications => _t(
        'Meldingen',
        en: 'Notifications',
        es: 'Notificaciones',
        ar: 'الإشعارات',
      );
  static String get rideAlertsSound => _t(
        'Geluid',
        en: 'Sound',
        es: 'Sonido',
        ar: 'الصوت',
      );
  static String get rideAlertsTimeSensitive => _t(
        'Tijdgevoelig',
        en: 'Time-sensitive',
        es: 'Urgentes',
        ar: 'حساس للوقت',
      );
  static String get rideAlertsRegistered => _t(
        'Apparaat geregistreerd',
        en: 'Device registered',
        es: 'Dispositivo registrado',
        ar: 'الجهاز مسجل',
      );
  static String get openSettings => _t(
        'Open instellingen',
        en: 'Open Settings',
        es: 'Abrir ajustes',
        ar: 'فتح الإعدادات',
      );

  static String acceptRideErrorMessage(String code) {
    final normalized = code.split(':').first.trim();
    switch (normalized) {
      case 'no_valid_invite':
      case 'invite_missing':
        return _t(
          'Je bent nog niet uitgenodigd voor deze rit. Zet je status op Online, controleer GPS, en probeer opnieuw.',
          en: 'You were not invited to this ride yet. Set your status to Online, check GPS, and try again.',
          es: 'Aún no fuiste invitado a este viaje. Pon tu estado en En línea, activa el GPS e inténtalo de nuevo.',
          ar: 'لم تتم دعوتك لهذه الرحلة بعد. اجعل حالتك متصلة، فعّل GPS، ثم حاول مرة أخرى.',
        );
      case 'invite_expired':
      case 'invite_not_pending':
        return _t(
          'Je uitnodiging voor deze rit is verlopen. Wacht op een nieuwe rit.',
          en: 'Your invite for this ride has expired. Wait for a new request.',
          es: 'Tu invitación para este viaje ha caducado. Espera una nueva solicitud.',
          ar: 'انتهت دعوتك لهذه الرحلة. انتظر طلبًا جديدًا.',
        );
      case 'stale_location':
      case 'gps_stale':
        return _t(
          'Je locatie is verouderd. Schakel locatie in en probeer opnieuw.',
          en: 'Your location is outdated. Enable location services and try again.',
          es: 'Tu ubicación está desactualizada. Activa la ubicación e inténtalo de nuevo.',
          ar: 'موقعك قديم. فعّل خدمات الموقع ثم حاول مرة أخرى.',
        );
      case 'billing_locked':
        return _t(
          'Rit accepteren geblokkeerd door openstaande platformkosten. Los dit op via Financiën.',
          en: 'Accept is blocked by outstanding platform fees. Resolve this in Finance.',
          es: 'Aceptar está bloqueado por tarifas pendientes. Resuélvelo en Finanzas.',
          ar: 'القبول محظور بسبب رسوم منصة مستحقة. حل ذلك من Finance.',
        );
      case 'missing_tariff':
        return _t(
          'Stel eerst je tarief in voordat je ritten accepteert.',
          en: 'Set your tariff before accepting rides.',
          es: 'Configura tu tarifa antes de aceptar viajes.',
          ar: 'حدّد تعرفتك قبل قبول الرحلات.',
        );
      case 'payment_incompatible':
      case 'payment_mismatch':
        return _t(
          'Deze rit gebruikt een betaalmethode die je niet ondersteunt.',
          en: 'This ride uses a payment method you do not support.',
          es: 'Este viaje usa un método de pago que no admites.',
          ar: 'هذه الرحلة تستخدم طريقة دفع لا تدعمها.',
        );
      case 'race_lost':
      case 'ride_not_pending':
      case 'database_conflict':
        return _t(
          'Een andere chauffeur heeft deze rit al geaccepteerd.',
          en: 'Another driver already accepted this ride.',
          es: 'Otro conductor ya aceptó este viaje.',
          ar: 'قبل سائق آخر هذه الرحلة بالفعل.',
        );
      case 'ride_not_found':
        return _t(
          'Deze rit bestaat niet meer.',
          en: 'This ride no longer exists.',
          es: 'Este viaje ya no existe.',
          ar: 'هذه الرحلة لم تعد موجودة.',
        );
      case 'ride_cancelled':
        return _t(
          'De rit is geannuleerd door de passagier.',
          en: 'The rider cancelled this trip.',
          es: 'El pasajero canceló este viaje.',
          ar: 'ألغى الراكب هذه الرحلة.',
        );
      case 'schedule_overlap':
        return _t(
          'Deze rit overlapt met een andere geplande rit in je agenda.',
          en: 'This trip overlaps another scheduled ride on your calendar.',
          es: 'Este viaje se solapa con otro viaje programado.',
          ar: 'هذه الرحلة تتداخل مع رحلة مجدولة أخرى.',
        );
      case 'not_scheduled':
        return _t(
          'Dit is geen geplande rit. Gebruik het live-aanbod scherm.',
          en: 'This is not a scheduled ride. Use the live offer screen.',
          es: 'Este no es un viaje programado. Usa la pantalla de oferta en vivo.',
          ar: 'هذه ليست رحلة مجدولة. استخدم شاشة العرض المباشر.',
        );
      case 'not_a_driver':
        return _t(
          'Geen chauffeursprofiel gevonden voor dit account.',
          en: 'No driver profile found for this account.',
          es: 'No se encontró perfil de conductor para esta cuenta.',
          ar: 'لم يتم العثور على ملف سائق لهذا الحساب.',
        );
      case 'rpc_failed':
      case 'rpc_error':
      case 'rpc_unavailable':
        return rideActionFailedMessage;
      default:
        return acceptRideFailedMessage;
    }
  }

  static String get scheduledRideDetailTitle => _t(
        'Geplande rit',
        en: 'Scheduled ride',
        es: 'Viaje programado',
        ar: 'رحلة مجدولة',
      );
  static String get acceptScheduledRide => _t(
        'Geplande rit accepteren',
        en: 'Accept scheduled ride',
        es: 'Aceptar viaje programado',
        ar: 'قبول الرحلة المجدولة',
      );
  static String get notInterestedScheduledRide => _t(
        'Niet geïnteresseerd',
        en: 'Not interested',
        es: 'No me interesa',
        ar: 'غير مهتم',
      );
  static String get scheduledRideAcceptedMessage => _t(
        'Geplande rit geaccepteerd. Je vindt hem bij Bevestigd.',
        en: 'Scheduled ride accepted. Find it under Confirmed.',
        es: 'Viaje programado aceptado. Búscalo en Confirmados.',
        ar: 'تم قبول الرحلة المجدولة. ستجدها ضمن المؤكدة.',
      );
  static String get scheduledRideAcceptFailedMessage => _t(
        'Geplande rit accepteren mislukt. Probeer opnieuw.',
        en: 'Could not accept the scheduled ride. Try again.',
        es: 'No se pudo aceptar el viaje programado. Inténtalo de nuevo.',
        ar: 'تعذر قبول الرحلة المجدولة. حاول مرة أخرى.',
      );
  static String get scheduledRideNotesLabel => _t(
        'Opmerkingen',
        en: 'Notes',
        es: 'Notas',
        ar: 'ملاحظات',
      );
  static String get scheduledRideWrongEntryMessage => _t(
        'Geplande ritten open je via Geplande ritten — niet via een live alarm.',
        en: 'Open scheduled rides from Scheduled rides — not the live alert screen.',
        es: 'Abre los viajes programados desde Viajes programados, no desde la alerta en vivo.',
        ar: 'افتح الرحلات المجدولة من الرحلات المجدولة — وليس من شاشة التنبيه المباشر.',
      );
  static String get requestStatusUpdateFailedMessage => _t(
        'Aanvraagstatus bijwerken mislukt. Probeer opnieuw.',
        en: 'Could not update request status. Try again.',
        es: 'No se pudo actualizar el estado de solicitudes. Inténtalo de nuevo.',
        ar: 'تعذر تحديث حالة الطلبات. حاول مرة أخرى.',
      );
  static String get enterValidPaidAmount => _t(
        'Voer een geldig betaald bedrag in.',
        en: 'Enter a valid paid amount.',
        es: 'Introduce un importe pagado válido.',
        ar: 'أدخل مبلغا مدفوعا صالحا.',
      );
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
  static String get communityPostCreateFailed => _t(
        'Plaatsen mislukt.',
        en: 'Post failed.',
        es: 'Error al publicar.',
        ar: 'فشل النشر.',
      );
  static String get rideNotFound => _t(
        'Rit niet gevonden',
        en: 'Ride not found',
        es: 'Viaje no encontrado',
        ar: 'الرحلة غير موجودة',
      );
  static String get missedRequestTitle => _t(
        'Aanvraag gemist',
        en: 'Missed request',
        es: 'Solicitud perdida',
        ar: 'طلب فائت',
      );
  static String get missedRequestBody => _t(
        'Je hebt niet op je volgende ritaanvraag gereageerd.',
        en: 'You didn\'t respond to your next ride request.',
        es: 'No respondiste a tu próxima solicitud de viaje.',
        ar: 'لم تستجب لطلب الرحلة التالي.',
      );
  static String get close => _t(
        'Sluiten',
        en: 'Close',
        es: 'Cerrar',
        ar: 'إغلاق',
      );
  static String get rideCompleteTitle => _t(
        'Rit afgerond',
        en: 'Ride completed',
        es: 'Viaje completado',
        ar: 'اكتملت الرحلة',
      );
  static String get rideCompleted => _t(
        'Rit voltooid',
        en: 'Ride completed',
        es: 'Viaje completado',
        ar: 'اكتملت الرحلة',
      );
  static String get destination => _t(
        'Bestemming',
        en: 'Destination',
        es: 'Destino',
        ar: 'الوجهة',
      );
  static String get navigateToPickup => _t(
        'Navigeer naar ophaalpunt',
        en: 'Navigate to pickup',
        es: 'Navegar a la recogida',
        ar: 'التنقل إلى نقطة الالتقاط',
      );
  static String get navigateToDestination => _t(
        'Navigeer naar bestemming',
        en: 'Navigate to destination',
        es: 'Navegar al destino',
        ar: 'التنقل إلى الوجهة',
      );
  static String navigateOpensIn(String appLabel) => _t(
        'Opent in $appLabel',
        en: 'Opens in $appLabel',
        es: 'Se abre en $appLabel',
        ar: 'يفتح في $appLabel',
      );
  static String startTripRiderNotifiedOpensIn(String appLabel) => _t(
        'Reiziger ziet dat je onderweg bent · $appLabel',
        en: 'Rider sees you’re on your way · $appLabel',
        es: 'El pasajero ve que vas en camino · $appLabel',
        ar: 'يرى الراكب أنك في الطريق · $appLabel',
      );
  static String get copyAddress => _t(
        'Adres kopiëren',
        en: 'Copy address',
        es: 'Copiar dirección',
        ar: 'نسخ العنوان',
      );
  static String get addressCopied => _t(
        'Adres gekopieerd',
        en: 'Address copied',
        es: 'Dirección copiada',
        ar: 'تم نسخ العنوان',
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
  static String get pickupAddress => _t(
        'Ophaaladres',
        en: 'Pickup address',
        es: 'Dirección de recogida',
        ar: 'عنوان الالتقاط',
      );
  static String get riderPrefix => _t(
        'Reiziger:',
        en: 'Rider:',
        es: 'Pasajero:',
        ar: 'الراكب:',
      );
  static String get rider => _t(
        'Reiziger',
        en: 'Rider',
        es: 'Pasajero',
        ar: 'الراكب',
      );
  static String get contactRider => _t(
        'Chat met reiziger',
        en: 'Chat with rider',
        es: 'Chatear con el pasajero',
        ar: 'الدردشة مع الراكب',
      );
  static String get batteryOptimizationTitle => _t(
        'Achtergrond toestaan?',
        en: 'Allow background?',
        es: '¿Permitir segundo plano?',
        ar: 'السماح بالعمل في الخلفية؟',
      );
  static String get batteryOptimizationBody => _t(
        'Zonder uitzondering kan Android je locatie en ritmeldingen beperken terwijl je online bent.',
        en: 'Without exception, Android may restrict your location and ride notifications while you\'re online.',
        es: 'Sin excepción, Android puede restringir tu ubicación y notificaciones de viaje mientras estés en línea.',
        ar: 'بدون استثناء، قد يقيد Android موقعك وإشعارات الرحلة أثناء اتصالك.',
      );
  static String get batteryOptimizationAllow => _t(
        'Instellingen openen',
        en: 'Open settings',
        es: 'Abrir ajustes',
        ar: 'فتح الإعدادات',
      );
  static String get batteryOptimizationLater => _t(
        'Later',
        en: 'Later',
        es: 'Más tarde',
        ar: 'لاحقا',
      );
  static String get navigate => _t(
        'Navigeren',
        en: 'Navigate',
        es: 'Navegar',
        ar: 'التنقل',
      );
  static String get avgPerRide => _t(
        'Gemiddeld per rit',
        en: 'Average per ride',
        es: 'Promedio por viaje',
        ar: 'المتوسط لكل رحلة',
      );
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
  static String get noShowConfirmTitle => _t(
        'Reiziger niet verschenen?',
        en: 'Rider did not show?',
        es: '¿El pasajero no apareció?',
        ar: 'لم يظهر الراكب؟',
      );
  static String get noShowConfirmBody => _t(
        'Bevestig alleen als de reiziger na 5 minuten wachten niet is verschenen.',
        en: 'Only confirm if the rider hasn\'t appeared after 5 minutes of waiting.',
        es: 'Solo confirma si el pasajero no ha aparecido después de 5 minutos de espera.',
        ar: 'أكد فقط إذا لم يظهر الراكب بعد 5 دقائق من الانتظار.',
      );
  static String get noShowConfirmAction => _t(
        'No-show melden',
        en: 'Report no-show',
        es: 'Reportar no-show',
        ar: 'الإبلاغ عن عدم الحضور',
      );
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
  static String get incomingRidePickupDeadhead => _t(
        'Naar ophaalpunt',
        en: 'To pickup',
        es: 'Hacia la recogida',
        ar: 'إلى نقطة الالتقاط',
      );
  static String get incomingRideTripPaid => _t(
        'Rit',
        en: 'Trip',
        es: 'Viaje',
        ar: 'الرحلة',
      );
  static String get incomingRideTerugTaxiBadge => _t(
        'TAXI TERUG',
        en: 'TAXI TERUG',
        es: 'TAXI TERUG',
        ar: 'TAXI TERUG',
      );
  static String get incomingRideTerugNextRide => _t(
        'Volgende rit na afronding',
        en: 'Next ride after current trip',
        es: 'Próximo viaje tras terminar el actual',
        ar: 'الرحلة التالية بعد إنهاء الحالية',
      );
  static String get taxiTerugQueuedBookedTitle => _t(
        'Taxi Terug geboekt',
        en: 'Taxi Terug booked',
        es: 'Taxi Terug reservado',
        ar: 'تم حجز Taxi Terug',
      );
  static String get taxiTerugQueuedNextRideGeneric => _t(
        'Volgende rit na afronding van deze rit',
        en: 'Next ride after you finish this trip',
        es: 'Próximo viaje tras terminar este viaje',
        ar: 'الرحلة التالية بعد إنهاء هذه الرحلة',
      );
  static String taxiTerugQueuedNextRideToward(String destination) => _t(
        'Volgende rit na afronding — richting $destination',
        en: 'Next ride after this trip — toward $destination',
        es: 'Próximo viaje tras este viaje — hacia $destination',
        ar: 'الرحلة التالية بعد هذه الرحلة — باتجاه $destination',
      );
  static String taxiTerugQueuedPickupWindow(int minMinutes, int maxMinutes) =>
      _t(
        'Ophalen over $minMinutes–$maxMinutes min',
        en: 'Pickup in $minMinutes–$maxMinutes min',
        es: 'Recogida en $minMinutes–$maxMinutes min',
        ar: 'الالتقاط خلال $minMinutes–$maxMinutes دقيقة',
      );
  static String get taxiTerugStatsTitle => _t(
        'Taxi Terug — deze maand',
        en: 'Taxi Terug — this month',
        es: 'Taxi Terug — este mes',
        ar: 'Taxi Terug — هذا الشهر',
      );
  static String get taxiTerugStatsEmpty => _t(
        'Voltooi je eerste Taxi Terug rit om km bespaard en verdiensten te zien.',
        en: 'Complete your first Taxi Terug ride to see km saved and earnings.',
        es: 'Completa tu primer viaje Taxi Terug para ver km ahorrados y ganancias.',
        ar: 'أكمل أول رحلة Taxi Terug لرؤية الكيلومترات الموفرة والأرباح.',
      );
  static String get taxiTerugStatsKmSaved => _t(
        'Km bespaard',
        en: 'Km saved',
        es: 'Km ahorrados',
        ar: 'كم موفر',
      );
  static String taxiTerugStatsKmValue(String km) => _t(
        '$km km',
        en: '$km km',
        es: '$km km',
        ar: '$km كم',
      );
  static String get taxiTerugStatsEarned => _t(
        'Verdiend aan terugritten',
        en: 'Earned on return rides',
        es: 'Ganado en viajes de vuelta',
        ar: 'أرباح رحلات العودة',
      );
  static String taxiTerugStatsRidesCount(int count) => _t(
        '$count terugritten deze maand',
        en: '$count Taxi Terug rides this month',
        es: '$count viajes Taxi Terug este mes',
        ar: '$count رحلات Taxi Terug هذا الشهر',
      );
  static String taxiTerugCompletionKmSaved(String km) => _t(
        '$km km lege kilometers vermeden',
        en: '$km km empty km avoided',
        es: '$km km en vacío evitados',
        ar: 'تم تجنب $km كم فارغة',
      );
  static String get incomingRideMarketplaceBadge => _t(
        'Marktplaats',
        en: 'Marketplace',
        es: 'Mercado',
        ar: 'السوق',
      );
  static String get incomingRideOutOfRadius => _t(
        'Buiten radius',
        en: 'Out of radius',
        es: 'Fuera de radio',
        ar: 'خارج النطاق',
      );
  static String incomingRideReturnFit(String destination) => _t(
        'Richting $destination',
        en: 'Toward $destination',
        es: 'Hacia $destination',
        ar: 'باتجاه $destination',
      );
  static String incomingRideRiderOffered(String amount) => _t(
        'Rider bood $amount',
        en: 'Rider offered $amount',
        es: 'El pasajero ofreció $amount',
        ar: 'عرض الراكب $amount',
      );
  static String get incomingRideTariffEstimate => _t(
        'Op basis van jouw tarief',
        en: 'Based on your tariff',
        es: 'Según tu tarifa',
        ar: 'بناءً على تعريفتك',
      );
  static String get incomingRideRiderNamedPrice => _t(
        'Rider heeft een prijs gekozen',
        en: 'Rider named a price',
        es: 'El pasajero fijó un precio',
        ar: 'حدد الراكب سعراً',
      );
  static String incomingRideFareFromDistance(String km) => _t(
        'Ca. €? · $km km rit',
        en: 'Est. from $km km trip',
        es: 'Est. por $km km de viaje',
        ar: 'تقدير من $km كم',
      );
  static String get incomingRideMapDecline => _t(
        'Weigeren',
        en: 'Decline',
        es: 'Rechazar',
        ar: 'رفض',
      );
  static String get rideRouteDetailsTitle => _t(
        'Ritdetails',
        en: 'Route details',
        es: 'Detalles de la ruta',
        ar: 'تفاصيل المسار',
      );
  static String rideRouteDetailsContact(String name) => _t(
        'Contact $name',
        en: 'Contact $name',
        es: 'Contactar a $name',
        ar: 'تواصل مع $name',
      );
  static String get rideRouteDetailsChangeNav => _t(
        'Wijzigen',
        en: 'Change',
        es: 'Cambiar',
        ar: 'تغيير',
      );
  static String get rideMapWaitHere => _t(
        'Wacht hier',
        en: 'Wait here',
        es: 'Espera aquí',
        ar: 'انتظر هنا',
      );
  static String get rideSafetyToolkitTitle => _t(
        'Veiligheidskit',
        en: 'Safety toolkit',
        es: 'Kit de seguridad',
        ar: 'أدوات السلامة',
      );
  static String get rideSafetyToolkitBody => _t(
        'Hulp om je veilig te voelen tijdens het rijden.',
        en: 'Features to help you feel safe and secure while driving.',
        es: 'Funciones para sentirte seguro mientras conduces.',
        ar: 'ميزات لمساعدتك على الشعور بالأمان أثناء القيادة.',
      );
  static String rideFarePill(String amount) => _t(
        'HeyCaby · $amount',
        en: 'HeyCaby · $amount',
        es: 'HeyCaby · $amount',
        ar: 'HeyCaby · $amount',
      );
  static String get chatQuickImHere => _t(
        'Ik ben er',
        en: "I'm here",
        es: 'Ya llegué',
        ar: 'وصلت',
      );
  static String get chatQuickOnMyWay => _t(
        'Onderweg',
        en: 'On my way',
        es: 'En camino',
        ar: 'في الطريق',
      );
  static String get chatQuickTwoMinutes => _t(
        'Ik ben er over 2 min',
        en: "I'll arrive in 2 min",
        es: 'Llego en 2 min',
        ar: 'أصل خلال دقيقتين',
      );
  static String get paymentCash => _t(
        'Contant',
        en: 'Cash',
        es: 'Efectivo',
        ar: 'نقدا',
      );
  static String get paymentCollectHeadline => _t(
        'Innen bij passagier',
        en: 'Collect from rider',
        es: 'Cobrar al pasajero',
        ar: 'تحصيل من الراكب',
      );
  static String paymentDriverCashInstruction(String amount) => _t(
        'Vraag de passagier om $amount voor ze uitstappen',
        en: 'Ask the rider for $amount before they exit',
        es: 'Pide al pasajero $amount antes de que salga',
        ar: 'اطلب من الراكب $amount قبل أن ينزل',
      );
  static String get paymentDriverPinInstruction => _t(
        'Pak je pinterminal en laat de passagier betalen',
        en: 'Take out your PIN terminal and ask the rider to pay',
        es: 'Saca el datáfono y pide al pasajero que pague',
        ar: 'أخرج جهاز الدفع واطلب من الراكب الدفع',
      );
  static String paymentDriverTikkieInstruction(String amount) => _t(
        'Tikkie $amount · toon je QR',
        en: 'Tikkie $amount · show your QR',
        es: 'Tikkie $amount · muestra tu QR',
        ar: 'Tikkie $amount · اعرض رمز QR',
      );
  static String get paymentCashCountBeforeExit => _t(
        'Tel het bedrag voordat ze uitstappen',
        en: 'Count before they exit',
        es: 'Cuenta antes de que salgan',
        ar: 'عدّ المبلغ قبل أن ينزلوا',
      );
  static String get paymentPinTakeTerminal => _t(
        'Laat de passagier op de terminal betalen',
        en: 'Ask the rider to pay on your terminal',
        es: 'Pide al pasajero pagar en el terminal',
        ar: 'اطلب من الراكب الدفع على الجهاز',
      );
  static String get paymentTikkieSendRequest => _t(
        'Maak een betaalverzoek in Tikkie',
        en: 'Create a payment request in Tikkie',
        es: 'Crea una solicitud de pago en Tikkie',
        ar: 'أنشئ طلب دفع في Tikkie',
      );
  static String get paymentTikkieShowQrToRider => _t(
        'Laat de passagier je QR scannen',
        en: 'Let the rider scan your QR',
        es: 'Deja que el pasajero escanee tu QR',
        ar: 'دع الراكب يمسح رمز QR',
      );
  static String get paymentCreateTikkieShowQr => _t(
        'Tikkie openen · QR tonen',
        en: 'Open Tikkie · show QR',
        es: 'Abrir Tikkie · mostrar QR',
        ar: 'فتح Tikkie · عرض QR',
      );
  static String get paymentTipFromRider => _t(
        'Fooi van passagier',
        en: 'Tip from rider',
        es: 'Propina del pasajero',
        ar: 'إكرامية من الراكب',
      );
  static String get paymentRiderConfirmedPay => _t(
        'Passagier heeft betaald bevestigd',
        en: 'Rider confirmed payment',
        es: 'El pasajero confirmó el pago',
        ar: 'أكد الراكب الدفع',
      );
  static String get paymentDownloadTikkieHint => _t(
        'Installeer Tikkie om te betalen',
        en: 'Install Tikkie to pay',
        es: 'Instala Tikkie para pagar',
        ar: 'ثبّت Tikkie للدفع',
      );
  static String get paymentOpenTikkie => _t(
        'Open Tikkie',
        en: 'Open Tikkie',
        es: 'Abrir Tikkie',
        ar: 'فتح Tikkie',
      );
  static String get paymentDownloadTikkie => _t(
        'Download Tikkie',
        en: 'Download Tikkie',
        es: 'Descargar Tikkie',
        ar: 'تنزيل Tikkie',
      );
  static String get paymentCashCollected => _t(
        'Contant ontvangen ✓',
        en: 'Cash collected ✓',
        es: 'Efectivo recibido ✓',
        ar: 'تم استلام النقد ✓',
      );
  static String get paymentPinReceived => _t(
        'Pinbetaling ontvangen ✓',
        en: 'PIN payment received ✓',
        es: 'Pago con tarjeta recibido ✓',
        ar: 'تم استلام الدفع بالبطاقة ✓',
      );
  static String get paymentTikkieReceived => _t(
        'Betaling ontvangen ✓',
        en: 'Payment received ✓',
        es: 'Pago recibido ✓',
        ar: 'تم استلام الدفع ✓',
      );
  static String get paymentConfirmFailed => _t(
        'Betaling bevestigen mislukt. Probeer opnieuw.',
        en: 'Could not confirm payment. Try again.',
        es: 'No se pudo confirmar el pago. Inténtalo de nuevo.',
        ar: 'تعذر تأكيد الدفع. حاول مرة أخرى.',
      );
  static String get paymentAmountDispute => _t(
        'Bedrag oneens',
        en: 'Amount dispute',
        es: 'Disputa de importe',
        ar: 'نزاع على المبلغ',
      );
  static String get paymentPinRetry => _t(
        'Betaling mislukt — opnieuw',
        en: 'Payment failed — retry',
        es: 'Pago fallido — reintentar',
        ar: 'فشل الدفع — إعادة المحاولة',
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
  static String startRideAndNavigate(String appLabel) => _t(
        'Naar ophaalpunt · $appLabel',
        en: 'Head to pickup · $appLabel',
        es: 'Ir al punto de recogida · $appLabel',
        ar: 'إلى نقطة الالتقاط · $appLabel',
      );
  static String headToDropoffAndNavigate(String appLabel) => _t(
        'Naar bestemming · $appLabel',
        en: 'Head to drop-off · $appLabel',
        es: 'Ir al destino · $appLabel',
        ar: 'إلى نقطة الوصول · $appLabel',
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
  static String get messageCategory => _t(
        'Categorie',
        en: 'Category',
        es: 'Categoría',
        ar: 'الفئة',
      );
  static String get supportMessageSentTitle => _t(
        'Bericht verzonden',
        en: 'Message sent',
        es: 'Mensaje enviado',
        ar: 'تم إرسال الرسالة',
      );
  static String get supportMessageSentBody => _t(
        'Bedankt voor je bericht. Ons ondersteuningsteam bekijkt het en reageert zo snel mogelijk. Voor urgente zaken kun je chatten met Lee (AI-ondersteuningsassistent).',
        en: 'Thank you for your message. Our support team reviews it and responds as soon as possible. For urgent matters you can chat with Lee (AI support assistant).',
        es: 'Gracias por tu mensaje. Nuestro equipo de soporte lo revisa y responde lo antes posible. Para urgencias puedes chatear con Lee (asistente de soporte IA).',
        ar: 'شكرا لرسالتك. يراجعها فريق الدعم ويرد في أسرع وقت ممكن. للأمور العاجلة يمكنك الدردشة مع Lee (مساعد الدعم بالذكاء الاصطناعي).',
      );
  static String get supportMessageSendFailedTitle => _t(
        'Bericht verzenden mislukt',
        en: 'Failed to send message',
        es: 'Error al enviar mensaje',
        ar: 'فشل إرسال الرسالة',
      );
  static String get supportMessageSendFailedBody => _t(
        'We konden je ondersteuningsbericht nu niet verzenden. Probeer het straks opnieuw, of gebruik Chat met Lee bij spoed.',
        en: 'We couldn\'t send your support message right now. Try again later, or use Chat with Lee for urgent matters.',
        es: 'No pudimos enviar tu mensaje de soporte ahora. Inténtalo más tarde, o usa Chat con Lee para urgencias.',
        ar: 'تعذر إرسال رسالة الدعم الآن. حاول لاحقا، أو استخدم الدردشة مع Lee للأمور العاجلة.',
      );
  static String get leeSupportAssistant => _t(
        'Lee AI-ondersteuningsassistent',
        en: 'Lee AI support assistant',
        es: 'Asistente de soporte IA Lee',
        ar: 'مساعد الدعم بالذكاء الاصطناعي لي',
      );
  static String get leeSupportPrompt => _t(
        'Stel vragen over ritten, account of uitbetalingen.',
        en: 'Ask questions about rides, account or payouts.',
        es: 'Haz preguntas sobre viajes, cuenta o pagos.',
        ar: 'اطرح أسئلة عن الرحلات أو الحساب أو المدفوعات.',
      );
  static String get submit => _t(
        'Versturen',
        en: 'Submit',
        es: 'Enviar',
        ar: 'إرسال',
      );
  static String get resumeRequests => _t(
        'Aanvragen hervatten',
        en: 'Resume requests',
        es: 'Reanudar solicitudes',
        ar: 'استئناف الطلبات',
      );
  static String get stopNewRequests => _t(
        'Nieuwe aanvragen stoppen',
        en: 'Stop new requests',
        es: 'Detener nuevas solicitudes',
        ar: 'إيقاف الطلبات الجديدة',
      );
  static String get iHaveArrived => _t(
        'Ik ben gearriveerd',
        en: 'I\'ve arrived',
        es: 'He llegado',
        ar: 'وصلت',
      );
  static String get preferencesLoadFailed => _t(
        'Voorkeuren laden mislukt',
        en: 'Preferences load failed',
        es: 'Error al cargar preferencias',
        ar: 'فشل تحميل التفضيلات',
      );
  static String get financeAndTax => _t(
        'Financiën en belastingen',
        en: 'Finance and tax',
        es: 'Finanzas e impuestos',
        ar: 'المالية والضرائب',
      );
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
  static String get statusSubmitted => _t(
        'Ingediend',
        en: 'Submitted',
        es: 'Enviado',
        ar: 'تم الإرسال',
      );
  static String get statusInReview => _t(
        'In behandeling',
        en: 'Under review',
        es: 'En revisión',
        ar: 'قيد المراجعة',
      );
  static String get statusRequired => _t(
        'Vereist',
        en: 'Required',
        es: 'Requerido',
        ar: 'مطلوب',
      );
  static String get statusNotTaxiVehicle => _t(
        'Niet-taxi voertuig',
        en: 'Non-taxi vehicle',
        es: 'Vehículo no taxi',
        ar: 'مركبة غير تاكسي',
      );
  static String get statusManualReview => _t(
        'Handmatige beoordeling',
        en: 'Manual review',
        es: 'Revisión manual',
        ar: 'مراجعة يدوية',
      );
  static String get statusChecking => _t(
        'Controleren...',
        en: 'Checking...',
        es: 'Comprobando...',
        ar: 'جاري الفحص...',
      );
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
  static String get pricingSaving => _t(
        'Opslaan...',
        en: 'Saving...',
        es: 'Guardando...',
        ar: 'جاري الحفظ...',
      );
  static String get pricingSaveRates => _t(
        'Tarieven opslaan',
        en: 'Save rates',
        es: 'Guardar tarifas',
        ar: 'حفظ الأسعار',
      );
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
  static String get loginBrandLabel => _t(
        'HeyCaby Driver',
        en: 'HeyCaby Driver',
        es: 'HeyCaby Driver',
        ar: 'HeyCaby Driver',
      );
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
  static String get loginConfigError => _t(
        'Supabase-sleutel ontbreekt of is ongeldig. Stop de app volledig en start opnieuw via ./scripts/run_driver_ios_debug.sh (of flutter run --dart-define-from-file=ios/.ipa_dart_defines.json).',
        en: 'Supabase key missing or invalid. Fully stop the app and restart via ./scripts/run_driver_ios_debug.sh (or flutter run --dart-define-from-file=ios/.ipa_dart_defines.json).',
        es: 'Falta la clave de Supabase o es inválida. Cierra la app completamente y reinicia via ./scripts/run_driver_ios_debug.sh (o flutter run --dart-define-from-file=ios/.ipa_dart_defines.json).',
        ar: 'مفتاح Supabase مفقود أو غير صالح. أوقف التطبيق بالكامل وأعد التشغيل عبر ./scripts/run_driver_ios_debug.sh (أو flutter run --dart-define-from-file=ios/.ipa_dart_defines.json).',
      );
  static String get reactionFailedMigration => _t(
        'Reactie mislukt. Controleer of de nieuwste database-migratie is toegepast.',
        en: 'Reaction failed. Check that the latest database migration is applied.',
        es: 'Reacción fallida. Comprueba que la última migración de base de datos esté aplicada.',
        ar: 'فشل التفاعل. تحقق من تطبيق أحدث ترحيل لقاعدة البيانات.',
      );
  static String get couldNotLoadEarnings => _t(
        'Verdiensten laden mislukt.',
        en: 'Could not load earnings.',
        es: 'No se pudieron cargar las ganancias.',
        ar: 'تعذر تحميل الأرباح.',
      );
  static String get couldNotLoadRides => _t(
        'Ritten laden mislukt.',
        en: 'Could not load rides.',
        es: 'No se pudieron cargar los viajes.',
        ar: 'تعذر تحميل الرحلات.',
      );
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
  static String get failedToGoOnline => _t(
        'Online gaan mislukt. Probeer opnieuw.',
        en: 'Failed to go online. Try again.',
        es: 'Error al conectarse. Inténtalo de nuevo.',
        ar: 'فشل الاتصال. حاول مرة أخرى.',
      );
  static String get couldNotReportComment => _t(
        'Opmerking melden mislukt. Probeer opnieuw.',
        en: 'Failed to report comment. Try again.',
        es: 'Error al reportar comentario. Inténtalo de nuevo.',
        ar: 'فشل الإبلاغ عن التعليق. حاول مرة أخرى.',
      );
  static String get announcementsLoadFailed => _t(
        'Aankondigingen laden mislukt.',
        en: 'Announcements load failed.',
        es: 'Error al cargar anuncios.',
        ar: 'فشل تحميل الإعلانات.',
      );
  static String get newRiderDemandNearby => _t(
        'Nieuwe vraag van reizigers in de buurt. Goede kans om nu te verdienen.',
        en: 'New rider demand nearby. Good chance to earn now.',
        es: 'Nueva demanda de pasajeros cerca. Buena oportunidad para ganar ahora.',
        ar: 'طلب جديد من الركاب في الجوار. فرصة جيدة للربح الآن.',
      );
  static String get chatWithLee => _t(
        'Chat met Lee',
        en: 'Chat with Lee',
        es: 'Chatear con Lee',
        ar: 'الدردشة مع لي',
      );
  static String get preferencesSounds => _t(
        'Geluid',
        en: 'Sound',
        es: 'Sonido',
        ar: 'الصوت',
      );
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
  static String get other => _t(
        'Overig',
        en: 'Other',
        es: 'Otros',
        ar: 'أخرى',
      );
  static String get report => _t(
        'Melden',
        en: 'Report',
        es: 'Reportar',
        ar: 'إبلاغ',
      );
  static String get dismiss => _t(
        'Sluiten',
        en: 'Dismiss',
        es: 'Descartar',
        ar: 'إغلاق',
      );
  static String get invalidExpiryDateFormat => _t(
        'Ontbrekende of ongeldige verloopdatum-indeling.',
        en: 'Missing or invalid expiry date format.',
        es: 'Formato de fecha de caducidad faltante o inválido.',
        ar: 'تنسيق تاريخ انتهاء الصلاحية مفقود أو غير صالح.',
      );

  // Today's rides
  static String get geenRittenVandaag => _t(
        'Geen ritten vandaag',
        en: 'No rides today',
        es: 'Sin viajes hoy',
        ar: 'لا توجد رحلات اليوم',
      );

  static String scheduledRidesCount(int count) =>
      count == 1 ? '1 $ride' : '$count $rides';

  static String endShiftBody(String hours, String minutes, int rideCount) => _t(
      'Je hebt $hours uur $minutes minuten gereden en $rideCount ritten voltooid vandaag.',
      en: 'You drove $hours hours $minutes minutes and completed $rideCount rides today.',
      es: 'Condujiste $hours horas $minutes minutos y completaste $rideCount viajes hoy.',
      ar: 'قدت لمدة $hours ساعات $minutes دقائق وأكملت $rideCount رحلة اليوم.');
  static String get dienstBeeindigen => _t(
        'Dienst beëindigen',
        en: 'End shift',
        es: 'Terminar turno',
        ar: 'إنهاء الوردية',
      );

  // Pre-ride confirmation (scheduled rides, optional €1–5 via Tikkie)
  static String get prerideReliabilityNew => _t(
        'Nieuw',
        en: 'New',
        es: 'Nuevo',
        ar: 'جديد',
      );
  static String get prerideReliabilityReliable => _t(
        'Betrouwbaar',
        en: 'Reliable',
        es: 'Confiable',
        ar: 'موثوق',
      );
  static String get prerideReliabilityAmber => _t(
        'Weinig historie',
        en: 'Limited history',
        es: 'Historial limitado',
        ar: 'سجل محدود',
      );
  static String get prerideReliabilityRisk => _t(
        'Let op: annuleringen',
        en: 'Caution: cancellations',
        es: 'Atención: cancelaciones',
        ar: 'تنبيه: إلغاءات',
      );
  static String get prerideAskWithFee => _t(
        'Bevestiging vragen →',
        en: 'Request confirmation →',
        es: 'Solicitar confirmación →',
        ar: 'طلب التأكيد ←',
      );
  static String get prerideAskNoFee => _t(
        'Bevestig zonder bijdrage',
        en: 'Confirm without contribution',
        es: 'Confirmar sin contribución',
        ar: 'تأكيد بدون مساهمة',
      );
  static String get prerideReleaseRide => _t(
        'Rit vrijgeven',
        en: 'Release ride',
        es: 'Liberar viaje',
        ar: 'تحرير الرحلة',
      );
  static String get prerideMarkTikkieReceived => _t(
        'Tikkie ontvangen',
        en: 'Tikkie received',
        es: 'Tikkie recibido',
        ar: 'تم استلام Tikkie',
      );
  static String get prerideAwaitingRider => _t(
        'Wacht op reiziger',
        en: 'Awaiting rider',
        es: 'Esperando al pasajero',
        ar: 'في انتظار الراكب',
      );
  static String get prerideRiderConfirmed => _t(
        'Reiziger bevestigd',
        en: 'Rider confirmed',
        es: 'Pasajero confirmado',
        ar: 'تم تأكيد الراكب',
      );
  static String get prerideModalTitle => _t(
        'Bevestigingsverzoek',
        en: 'Confirmation request',
        es: 'Solicitud de confirmación',
        ar: 'طلب تأكيد',
      );
  static String get prerideModalTikkieHint => _t(
        'Je ontvangt een Tikkie-link om te delen met de reiziger in de chat.',
        en: 'You\'ll receive a Tikkie link to share with the rider in the chat.',
        es: 'Recibirás un enlace Tikkie para compartir con el pasajero en el chat.',
        ar: 'ستتلقى رابط Tikkie لمشاركته مع الراكب في الدردشة.',
      );
  static String get prerideTikkieUrlLabel => _t(
        'Tikkie-link (plakken)',
        en: 'Tikkie link (paste)',
        es: 'Enlace Tikkie (pegar)',
        ar: 'رابط Tikkie (لصق)',
      );
  static String get prerideTikkieLinkCopied => _t(
        'Tikkie-link gekopieerd',
        en: 'Tikkie link copied',
        es: 'Enlace Tikkie copiado',
        ar: 'تم نسخ رابط Tikkie',
      );
  static String get prerideSendRequest => _t(
        'Stuur bevestigingsverzoek',
        en: 'Send confirmation request',
        es: 'Enviar solicitud de confirmación',
        ar: 'إرسال طلب التأكيد',
      );
  static String get prerideFeeLabel => _t(
        'Bijdrage (max €5)',
        en: 'Contribution (max €5)',
        es: 'Contribución (máx €5)',
        ar: 'المساهمة (بحد أقصى 5 يورو)',
      );
  static String get prerideErrorGeneric => _t(
        'Kon actie niet uitvoeren. Probeer opnieuw.',
        en: 'Could not perform action. Try again.',
        es: 'No se pudo realizar la acción. Inténtalo de nuevo.',
        ar: 'تعذر تنفيذ الإجراء. حاول مرة أخرى.',
      );
  static String get prerideErrorOutsideWindow => _t(
        'Alleen ongeveer 16–40 minuten voor de rit kun je dit versturen.',
        en: 'You can only send this approximately 16–40 minutes before the ride.',
        es: 'Solo puedes enviar esto aproximadamente 16–40 minutos antes del viaje.',
        ar: 'يمكنك إرسال هذا فقط قبل الرحلة بحوالي 16–40 دقيقة.',
      );
  static String get prerideErrorDeadlineNotPassed => _t(
        'Je kunt pas vrijgeven na de deadline van de reiziger.',
        en: 'You can only release after the rider\'s deadline.',
        es: 'Solo puedes liberar después de la fecha límite del pasajero.',
        ar: 'يمكنك التحرير فقط بعد الموعد النهائي للراكب.',
      );
  static String get myAssignedScheduled => _t(
        'Mijn geplande ritten',
        en: 'My scheduled rides',
        es: 'Mis viajes programados',
        ar: 'رحلاتي المجدولة',
      );
  static String get openScheduledRequests => _t(
        'Open aanvragen',
        en: 'Open requests',
        es: 'Solicitudes abiertas',
        ar: 'الطلبات المفتوحة',
      );

  // Finance hub & export (NL, accountant-friendly)
  static String get financeHubTitle => _t(
        'Financiën en belastingen',
        en: 'Finance and tax',
        es: 'Finanzas e impuestos',
        ar: 'المالية والضرائب',
      );
  static String get financeExportSheetTitle => _t(
        'Rapport exporteren',
        en: 'Export report',
        es: 'Exportar informe',
        ar: 'تصدير التقرير',
      );
  static String get financeExportPdf => _t(
        'PDF downloaden',
        en: 'Download PDF',
        es: 'Descargar PDF',
        ar: 'تنزيل PDF',
      );
  static String get financeExportPdfSubtitle => _t(
        'Opslaan op dit toestel',
        en: 'Save to this device',
        es: 'Guardar en este dispositivo',
        ar: 'حفظ في هذا الجهاز',
      );
  static String get financeExportEmail => _t(
        'Versturen via e-mail',
        en: 'Send via email',
        es: 'Enviar por correo',
        ar: 'إرسال عبر البريد',
      );
  static String get financeExportEmailSubtitle => _t(
        'Naar accountant',
        en: 'To accountant',
        es: 'Al contador',
        ar: 'إلى المحاسب',
      );
  static String get financeExportWhatsapp => _t(
        'Delen via WhatsApp',
        en: 'Share via WhatsApp',
        es: 'Compartir por WhatsApp',
        ar: 'مشاركة عبر واتساب',
      );
  static String get financeExportWhatsappSubtitle => _t(
        'PDF — kies WhatsApp in het deelmenu',
        en: 'PDF — choose WhatsApp in the share menu',
        es: 'PDF — elige WhatsApp en el menú compartir',
        ar: 'PDF — اختر WhatsApp في قائمة المشاركة',
      );
  static String get financeWhatsappSharePdfCaption => _t(
        'Financieel overzicht als PDF (HeyCaby chauffeur).',
        en: 'Financial overview as PDF (HeyCaby driver).',
        es: 'Resumen financiero en PDF (conductor HeyCaby).',
        ar: 'ملخص مالي كملف PDF (سائق HeyCaby).',
      );

  static String get financeRangeToday => _t(
        'Vandaag',
        en: 'Today',
        es: 'Hoy',
        ar: 'اليوم',
      );
  static String get financeRangeThisWeek => _t(
        'Deze week',
        en: 'This week',
        es: 'Esta semana',
        ar: 'هذا الأسبوع',
      );
  static String get financeRangeThisMonth => _t(
        'Deze maand',
        en: 'This month',
        es: 'Este mes',
        ar: 'هذا الشهر',
      );
  static String get financeRangeThisQuarter => _t(
        'Dit kwartaal',
        en: 'This quarter',
        es: 'Este trimestre',
        ar: 'هذا الربع',
      );
  static String get financeRangeThisYear => _t(
        'Dit jaar',
        en: 'This year',
        es: 'Este año',
        ar: 'هذا العام',
      );
  static String get financeRangeCustom => _t(
        'Aangepast',
        en: 'Custom',
        es: 'Personalizado',
        ar: 'مخصص',
      );

  static String get financeReportTitle => _t(
        'HeyCaby — chauffeur financieel overzicht',
        en: 'HeyCaby — driver financial overview',
        es: 'HeyCaby — resumen financiero del conductor',
        ar: 'HeyCaby — الملخص المالي للسائق',
      );
  static String get financeReportPeriodHeading => _t(
        'Weergave',
        en: 'View',
        es: 'Vista',
        ar: 'العرض',
      );
  static String get financeReportDatesHeading => _t(
        'Datumbereik',
        en: 'Date range',
        es: 'Rango de fechas',
        ar: 'نطاق التاريخ',
      );
  static String get financeReportGenerated => _t(
        'Aangemaakt',
        en: 'Generated',
        es: 'Generado',
        ar: 'تم الإنشاء',
      );
  static String get financeReportSectionSummary => _t(
        'Samenvatting',
        en: 'Summary',
        es: 'Resumen',
        ar: 'الملخص',
      );
  static String get financeReportGross => _t(
        'Bruto inkomsten',
        en: 'Gross income',
        es: 'Ingresos brutos',
        ar: 'الدخل الإجمالي',
      );
  static String get financeReportNet => _t(
        'Netto inkomsten',
        en: 'Net income',
        es: 'Ingresos netos',
        ar: 'الدخل الصافي',
      );
  static String get financeReportTotalRides => _t(
        'Ritten totaal',
        en: 'Total rides',
        es: 'Viajes totales',
        ar: 'إجمالي الرحلات',
      );
  static String get financeReportKm => _t(
        'Kilometers',
        en: 'Kilometres',
        es: 'Kilómetros',
        ar: 'الكيلومترات',
      );
  static String get financeReportPlatformFees => _t(
        'Platformkosten',
        en: 'Platform fees',
        es: 'Cuotas de plataforma',
        ar: 'رسوم المنصة',
      );
  static String get financeReportTips => _t(
        'Fooien',
        en: 'Tips',
        es: 'Propinas',
        ar: 'الإكراميات',
      );
  static String get financeReportCompleted => _t(
        'Voltooide ritten',
        en: 'Completed rides',
        es: 'Viajes completados',
        ar: 'الرحلات المكتملة',
      );
  static String get financeReportCancelled => _t(
        'Geannuleerde ritten',
        en: 'Cancelled rides',
        es: 'Viajes cancelados',
        ar: 'الرحلات الملغاة',
      );
  static String get financeReportCancellationFees => _t(
        'Annuleringsvergoedingen',
        en: 'Cancellation fees',
        es: 'Tarifas de cancelación',
        ar: 'رسوم الإلغاء',
      );
  static String get financeReportFooter => _t(
        'Bron: HeyCaby Driver-app. Controleer de bedragen in je eigen administratie.',
        en: 'Source: HeyCaby Driver app. Verify amounts in your own records.',
        es: 'Fuente: App HeyCaby Driver. Verifica los importes en tus propios registros.',
        ar: 'المصدر: تطبيق HeyCaby Driver. تحقق من المبالغ في سجلاتك الخاصة.',
      );

  static String get financeEmailSubject => _t(
        'HeyCaby financieel overzicht chauffeur',
        en: 'HeyCaby driver financial overview',
        es: 'HeyCaby resumen financiero del conductor',
        ar: 'HeyCaby الملخص المالي للسائق',
      );
  static String get financePdfShareCaption => _t(
        'Financieel overzicht (PDF)',
        en: 'Financial overview (PDF)',
        es: 'Resumen financiero (PDF)',
        ar: 'الملخص المالي (PDF)',
      );

  static String get financeMetricsTotalEarnings => _t(
        'Totale inkomsten',
        en: 'Total earnings',
        es: 'Ingresos totales',
        ar: 'إجمالي الأرباح',
      );
  static String get financeMetricsNetEarnings => _t(
        'Netto inkomsten',
        en: 'Net earnings',
        es: 'Ingresos netos',
        ar: 'الأرباح الصافية',
      );
  static String get financeMetricsTotalRides => _t(
        'Ritten totaal',
        en: 'Total rides',
        es: 'Viajes totales',
        ar: 'إجمالي الرحلات',
      );
  static String get financeMetricsKm => _t(
        'Kilometers',
        en: 'Kilometres',
        es: 'Kilómetros',
        ar: 'الكيلومترات',
      );
  static String get financeMetricsPlatformFees => _t(
        'Platformkosten',
        en: 'Platform fees',
        es: 'Cuotas de plataforma',
        ar: 'رسوم المنصة',
      );
  static String get financeMetricsTips => _t(
        'Fooien',
        en: 'Tips',
        es: 'Propinas',
        ar: 'الإكراميات',
      );

  static String get financeBreakdownTitle => _t(
        'Ritoverzicht',
        en: 'Ride overview',
        es: 'Resumen de viajes',
        ar: 'ملخص الرحلات',
      );
  static String get financeBreakdownCompleted => _t(
        'Voltooide ritten',
        en: 'Completed rides',
        es: 'Viajes completados',
        ar: 'الرحلات المكتملة',
      );
  static String get financeBreakdownCancelled => _t(
        'Geannuleerde ritten',
        en: 'Cancelled rides',
        es: 'Viajes cancelados',
        ar: 'الرحلات الملغاة',
      );
  static String get financeBreakdownCancelFees => _t(
        'Annuleringsvergoedingen',
        en: 'Cancellation fees',
        es: 'Tarifas de cancelación',
        ar: 'رسوم الإلغاء',
      );
  static String get financeViewAllRides => _t(
        'Alle ritten bekijken',
        en: 'View all rides',
        es: 'Ver todos los viajes',
        ar: 'عرض جميع الرحلات',
      );

  static String get financePaymentReconciliationTitle => _t(
        'Betalingen en afstemming',
        en: 'Payments and reconciliation',
        es: 'Pagos y conciliación',
        ar: 'المدفوعات والتسوية',
      );
  static String get financeNoPaymentRecords => _t(
        'Nog geen betalingsregels.',
        en: 'No payment records yet.',
        es: 'Sin registros de pago.',
        ar: 'لا توجد سجلات دفع بعد.',
      );
  static String get financePaymentRecordsError => _t(
        'Betalingsregels laden mislukt.',
        en: 'Failed to load payment records.',
        es: 'Error al cargar registros de pago.',
        ar: 'فشل تحميل سجلات الدفع.',
      );

  static String get financeDataUnavailable => _t(
        'Financiële gegevens tijdelijk niet beschikbaar. Getoond: nulwaarden.',
        en: 'Financial data temporarily unavailable. Showing: zero values.',
        es: 'Datos financieros temporalmente no disponibles. Mostrando: valores cero.',
        ar: 'البيانات المالية غير متاحة مؤقتا. يعرض: قيما صفرية.',
      );

  static String get financeAccountantTitle => _t(
        'Accountant',
        en: 'Accountant',
        es: 'Contador',
        ar: 'المحاسب',
      );
  static String get financeAccountantEmptyHint => _t(
        'Bewaar het e-mailadres van je accountant voor snel delen.',
        en: 'Save your accountant\'s email address for quick sharing.',
        es: 'Guarda el email de tu contador para compartir rápido.',
        ar: 'احفظ بريد محاسبك الإلكتروني للمشاركة السريعة.',
      );
  static String get financeAccountantCurrentPrefix => _t(
        'Huidig e-mailadres:',
        en: 'Current email:',
        es: 'Correo actual:',
        ar: 'البريد الحالي:',
      );
  static String get financeAccountantAdd => _t(
        'E-mailadres toevoegen',
        en: 'Add email',
        es: 'Añadir correo',
        ar: 'إضافة بريد',
      );
  static String get financeAccountantEdit => _t(
        'E-mailadres wijzigen',
        en: 'Edit email',
        es: 'Cambiar correo',
        ar: 'تعديل البريد',
      );

  static String get financeAccountantDialogTitle => _t(
        'E-mailadres accountant',
        en: 'Accountant email',
        es: 'Correo del contador',
        ar: 'بريد المحاسب',
      );
  static String get financeAccountantDialogHint => _t(
        'accountant@voorbeeld.nl',
        en: 'accountant@example.com',
        es: 'contador@ejemplo.com',
        ar: 'accountant@example.com',
      );
  static String get financeAccountantDialogCancel => _t(
        'Annuleren',
        en: 'Cancel',
        es: 'Cancelar',
        ar: 'إلغاء',
      );
  static String get financeAccountantDialogSave => _t(
        'Opslaan',
        en: 'Save',
        es: 'Guardar',
        ar: 'حفظ',
      );

  static String get financePdfSaved => _t(
        'PDF opgeslagen:',
        en: 'PDF saved:',
        es: 'PDF guardado:',
        ar: 'تم حفظ PDF:',
      );
  static String get financePdfExportError => _t(
        'PDF exporteren mislukt:',
        en: 'PDF export failed:',
        es: 'Error al exportar PDF:',
        ar: 'فشل تصدير PDF:',
      );
  static String get financeEmailNoApp => _t(
        'Geen e-mailapp op dit toestel.',
        en: 'No email app on this device.',
        es: 'Sin app de correo en este dispositivo.',
        ar: 'لا يوجد تطبيق بريد على هذا الجهاز.',
      );
  static String get financeEmailOpenError => _t(
        'E-mailprogramma openen mislukt.',
        en: 'Failed to open email app.',
        es: 'Error al abrir app de correo.',
        ar: 'فشل فتح تطبيق البريد.',
      );
  static String get financeShareError => _t(
        'Rapport delen mislukt.',
        en: 'Report sharing failed.',
        es: 'Error al compartir informe.',
        ar: 'فشل مشاركة التقرير.',
      );
  static String get financeEmailBodyTooLongHint => _t(
        'Dit rapport is te lang om automatisch in de mailapp te openen. Kies Mail (of een andere app) in het deelmenu en controleer het bericht voordat je verzendt.',
        en: 'This report is too long to open in the mail app automatically. Choose Mail (or another app) in the share menu and check the message before sending.',
        es: 'Este informe es demasiado largo para abrirlo automáticamente en la app de correo. Elige Mail (u otra app) en el menú compartir y revisa el mensaje antes de enviar.',
        ar: 'هذا التقرير طويل جدا للفتح التلقائي في تطبيق البريد. اختر Mail (أو تطبيقا آخر) في قائمة المشاركة وتحقق من الرسالة قبل الإرسال.',
      );
  static String get financeEmailMailtoFailedHint => _t(
        'De mailapp opende niet automatisch. Kies Mail in het deelmenu en controleer het bericht.',
        en: 'The mail app didn\'t open automatically. Choose Mail in the share menu and check the message.',
        es: 'La app de correo no se abrió automáticamente. Elige Mail en el menú compartir y revisa el mensaje.',
        ar: 'لم يفتح تطبيق البريد تلقائيا. اختر Mail في قائمة المشاركة وتحقق من الرسالة.',
      );
  static String get financeEmailRecipientCopied => _t(
        'E-mailadres accountant staat op het klembord — plak bij Aan:.',
        en: 'Accountant email address copied to clipboard — paste in To:.',
        es: 'Email del contador copiado al portapapeles — pega en Para:.',
        ar: 'تم نسخ بريد المحاسب إلى الحافظة — الصقه في To:.',
      );
  static String get financeEmailNoRecipientHint => _t(
        'Tip: sla het e-mailadres van je accountant op dit scherm op; dan wordt Aan: automatisch ingevuld.',
        en: 'Tip: save your accountant\'s email on this screen; then To: is filled automatically.',
        es: 'Consejo: guarda el email de tu contador en esta pantalla; entonces Para: se rellena automáticamente.',
        ar: 'نصيحة: احفظ بريد محاسبك على هذه الشاشة؛ ثم يتم ملء To: تلقائيا.',
      );

  // Finance — tabs
  static String get financeTabOverview => _t(
        'Overzicht',
        en: 'Overview',
        es: 'Resumen',
        ar: 'نظرة عامة',
      );
  static String get financeTabSavings => _t(
        'Besparing',
        en: 'Savings',
        es: 'Ahorros',
        ar: 'المدخرات',
      );

  // Finance — new metrics
  static String get financeMetricsAverageFare => _t(
        'Gemiddelde ritprijs',
        en: 'Average fare',
        es: 'Tarifa promedio',
        ar: 'متوسط الأجرة',
      );
  static String get financeMetricsHoursOnline => _t(
        'Uren online',
        en: 'Hours online',
        es: 'Horas en línea',
        ar: 'ساعات الاتصال',
      );
  static String get financeMetricsTotalShifts => _t(
        'Diensten',
        en: 'Shifts',
        es: 'Turnos',
        ar: 'الورديات',
      );
  static String get financeMetricsNetAfterFees => _t(
        'Netto na platformkosten',
        en: 'Net after platform fees',
        es: 'Neto tras comisiones',
        ar: 'الصافي بعد الرسوم',
      );

  // Finance — savings tab
  static String get financeSavingsTitle => _t(
        'Jouw besparing met HeyCaby',
        en: 'Your savings with HeyCaby',
        es: 'Tu ahorro con HeyCaby',
        ar: 'مدخراتك مع HeyCaby',
      );
  static String get financeSavingsSubtitle => _t(
        'Vaste vergoeding versus commissie',
        en: 'Flat fee versus commission',
        es: 'Tarifa fija frente a comisión',
        ar: 'رسوم ثابتة مقابل عمولة',
      );
  static String get financeSavingsHeyCabyFee => _t(
        'HeyCaby vaste vergoeding',
        en: 'HeyCaby flat fee',
        es: 'Tarifa fija HeyCaby',
        ar: 'رسوم HeyCaby الثابتة',
      );
  static String get financeSavingsOtherPlatform => _t(
        'Andere platforms tot 25% commissie',
        en: 'Other platforms up to 25% commission',
        es: 'Otras plataformas hasta 25% de comisión',
        ar: 'منصات أخرى تصل إلى 25% عمولة',
      );
  static String get financeSavingsYouSave => _t(
        'Jij bespaart',
        en: 'You save',
        es: 'Tú ahorras',
        ar: 'توفّر',
      );
  static String get financeSavingsPerMonth => _t(
        'per maand',
        en: 'per month',
        es: 'por mes',
        ar: 'شهرياً',
      );
  static String get financeSavingsPerYear => _t(
        'per jaar',
        en: 'per year',
        es: 'por año',
        ar: 'سنوياً',
      );
  static String get financeSavingsDescription => _t(
        'Bij andere platforms betaal je tot 25% commissie over elke rit. Bij HeyCaby betaal je een vaste vergoeding van €50 per week — ongeacht hoeveel je verdient. Hoe meer je rijdt, hoe meer je bespaart.',
        en: 'Other platforms charge up to 25% commission on every ride. With HeyCaby you pay a flat fee of €50 per week — no matter how much you earn. The more you drive, the more you save.',
        es: 'Otras plataformas cobran hasta 25% de comisión en cada viaje. Con HeyCaby pagas una tarifa fija de €50 por semana — sin importar cuánto ganes. Cuanto más conduces, más ahorras.',
        ar: 'تفرض المنصات الأخرى عمولة تصل إلى 25% على كل رحلة. مع HeyCaby تدفع رسوماً ثابتة قدرها 50 يورو أسبوعياً — بغض النظر عن مقدار أرباحك. كلما قُدت أكثر، وفّرت أكثر.',
      );
  static String get financeSavingsChartTitle => _t(
        'Kostenvergelijking',
        en: 'Cost comparison',
        es: 'Comparación de costos',
        ar: 'مقارنة التكاليف',
      );
  static String get financeSavingsWeeklyFee => _t(
        'Vaste vergoeding / week',
        en: 'Flat fee / week',
        es: 'Tarifa fija / semana',
        ar: 'رسوم ثابتة / أسبوع',
      );
  static String get financeSavingsCommissionRate => _t(
        'Commissiepercentage andere platforms',
        en: 'Other platforms commission rate',
        es: 'Tasa de comisión otras plataformas',
        ar: 'نسبة عمولة المنصات الأخرى',
      );
  static String get financeSavingsEstimatedCommission => _t(
        'Geschatte commissie bij andere platforms',
        en: 'Estimated commission on other platforms',
        es: 'Comisión estimada en otras plataformas',
        ar: 'العمولة المقدرة على المنصات الأخرى',
      );
  static String get financeSavingsHeyCabyCost => _t(
        'HeyCaby kosten',
        en: 'HeyCaby cost',
        es: 'Costo HeyCaby',
        ar: 'تكلفة HeyCaby',
      );
  static String get financeSavingsTotalSavings => _t(
        'Totale besparing',
        en: 'Total savings',
        es: 'Ahorro total',
        ar: 'إجمالي المدخرات',
      );

  // Finance — charts
  static String get financeChartIncomeBreakdown => _t(
        'Inkomstenverdeling',
        en: 'Income breakdown',
        es: 'Desglose de ingresos',
        ar: 'توزيع الدخل',
      );
  static String get financeChartRidesVsCancelled => _t(
        'Ritten vs geannuleerd',
        en: 'Rides vs cancelled',
        es: 'Viajes vs cancelados',
        ar: 'الرحلات مقابل الملغاة',
      );
  static String get financeChartEarningsTrend => _t(
        'Inkomsten trend',
        en: 'Earnings trend',
        es: 'Tendencia de ingresos',
        ar: 'اتجاه الأرباح',
      );

  // Finance — PDF structured sections
  static String get financePdfSectionDriverInfo => _t(
        'Bestuurder informatie',
        en: 'Driver information',
        es: 'Información del conductor',
        ar: 'معلومات السائق',
      );
  static String get financePdfSectionRideDetails => _t(
        'Ritdetails',
        en: 'Ride details',
        es: 'Detalles de viajes',
        ar: 'تفاصيل الرحلات',
      );
  static String get financePdfSectionSavings => _t(
        'Besparingsanalyse',
        en: 'Savings analysis',
        es: 'Análisis de ahorros',
        ar: 'تحليل المدخرات',
      );
  static String get financePdfColumnDate => _t(
        'Datum',
        en: 'Date',
        es: 'Fecha',
        ar: 'التاريخ',
      );
  static String get financePdfColumnFare => _t(
        'Ritprijs',
        en: 'Fare',
        es: 'Tarifa',
        ar: 'الأجرة',
      );
  static String get financePdfColumnTip => _t(
        'Fooi',
        en: 'Tip',
        es: 'Propina',
        ar: 'إكرامية',
      );
  static String get financePdfColumnKm => _t(
        'Km',
        en: 'Km',
        es: 'Km',
        ar: 'كم',
      );
  static String get financePdfColumnPayment => _t(
        'Betaling',
        en: 'Payment',
        es: 'Pago',
        ar: 'الدفع',
      );
  static String get financePdfColumnTotal => _t(
        'Totaal',
        en: 'Total',
        es: 'Total',
        ar: 'المجموع',
      );

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
  static String get communityNewPost => _t(
        'Nieuw bericht',
        en: 'New post',
        es: 'Nueva publicación',
        ar: 'منشور جديد',
      );
  static String get communityWelcomeDisclaimerTitle => _t(
        'Welkom bij de gemeenschap',
        en: 'Welcome to the community',
        es: 'Bienvenido a la comunidad',
        ar: 'مرحبا بك في المجتمع',
      );
  static String get communityWelcomeDisclaimerSubtitle => _t(
        'Lees dit voordat je deelneemt',
        en: 'Read this before joining',
        es: 'Lee esto antes de unirte',
        ar: 'اقرأ هذا قبل الانضمام',
      );
  static String get communityDisclaimerChannelsTitle => _t(
        'Kanalen',
        en: 'Channels',
        es: 'Canales',
        ar: 'القنوات',
      );
  static String get communityDisclaimerChannelsItem1 => _t(
        'Aankondigingen: officiële HeyCaby-updates',
        en: 'Announcements: official HeyCaby updates',
        es: 'Anuncios: actualizaciones oficiales de HeyCaby',
        ar: 'الإعلانات: تحديثات HeyCaby الرسمية',
      );
  static String get communityDisclaimerChannelsItem2 => _t(
        'Chauffeurpraat: gesprekken tussen chauffeurs',
        en: 'Driver talk: conversations between drivers',
        es: 'Charla de conductores: conversaciones entre conductores',
        ar: 'نقاش السائقين: محادثات بين السائقين',
      );
  static String get communityDisclaimerVisibilityTitle => _t(
        'Zichtbaarheid',
        en: 'Visibility',
        es: 'Visibilidad',
        ar: 'الظهور',
      );
  static String get communityDisclaimerVisibilityItem1 => _t(
        'Berichten zijn zichtbaar voor andere chauffeurs',
        en: 'Posts are visible to other drivers',
        es: 'Las publicaciones son visibles para otros conductores',
        ar: 'المنشورات مرئية للسائقين الآخرين',
      );
  static String get communityDisclaimerVisibilityItem2 => _t(
        'Dit is geen privéchat met medewerkers',
        en: 'This is not a private chat with staff',
        es: 'Esto no es un chat privado con el personal',
        ar: 'هذه ليست دردشة خاصة مع الموظفين',
      );
  static String get communityDisclaimerVisibilityItem3 => _t(
        'Gebruik Ondersteuning voor directe hulp',
        en: 'Use Support for direct help',
        es: 'Usa Soporte para ayuda directa',
        ar: 'استخدم الدعم للمساعدة المباشرة',
      );
  static String get communityDisclaimerDataTitle => _t(
        'Data en privacy',
        en: 'Data and privacy',
        es: 'Datos y privacidad',
        ar: 'البيانات والخصوصية',
      );
  static String get communityDisclaimerDataItem1 => _t(
        'Berichten worden verwerkt voor moderatie en veiligheid',
        en: 'Posts are processed for moderation and safety',
        es: 'Las publicaciones se procesan para moderación y seguridad',
        ar: 'تتم معالجة المنشورات للإشراف والسلامة',
      );
  static String get communityDisclaimerDataItem2 => _t(
        'Inhoud kan worden gemodereerd of verwijderd',
        en: 'Content may be moderated or removed',
        es: 'El contenido puede ser moderado o eliminado',
        ar: 'قد يتم الإشراف على المحتوى أو إزالته',
      );
  static String get communityDisclaimerDataItem3 => _t(
        'Er geldt een rollend bewaartermijn',
        en: 'A rolling retention period applies',
        es: 'Se aplica un período de retención continuo',
        ar: 'توجد فترة احتفاظ متجددة',
      );
  static String get communityDisclaimerConductTitle => _t(
        'Gedrag',
        en: 'Conduct',
        es: 'Conducta',
        ar: 'السلوك',
      );
  static String get communityDisclaimerConductItem1 => _t(
        'Geen intimidatie, haatzaaien of bedreigingen',
        en: 'No harassment, hate speech, or threats',
        es: 'No acoso, discurso de odio ni amenazas',
        ar: 'لا مضايقة ولا خطاب كراهية ولا تهديدات',
      );
  static String get communityDisclaimerConductItem2 => _t(
        'Geen fraude of onveilige adviezen',
        en: 'No fraud or unsafe advice',
        es: 'No fraude ni consejos inseguros',
        ar: 'لا احتيال ولا نصائح غير آمنة',
      );
  static String get communityDisclaimerConductItem3 => _t(
        'Spam of misbruik kan tot beperkingen leiden',
        en: 'Spam or abuse may lead to restrictions',
        es: 'Spam o abuso puede llevar a restricciones',
        ar: 'قد يؤدي الإسعاء أو إساءة الاستخدام إلى قيود',
      );
  static String get communityDisclaimerAgreeCheckbox => _t(
        'Ik ga akkoord met de Algemene voorwaarden en het privacybeleid',
        en: 'I agree to the Terms and privacy policy',
        es: 'Acepto los Términos y la política de privacidad',
        ar: 'أوافق على الشروط وسياسة الخصوصية',
      );
  static String get communityContactSupport => _t(
        'Contact ondersteuning',
        en: 'Contact support',
        es: 'Contactar soporte',
        ar: 'تواصل مع الدعم',
      );
  static String get communityJoin => _t(
        'Deelnemen',
        en: 'Join',
        es: 'Unirse',
        ar: 'انضمام',
      );
  static String get communityOpeningEmailClient => _t(
        'E-mailapp openen…',
        en: 'Opening email app…',
        es: 'Abriendo app de correo…',
        ar: 'جاري فتح تطبيق البريد…',
      );
  static String get communityEditPostTitle => _t(
        'Bericht bewerken',
        en: 'Edit post',
        es: 'Editar publicación',
        ar: 'تعديل المنشور',
      );
  static String get communityEditPostHint => _t(
        'Pas je bericht aan',
        en: 'Edit your post',
        es: 'Edita tu publicación',
        ar: 'عدّل منشورك',
      );
  static String get communityDeletePostTitle => _t(
        'Bericht verwijderen?',
        en: 'Delete post?',
        es: '¿Eliminar publicación?',
        ar: 'حذف المنشور؟',
      );
  static String get communityDeletePostBody => _t(
        'Hiermee wordt je bericht uit de chauffeursgemeenschap gehaald.',
        en: 'This removes your post from the driver community.',
        es: 'Esto elimina tu publicación de la comunidad de conductores.',
        ar: 'هذا يزيل منشورك من مجتمع السائقين.',
      );
  static String get communityDeleteAction => _t(
        'Verwijderen',
        en: 'Delete',
        es: 'Eliminar',
        ar: 'حذف',
      );
  static String get communityClose => _t(
        'Sluiten',
        en: 'Close',
        es: 'Cerrar',
        ar: 'إغلاق',
      );
  static String get communityViewAll => _t(
        'Bekijk alles',
        en: 'View all',
        es: 'Ver todo',
        ar: 'عرض الكل',
      );
  static String get communityFeedLoadFailed => _t(
        'Berichten laden mislukt.',
        en: 'Failed to load posts.',
        es: 'Error al cargar publicaciones.',
        ar: 'فشل تحميل المنشورات.',
      );
  static String get communityFeedEmptyAnnouncements => _t(
        'Nog geen aankondigingen.',
        en: 'No announcements yet.',
        es: 'Sin anuncios todavía.',
        ar: 'لا توجد إعلانات بعد.',
      );
  static String get communityFeedEmptyTalk => _t(
        'Nog geen berichten in Chauffeurpraat.',
        en: 'No posts in Driver Talk yet.',
        es: 'Sin publicaciones en Charla de conductores.',
        ar: 'لا توجد منشورات في نقاش السائقين بعد.',
      );
  static String get communityNotificationsLoadFailed => _t(
        'Meldingen laden mislukt.',
        en: 'Notifications load failed.',
        es: 'Error al cargar notificaciones.',
        ar: 'فشل تحميل الإشعارات.',
      );
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
  static String get communityPostChipTraffic => _t(
        'Verkeer melden',
        en: 'Report traffic',
        es: 'Reportar tráfico',
        ar: 'الإبلاغ عن المرور',
      );
  static String get communityPostChipTip => _t(
        'Tip delen',
        en: 'Share tip',
        es: 'Compartir consejo',
        ar: 'مشاركة نصيحة',
      );
  static String get communityPostChipHelp => _t(
        'Hulp vragen',
        en: 'Ask for help',
        es: 'Pedir ayuda',
        ar: 'طلب المساعدة',
      );
  static String get communityPostChipGeneral => _t(
        'Algemeen',
        en: 'General',
        es: 'General',
        ar: 'عام',
      );
  static String get communityCreateKindText => _t(
        'Bericht',
        en: 'Post',
        es: 'Publicación',
        ar: 'منشور',
      );
  static String get communityCreateKindPoll => _t(
        'Peiling',
        en: 'Poll',
        es: 'Encuesta',
        ar: 'استطلاع',
      );
  static String get communityPostMessageHint => _t(
        'Schrijf je bericht…',
        en: 'Write your post…',
        es: 'Escribe tu publicación…',
        ar: 'اكتب منشورك…',
      );
  static String get communityPostMessageRequired => _t(
        'Schrijf een bericht.',
        en: 'Write a post.',
        es: 'Escribe una publicación.',
        ar: 'اكتب منشورا.',
      );
  static String get communityPollLabel => _t(
        'Peiling',
        en: 'Poll',
        es: 'Encuesta',
        ar: 'استطلاع',
      );
  static String get communityPollWeightedHint => _t(
        'Founding-leden: jouw stem telt zwaarder (×3 gewicht). Punten zijn gewogen.',
        en: 'Founding members: your vote counts more (×3 weight). Points are weighted.',
        es: 'Miembros fundadores: tu voto cuenta más (×3 peso). Los puntos son ponderados.',
        ar: 'الأعضاء المؤسسون: صوتك يحسب أكثر (×3 وزن). النقاط مرجحة.',
      );
  static String get communityPollQuestionHint => _t(
        'Je vraag of stelling…',
        en: 'Your question or statement…',
        es: 'Tu pregunta o afirmación…',
        ar: 'سؤالك أو طرحك…',
      );
  static String get communityPollOptionHint => _t(
        'Antwoord…',
        en: 'Answer…',
        es: 'Respuesta…',
        ar: 'إجابة…',
      );
  static String get communityPollAddOption => _t(
        'Antwoord toevoegen',
        en: 'Add answer',
        es: 'Añadir respuesta',
        ar: 'إضافة إجابة',
      );
  static String get communityPollNeedTwoOptions => _t(
        'Voeg minimaal twee antwoorden toe.',
        en: 'Add at least two answers.',
        es: 'Añade al menos dos respuestas.',
        ar: 'أضف إجابتين على الأقل.',
      );
  static String get communityPollVoteFailed => _t(
        'Stem opslaan mislukt.',
        en: 'Failed to save vote.',
        es: 'Error al guardar voto.',
        ar: 'فشل حفظ التصويت.',
      );
  static String communityPollVoteCount(int n) =>
      n == 1 ? '1 stem' : '$n stemmen';
  static String get communityPostLegacyUntitled => _t(
        'Bericht',
        en: 'Post',
        es: 'Publicación',
        ar: 'منشور',
      );
  static String get communityPostLegacyNearby => _t(
        'Locatie onbekend',
        en: 'Location unknown',
        es: 'Ubicación desconocida',
        ar: 'الموقع غير معروف',
      );

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

  static String get communityMenuEdit => _t(
        'Bewerken',
        en: 'Edit',
        es: 'Editar',
        ar: 'تعديل',
      );
  static String get communityMenuDelete => _t(
        'Verwijderen',
        en: 'Delete',
        es: 'Eliminar',
        ar: 'حذف',
      );
  static String get communityPostNotSentSnack => _t(
        'Bericht niet verzonden. Strikte limiet tegen spam.',
        en: 'Post not sent. Strict anti-spam limit.',
        es: 'Publicación no enviada. Límite estricto anti-spam.',
        ar: 'لم يتم إرسال المنشور. حد صارم ضد الإسعاء.',
      );
  static String get communitySearchNoLiveResults => _t(
        'Geen live resultaten.',
        en: 'No live results.',
        es: 'Sin resultados en vivo.',
        ar: 'لا توجد نتائج مباشرة.',
      );
  static String get communitySearchNoCategoryResults => _t(
        'Geen resultaten voor deze categorie.',
        en: 'No results for this category.',
        es: 'Sin resultados para esta categoría.',
        ar: 'لا توجد نتائج لهذه الفئة.',
      );
  static String get communityPostPreviewFallback => _t(
        'Gemeenschapsbericht',
        en: 'Community post',
        es: 'Publicación de comunidad',
        ar: 'منشور مجتمعي',
      );
  static String get communityCategoryAll => _t(
        'Alle',
        en: 'All',
        es: 'Todos',
        ar: 'الكل',
      );
  static String get communityCategoryTraffic => _t(
        'Verkeer',
        en: 'Traffic',
        es: 'Tráfico',
        ar: 'المرور',
      );
  static String get communityCategoryTips => _t(
        'Tips',
        en: 'Tips',
        es: 'Consejos',
        ar: 'نصائح',
      );
  static String get communityCategorySafety => _t(
        'Veiligheid',
        en: 'Safety',
        es: 'Seguridad',
        ar: 'السلامة',
      );
  static String get communityCategoryHelp => _t(
        'Hulp',
        en: 'Help',
        es: 'Ayuda',
        ar: 'المساعدة',
      );
  static String get communityCategoryGeneral => _t(
        'Algemeen',
        en: 'General',
        es: 'General',
        ar: 'عام',
      );
  static String get timeJustNow => _t(
        'Nu',
        en: 'Now',
        es: 'Ahora',
        ar: 'الآن',
      );
  static String timeMinutesAgo(int m) => _t('$m min geleden',
      en: '$m min ago', es: 'Hace $m min', ar: 'قبل $m دقيقة');
  static String timeHoursAgo(int h) =>
      _t('$h u geleden', en: '$h h ago', es: 'Hace $h h', ar: 'قبل $h ساعة');
  static String timeDaysAgo(int d) =>
      _t('$d d geleden', en: '$d d ago', es: 'Hace $d d', ar: 'قبل $d يوما');

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
  static String get openReturnRides => _t(
        'Open terugritten',
        en: 'Open return rides',
        es: 'Abrir viajes de vuelta',
        ar: 'فتح رحلات العودة',
      );

  // Feature tour (first-run sheet, NL default)
  static String get featureTourSkip => _t(
        'Overslaan',
        en: 'Skip',
        es: 'Omitir',
        ar: 'تخطي',
      );
  static String get featureTourNext => _t(
        'Volgende',
        en: 'Next',
        es: 'Siguiente',
        ar: 'التالي',
      );
  static String get featureTourStartNow => _t(
        'Nu starten',
        en: 'Start now',
        es: 'Empezar ahora',
        ar: 'ابدأ الآن',
      );
  static String get featureTour1Kicker => _t(
        'Welkom',
        en: 'Welcome',
        es: 'Bienvenido',
        ar: 'مرحبا',
      );
  static String get featureTour1Heading => _t(
        'Jij bent eindelijk de baas',
        en: 'You\'re finally the boss',
        es: 'Por fin eres el jefe',
        ar: 'أنت أخيرا المدير',
      );
  static String get featureTour1Body => _t(
        'Werk wanneer jij wilt, pauzeer wanneer jij wilt, en bouw jouw eigen zaak op jouw manier.',
        en: 'Work when you want, break when you want, and build your business your way.',
        es: 'Trabaja cuando quieras, descansa cuando quieras, y construye tu negocio a tu manera.',
        ar: 'اعمل متى شئت، استرح متى شئت، وابنِ عملك بطريقتك.',
      );
  static String get featureTour2Kicker => _t(
        'Tarieven',
        en: 'Rates',
        es: 'Tarifas',
        ar: 'الأسعار',
      );
  static String get featureTour2Heading => _t(
        'Stel je vier eigen prijzen in',
        en: 'Set your four own prices',
        es: 'Configura tus cuatro precios',
        ar: 'حدد أسعارك الأربعة',
      );
  static String get featureTour2Body => _t(
        'Jij bepaalt alles: basistarief, prijs per kilometer, prijs per minuut en wachttijdprijs.',
        en: 'You decide everything: base fare, price per kilometre, price per minute, and wait time price.',
        es: 'Tú decides todo: tarifa base, precio por kilómetro, precio por minuto y precio de espera.',
        ar: 'أنت تحدد كل شيء: الأجرة الأساسية والسعر لكل كيلومتر والسعر لكل دقيقة وسعر الانتظار.',
      );
  static String get featureTour3Kicker => _t(
        'Gemeenschap',
        en: 'Community',
        es: 'Comunidad',
        ar: 'المجتمع',
      );
  static String get featureTour3Heading => _t(
        'Deel met collega-chauffeurs',
        en: 'Share with fellow drivers',
        es: 'Comparte con otros conductores',
        ar: 'شارك مع الزملاء السائقين',
      );
  static String get featureTour3Body => _t(
        'Nodig andere chauffeurs uit. Hoe meer chauffeurs op het platform, hoe meer passagiers het vertrouwen en gebruiken.',
        en: 'Invite other drivers. The more drivers on the platform, the more riders trust and use it.',
        es: 'Invita a otros conductores. Cuantos más conductores haya, más pasajeros confiarán y usarán la plataforma.',
        ar: 'ادعُ سائقين آخرين. كلما زاد عدد السائقين على المنصة، زاد ثقة الركاب واستخدامهم لها.',
      );
  static String get featureTour4Kicker => _t(
        'Platformbalans',
        en: 'Platform balance',
        es: 'Saldo de plataforma',
        ar: 'رصيد المنصة',
      );
  static String get featureTour4Heading => _t(
        'Werk eerst, vereffen later',
        en: 'Work first, settle later',
        es: 'Trabaja primero, liquida después',
        ar: 'اعمل أولاً، ثم ساوِ لاحقا',
      );
  static String get featureTour4Body => _t(
        'HeyCaby toont alleen een openstaand platformsaldo wanneer er echt iets te vereffenen is. Nieuwe ritverzoeken pauzeren pas als dat saldo na de betaaltermijn open blijft.',
        en: 'HeyCaby only shows an outstanding platform balance when there\'s actually something to settle. New ride requests only pause if that balance remains open after the payment period.',
        es: 'HeyCaby solo muestra un saldo pendiente cuando hay algo que liquidar. Las nuevas solicitudes solo se pausan si el saldo sigue abierto tras el período de pago.',
        ar: 'يعرض HeyCaby رصيد منصة مستحقا فقط عندما يكون هناك ما يسوى. يتم إيقاف طلبات الرحلات الجديدة فقط إذا بقي الرصيد مستحقا بعد فترة الدفع.',
      );
  static String get featureTour5Kicker => _t(
        'Founding-leden',
        en: 'Founding members',
        es: 'Miembros fundadores',
        ar: 'الأعضاء المؤسسون',
      );
  static String get featureTour5Heading => _t(
        'Foundingplaatsen zijn beperkt',
        en: 'Founding spots are limited',
        es: 'Plazas de fundador son limitadas',
        ar: 'أماكن العضوية المؤسسة محدودة',
      );
  static String get featureTour5Body => _t(
        'Founding-lidmaatschap is beperkt. Activeer je account, vul je profiel aan en claim vroegtijdig je plek.',
        en: 'Founding membership is limited. Activate your account, complete your profile, and claim your spot early.',
        es: 'La membresía fundadora es limitada. Activa tu cuenta, completa tu perfil y reclama tu plaza pronto.',
        ar: 'العضوية المؤسسة محدودة. فعّل حسابك وأكمل ملفك واحجز مكانك مبكرا.',
      );
  static String get featureTour6Kicker => _t(
        'Belangrijk',
        en: 'Important',
        es: 'Importante',
        ar: 'مهم',
      );
  static String get featureTour6Heading => _t(
        'Lees eerst de voorwaarden en privacy',
        en: 'Read the terms and privacy first',
        es: 'Lee primero los términos y privacidad',
        ar: 'اقرأ الشروط والخصوصية أولا',
      );
  static String get featureTour6Body => _t(
        'Lees en begrijp alle algemene voorwaarden en privacyteksten voordat je het platform gebruikt. Verifieer daarna je documenten en ga online.',
        en: 'Read and understand all terms and privacy texts before using the platform. Then verify your documents and go online.',
        es: 'Lee y entiende todos los términos y textos de privacidad antes de usar la plataforma. Luego verifica tus documentos y conéctate.',
        ar: 'اقرأ وافهم جميع الشروط ونصوص الخصوصية قبل استخدام المنصة. ثم تحقق من مستنداتك واتصل.',
      );

  // ── Saved by Riders (driver-side favorite feedback) ──
  static String get savedByRidersTitle => _t(
        'Opgeslagen door passagiers',
        en: 'Saved by Riders',
        es: 'Guardado por pasajeros',
        ar: 'محفوظ من قبل الركاب',
      );
  static String get savedByRidersSubtitle => _t(
        'Passagiers die je toevoegen aan hun favorieten',
        en: 'Riders who added you to their favorites',
        es: 'Pasajeros que te añadieron a sus favoritos',
        ar: 'الركاب الذين أضافوك إلى المفضلين',
      );
  static String savedByRidersTotal(int n) => _t(
        '$n passagiers hebben je opgeslagen',
        en: '$n riders saved you',
        es: '$n pasajeros te guardaron',
        ar: '$n راكب حفظك',
      );
  static String savedByRidersThisWeek(int n) => _t(
        '+$n deze week',
        en: '+$n this week',
        es: '+$n esta semana',
        ar: '+$n هذا الأسبوع',
      );
  static String get savedByRidersKeepItUp => _t(
        'Blijf geweldige service leveren.',
        en: 'Keep delivering great service.',
        es: 'Sigue brindando un excelente servicio.',
        ar: 'استمر في تقديم خدمة رائعة.',
      );
  static String get savedByRidersRecent => _t(
        'Recent',
        en: 'Recent',
        es: 'Reciente',
        ar: 'الأخيرة',
      );
  static String get savedByRidersMicrocopy => _t(
        'Passagiers die je opslaan kunnen je de volgende keer eerst vragen.',
        en: 'Riders who save you can request you first next time.',
        es: 'Los pasajeros que te guardan pueden solicitarte primero la próxima vez.',
        ar: 'الركاب الذين يحفظونك يمكنهم طلبك أولاً في المرة القادمة.',
      );
  static String savedByRiderEntry(String name, String when) => _t(
        '$name · $when',
        en: '$name · $when',
        es: '$name · $when',
        ar: '$name · $when',
      );
  static String get savedByRidersToday => _t(
        'Vandaag',
        en: 'Today',
        es: 'Hoy',
        ar: 'اليوم',
      );
  static String get savedByRidersYesterday => _t(
        'Gisteren',
        en: 'Yesterday',
        es: 'Ayer',
        ar: 'أمس',
      );
  static String get savedByRidersDaysAgo => _t(
        'dagen geleden',
        en: 'days ago',
        es: 'días atrás',
        ar: 'أيام مضت',
      );

  static String get ridesFilterAll => _t(
        'Alle',
        en: 'All',
        es: 'Todos',
        ar: 'الكل',
      );
  static String get ridesFilterCompleted => _t(
        'Voltooid',
        en: 'Completed',
        es: 'Completados',
        ar: 'مكتملة',
      );
  static String get ridesFilterCancelled => _t(
        'Geannuleerd',
        en: 'Cancelled',
        es: 'Cancelados',
        ar: 'ملغاة',
      );
  static String get ridesFilterUpcoming => _t(
        'Aankomend',
        en: 'Upcoming',
        es: 'Próximos',
        ar: 'القادمة',
      );
  static String get noCompletedRides => _t(
        'Nog geen voltooide ritten.',
        en: 'No completed rides yet.',
        es: 'Aún no hay viajes completados.',
        ar: 'لا توجد رحلات مكتملة بعد.',
      );
  static String get noCancelledRides => _t(
        'Nog geen geannuleerde ritten.',
        en: 'No cancelled rides yet.',
        es: 'Aún no hay viajes cancelados.',
        ar: 'لا توجد رحلات ملغاة بعد.',
      );
  static String get noUpcomingRides => _t(
        'Nog geen aankomende ritten.',
        en: 'No upcoming rides yet.',
        es: 'Aún no hay viajes próximos.',
        ar: 'لا توجد رحلات قادمة بعد.',
      );

  // ─── Journey Intent ────────────────────────────────────────────────
  static String get journeyIntentTitle => _t(
        'Rit plannen',
        en: 'Plan a trip',
        es: 'Planear un viaje',
        ar: 'تخطيط رحلة',
      );
  static String get journeyIntentSubtitle => _t(
        'Stel uw bestemming en vertrektijd in om ritten onderweg te vinden.',
        en: 'Set your destination and departure time to find rides along the way.',
        es: 'Configura tu destino y hora de salida para encontrar viajes en el camino.',
        ar: 'حدد وجهتك ووقت المغادرة للعثور على رحلات في الطريق.',
      );
  static String get journeyIntentTypeLabel => _t(
        'Type rit',
        en: 'Trip type',
        es: 'Tipo de viaje',
        ar: 'نوع الرحلة',
      );
  static String get journeyIntentTypeBody => _t(
        'Waar gaat u heen?',
        en: 'Where are you heading?',
        es: '¿Hónde vas?',
        ar: 'إلى أين تتجه؟',
      );
  static String get journeyIntentTypeHome => _t(
        'Huis',
        en: 'Home',
        es: 'Casa',
        ar: 'المنزل',
      );
  static String get journeyIntentTypeAirport => _t(
        'Luchthaven',
        en: 'Airport',
        es: 'Aeropuerto',
        ar: 'المطار',
      );
  static String get journeyIntentTypeCity => _t(
        'Stad',
        en: 'City',
        es: 'Ciudad',
        ar: 'المدينة',
      );
  static String get journeyIntentTypeCustom => _t(
        'Anders',
        en: 'Custom',
        es: 'Personalizado',
        ar: 'مخصص',
      );
  static String get journeyIntentDestinationLabel => _t(
        'Bestemming',
        en: 'Destination',
        es: 'Destino',
        ar: 'الوجهة',
      );
  static String get journeyIntentDestinationHint => _t(
        'Zoek een bestemming...',
        en: 'Search a destination...',
        es: 'Buscar un destino...',
        ar: 'ابحث عن وجهة...',
      );
  static String get journeyIntentDestinationSet => _t(
        'Bestemming ingesteld',
        en: 'Destination set',
        es: 'Destino configurado',
        ar: 'تم تحديد الوجهة',
      );
  static String get journeyIntentDepartureLabel => _t(
        'Vertrektijd',
        en: 'Departure time',
        es: 'Hora de salida',
        ar: 'وقت المغادرة',
      );
  static String get journeyIntentDepartureBody => _t(
        'Wanneer wilt u vertrekken?',
        en: 'When do you want to leave?',
        es: '¿Cuándo quieres salir?',
        ar: 'متى تريد المغادرة؟',
      );
  static String get journeyIntentDepartureNow => _t(
        'Nu',
        en: 'Now',
        es: 'Ahora',
        ar: 'الآن',
      );
  static String get journeyIntentDepartureIn30 => _t(
        'Over 30 min',
        en: 'In 30 min',
        es: 'En 30 min',
        ar: 'خلال 30 دقيقة',
      );
  static String get journeyIntentDepartureIn60 => _t(
        'Over 1 uur',
        en: 'In 1 hour',
        es: 'En 1 hora',
        ar: 'خلال ساعة',
      );
  static String get journeyIntentDepartureCustom => _t(
        'Kies tijd',
        en: 'Pick time',
        es: 'Elegir hora',
        ar: 'اختر وقتاً',
      );
  static String get journeyIntentRadiusLabel => _t(
        'Bereik',
        en: 'Range',
        es: 'Rango',
        ar: 'النطاق',
      );
  static String get journeyIntentPickupRadius => _t(
        'Ophaalradius',
        en: 'Pickup radius',
        es: 'Radio de recogida',
        ar: 'نطاق الالتقاط',
      );
  static String get journeyIntentDestinationRadius => _t(
        'Bestemmingsradius',
        en: 'Destination radius',
        es: 'Radio de destino',
        ar: 'نطاق الوجهة',
      );
  static String get journeyIntentDiscountLabel => _t(
        'Korting',
        en: 'Discount',
        es: 'Descuento',
        ar: 'الخصم',
      );
  static String get journeyIntentDiscountBody => _t(
        'Bied ridders korting om sneller een match te vinden.',
        en: 'Offer riders a discount to get matched faster.',
        es: 'Ofrece un descuento a los pasajeros para coincidir más rápido.',
        ar: 'قدم خصماً للركاب للحصول على تطابق أسرع.',
      );
  static String get journeyIntentActivate => _t(
        'Taxi Terug activeren',
        en: 'Activate Taxi Terug',
        es: 'Activar Taxi Terug',
        ar: 'تفعيل Taxi Terug',
      );
  static String get journeyIntentActivating => _t(
        'Activeren...',
        en: 'Activating...',
        es: 'Activando...',
        ar: 'جاري التفعيل...',
      );
  static String get journeyIntentPickDestination => _t(
        'Kies eerst een bestemming.',
        en: 'Please pick a destination first.',
        es: 'Por favor, elige un destino primero.',
        ar: 'يرجى اختيار وجهة أولاً.',
      );
  static String get journeyIntentPlanTrip => _t(
        'Rit plannen',
        en: 'Plan a trip',
        es: 'Planear un viaje',
        ar: 'تخطيط رحلة',
      );
  static String get journeyIntentDepartureTooFar => _t(
        'Vertrektijd is te ver in de toekomst.',
        en: 'Departure time is too far in the future.',
        es: 'La hora de salida está demasiado lejos en el futuro.',
        ar: 'وقت المغادرة بعيد جداً في المستقبل.',
      );

  // ─── Taxi Thru (driver browse rider posts) ──────────────────────────
  static String get taxiThruTitle => _t(
        'Taxi Thru',
        en: 'Taxi Thru',
        es: 'Taxi Thru',
        ar: 'Taxi Thru',
      );
  static String get taxiThruEmpty => _t(
        'Geen riterposts gevonden. Trek om te vernieuwen.',
        en: 'No rider posts found. Pull to refresh.',
        es: 'No se encontraron publicaciones de pasajeros. Desliza para actualizar.',
        ar: 'لا توجد منشورات للركاب. اسحب للتحديث.',
      );
  static String get taxiThruDisabled => _t(
        'Taxi Thru is momenteel niet beschikbaar.',
        en: 'Taxi Thru is currently unavailable.',
        es: 'Taxi Thru no está disponible actualmente.',
        ar: 'Taxi Thru غير متاح حالياً.',
      );
  static String get taxiThruLoadError => _t(
        'Kan posts niet laden. Controleer je verbinding.',
        en: 'Could not load posts. Check your connection.',
        es: 'No se pudieron cargar las publicaciones. Verifica tu conexión.',
        ar: 'تعذر تحميل المنشورات. تحقق من اتصالك.',
      );
  static String get taxiThruRetry => _t(
        'Opnieuw proberen',
        en: 'Try again',
        es: 'Intentar de nuevo',
        ar: 'حاول مرة أخرى',
      );
  static String get taxiThruAccept => _t(
        'Accepteren',
        en: 'Accept',
        es: 'Aceptar',
        ar: 'قبول',
      );
}
