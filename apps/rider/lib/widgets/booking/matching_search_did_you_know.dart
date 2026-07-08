import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class _SearchFact {
  const _SearchFact({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

List<_SearchFact> _searchFacts(AppLocalizations l10n) => [
      _SearchFact(
        icon: Icons.payments_outlined,
        text: l10n.searchFactDriversKeep100,
      ),
      _SearchFact(
        icon: Icons.trending_flat_rounded,
        text: l10n.searchFactNoSurgePricing,
      ),
      _SearchFact(
        icon: Icons.local_taxi_outlined,
        text: l10n.searchFactAllVerified,
      ),
      _SearchFact(
        icon: Icons.storefront_outlined,
        text: l10n.searchFactMarketplace,
      ),
      _SearchFact(
        icon: Icons.badge_outlined,
        text: l10n.searchFactZZP,
      ),
      _SearchFact(
        icon: Icons.home_outlined,
        text: l10n.searchFactSaveAddresses,
      ),
      _SearchFact(
        icon: Icons.account_balance_wallet_outlined,
        text: l10n.searchFactPayHowYouWant,
      ),
      _SearchFact(
        icon: Icons.favorite_outline_rounded,
        text: l10n.searchFactFavorites,
      ),
    ];

/// Rotating "Did you know?" strip while the rider waits for a match.
class MatchingSearchDidYouKnowStrip extends StatefulWidget {
  const MatchingSearchDidYouKnowStrip({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  State<MatchingSearchDidYouKnowStrip> createState() =>
      _MatchingSearchDidYouKnowStripState();
}

class _MatchingSearchDidYouKnowStripState
    extends State<MatchingSearchDidYouKnowStrip> {
  static const _rotateEvery = Duration(seconds: 9);

  late final List<_SearchFact> _facts;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _facts = _searchFacts(widget.l10n);
    _timer = Timer.periodic(_rotateEvery, (_) {
      if (!mounted || _facts.isEmpty) return;
      setState(() => _index = (_index + 1) % _facts.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_facts.isEmpty) return const SizedBox.shrink();

    final fact = _facts[_index];
    final colors = widget.colors;
    final typo = widget.typo;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accentL.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(fact.icon, color: colors.accent, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.l10n.searchDidYouKnowEyebrow,
                    style: typo.labelMedium.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: Text(
                      fact.text,
                      key: ValueKey<int>(_index),
                      style: typo.bodySmall.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < _facts.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width: i == _index ? 14 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? colors.accent
                                : colors.accent.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ],
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
