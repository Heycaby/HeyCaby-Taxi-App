import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_locale_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_legal_trust_body.dart';

class _PrivacySection {
  final String title;
  final String body;

  const _PrivacySection({required this.title, required this.body});
}

const List<_PrivacySection> _privacySectionsEn = [
  _PrivacySection(
    title: 'Effective date',
    body: '1 May 2026\n\nThis Privacy Policy explains how HeyCaby processes '
        'your personal data when you use the platform as a driver.',
  ),
  _PrivacySection(
    title: '1. Data we collect',
    body: 'HeyCaby may process the following categories of personal data:\n\n'
        '• Account data — such as your name, email address, and phone number\n'
        '• Driver profile data — including service area, pricing, and availability\n'
        '• Vehicle data — including license plate, vehicle type, and registration details\n'
        '• Compliance data — including licences, permits, insurance documents, and verification status\n'
        '• Trip and earnings data — including ride requests, trip activity, and earnings records\n'
        '• Support data — including messages and support requests\n'
        '• Technical data — including device information, app usage, and security logs\n\n'
        'Legal basis: performance of contract (Article 6(1)(b) GDPR), legal obligations (Article 6(1)(c)), '
        'and legitimate interests such as platform security and fraud prevention (Article 6(1)(f)).',
  ),
  _PrivacySection(
    title: '2. Location data',
    body:
        'Your location is processed only when necessary for driver operations, '
        'including when you are online, receiving ride requests, or actively completing a trip.\n\n'
        'Location data is used for:\n\n'
        '• Matching riders and drivers\n'
        '• Navigation context\n'
        '• Safety and fraud prevention\n'
        '• Service quality improvements\n\n'
        'When you are offline, continuous live location tracking is not active.\n\n'
        'Legal basis: performance of contract and legitimate interest.',
  ),
  _PrivacySection(
    title: '3. Why we process data',
    body: 'We process personal data to:\n\n'
        '• Operate and maintain the platform\n'
        '• Match drivers with riders\n'
        '• Maintain payment records and invoices\n'
        '• Verify legal compliance and driver eligibility\n'
        '• Provide customer support\n'
        '• Prevent fraud and abuse\n'
        '• Improve platform performance and safety',
  ),
  _PrivacySection(
    title: '4. AI support (Lee)',
    body: 'HeyCaby offers an optional AI support assistant called Lee.\n\n'
        'If you choose to use AI chat:\n\n'
        '• Your messages and limited support context are processed by third-party AI providers (including OpenAI)\n'
        '• AI processing is only activated after clear notice and your explicit consent\n'
        '• You should not share sensitive personal or financial data in AI chat\n\n'
        'You can always choose to use human support instead.\n\n'
        'Legal basis: explicit consent (Article 6(1)(a) GDPR).',
  ),
  _PrivacySection(
    title: '5. Data sharing',
    body: 'HeyCaby does not sell your personal data.\n\n'
        'We may share data only where necessary with:\n\n'
        '• Service providers (such as hosting, payments, and verification providers)\n'
        '• Legal authorities where required by law\n'
        '• Partners strictly required to operate the platform\n\n'
        'All third parties are bound by data processing agreements and GDPR obligations.',
  ),
  _PrivacySection(
    title: '6. Veriff verification data (third-party)',
    body: 'Identity and licence verification is performed by Veriff as an '
        'independent data processor.\n\n'
        'Veriff processes and stores verification data within its own secure systems.\n\n'
        'HeyCaby only receives and stores limited verification metadata necessary '
        'to confirm compliance status.\n\n'
        'HeyCaby does not store full identity document copies within the app database.\n\n'
        'Where required by law, verification data may be shared with competent authorities.',
  ),
  _PrivacySection(
    title: '7. Retention and security',
    body: 'We retain personal data only for as long as necessary for:\n\n'
        '• Operational purposes\n'
        '• Legal and tax obligations\n'
        '• Dispute handling and fraud prevention\n'
        '• Safety and compliance\n\n'
        'We apply appropriate technical and organisational measures to protect '
        'your data against unauthorised access, loss, or misuse.',
  ),
  _PrivacySection(
    title: '8. Your rights',
    body: 'Under the GDPR, you have the right to:\n\n'
        '• Access your personal data\n'
        '• Correct inaccurate data\n'
        '• Request deletion of your data\n'
        '• Restrict or object to processing\n'
        '• Request data portability\n\n'
        'You can exercise your rights via in-app support or by contacting us directly.',
  ),
  _PrivacySection(
    title: '9. Community guidelines and data use',
    body: 'The Driver Community includes two channels:\n\n'
        '• Announcements — official platform updates from HeyCaby\n'
        '• Driver Talk — messages between drivers\n\n'
        'Driver Talk is visible to other drivers and is not a private support chat with HeyCaby.\n'
        'For direct company support, use the in-app Support section.\n\n'
        'Data used in Community may include:\n'
        '• Post content, category, and timestamp\n'
        '• Driver identifier needed for ownership, moderation, and anti-abuse controls\n'
        '• Reactions (like/thanks) and related metadata\n\n'
        'How this data is used:\n'
        '• Operate community feed, filtering, and engagement features\n'
        '• Enforce rate limits and anti-spam protections\n'
        '• Investigate abuse reports and apply moderation actions\n'
        '• Improve safety and product quality through aggregated analytics\n\n'
        'Retention:\n'
        '• Community feed visibility follows a limited rolling window (including 24-hour active visibility)\n'
        '• Some records may be retained longer where legally required or necessary for fraud/safety investigations\n\n'
        'Community posts and reactions are processed to operate the feature, keep discussions safe, prevent abuse, '
        'and improve product quality. Content may be moderated and rate-limited. Community posts are retained for a limited period '
        '(including 24-hour rolling retention for active feed visibility).\n\n'
        'Legal basis: performance of contract and legitimate interests in safety, moderation, and service integrity.',
  ),
  _PrivacySection(
    title: '10. Contact',
    body: 'For privacy-related questions or requests, contact:\n\n'
        'hello@heycaby.nl\n'
        'or via in-app support\n\n'
        'You also have the right to file a complaint with the Dutch Data Protection Authority '
        '(Autoriteit Persoonsgegevens).',
  ),
];

