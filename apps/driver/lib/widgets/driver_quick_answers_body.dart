import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import 'driver_support_flow_common.dart';

/// FAQ content used by [DriverQuickAnswersBody] and the FAQ screen.
const kDriverFaqSections = [
  DriverFaqSectionData(
    title: 'Aan de slag',
    items: [
      DriverFaqItemData(
        question: 'Hoe ga ik online?',
        answer: 'Gebruik de schuifknop op het startscherm om online te gaan. '
            'Veeg naar rechts om online te gaan, naar het midden voor '
            'pauze, en naar links om offline te gaan.',
      ),
      DriverFaqItemData(
        question: 'Hoe stel ik mijn tarieven in?',
        answer: 'Ga naar het Driver Hub-menu en tik op Tariefprofielen. '
            'Hier kunt u meerdere tariefprofielen aanmaken en '
            'schakelen tussen verschillende tarieven.',
      ),
      DriverFaqItemData(
        question: 'Hoe ontvang ik ritaanvragen?',
        answer: 'Zodra u online bent, ontvangt u automatisch '
            'ritaanvragen van passagiers in de buurt. U krijgt een '
            'melding met de ritdetails en kunt deze accepteren of '
            'weigeren.',
      ),
    ],
  ),
  DriverFaqSectionData(
    title: 'Ritten en verdiensten',
    items: [
      DriverFaqItemData(
        question: 'Hoe berekent HeyCaby mijn verdiensten?',
        answer: 'Uw verdiensten worden berekend op basis van het '
            'starttarief + prijs per kilometer + prijs per minuut. '
            'U stelt deze tarieven zelf in via uw tariefprofiel.',
      ),
      DriverFaqItemData(
        question: 'Wanneer krijg ik betaald?',
        answer: 'Passagiers betalen direct aan u via contant geld, pin '
            'of Tikkie. HeyCaby rekent 0% commissie.',
      ),
      DriverFaqItemData(
        question: 'Wat zijn retourritten?',
        answer: 'Retourritten zijn ritten die terugkeren naar uw '
            'thuisgebied. Via de retourrittenmarktplaats kunt u '
            'ritten vinden die in uw richting gaan.',
      ),
      DriverFaqItemData(
        question: 'Hoe werkt de Marktplaats?',
        answer: 'Op de Marktplaats kunt u bieden op beschikbare ritten. '
            'Passagiers plaatsen een ritverzoek en u kunt hier op '
            'reageren met uw tarief.',
      ),
    ],
  ),
  DriverFaqSectionData(
    title: 'Pauzes en diensten',
    items: [
      DriverFaqItemData(
        question: 'Hoe lang mag ik rijden zonder pauze?',
        answer: 'Volgens Nederlandse wet- en regelgeving mag u maximaal '
            '4,5 uur achtereen rijden. Daarna is een pauze van '
            'minimaal 30 minuten verplicht.',
      ),
      DriverFaqItemData(
        question: 'Hoe neem ik pauze?',
        answer: 'Veeg de statusschakelaar naar het midden (pauze). '
            'Uw status verandert naar oranje en u ontvangt geen '
            'nieuwe ritaanvragen.',
      ),
      DriverFaqItemData(
        question: 'Hoe beëindig ik mijn dienst?',
        answer: 'Veeg de statusschakelaar naar links (offline). Als u '
            'langer dan 30 minuten online bent geweest, wordt er '
            'een bevestigingsdialoog getoond.',
      ),
    ],
  ),
  DriverFaqSectionData(
    title: 'Veiligheid',
    items: [
      DriverFaqItemData(
        question: 'Wat is de veiligheidskit?',
        answer: 'De veiligheidskit bevat drie functies: noodoproep '
            '(112), rit delen met contactpersonen, en '
            'audio-opname tijdens ritten.',
      ),
      DriverFaqItemData(
        question: 'Hoe gebruik ik audio-opname?',
        answer: 'Audio-opname is alleen beschikbaar tijdens actieve '
            'ritten. Tik op Audio-opname in de veiligheidskit om '
            'te starten. De opname wordt lokaal opgeslagen.',
      ),
    ],
  ),
  DriverFaqSectionData(
    title: 'Documenten en compliance',
    items: [
      DriverFaqItemData(
        question: 'Welke documenten heb ik nodig?',
        answer: 'U heeft nodig: chauffeurspas, rijbewijs, VOG '
            '(Verklaring Omtrent het Gedrag), taxidiploma en '
            'taxiverzekering.',
      ),
      DriverFaqItemData(
        question: 'Hoe verleng ik mijn documenten?',
        answer: 'Neem contact op met het RDW of uw gemeente voor '
            'verlenging van uw chauffeurspas en rijbewijs. Voor '
            'de VOG kunt u terecht bij Justis.',
      ),
      DriverFaqItemData(
        question: 'Wat als mijn chauffeurspas verloopt?',
        answer: 'Als uw chauffeurspas verloopt, wordt uw account '
            'opgeschort. Neem contact op met support via de '
            'in-app chat om uw documenten bij te werken.',
      ),
    ],
  ),
  DriverFaqSectionData(
    title: 'Ondersteuning',
    items: [
      DriverFaqItemData(
        question: 'Hoe neem ik contact op met support?',
        answer: 'Ga naar Ondersteuning in het menu en tik op '
            '"Nieuw bericht" om een chatgesprek te starten met '
            'ons supportteam.',
      ),
      DriverFaqItemData(
        question: 'Kan ik bellen met support?',
        answer: 'Nee, communicatie met support verloopt uitsluitend '
            'via de in-app chat.',
      ),
      DriverFaqItemData(
        question: 'Hoe lang duurt het voor ik antwoord krijg?',
        answer: 'Ons supportteam streeft ernaar binnen 24 uur te '
            'reageren op uw bericht.',
      ),
    ],
  ),
];

/// One FAQ question + answer.
class DriverFaqItemData {
  const DriverFaqItemData({required this.question, required this.answer});

  final String question;
  final String answer;

  /// Legacy field names for FAQ migration.
  String get q => question;
  String get a => answer;
}

/// FAQ section grouping.
class DriverFaqSectionData {
  const DriverFaqSectionData({
    required this.title,
    required this.items,
  });

  final String title;
  final List<DriverFaqItemData> items;
}

/// **Quick Answers** — FAQ scannable while parked.
class DriverQuickAnswersBody extends StatelessWidget {
  const DriverQuickAnswersBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.sections,
    required this.onBack,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverFaqSectionData> sections;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverSupportFlowScaffold(
      title: DriverStrings.faq,
      colors: colors,
      typography: typography,
      centerTitle: true,
      onBack: onBack,
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          bottomPad + DriverSpacing.lg,
        ),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: DriverSpacing.md),
        itemBuilder: (context, index) {
          final section = sections[index];
          return DriverCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: typography.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                ...section.items.map(
                  (item) => Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: colors.border.withValues(alpha: 0.5),
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(
                        bottom: DriverSpacing.sm,
                      ),
                      title: Text(
                        item.question,
                        style: typography.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      iconColor: colors.primary,
                      collapsedIconColor: colors.textMuted,
                      children: [
                        Text(
                          item.answer,
                          style: typography.bodySmall.copyWith(
                            color: colors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).driverFadeSlideIn(staggerIndex: index);
        },
      ),
    );
  }
}
