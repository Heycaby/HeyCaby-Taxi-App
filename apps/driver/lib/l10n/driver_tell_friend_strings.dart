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
  navLabel: 'Invite',
  screenTitle: 'Invite a driver',
  headline: 'More drivers, more earnings.',
  bullet1: 'The more drivers on HeyCaby, the more users will use the platform.',
  bullet2: 'Build a strong driver community and increase your earning potential.',
  bullet3: 'Share your invite link with fellow drivers you trust.',
  inviteLinkLabel: 'Your invite link',
  linkResolving: 'Getting your short invite link…',
  copyLink: 'Copy link',
  shareLink: 'Share invite',
  linkCopied: 'Link copied',
  shareSubject: 'Join me on HeyCaby — earn together',
  shareMessage:
      'I drive on HeyCaby and the more drivers we have, the more we all earn. Join our driver community and start earning today. Here is my invite:',
  linkUnavailable: 'Link not ready yet',
  linkUnavailableHint: 'Open this screen again in a moment, or restart the app.',
);

const _nl = DriverTellFriendStrings(
  navLabel: 'Uitnodigen',
  screenTitle: 'Nodig een chauffeur uit',
  headline: 'Meer chauffeurs, meer verdiensten.',
  bullet1: 'Hoe meer chauffeurs op HeyCaby, hoe meer gebruikers het platform gebruiken.',
  bullet2: 'Bouw een sterke chauffeursgemeenschap en verhoog je verdienpotentieel.',
  bullet3: 'Deel je uitnodigingslink met mede-chauffeurs die je vertrouwt.',
  inviteLinkLabel: 'Jouw uitnodigingslink',
  linkResolving: 'Je korte uitnodigingslink ophalen…',
  copyLink: 'Link kopiëren',
  shareLink: 'Uitnodiging delen',
  linkCopied: 'Link gekopieerd',
  shareSubject: 'Doe mee met HeyCaby — verdien samen',
  shareMessage:
      'Ik rijd met HeyCaby en hoe meer chauffeurs we hebben, hoe meer we allemaal verdienen. Sluit je aan bij onze chauffeursgemeenschap en begin vandaag met verdienen. Hier is mijn uitnodiging:',
  linkUnavailable: 'Link nog niet beschikbaar',
  linkUnavailableHint: 'Probeer het zo opnieuw of start de app opnieuw.',
);

const _de = DriverTellFriendStrings(
  navLabel: 'Einladen',
  screenTitle: 'Fahrer einladen',
  headline: 'Mehr Fahrer, mehr Einkommen.',
  bullet1: 'Je mehr Fahrer auf HeyCaby, desto mehr Nutzer nutzen die Plattform.',
  bullet2: 'Baue eine starke Fahrergemeinschaft auf und erhöhe dein Verdienpotenzial.',
  bullet3: 'Teile deinen Einladungslink mit Fahrerkollegen, denen du vertraust.',
  inviteLinkLabel: 'Dein Einladungslink',
  linkResolving: 'Kurzer Einladungslink wird geladen…',
  copyLink: 'Link kopieren',
  shareLink: 'Einladung teilen',
  linkCopied: 'Link kopiert',
  shareSubject: 'Komm zu HeyCaby — gemeinsam verdienen',
  shareMessage:
      'Ich fahre mit HeyCaby und je mehr Fahrer wir haben, desto mehr verdienen wir alle. Schließ dich unserer Fahrergemeinschaft an und fang heute an zu verdienen. Hier ist meine Einladung:',
  linkUnavailable: 'Link noch nicht bereit',
  linkUnavailableHint: 'Versuche es gleich erneut oder starte die App neu.',
);

const _fr = DriverTellFriendStrings(
  navLabel: 'Inviter',
  screenTitle: 'Inviter un chauffeur',
  headline: 'Plus de chauffeurs, plus de revenus.',
  bullet1: 'Plus de chauffeurs sur HeyCaby, plus d\'utilisateurs sur la plateforme.',
  bullet2: 'Construisez une forte communauté de chauffeurs et augmentez vos revenus.',
  bullet3: 'Partagez votre lien d\'invitation avec les chauffeurs de confiance.',
  inviteLinkLabel: 'Votre lien d’invitation',
  linkResolving: 'Récupération de votre lien court…',
  copyLink: 'Copier le lien',
  shareLink: 'Partager l’invitation',
  linkCopied: 'Lien copié',
  shareSubject: 'Rejoignez-moi sur HeyCaby — gagnez ensemble',
  shareMessage:
      'Je roule avec HeyCaby et plus nous avons de chauffeurs, plus nous gagnons tous. Rejoignez notre communauté de chauffeurs et commencez à gagner aujourd\'hui. Voici mon invitation :',
  linkUnavailable: 'Lien pas encore prêt',
  linkUnavailableHint: 'Réessayez dans un instant ou redémarrez l’application.',
);