const List<_PrivacySection> _privacySectionsNl = [
  _PrivacySection(
    title: 'Ingangsdatum',
    body:
        '1 mei 2026\n\nDit Privacybeleid legt uit hoe HeyCaby uw persoonsgegevens verwerkt '
        'wanneer u het platform gebruikt als chauffeur.',
  ),
  _PrivacySection(
    title: '1. Gegevens die we verzamelen',
    body: 'HeyCaby kan de volgende categorieën persoonsgegevens verwerken:\n\n'
        '• Accountgegevens — zoals uw naam, e-mailadres en telefoonnummer\n'
        '• Chauffeursprofielgegevens — inclusief servicegebied, tarieven en beschikbaarheid\n'
        '• Voertuiggegevens — inclusief kenteken, voertuigtype en registratiedetails\n'
        '• Nalevingsgegevens — inclusief rijbewijzen, vergunningen, verzekeringsdocumenten en verificatiestatus\n'
        '• Rit- en inkomstengegevens — inclusief ritverzoeken, ritactiviteit en inkomstenregistraties\n'
        '• Supportgegevens — inclusief berichten en supportverzoeken\n'
        '• Technische gegevens — inclusief apparaatinformatie, app-gebruik en beveiligingslogs\n\n'
        'Rechtsgrond: uitvoering van overeenkomst (artikel 6(1)(b) AVG), wettelijke verplichtingen (artikel 6(1)(c)), '
        'en gerechtvaardigde belangen zoals platformbeveiliging en fraudepreventie (artikel 6(1)(f)).',
  ),
  _PrivacySection(
    title: '2. Locatiegegevens',
    body:
        'Uw locatie wordt alleen verwerkt wanneer nodig voor chauffeursoperaties, '
        'inclusief wanneer u online bent, ritverzoeken ontvangt, of actief een rit voltooit.\n\n'
        'Locatiegegevens worden gebruikt voor:\n\n'
        '• Het matchen van passagiers en chauffeurs\n'
        '• Navigatiecontext\n'
        '• Veiligheid en fraudepreventie\n'
        '• Servicekwaliteitsverbeteringen\n\n'
        'Wanneer u offline bent, is continue live-locatie-tracking niet actief.\n\n'
        'Rechtsgrond: uitvoering van overeenkomst en gerechtvaardigd belang.',
  ),
  _PrivacySection(
    title: '3. Waarom we gegevens verwerken',
    body: 'We verwerken persoonsgegevens om:\n\n'
        '• Het platform te exploiteren en onderhouden\n'
        '• Chauffeurs met passagiers te matchen\n'
        '• Betalingsregistraties en facturen bij te houden\n'
        '• Wettelijke naleving en chauffeursgeschiktheid te verifiëren\n'
        '• Klantensupport te bieden\n'
        '• Fraude en misbruik te voorkomen\n'
        '• Platformprestaties en veiligheid te verbeteren',
  ),
  _PrivacySection(
    title: '4. AI-ondersteuning (Lee)',
    body: 'HeyCaby biedt een optionele AI-supportassistent genaamd Lee.\n\n'
        'Als u ervoor kiest om AI-chat te gebruiken:\n\n'
        '• Uw berichten en beperkte supportcontext worden verwerkt door externe AI-providers (inclusief OpenAI)\n'
        '• AI-verwerking wordt alleen geactiveerd na duidelijke kennisgeving en uw expliciete toestemming\n'
        '• U dient geen gevoelige persoonlijke of financiële gegevens te delen in AI-chat\n\n'
        'U kunt altijd kiezen om menselijke support te gebruiken.\n\n'
        'Rechtsgrond: expliciete toestemming (artikel 6(1)(a) AVG).',
  ),
  _PrivacySection(
    title: '5. Gegevensdeling',
    body: 'HeyCaby verkoopt uw persoonsgegevens niet.\n\n'
        'We kunnen gegevens alleen delen waar nodig met:\n\n'
        '• Serviceproviders (zoals hosting, betalingen en verificatieproviders)\n'
        '• Juridische autoriteiten waar vereist door wetgeving\n'
        '• Partners strikt noodzakelijk om het platform te exploiteren\n\n'
        'Alle derden zijn gebonden door gegevensverwerkingsovereenkomsten en AVG-verplichtingen.',
  ),
  _PrivacySection(
    title: '6. Veriff-verificatiegegevens (derde partij)',
    body:
        'Identiteits- en rijbewijsverificatie wordt uitgevoerd door Veriff als onafhankelijke verwerkingsverantwoordelijke.\n\n'
        'Veriff verwerkt en slaat verificatiegegevens op binnen zijn eigen beveiligde systemen.\n\n'
        'HeyCaby ontvangt en slaat alleen beperkte verificatiemetagegevens op die nodig zijn om nalevingsstatus te bevestigen.\n\n'
        'HeyCaby slaat geen volledige identiteitsdocumentkopieën op binnen de app-database.\n\n'
        'Waar vereist door wetgeving, kunnen verificatiegegevens worden gedeeld met bevoegde autoriteiten.',
  ),
  _PrivacySection(
    title: '7. Bewaartermijn en beveiliging',
    body: 'We bewaren persoonsgegevens alleen zo lang als nodig voor:\n\n'
        '• Operationele doeleinden\n'
        '• Juridische en belastingverplichtingen\n'
        '• Geschillenafhandeling en fraudepreventie\n'
        '• Veiligheid en naleving\n\n'
        'We passen passende technische en organisatorische maatregelen toe om uw gegevens te beschermen tegen ongeautoriseerde toegang, verlies of misbruik.',
  ),
  _PrivacySection(
    title: '8. Uw rechten',
    body: 'Onder de AVG heeft u het recht om:\n\n'
        '• Toegang te krijgen tot uw persoonsgegevens\n'
        '• Onjuiste gegevens te corrigeren\n'
        '• Verwijdering van uw gegevens te vragen\n'
        '• Verwerking te beperken of bezwaar te maken\n'
        '• Gegevensportabiliteit te vragen\n\n'
        'U kunt uw rechten uitoefenen via in-app support of door ons direct te contacteren.',
  ),
  _PrivacySection(
    title: '9. Community-richtlijnen en datagebruik',
    body: 'De Driver Community bevat twee kanalen:\n\n'
        '• Announcements — officiële platformupdates van HeyCaby\n'
        '• Driver Talk — berichten tussen chauffeurs\n\n'
        'Driver Talk is zichtbaar voor andere chauffeurs en is geen privé-supportchat met HeyCaby.\n'
        'Voor direct bedrijfscontact gebruikt u de supportsectie in de app.\n\n'
        'Gegevens die in Community kunnen worden verwerkt:\n'
        '• Berichtinhoud, categorie en tijdstempel\n'
        '• Chauffeurs-ID nodig voor eigenaarschap, moderatie en anti-misbruikcontroles\n'
        '• Reacties (like/thanks) en bijbehorende metadata\n\n'
        'Hoe deze gegevens worden gebruikt:\n'
        '• Community-feed, filtering en engagementfuncties uitvoeren\n'
        '• Rate limits en anti-spambeveiliging afdwingen\n'
        '• Misbruikmeldingen onderzoeken en moderatie toepassen\n'
        '• Veiligheid en productkwaliteit verbeteren via geaggregeerde analyses\n\n'
        'Bewaartermijn:\n'
        '• Zichtbaarheid in de community-feed volgt een beperkte rolling window (inclusief 24-uurs actieve zichtbaarheid)\n'
        '• Sommige records kunnen langer worden bewaard indien wettelijk vereist of nodig voor fraude-/veiligheidsonderzoek\n\n'
        'Community-berichten en reacties worden verwerkt om de functie te laten werken, discussies veilig te houden, '
        'misbruik te voorkomen en productkwaliteit te verbeteren. Inhoud kan gemodereerd en rate-limited worden. '
        'Community-berichten worden beperkt bewaard (inclusief 24-uurs rolling retention voor feed-zichtbaarheid).\n\n'
        'Rechtsgrond: uitvoering van overeenkomst en gerechtvaardigd belang in veiligheid, moderatie en service-integriteit.',
  ),
  _PrivacySection(
    title: '10. Contact',
    body: 'Voor privacy-gerelateerde vragen of verzoeken, contacteer:\n\n'
        'hello@heycaby.nl\n'
        'of via in-app support\n\n'
        'U heeft ook het recht om een klacht in te dienen bij de Nederlandse Autoriteit Persoonsgegevens.',
  ),
];

