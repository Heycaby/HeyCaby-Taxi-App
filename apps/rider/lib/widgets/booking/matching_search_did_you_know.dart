import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class _SearchFact {
  const _SearchFact({required this.text});

  final String text;
}

List<_SearchFact> _searchFacts(AppLocalizations l10n) => [
      _SearchFact(text: l10n.searchFactDriversKeep100),
      _SearchFact(text: l10n.searchFactNoSurgePricing),
      _SearchFact(text: l10n.searchFactAllVerified),
      _SearchFact(text: l10n.searchFactMarketplace),
      _SearchFact(text: l10n.searchFactZZP),
      _SearchFact(text: l10n.searchFactSaveAddresses),
      _SearchFact(text: l10n.searchFactPayHowYouWant),
      _SearchFact(text: l10n.searchFactFavorites),
    ];

/// Quiet rotating footnote while the rider waits for a match.
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

  late List<_SearchFact> _facts;
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
  void didUpdateWidget(covariant MatchingSearchDidYouKnowStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.l10n != widget.l10n) {
      _facts = _searchFacts(widget.l10n);
      _index = _facts.isEmpty ? 0 : _index % _facts.length;
    }
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bg.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.38)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: colors.textMid,
                  size: 19,
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
                        color: colors.textMid,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        if (reduceMotion) return child;
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.035, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        fact.text,
                        key: ValueKey<int>(_index),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: typo.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        for (var i = 0; i < _facts.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          AnimatedContainer(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            width: i == _index ? 12 : 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? colors.textMid
                                  : colors.border.withValues(alpha: 0.85),
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
      ),
    );
  }
}
