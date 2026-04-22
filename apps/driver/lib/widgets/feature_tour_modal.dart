import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

// ── Tour card data ─────────────────────────────────────────────────────────────
class _TourCard {
  final String heading;
  final String body;
  final IconData icon;

  const _TourCard({
    required this.heading,
    required this.body,
    required this.icon,
  });
}

const _kCards = [
  _TourCard(
    heading: 'Welkom bij HeyCaby 👋',
    body:
        'Je rijdt nu voor het snelst groeiende taxi-platform van Nederland. Hier is hoe het werkt.',
    icon: Icons.waving_hand_rounded,
  ),
  _TourCard(
    heading: 'Jij houdt alles 💰',
    body:
        'HeyCaby neemt geen commissie. Je betaalt een vaste weekbijdrage en houdt 100% van elke rit.',
    icon: Icons.account_balance_wallet_rounded,
  ),
  _TourCard(
    heading: 'Online gaan is simpel 🟢',
    body:
        'Schuif de Online-knop op je Home scherm. Je verschijnt direct op de kaart voor reizigers in jouw buurt.',
    icon: Icons.toggle_on_rounded,
  ),
  _TourCard(
    heading: 'Eerst even verifiëren 📋',
    body:
        'Voordat je online kunt gaan, hebben we je chauffeurspas, rijbewijs en voertuig nodig. Het duurt minder dan 10 minuten.',
    icon: Icons.verified_user_outlined,
  ),
  _TourCard(
    heading: 'Lee helpt je altijd 💬',
    body:
        'Bij vragen kun je altijd chatten met Lee — onze AI-supportassistent. In het Nederlands of Engels, 24/7.',
    icon: Icons.chat_bubble_outline_rounded,
  ),
  _TourCard(
    heading: 'Je bent niet alleen 🤝',
    body:
        'In de Community-tab vind je andere chauffeurs, tips, en updates van HeyCaby. Samen staan we sterk.',
    icon: Icons.people_alt_outlined,
  ),
];

/// Shows the one-time feature tour modal. Call once after first login when
/// `onboarding_feature_tour_shown = false`. Completes with true when the
/// driver reaches the last card or skips.
Future<void> showFeatureTourModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _FeatureTourSheet(),
  );
}

class _FeatureTourSheet extends ConsumerStatefulWidget {
  const _FeatureTourSheet();

  @override
  ConsumerState<_FeatureTourSheet> createState() => _FeatureTourSheetState();
}

class _FeatureTourSheetState extends ConsumerState<_FeatureTourSheet> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _kCards.length - 1) {
      _pageCtrl.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final isLast = _page == _kCards.length - 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),

          // Page indicator dots
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_kCards.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? colors.accent
                        : colors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                );
              }),
            ),
          ),

          // Card pages
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: _kCards.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _CardPage(
                card: _kCards[i],
                colors: colors,
                typo: typo,
              ),
            ),
          ),

          // Buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            child: Row(
              children: [
                if (!isLast)
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Overslaan',
                      style: typo.bodyMedium.copyWith(color: colors.textMid),
                    ),
                  )
                else
                  const Spacer(),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isLast ? 'Beginnen' : 'Verder',
                    style: typo.labelLarge
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPage extends StatelessWidget {
  final _TourCard card;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _CardPage({
    required this.card,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(card.icon, size: 40, color: colors.accent),
          ),
          const SizedBox(height: 28),
          Text(
            card.heading,
            textAlign: TextAlign.center,
            style: typo.headingMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            card.body,
            textAlign: TextAlign.center,
            style: typo.bodyMedium.copyWith(
              color: colors.textMid,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
