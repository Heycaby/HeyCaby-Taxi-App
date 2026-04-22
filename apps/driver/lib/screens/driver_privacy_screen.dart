import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

class DriverPrivacyScreen extends ConsumerWidget {
  const DriverPrivacyScreen({super.key});

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
          DriverStrings.privacyPolicy,
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
              title: '1. Verzamelde gegevens',
              body: 'HeyCaby verzamelt de volgende gegevens: locatiedata '
                  '(alleen wanneer u online bent), ritgeschiedenis, '
                  'documenten (chauffeurspas, rijbewijs, VOG, '
                  'verzekeringsbewijs), voertuiggegevens en contactgegevens.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '2. Gebruik van locatiegegevens',
              body: 'Uw locatie wordt alleen verzameld wanneer u online '
                  'bent in de app. Locatiegegevens worden gebruikt om u '
                  'te koppelen aan ritaanvragen, uw positie op de kaart '
                  'weer te geven, en zone-analyse uit te voeren. Wanneer '
                  'u offline gaat, wordt uw locatie niet meer bijgehouden.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '3. Bewaartermijnen',
              body: 'Ritgegevens worden bewaard voor een periode van 7 '
                  'jaar conform fiscale wetgeving. Locatiegegevens worden '
                  'na 90 dagen geanonimiseerd. Documenten worden bewaard '
                  'zolang uw account actief is, plus 12 maanden na '
                  'deactivering.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '4. Uw rechten (AVG)',
              body: 'U heeft recht op inzage, correctie en verwijdering '
                  'van uw persoonsgegevens. U kunt een verzoek indienen '
                  'via de in-app support. Wij reageren binnen 30 dagen op '
                  'uw verzoek conform de Algemene Verordening '
                  'Gegevensbescherming (AVG).',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '5. Geen verkoop aan derden',
              body: 'HeyCaby verkoopt uw persoonsgegevens niet aan derden. '
                  'Uw gegevens worden alleen gedeeld met derden wanneer '
                  'dit wettelijk verplicht is of noodzakelijk voor de '
                  'dienstverlening (bijv. verzekeraars bij een incident).',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '6. Anonieme gegevens',
              body: 'Marktgegevens in Union Mode zijn volledig anoniem. '
                  'Er wordt geen driver_id opgeslagen bij marktsignalen. '
                  'Deze gegevens worden uitsluitend gebruikt voor '
                  'geaggregeerde marktanalyse.',
              colors: colors,
              typo: typo,
            ),
            _Section(
              title: '7. Contact',
              body: 'Voor privacygerelateerde vragen kunt u contact '
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
