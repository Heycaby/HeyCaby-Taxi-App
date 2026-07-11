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

class _TermsCopy {
  final String title;
  final List<({String heading, String body})> sections;

  const _TermsCopy({required this.title, required this.sections});
}

const _termsCopyEn = _TermsCopy(
  title: 'Driver Terms of Service — Summary',
  sections: [
    (
      heading: 'Introduction',
      body:
          'These Terms apply to your use of the HeyCaby platform as a Driver. By using the platform, you agree to these Terms.',
    ),
    (
      heading: '1. Platform role only',
      body:
          'HeyCaby provides a digital platform that enables independent drivers and riders to connect.\n\n'
          'HeyCaby is not a transport provider, taxi operator, employer, agent, or intermediary in any transport service.\n\n'
          'HeyCaby does not provide rides, does not employ drivers, and does not control pricing, routes, availability, or how services are delivered.\n\n'
          'All transport services are provided independently by Drivers under their own responsibility.',
    ),
    (
      heading: '2. Independent business responsibility',
      body:
          'You operate as an independent self-employed professional (ZZP).\n\n'
          'You are solely responsible for the operation of your business, including:\n\n'
          '• Administration and record-keeping\n'
          '• Invoicing and financial management\n'
          '• Compliance with all legal and regulatory obligations\n'
          '• Customer service and service delivery\n\n'
          'Nothing in the platform creates an employment, partnership, or agency relationship between you and HeyCaby.',
    ),
    (
      heading: '3. Taxes and financial obligations',
      body:
          'You are fully and solely responsible for all taxes and financial obligations, including:\n\n'
          '• VAT (if applicable)\n'
          '• Income tax\n'
          '• Business taxes and filings\n'
          '• Payments, declarations, and deadlines\n\n'
          'HeyCaby does not calculate, file, or pay taxes on your behalf and is not liable for any tax-related errors, penalties, or enforcement actions.',
    ),
    (
      heading: '4. Insurance and vehicle compliance',
      body: 'You are solely responsible for ensuring that:\n\n'
          '• You maintain all legally required insurance coverage\n'
          '• Your vehicle is roadworthy and compliant with all regulations\n'
          '• All licences, permits, and documents remain valid and up to date\n\n'
          'This includes, where applicable, commercial/taxi insurance and third-party liability coverage.',
    ),
    (
      heading: '5. Driver information and data accuracy',
      body:
          'You must provide accurate, complete, and up-to-date information at all times.\n\n'
          'HeyCaby may perform checks using publicly available or third-party sources.\n\n'
          'If your information is found to be false, misleading, expired, or non-compliant, HeyCaby may restrict, suspend, or terminate your access to the platform.',
    ),
    (
      heading: '6. Legal compliance and enforcement',
      body:
          'You are responsible for complying with all applicable laws and regulations related to your activities.\n\n'
          'Where required by law, court order, or competent authority, HeyCaby may disclose relevant data in accordance with its legal obligations.',
    ),
    (
      heading: '7. Identity verification (third-party)',
      body:
          'Identity and licence verification may be performed through third-party providers such as Veriff.\n\n'
          'These providers process and secure verification data within their own systems.\n\n'
          'HeyCaby stores only the minimum verification data necessary to confirm compliance status and does not retain full identity document copies within the app.\n\n'
          'HeyCaby is not responsible for outages, errors, or security incidents arising from third-party verification systems outside its control.',
    ),
    (
      heading: '8. Limitation of responsibility',
      body: 'To the maximum extent permitted by applicable law:\n\n'
          '• You remain fully responsible for your business operations, services, and compliance\n'
          '• HeyCaby is not liable for how you provide transport services\n'
          '• HeyCaby does not assume responsibility for taxes, insurance, permits, or regulatory compliance',
    ),
    (
      heading: '9. Contact',
      body: 'For questions about these Terms, contact:\n\n'
          'hello@heycaby.nl\n'
          'or use in-app support',
    ),
    (
      heading: '10. Indemnification and Liability Declaration',
      body:
          'As a Driver, you are required to review and accept the separate "Indemnification and Liability Declaration" provided during registration.\n\n'
          'This document contains important legal provisions regarding:\n\n'
          '• Your responsibility for transport services\n'
          '• Your obligation to indemnify HeyCaby against claims\n'
          '• Liability allocation between you and the platform\n'
          '• Legal and financial risks associated with operating as an independent driver\n\n'
          'By continuing to use the platform, you confirm that:\n\n'
          '• You have read and understood the Indemnification and Liability Declaration in full\n'
          '• You agree to be legally bound by its terms\n'
          '• You accept that it forms an integral part of your agreement with HeyCaby\n\n'
          'If you have not read or do not agree with this document, you must not use the platform.',
    ),
    (
      heading: '11. Acknowledgment and Waiver',
      body: 'By using the HeyCaby platform, you expressly acknowledge that:\n\n'
          '• You have been given the opportunity to read these Terms of Service\n'
          '• You have been given the opportunity to read the Indemnification and Liability Declaration\n'
          '• You understand your rights and obligations under both documents\n\n'
          'You waive any claim that you were not aware of the contents of these documents, '
          'that you did not understand them, or that you did not have adequate opportunity to review them.\n\n'
          'I have read and agree to the Terms of Service and the Indemnification & Liability Declaration',
    ),
  ],
);

