import 'package:flutter/material.dart';

/// Localized copy for the driver TAF (Tell a friend) invite flow.
/// Matches [supportedLanguageCodes] in [driver_locale_provider.dart].
class DriverTellFriendStrings {
  const DriverTellFriendStrings({
    required this.navLabel,
    required this.screenTitle,
    required this.headline,
    required this.bullet1,
    required this.bullet2,
    required this.bullet3,
    required this.copyLink,
    required this.shareLink,
    required this.linkCopied,
    required this.shareSubject,
    required this.shareMessage,
    required this.linkUnavailable,
    required this.linkUnavailableHint,
    required this.inviteLinkLabel,
    required this.linkResolving,
  });

  /// Bottom navigation label (short).
  final String navLabel;

  /// App bar title.
  final String screenTitle;

  final String headline;

  final String bullet1;
  final String bullet2;
  final String bullet3;

  final String inviteLinkLabel;

  /// Shown while fetching short `/i/xxxxxxx` code from Supabase.
  final String linkResolving;

  final String copyLink;
  final String shareLink;
  final String linkCopied;

  /// OS share sheet subject / preview title.
  final String shareSubject;

  /// Body text before the URL is appended in the UI.
  final String shareMessage;

  final String linkUnavailable;
  final String linkUnavailableHint;
}

const _en = DriverTellFriendStrings(
  navLabel: 'TAF',
  screenTitle: 'Tell a friend',
  headline: 'Grow demand on your routes.',
  bullet1: 'More locals on HeyCaby mean trips where you already drive.',
  bullet2: 'Invites show real demand and build trust with other drivers.',
  bullet3: 'Share your link below with regulars and friends you trust.',
  inviteLinkLabel: 'Your invite link',
  linkResolving: 'Getting your short invite link…',
  copyLink: 'Copy link',
  shareLink: 'Share invite',
  linkCopied: 'Link copied',
  shareSubject: 'HeyCaby — grow local demand together',
  shareMessage:
      'I drive on HeyCaby — a community rides network. More locals on the app means steadier trips for drivers and faster pickups for riders. Here is my invite:',
  linkUnavailable: 'Link not ready yet',
  linkUnavailableHint: 'Open this screen again in a moment, or restart the app.',
);

const _nl = DriverTellFriendStrings(
  navLabel: 'TAF',
  screenTitle: 'Vertel het door',
  headline: 'Laat de vraag op jouw routes groeien.',
  bullet1: 'Meer mensen uit de buurt op HeyCaby = meer ritten waar jij rijdt.',
  bullet2: 'Uitnodigingen tonen echte vraag en vertrouwen bij andere chauffeurs.',
  bullet3: 'Deel je link hieronder met vaste klanten en vrienden die je vertrouwt.',
  inviteLinkLabel: 'Jouw uitnodigingslink',
  linkResolving: 'Je korte uitnodigingslink ophalen…',
  copyLink: 'Link kopiëren',
  shareLink: 'Uitnodiging delen',
  linkCopied: 'Link gekopieerd',
  shareSubject: 'HeyCaby — laten we lokale vraag laten groeien',
  shareMessage:
      'Ik rijd met HeyCaby — een communityrit-netwerk. Meer mensen uit de buurt op de app betekent rustigere ritten voor chauffeurs en snellere pickups voor passagiers. Hier is mijn uitnodiging:',
  linkUnavailable: 'Link nog niet beschikbaar',
  linkUnavailableHint: 'Probeer het zo opnieuw of start de app opnieuw.',
);

const _de = DriverTellFriendStrings(
  navLabel: 'TAF',
  screenTitle: 'Freunde einladen',
  headline: 'Mehr Nachfrage auf deinen Strecken.',
  bullet1: 'Mehr Menschen aus der Gegend auf HeyCaby = mehr Fahrten, wo du fährst.',
  bullet2: 'Einladungen zeigen echte Nachfrage und Vertrauen bei anderen Fahrern.',
  bullet3: 'Teile deinen Link unten mit Stammkunden und Freunden, denen du vertraust.',
  inviteLinkLabel: 'Dein Einladungslink',
  linkResolving: 'Kurzer Einladungslink wird geladen…',
  copyLink: 'Link kopieren',
  shareLink: 'Einladung teilen',
  linkCopied: 'Link kopiert',
  shareSubject: 'HeyCaby — gemeinsam lokale Nachfrage stärken',
  shareMessage:
      'Ich fahre mit HeyCaby — einem Community-Fahrdienst. Mehr Menschen aus der Gegend auf der App bedeutet ruhigere Auslastung für Fahrer und schnellere Abholungen für Fahrgäste. Hier ist meine Einladung:',
  linkUnavailable: 'Link noch nicht bereit',
  linkUnavailableHint: 'Versuche es gleich erneut oder starte die App neu.',
);