const _es = DriverTellFriendStrings(
  navLabel: 'Invitar',
  screenTitle: 'Invitar a un conductor',
  headline: 'Más conductores, más ganancias.',
  bullet1: 'Cuántos más conductores en HeyCaby, más usuarios usarán la plataforma.',
  bullet2: 'Construye una fuerte comunidad de conductores y aumenta tu potencial de ganancias.',
  bullet3: 'Comparte tu enlace de invitación con conductores de confianza.',
  inviteLinkLabel: 'Tu enlace de invitación',
  linkResolving: 'Obteniendo tu enlace corto…',
  copyLink: 'Copiar enlace',
  shareLink: 'Compartir invitación',
  linkCopied: 'Enlace copiado',
  shareSubject: 'Únete a HeyCaby — gana junto conmigo',
  shareMessage:
      'Conduzco en HeyCaby y cuantos más conductores tengamos, más ganaremos todos. Únete a nuestra comunidad de conductores y empieza a ganar hoy. Aquí está mi invitación:',
  linkUnavailable: 'Enlace aún no disponible',
  linkUnavailableHint: 'Vuelve a intentarlo en un momento o reinicia la app.',
);

const _ar = DriverTellFriendStrings(
  navLabel: 'دعوة',
  screenTitle: 'دعوة سائق',
  headline: 'المزيد من السائقين، المزيد من الأرباح.',
  bullet1: 'كلما زاد عدد السائقين على HeyCaby، زاد عدد المستخدمين على المنصة.',
  bullet2: 'ابنِ مجتمعًا قويًا من السائقين وزد من إمكاناتك في الكسب.',
  bullet3: 'شارك رابط دعوتك مع السائقين الذين تثق بهم.',
  inviteLinkLabel: 'رابط دعوتك',
  linkResolving: 'جاري إعداد رابط الدعوة القصير…',
  copyLink: 'نسخ الرابط',
  shareLink: 'مشاركة الدعوة',
  linkCopied: 'تم نسخ الرابط',
  shareSubject: 'انضم إلي على HeyCaby — اكسب معًا',
  shareMessage:
      'أقود على HeyCaby وكلما زاد عدد السائقين لدينا، زادت أرباحنا جميعًا. انضم إلى مجتمع السائقين لدينا وابدأ في الكسب اليوم. إليك رابط دعوتي:',
  linkUnavailable: 'الرابط غير جاهز بعد',
  linkUnavailableHint: 'حاول مرة أخرى بعد لحظات أو أعد تشغيل التطبيق.',
);

const _tr = DriverTellFriendStrings(
  navLabel: 'Davet',
  screenTitle: 'Sürücü davet et',
  headline: 'Daha fazla sürücü, daha fazla kazanç.',
  bullet1: 'HeyCaby\'de ne kadar çok sürücü olursa, platformu o kadar çok kullanıcı kullanır.',
  bullet2: 'Güçlü bir sürücü topluluğu oluşturun ve kazanç potansiyelinizi artırın.',
  bullet3: 'Davet bağlantınızı güvendiğiniz sürücü arkadaşlarla paylaşın.',
  inviteLinkLabel: 'Davet bağlantın',
  linkResolving: 'Kısa davet bağlantısı alınıyor…',
  copyLink: 'Bağlantıyı kopyala',
  shareLink: 'Daveti paylaş',
  linkCopied: 'Bağlantı kopyalandı',
  shareSubject: 'HeyCaby\'ye katıl — birlikte kazanalım',
  shareMessage:
      'HeyCaby\'de sürüyorum ve ne kadar çok sürücümüz olursa, o kadar çok kazanırız. Sürücü topluluğumuza katılın ve bugün kazanmaya başlayın. İşte davetim:',
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
/// Dutch is the fallback when no specific language is available.
DriverTellFriendStrings driverTellFriendStringsFor(Locale? locale) {
  final code = locale?.languageCode ?? 'nl';
  return _driverTellFriendByLang[code] ?? _nl;
}
