import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

class DriverFaqScreen extends ConsumerWidget {
  const DriverFaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          DriverStrings.faq,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FaqSection(
            title: 'Aan de slag',
            colors: colors,
            typo: typo,
            items: const [
              _FaqItem(
                q: 'Hoe ga ik online?',
                a: 'Gebruik de schuifknop op het startscherm om online te gaan. '
                    'Veeg naar rechts om online te gaan, naar het midden voor '
                    'pauze, en naar links om offline te gaan.',
              ),
              _FaqItem(
                q: 'Hoe stel ik mijn tarieven in?',
                a: 'Ga naar het Driver Hub-menu en tik op Tariefprofielen. '
                    'Hier kunt u meerdere tariefprofielen aanmaken en '
                    'schakelen tussen verschillende tarieven.',
              ),
              _FaqItem(
                q: 'Hoe ontvang ik ritaanvragen?',
                a: 'Zodra u online bent, ontvangt u automatisch '
                    'ritaanvragen van passagiers in de buurt. U krijgt een '
                    'melding met de ritdetails en kunt deze accepteren of '
                    'weigeren.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FaqSection(
            title: 'Ritten en verdiensten',
            colors: colors,
            typo: typo,
            items: const [
              _FaqItem(
                q: 'Hoe berekent HeyCaby mijn verdiensten?',
                a: 'Uw verdiensten worden berekend op basis van het '
                    'starttarief + prijs per kilometer + prijs per minuut. '
                    'U stelt deze tarieven zelf in via uw tariefprofiel.',
              ),
              _FaqItem(
                q: 'Wanneer krijg ik betaald?',
                a: 'Passagiers betalen direct aan u via contant geld, pin '
                    'of Tikkie. HeyCaby rekent 0% commissie.',
              ),
              _FaqItem(
                q: 'Wat zijn retourritten?',
                a: 'Retourritten zijn ritten die terugkeren naar uw '
                    'thuisgebied. Via de retourrittenmarktplaats kunt u '
                    'ritten vinden die in uw richting gaan.',
              ),
              _FaqItem(
                q: 'Hoe werkt de Marktplaats?',
                a: 'Op de Marktplaats kunt u bieden op beschikbare ritten. '
                    'Passagiers plaatsen een ritverzoek en u kunt hier op '
                    'reageren met uw tarief.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FaqSection(
            title: 'Pauzes en diensten',
            colors: colors,
            typo: typo,
            items: const [
              _FaqItem(
                q: 'Hoe lang mag ik rijden zonder pauze?',
                a: 'Volgens Nederlandse wet- en regelgeving mag u maximaal '
                    '4,5 uur achtereen rijden. Daarna is een pauze van '
                    'minimaal 30 minuten verplicht.',
              ),
              _FaqItem(
                q: 'Hoe neem ik pauze?',
                a: 'Veeg de statusschakelaar naar het midden (pauze). '
                    'Uw status verandert naar oranje en u ontvangt geen '
                    'nieuwe ritaanvragen.',
              ),
              _FaqItem(
                q: 'Hoe beëindig ik mijn dienst?',
                a: 'Veeg de statusschakelaar naar links (offline). Als u '
                    'langer dan 30 minuten online bent geweest, wordt er '
                    'een bevestigingsdialoog getoond.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FaqSection(
            title: 'Veiligheid',
            colors: colors,
            typo: typo,
            items: const [
              _FaqItem(
                q: 'Wat is de veiligheidskit?',
                a: 'De veiligheidskit bevat drie functies: noodoproep '
                    '(112), rit delen met contactpersonen, en '
                    'audio-opname tijdens ritten.',
              ),
              _FaqItem(
                q: 'Hoe gebruik ik audio-opname?',
                a: 'Audio-opname is alleen beschikbaar tijdens actieve '
                    'ritten. Tik op Audio-opname in de veiligheidskit om '
                    'te starten. De opname wordt lokaal opgeslagen.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FaqSection(
            title: 'Documenten en compliance',
            colors: colors,
            typo: typo,
            items: const [
              _FaqItem(
                q: 'Welke documenten heb ik nodig?',
                a: 'U heeft nodig: chauffeurspas, rijbewijs, VOG '
                    '(Verklaring Omtrent het Gedrag), taxidiploma en '
                    'taxiverzekering.',
              ),
              _FaqItem(
                q: 'Hoe verleng ik mijn documenten?',
                a: 'Neem contact op met het RDW of uw gemeente voor '
                    'verlenging van uw chauffeurspas en rijbewijs. Voor '
                    'de VOG kunt u terecht bij Justis.',
              ),
              _FaqItem(
                q: 'Wat als mijn chauffeurspas verloopt?',
                a: 'Als uw chauffeurspas verloopt, wordt uw account '
                    'opgeschort. Neem contact op met support via de '
                    'in-app chat om uw documenten bij te werken.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FaqSection(
            title: 'Ondersteuning',
            colors: colors,
            typo: typo,
            items: const [
              _FaqItem(
                q: 'Hoe neem ik contact op met support?',
                a: 'Ga naar Ondersteuning in het menu en tik op '
                    '"Nieuw bericht" om een chatgesprek te starten met '
                    'ons supportteam.',
              ),
              _FaqItem(
                q: 'Kan ik bellen met support?',
                a: 'Nee, communicatie met support verloopt uitsluitend '
                    'via de in-app chat.',
              ),
              _FaqItem(
                q: 'Hoe lang duurt het voor ik antwoord krijg?',
                a: 'Ons supportteam streeft ernaar binnen 24 uur te '
                    'reageren op uw bericht.',
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});
}

class _FaqSection extends StatelessWidget {
  final String title;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final List<_FaqItem> items;

  const _FaqSection({
    required this.title,
    required this.colors,
    required this.typo,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              title,
              style: typo.headingMedium.copyWith(color: colors.text),
            ),
          ),
          ...items.map((item) => Theme(
                data: Theme.of(context).copyWith(dividerColor: colors.border),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  title: Text(
                    item.q,
                    style: typo.bodyMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  iconColor: colors.accent,
                  collapsedIconColor: colors.textSoft,
                  children: [
                    Text(
                      item.a,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