const _fr = DriverTellFriendStrings(
  navLabel: 'TAF',
  screenTitle: 'Parler autour de soi',
  headline: 'Développez la demande sur vos trajets.',
  bullet1: 'Plus de monde du quartier sur HeyCaby = plus de courses où vous roulez.',
  bullet2: 'Les invitations montrent une vraie demande et rassurent les autres chauffeurs.',
  bullet3: 'Partagez votre lien ci-dessous avec habitués et amis de confiance.',
  inviteLinkLabel: 'Votre lien d’invitation',
  linkResolving: 'Récupération de votre lien court…',
  copyLink: 'Copier le lien',
  shareLink: 'Partager l’invitation',
  linkCopied: 'Lien copié',
  shareSubject: 'HeyCaby — développons la demande locale ensemble',
  shareMessage:
      'Je roule avec HeyCaby — un réseau de courses communautaires. Plus de monde du quartier sur l’app, c’est des courses plus régulières pour les chauffeurs et des prises en charge plus rapides pour les passagers. Voici mon invitation :',
  linkUnavailable: 'Lien pas encore prêt',
  linkUnavailableHint: 'Réessayez dans un instant ou redémarrez l’application.',
);

const _es = DriverTellFriendStrings(
  navLabel: 'TAF',
  screenTitle: 'Invitar amigos',
  headline: 'Aumenta la demanda en tus rutas.',
  bullet1: 'Más gente del barrio en HeyCaby = más viajes donde ya conduces.',
  bullet2: 'Las invitaciones muestran demanda real y confianza entre conductores.',
  bullet3: 'Comparte tu enlace abajo con clientes habituales y amigos de confianza.',
  inviteLinkLabel: 'Tu enlace de invitación',
  linkResolving: 'Obteniendo tu enlace corto…',
  copyLink: 'Copiar enlace',
  shareLink: 'Compartir invitación',
  linkCopied: 'Enlace copiado',
  shareSubject: 'HeyCaby — hagamos crecer la demanda local juntos',
  shareMessage:
      'Conduzco en HeyCaby — una red de viajes comunitarios. Más gente del barrio en la app significa viajes más estables para conductores y recogidas más rápidas para pasajeros. Aquí va mi invitación:',
  linkUnavailable: 'Enlace aún no disponible',
  linkUnavailableHint: 'Vuelve a intentarlo en un momento o reinicia la app.',
);

const _ar = DriverTellFriendStrings(
  navLabel: 'TAF',
  screenTitle: 'أخبر صديقًا',
  headline: 'زِد الطلب على طرقاتك.',
  bullet1: 'المزيد من أهل الحي على HeyCaby يعني رحلات أكثر حيث تقود.',
  bullet2: 'الدعوات تُظهر طلبًا حقيقيًا وتبني ثقة مع السائقين الآخرين.',
  bullet3: 'شارك رابطك أدناه مع زبائن دائمين وأصدقاء تثق بهم.',
  inviteLinkLabel: 'رابط دعوتك',
  linkResolving: 'جاري إعداد رابط الدعوة القصير…',
  copyLink: 'نسخ الرابط',
  shareLink: 'مشاركة الدعوة',
  linkCopied: 'تم نسخ الرابط',
  shareSubject: 'HeyCaby — لننمّ الطلب المحلي معًا',
  shareMessage:
      'أقود على HeyCaby — شبكة رحلات مجتمعية. المزيد من أهل الحي على التطبيق يعني رحلات أوضح للسائقين واستلامًا أسرع للركاب. إليك رابط دعوتي:',
  linkUnavailable: 'الرابط غير جاهز بعد',
  linkUnavailableHint: 'حاول مرة أخرى بعد لحظات أو أعد تشغيل التطبيق.',
);

const _tr = DriverTellFriendStrings(
  navLabel: 'TAF',
  screenTitle: 'Arkadaşına söyle',
  headline: 'Güzergâhlarında talebi büyüt.',
  bullet1: 'Mahallede daha çok HeyCaby kullanıcısı = zaten sürdüğün bölgelerde daha çok iş.',
  bullet2: 'Davetler gerçek talebi gösterir ve diğer sürücülerle güven oluşturur.',
  bullet3: 'Bağlantını aşağıdan düzenli yolcularınla ve güvendiğin arkadaşlarınla paylaş.',
  inviteLinkLabel: 'Davet bağlantın',
  linkResolving: 'Kısa davet bağlantısı alınıyor…',
  copyLink: 'Bağlantıyı kopyala',
  shareLink: 'Daveti paylaş',
  linkCopied: 'Bağlantı kopyalandı',
  shareSubject: 'HeyCaby — yerel talebi birlikte büyütelim',
  shareMessage:
      'HeyCaby’de sürüyorum — topluluk odaklı bir yolculuk ağı. Mahalleden daha çok kişi uygulamada olunca sürücüler için daha istikrarlı işler, yolcular için daha hızlı karşılama demek. İşte davetim:',
  linkUnavailable: 'Bağlantı henüz hazır değil',
  linkUnavailableHint: 'Biraz sonra tekrar dene veya uygulamayı yeniden başlat.',
);

final Map<String, DriverTellFriendStrings> _driverTellFriendByLang = {
  'en': _en,
  'nl': _nl,
  'de': _de,
  'fr': _fr,
  'es': _es,
  'ar': _ar,
  'tr': _tr,
};

/// Resolves strings for the current app [locale] (language code only).
DriverTellFriendStrings driverTellFriendStringsFor(Locale? locale) {
  final code = locale?.languageCode ?? 'en';
  return _driverTellFriendByLang[code] ?? _en;
}
