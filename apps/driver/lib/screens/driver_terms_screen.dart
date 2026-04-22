import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

class DriverTermsScreen extends ConsumerWidget {
  const DriverTermsScreen({super.key});

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
          DriverStrings.termsOfService,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: '1. Serviceovereenkomst',
              body: 'Deze Gebruiksvoorwaarden vormen een overeenkomst '
                  'tussen u als zelfstandig chauffeur en HeyCaby B.V. '
                  '(hierna "HeyCaby" of "het Platform"). Door gebruik te '
                  'maken van de HeyCaby-chauffeursapp gaat u akkoord '
                  'met deze voorwaarden.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '2. Verplichtingen van de chauffeur',
              body: 'U bent verantwoordelijk voor het beschikken over '
                  'geldige documenten waaronder een chauffeurspas, '
                  'rijbewijs, VOG en taxiverzekering. Uw voertuig dient te '
                  'voldoen aan alle wettelijke eisen. U bent '
                  'verantwoordelijk voor de veiligheid van uw passagiers '
                  'en het naleven van de Arbeidstijdenwet, waaronder de '
                  'maximale rijtijd van 4,5 uur.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '3. Betalingsvoorwaarden',
              body: 'HeyCaby rekent 0% commissie. Passagiers betalen '
                  'rechtstreeks aan u via contant geld, pin of Tikkie. '
                  'U stelt zelf uw tarieven in via uw tariefprofiel in de '
                  'app. HeyCaby heeft geen rol in de financiële afhandeling '
                  'tussen u en de passagier.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '4. Opschorting van account',
              body: 'HeyCaby behoudt zich het recht voor uw account op te '
                  'schorten bij: verlopen documenten, herhaaldelijke '
                  'klachten van passagiers, schending van deze '
                  'voorwaarden, of fraude. U wordt hiervan op de hoogte '
                  'gesteld via de in-app chat.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '5. Geschillenbeslechting',
              body: 'Geschillen tussen u en HeyCaby worden bij voorkeur '
                  'opgelost via de in-app support. Indien dit niet leidt '
                  'tot een oplossing, kunt u een klacht indienen bij de '
                  'Autoriteit Consument & Markt of de bevoegde rechter '
                  'in Nederland.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '6. Toepasselijk recht',
              body: 'Op deze overeenkomst is het Nederlands recht van '
                  'toepassing. De bevoegde rechter in het arrondissement '
                  'Amsterdam is bij uitsluiting bevoegd.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '7. Contact',
              body: 'Voor vragen over deze voorwaarden kunt u contact '
                  'opnemen via de in-app support.',
              colors: colors,
              typo: typo,
              onSupportTap: () => context.push('/driver/support'),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback? onSupportTap;

  const _Section({
    required this.title,
    required this.body,
    required this.colors,
    required this.typo,
    this.onSupportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typo.headingMedium.copyWith(color: colors.text),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
          if (onSupportTap != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onSupportTap,
              child: Text(
                DriverStrings.ondersteuning,
                style: typo.bodyMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
