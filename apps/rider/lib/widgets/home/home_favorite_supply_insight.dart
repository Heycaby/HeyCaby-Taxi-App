import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../screens/location_required_screen.dart';
import '../../services/nearby_supply_service.dart';

String? _formatKm(double? km) {
  if (km == null || km.isNaN || km <= 0) return null;
  if (km < 10) return km.toStringAsFixed(1);
  return km.round().toString();
}

class HomeFavoriteSupplyInsightCard extends ConsumerWidget {
  const HomeFavoriteSupplyInsightCard({
    super.key,
    required this.snapshot,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final RiderFavoriteSupplySnapshot snapshot;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!snapshot.rpcSucceeded || snapshot.onlineCount <= 0) {
      return const SizedBox.shrink();
    }

    final km = _formatKm(snapshot.closestKm);
    final subtitle = km != null
        ? l10n.homeFavoriteSupplySubtitle(km)
        : l10n.homeFavoriteSupplySubtitleShort;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 0),
      child: Material(
        color: colors.accentL.withValues(alpha: 0.62),
        elevation: 0,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _bookWithFavoritesFirst(context, ref),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: colors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeFavoriteSupplyTitle(snapshot.onlineCount),
                        style: typo.labelLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: colors.textSoft, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _bookWithFavoritesFirst(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await ensureLocationForBooking(context: context, ref: ref);
    if (!ok) return;
    ref.read(bookingProvider.notifier).setMarketplaceDriverAudience(
          MarketplaceDriverAudience.myDriversFirst,
        );
    if (context.mounted) context.go('/search');
  }
}
