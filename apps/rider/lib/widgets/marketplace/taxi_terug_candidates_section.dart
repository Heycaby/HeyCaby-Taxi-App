import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../models/taxi_terug_candidate.dart';
import '../../providers/marketplace_pricing_provider.dart';
import '../../providers/taxi_terug_candidates_provider.dart';

class TaxiTerugCandidatesSection extends ConsumerWidget {
  const TaxiTerugCandidatesSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    this.onSuggestedBid,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ValueChanged<int>? onSuggestedBid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taxiTerugCandidatesProvider);

    return async.when(
      loading: () => _LoadingCard(colors: colors, typo: typo, l10n: l10n),
      error: (_, __) => const SizedBox.shrink(),
      data: (snap) {
        if (!snap.enabled) return const SizedBox.shrink();
        if (snap.candidates.isNotEmpty && onSuggestedBid != null) {
          final best = snap.candidates.first;
          final suggested = best.estimatedFareMin.ceil().clamp(15, 250);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onSuggestedBid!(suggested);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.taxiTerugCandidatesTitle,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              snap.candidates.isEmpty
                  ? l10n.taxiTerugCandidatesEmpty
                  : l10n.taxiTerugCandidatesSubtitle(snap.candidateCount),
              style: typo.bodySmall.copyWith(
                color: colors.textMid,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            if (snap.candidates.isEmpty)
              _EmptyHint(colors: colors, typo: typo, l10n: l10n)
            else
              ...snap.candidates.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CandidateCard(
                    candidate: c,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.taxiTerugCandidatesTitle,
          style: typo.titleSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: colors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.search_rounded, color: colors.textMid, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.taxiTerugCandidatesEmpty,
              style: typo.bodySmall.copyWith(
                color: colors.textMid,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final TaxiTerugCandidate candidate;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final vehicle = candidate.vehicle;
    final heading = candidate.headingTo;
    final fareMin = formatMarketplaceEuro(candidate.estimatedFareMin);
    final fareMax = formatMarketplaceEuro(candidate.estimatedFareMax);
    final fareLabel = candidate.estimatedFareMin == candidate.estimatedFareMax
        ? fareMin
        : l10n.taxiTerugCandidateFareRange(fareMin, fareMax);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TAXI TERUG',
                  style: typo.labelSmall.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                l10n.taxiTerugCandidateMatch(
                  candidate.matchScore.round().clamp(0, 100),
                ),
                style: typo.labelSmall.copyWith(
                  color: colors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            candidate.driverName,
            style: typo.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (vehicle != null && vehicle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              vehicle,
              style: typo.bodySmall.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (heading != null && heading.isNotEmpty)
            Text(
              l10n.taxiTerugCandidateHeading(heading),
              style: typo.bodySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 4),
          if (candidate.inTransit &&
              candidate.pickupAvailableMin != null &&
              candidate.pickupAvailableMax != null)
            Text(
              l10n.taxiTerugCandidatePickupWindow(
                candidate.pickupAvailableMin!,
                candidate.pickupAvailableMax!,
              ),
              style: typo.bodySmall.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Text(
              l10n.taxiTerugCandidateEta(candidate.pickupEtaMinutes),
              style: typo.bodySmall.copyWith(color: colors.textMid),
            ),
          if (candidate.inTransit) ...[
            const SizedBox(height: 4),
            Text(
              l10n.taxiTerugCandidateFinishingRide,
              style: typo.labelSmall.copyWith(
                color: colors.textMid,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            fareLabel,
            style: typo.labelLarge.copyWith(
              color: colors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (candidate.whyMatch != null && candidate.whyMatch!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              candidate.whyMatch!,
              style: typo.labelSmall.copyWith(
                color: colors.textSoft,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