const _termsCopyNl = _TermsCopy(
  title: 'Gebruiksvoorwaarden voor Chauffeurs — Samenvatting',
  sections: [
    (
      heading: 'Introductie',
      body:
          'Deze Voorwaarden zijn van toepassing op uw gebruik van het HeyCaby-platform als Chauffeur. Door het platform te gebruiken, gaat u akkoord met deze Voorwaarden.',
    ),
    (
      heading: '1. Alleen platform/software',
      body:
          'HeyCaby levert een digitaal platform dat zelfstandige chauffeurs en passagiers met elkaar verbindt.\n\n'
          'HeyCaby is geen vervoersprovider, taxioperator, werkgever, agent of intermediair in enige vervoersdienst.\n\n'
          'HeyCaby biedt geen ritten aan, neemt geen chauffeurs in dienst en bepaalt/geeft geen prijzen, routes, beschikbaarheid of hoe diensten worden geleverd.\n\n'
          'Alle vervoersdiensten worden onafhankelijk door Chauffeurs verleend onder hun eigen verantwoordelijkheid.',
    ),
    (
      heading: '2. Verantwoordelijkheid als zelfstandige',
      body: 'U werkt als zelfstandig ondernemer/professional (ZZP).\n\n'
          'U bent uitsluitend verantwoordelijk voor de operatie van uw bedrijf, inclusief:\n\n'
          '• Administratie en dossiervorming\n'
          '• Facturatie en financieel beheer\n'
          '• Naleving van alle wettelijke en regelgevende verplichtingen\n'
          '• Klantenservice en servicelevering\n\n'
          'Niets in het platform creëert een arbeids-, partnerschaps- of agentschapsrelatie tussen u en HeyCaby.',
    ),
    (
      heading: '3. Belastingen en financiële verplichtingen',
      body:
          'U bent volledig en uitsluitend verantwoordelijk voor alle belastingen en financiële verplichtingen, inclusief:\n\n'
          '• BTW (indien van toepassing)\n'
          '• Inkomstenbelasting\n'
          '• Bedrijfsbelastingen en aangiftes\n'
          '• Betalingen, aangiftes en deadlines\n\n'
          'HeyCaby berekent, dient niet in of betaalt geen belastingen namens u en is niet aansprakelijk voor belastinggerelateerde fouten, boetes of handhavingsmaatregelen.',
    ),
    (
      heading: '4. Verzekeringen en voertuigcompliance',
      body: 'U bent uitsluitend verantwoordelijk voor het waarborgen dat:\n\n'
          '• U alle wettelijk vereiste verzekeringen onderhoudt\n'
          '• Uw voertuig wegwaardig en compliant is met alle regelgeving\n'
          '• Alle licenties, vergunningen en documenten geldig en actueel blijven\n\n'
          'Dit omvat, waar van toepassing, commerciële/taxi-verzekering en dekking voor derden.',
    ),
    (
      heading: '5. Chauffeursinformatie en gegevensnauwkeurigheid',
      body:
          'U moet te allen tijde nauwkeurige, volledige en actuele informatie verstrekken.\n\n'
          'HeyCaby kan controles uitvoeren met behulp van publiek beschikbare of externe bronnen.\n\n'
          'Als uw informatie onwaar, misleidend, verlopen of non-compliant blijkt, kan HeyCaby uw toegang tot het platform beperken, schorsen of beëindigen.',
    ),
    (
      heading: '6. Wettelijke naleving en handhaving',
      body:
          'U bent verantwoordelijk voor het naleven van alle toepasselijke wetten en regelgeving met betrekking tot uw activiteiten.\n\n'
          'Waar wettelijk vereist, bij gerechtelijk bevel of door bevoegde autoriteit, kan HeyCaby relevante gegevens openbaren in overeenstemming met haar wettelijke verplichtingen.',
    ),
    (
      heading: '7. Identiteitsverificatie (derde partij)',
      body:
          'Identiteits- en rijbewijsverificatie kan worden uitgevoerd via externe providers zoals Veriff.\n\n'
          'Deze providers verwerken en beveiligen verificatiegegevens binnen hun eigen systemen.\n\n'
          'HeyCaby slaat alleen de minimale verificatiegegevens op die nodig zijn om nalevingsstatus te bevestigen en bewaart geen volledige identiteitsdocumentkopieën binnen de app.\n\n'
          'HeyCaby is niet verantwoordelijk voor uitval, fouten of beveiligingsincidenten die voortvloeien uit externe verificatiesystemen buiten haar controle.',
    ),
    (
      heading: '8. Beperking van verantwoordelijkheid',
      body: 'Voor zover maximaal toegestaan door toepasselijk recht:\n\n'
          '• U blijft volledig verantwoordelijk voor uw bedrijfsoperaties, diensten en naleving\n'
          '• HeyCaby is niet aansprakelijk voor hoe u vervoersdiensten verleent\n'
          '• HeyCaby neemt geen verantwoordelijkheid voor belastingen, verzekeringen, vergunningen of regelgevende naleving',
    ),
    (
      heading: '9. Contact',
      body: 'Voor vragen over deze Voorwaarden, contacteer:\n\n'
          'hello@heycaby.nl\n'
          'of gebruik in-app support',
    ),
    (
      heading: '10. Vrijwaring en Aansprakelijkheidsverklaring',
      body:
          'Als Chauffeur bent u verplicht om de afzonderlijke "Vrijwarings- en Aansprakelijkheidsverklaring" te reviewen en accepteren die tijdens registratie wordt verstrekt.\n\n'
          'Dit document bevat belangrijke juridische bepalingen met betrekking tot:\n\n'
          '• Uw verantwoordelijkheid voor vervoersdiensten\n'
          '• Uw verplichting om HeyCaby te vrijwaren tegen claims\n'
          '• Aansprakelijkheidsverdeling tussen u en het platform\n'
          '• Juridische en financiële risico\'s verbonden aan het opereren als zelfstandige chauffeur\n\n'
          'Door het platform te blijven gebruiken, bevestigt u dat:\n\n'
          '• U de Vrijwarings- en Aansprakelijkheidsverklaring volledig hebt gelezen en begrepen\n'
          '• U ermee instemt juridisch gebonden te zijn aan de voorwaarden ervan\n'
          '• U accepteert dat het een integraal onderdeel vormt van uw overeenkomst met HeyCaby\n\n'
          'Als u dit document niet hebt gelezen of ermee instemt, mag u het platform niet gebruiken.',
    ),
    (
      heading: '11. Erkenning en Vrijwaring',
      body:
          'Door het HeyCaby-platform te gebruiken, erkent u uitdrukkelijk dat:\n\n'
          '• U de gelegenheid hebt gehad om deze Gebruiksvoorwaarden te lezen\n'
          '• U de gelegenheid hebt gehad om de Vrijwarings- en Aansprakelijkheidsverklaring te lezen\n'
          '• U uw rechten en verplichtingen onder beide documenten begrijpt\n\n'
          'U doet afstand van elke claim dat u niet op de hoogte was van de inhoud van deze documenten, '
          'dat u ze niet begreep, of dat u niet voldoende gelegenheid had om ze te reviewen.\n\n'
          'Ik heb de Gebruiksvoorwaarden en de Vrijwarings- en Aansprakelijkheidsverklaring gelezen en ga ermee akkoord',
    ),
  ],
);