class DriverPrivacyScreen extends ConsumerStatefulWidget {
  const DriverPrivacyScreen({super.key});

  @override
  ConsumerState<DriverPrivacyScreen> createState() =>
      _DriverPrivacyScreenState();
}

class _DriverPrivacyScreenState extends ConsumerState<DriverPrivacyScreen> {
  bool _isDutch = false;
  bool _hasManualLanguageChoice = false;

  void _syncDocumentLanguage() {
    if (_hasManualLanguageChoice) return;
    final locale = ref.watch(localeProvider);
    _isDutch = locale == null || locale.languageCode == 'nl';
  }

  List<_PrivacySection> get _sections =>
      _isDutch ? _privacySectionsNl : _privacySectionsEn;

  String get _title => _isDutch ? 'Privacybeleid' : 'Privacy Policy';

  String get _fullText =>
      _sections.map((s) => '${s.title}\n\n${s.body}').join('\n\n---\n\n');

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _fullText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.copiedToClipboard)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    _syncDocumentLanguage();
    final sections = _sections;

    return DriverLegalTrustBody(
      title: _title,
      colors: colors,
      typography: typography,
      isDutch: _isDutch,
      onBack: () => context.pop(),
      onSelectEnglish: () => setState(() {
        _hasManualLanguageChoice = true;
        _isDutch = false;
      }),
      onSelectDutch: () => setState(() {
        _hasManualLanguageChoice = true;
        _isDutch = true;
      }),
      onToggleLanguage: () => setState(() {
        _hasManualLanguageChoice = true;
        _isDutch = !_isDutch;
      }),
      onCopy: _copyToClipboard,
      sections: [
        for (var i = 0; i < sections.length; i++)
          DriverLegalTrustSection(
            title: sections[i].title,
            body: sections[i].body,
            onSupportTap: i == sections.length - 1
                ? () => context.push('/driver/support')
                : null,
          ),
      ],
    );
  }
}
