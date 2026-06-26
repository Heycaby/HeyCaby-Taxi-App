import 'package:flutter/material.dart';

/// Copy for the below-minimum-iOS full-screen gate (driver has no gen-l10n).
class DriverIosUpdateStrings {
  const DriverIosUpdateStrings({
    required this.title,
    required this.bodyTemplate,
    required this.footerTemplate,
  });

  final String title;

  /// Use `{minimum}` and `{current}` placeholders.
  final String bodyTemplate;

  /// Use `{minimum}` placeholder.
  final String footerTemplate;

  String body(String minimum, String current) => bodyTemplate
      .replaceAll('{minimum}', minimum)
      .replaceAll('{current}', current);

  String footer(String minimum) =>
      footerTemplate.replaceAll('{minimum}', minimum);
}

const _en = DriverIosUpdateStrings(
  title: 'Please update iOS',
  bodyTemplate:
      'HeyCaby Driver requires iOS {minimum} or later. This iPhone is on iOS {current}. Open Settings → General → Software Update to install the latest iOS your device supports.',
  footerTemplate:
      'If your device cannot upgrade to iOS {minimum}, you will need a newer iPhone to use HeyCaby Driver.',
);

const _nl = DriverIosUpdateStrings(
  title: 'Werk iOS bij',
  bodyTemplate:
      'HeyCaby Driver vereist iOS {minimum} of nieuwer. Deze iPhone draait iOS {current}. Ga naar Instellingen → Algemeen → Software-update om de nieuwste iOS voor je toestel te installeren.',
  footerTemplate:
      'Als je toestel niet kan upgraden naar iOS {minimum}, heb je een nieuwere iPhone nodig voor HeyCaby Driver.',
);

const _de = DriverIosUpdateStrings(
  title: 'Bitte iOS aktualisieren',
  bodyTemplate:
      'HeyCaby Driver erfordert iOS {minimum} oder neuer. Dieses iPhone nutzt iOS {current}. Öffnen Sie Einstellungen → Allgemein → Softwareupdate, um die neueste unterstützte iOS-Version zu installieren.',
  footerTemplate:
      'Wenn Ihr Gerät nicht auf iOS {minimum} aktualisiert werden kann, benötigen Sie ein neueres iPhone für HeyCaby Driver.',
);

const _fr = DriverIosUpdateStrings(
  title: 'Veuillez mettre à jour iOS',
  bodyTemplate:
      'HeyCaby Driver nécessite iOS {minimum} ou une version ultérieure. Cet iPhone est en iOS {current}. Ouvrez Réglages → Général → Mise à jour logicielle pour installer la dernière version prise en charge.',
  footerTemplate:
      'Si votre appareil ne peut pas passer à iOS {minimum}, vous aurez besoin d’un iPhone plus récent pour utiliser HeyCaby Driver.',
);

const _es = DriverIosUpdateStrings(
  title: 'Actualiza iOS',
  bodyTemplate:
      'HeyCaby Driver requiere iOS {minimum} o posterior. Este iPhone tiene iOS {current}. Abre Ajustes → General → Actualización de software para instalar la última versión compatible.',
  footerTemplate:
      'Si tu dispositivo no puede actualizarse a iOS {minimum}, necesitarás un iPhone más nuevo para usar HeyCaby Driver.',
);

const _ar = DriverIosUpdateStrings(
  title: 'يُرجى تحديث iOS',
  bodyTemplate:
      'يتطلب HeyCaby Driver iOS {minimum} أو أحدث. هذا الـ iPhone يعمل بـ iOS {current}. افتح الإعدادات → عام → تحديث البرنامج لتثبيت أحدث إصدار يدعمه جهازك.',
  footerTemplate:
      'إذا لم يستطع جهازك الترقية إلى iOS {minimum}، ستحتاج إلى iPhone أحدث لاستخدام HeyCaby Driver.',
);

const _tr = DriverIosUpdateStrings(
  title: 'Lütfen iOS’u güncelleyin',
  bodyTemplate:
      'HeyCaby Driver için iOS {minimum} veya üzeri gerekir. Bu iPhone’da iOS {current} var. Ayarlar → Genel → Yazılım Güncelleme’den cihazınızın desteklediği en son iOS’u yükleyin.',
  footerTemplate:
      'Cihazınız iOS {minimum} sürümüne yükseltilemiyorsa, HeyCaby Driver için daha yeni bir iPhone gerekir.',
);

final Map<String, DriverIosUpdateStrings> _byLang = {
  'en': _en,
  'nl': _nl,
  'de': _de,
  'fr': _fr,
  'es': _es,
  'ar': _ar,
  'tr': _tr,
};

DriverIosUpdateStrings driverIosUpdateStringsFor(Locale? locale) {
  final code = locale?.languageCode ?? 'nl';
  return _byLang[code] ?? _nl;
}