class DriverTermsScreen extends ConsumerStatefulWidget {
  const DriverTermsScreen({super.key});

  @override
  ConsumerState<DriverTermsScreen> createState() => _DriverTermsScreenState();
}

class _DriverTermsScreenState extends ConsumerState<DriverTermsScreen> {
  bool _isDutch = false;
  bool _hasManualLanguageChoice = false;

  void _syncDocumentLanguage() {
    if (_hasManualLanguageChoice) return;
    final locale = ref.watch(localeProvider);
    _isDutch = locale == null || locale.languageCode == 'nl';
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
  }

  _TermsCopy get _copy => _isDutch ? _termsCopyNl : _termsCopyEn;

  String get _fullText => _copy.sections
      .map((s) => '${s.heading}\n\n${s.body}')
      .join('\n\n---\n\n');

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _fullText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.copiedToClipboard)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    _syncDocumentLanguage();
    final copy = _copy;

    return DriverLegalTrustBody(
      title: copy.title,
      colors: colors,
      typography: typography,
      isDutch: _isDutch,
      onBack: _handleBack,
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
        for (var i = 0; i < copy.sections.length; i++)
          DriverLegalTrustSection(
            title: copy.sections[i].heading,
            body: copy.sections[i].body,
            onSupportTap: i == copy.sections.length - 1
                ? () => context.push('/driver/support')
                : null,
          ),
      ],
    );
  }
}
