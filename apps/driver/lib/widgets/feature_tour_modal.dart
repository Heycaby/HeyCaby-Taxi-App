import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../widgets/heycaby_driver_logo.dart';

// ── Tour card data (accents come from [HeyCabyColorTokens] at build time) ───
class _TourCard {
  final String heading;
  final String body;
  final IconData icon;
  final String kicker;

  const _TourCard({
    required this.heading,
    required this.body,
    required this.icon,
    required this.kicker,
  });
}

final _kCards = [
  _TourCard(
    kicker: DriverStrings.featureTour1Kicker,
    heading: DriverStrings.featureTour1Heading,
    body: DriverStrings.featureTour1Body,
    icon: Icons.waving_hand_rounded,
  ),
  _TourCard(
    kicker: DriverStrings.featureTour2Kicker,
    heading: DriverStrings.featureTour2Heading,
    body: DriverStrings.featureTour2Body,
    icon: Icons.account_balance_wallet_rounded,
  ),
  _TourCard(
    kicker: DriverStrings.featureTour3Kicker,
    heading: DriverStrings.featureTour3Heading,
    body: DriverStrings.featureTour3Body,
    icon: Icons.groups_rounded,
  ),
  _TourCard(
    kicker: DriverStrings.featureTour4Kicker,
    heading: DriverStrings.featureTour4Heading,
    body: DriverStrings.featureTour4Body,
    icon: Icons.payments_rounded,
  ),
  _TourCard(
    kicker: DriverStrings.featureTour5Kicker,
    heading: DriverStrings.featureTour5Heading,
    body: DriverStrings.featureTour5Body,
    icon: Icons.emoji_events_rounded,
  ),
  _TourCard(
    kicker: DriverStrings.featureTour6Kicker,
    heading: DriverStrings.featureTour6Heading,
    body: DriverStrings.featureTour6Body,
    icon: Icons.fact_check_rounded,
  ),
];

Color _tourAccentForPage(HeyCabyColorTokens c, int index) {
  final palette = <Color>[
    c.accent,
    c.success,
    c.warning,
    c.textMid,
    c.accent,
    c.success,
  ];
  return palette[index % palette.length];
}

/// Shows the feature tour helper modal.
/// Returns true when it should not be shown again.
Future<bool> showFeatureTourModal(BuildContext context) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: true,
    builder: (_) => const _FeatureTourSheet(),
  );
  return res ?? true;
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
      // Completing the full tour marks it as seen.
      Navigator.of(context).pop(true);
    }
  }

  void _skip() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final isLast = _page == _kCards.length - 1;

    return GlassPanel(
      colors: colors,
      typography: typo,
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      tintColor: colors.card,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.52,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const HeyCabyDriverLogo(width: 100),
                ],
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
                accent: _tourAccentForPage(colors, i),
                colors: colors,
                typo: typo,
                isActive: i == _page,
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
                TextButton.icon(
                  onPressed: _skip,
                  icon: Icon(Icons.skip_next_rounded, size: 18, color: colors.textMid),
                  label: Text(
                    DriverStrings.featureTourSkip,
                    style: typo.bodyMedium.copyWith(color: colors.textMid),
                  ),
                ),
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
                    isLast
                        ? DriverStrings.featureTourStartNow
                        : DriverStrings.featureTourNext,
                    style: typo.labelLarge
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _CardPage extends StatelessWidget {
  final _TourCard card;
  final Color accent;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool isActive;

  const _CardPage({
    required this.card,
    required this.accent,
    required this.colors,
    required this.typo,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0.0, isActive ? 0.0 : 10.0, 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  card.kicker,
                  textAlign: TextAlign.center,
                  style: typo.labelMedium.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.92, end: isActive ? 1.0 : 0.95),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(card.icon, size: 26, color: accent),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                card.heading,
                textAlign: TextAlign.center,
                style: typo.headingMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  height: 1.22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                card.body,
                textAlign: TextAlign.center,
                style: typo.bodyMedium.copyWith(
                  color: colors.textMid,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
