import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../constants/rider_search_window.dart';
import '../../models/ride_matching_variant.dart';
import 'matching_recovery_sheet.dart';
import 'matching_search_did_you_know.dart';

/// Minimal Bolt-style pull-up sheet while searching for a driver.
class MatchingSearchSheet extends StatelessWidget {
  const MatchingSearchSheet({
    super.key,
    required this.scrollController,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.pickup,
    required this.destination,
    required this.variant,
    this.onSeeOptions,
    this.marketplaceBidCount = 0,
    this.showOptionsHint = false,
    this.waveCountdown,
    this.expired = false,
    this.onTryAgain,
    this.onNotifyMe,
    this.onSchedule,
    this.onMarketplace,
  });

  final ScrollController scrollController;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String title;
  final String subtitle;
  final double progress;
  final String pickup;
  final String destination;
  final RideMatchingVariant variant;
  final VoidCallback? onSeeOptions;
  final int marketplaceBidCount;
  final bool showOptionsHint;
  final String? waveCountdown;
  final bool expired;
  final VoidCallback? onTryAgain;
  final VoidCallback? onNotifyMe;
  final VoidCallback? onSchedule;
  final VoidCallback? onMarketplace;

  @override
  Widget build(BuildContext context) {
    if (expired &&
        onTryAgain != null &&
        onNotifyMe != null &&
        onSchedule != null &&
        onMarketplace != null) {
      final minutes = kRiderDriverSearchWindow.inMinutes;
      return MatchingRecoverySheet(
        scrollController: scrollController,
        colors: colors,
        typo: typo,
        l10n: l10n,
        title: l10n.searchExpiredSheetTitle,
        body: l10n.searchExpiredSheetBody(minutes),
        variant: variant,
        showTryAgain: true,
        onTryAgain: onTryAgain!,
        onNotifyMe: onNotifyMe!,
        onSchedule: onSchedule!,
        onMarketplace: onMarketplace!,
        initiallyExpanded: false,
      );
    }

    return GlassPanel(
      colors: colors,
      typography: typo,
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      tintColor: colors.card,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 20),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typo.titleLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: typo.bodyMedium.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (waveCountdown != null) ...[
                const SizedBox(width: 12),
                Text(
                  waveCountdown!,
                  style: typo.titleMedium.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.05, 1.0),
              minHeight: 4,
              backgroundColor: colors.border.withValues(alpha: 0.55),
              color: colors.accent,
            ),
          ),
          if (!expired) ...[
            const SizedBox(height: 14),
            MatchingSearchDidYouKnowStrip(
              colors: colors,
              typo: typo,
              l10n: l10n,
            ),
          ],
          if (pickup.isNotEmpty || destination.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MatchingSearchRouteSummary(
              colors: colors,
              typo: typo,
              pickup: pickup,
              destination: destination,
            ),
          ],
          if ((variant == RideMatchingVariant.marketplace ||
                  variant == RideMatchingVariant.terug) &&
              marketplaceBidCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              l10n.matchingStatusOffers,
              style: typo.labelLarge.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (showOptionsHint && onSeeOptions != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onSeeOptions,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.searchSeeOptions,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pickup muted; destination uses primary text so the drop-off stays readable.
class _MatchingSearchRouteSummary extends StatelessWidget {
  const _MatchingSearchRouteSummary({
    required this.colors,
    required this.typo,
    required this.pickup,
    required this.destination,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String pickup;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final pickupStyle = typo.bodyMedium.copyWith(
      color: colors.textMid,
      fontWeight: FontWeight.w500,
    );
    final arrowStyle = typo.bodyMedium.copyWith(
      color: colors.textMid,
      fontWeight: FontWeight.w500,
    );
    final destinationStyle = typo.bodyMedium.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w600,
    );

    if (pickup.isEmpty) {
      return Text(
        destination,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: destinationStyle,
      );
    }
    if (destination.isEmpty) {
      return Text(
        pickup,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: destinationStyle,
      );
    }

    return Text.rich(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      TextSpan(
        children: [
          TextSpan(text: pickup, style: pickupStyle),
          TextSpan(text: ' → ', style: arrowStyle),
          TextSpan(text: destination, style: destinationStyle),
        ],
      ),
    );
  }
}
