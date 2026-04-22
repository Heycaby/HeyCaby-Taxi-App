import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/near_term_ride_request_provider.dart';
import '../utils/ride_matching_labels.dart';

/// Home sheet banner for an open ride_request within the near-term window (matching or pickup soon).
/// Tapping expands trip details in place — does not navigate to the searching screen.
class NearTermRideHomeBanner extends ConsumerStatefulWidget {
  const NearTermRideHomeBanner({super.key});

  @override
  ConsumerState<NearTermRideHomeBanner> createState() =>
      _NearTermRideHomeBannerState();
}

class _NearTermRideHomeBannerState extends ConsumerState<NearTermRideHomeBanner> {
  Timer? _ticker;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _formatRemaining(DateTime pickup) {
    final now = DateTime.now();
    if (!pickup.isAfter(now)) return '—';
    final d = pickup.difference(now);
    if (d.inDays >= 1) {
      return '${d.inDays}d ${d.inHours.remainder(24)}h';
    }
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes.clamp(1, 9999)}m';
  }

  static String _titleForMode(AppLocalizations l10n, String? mode) {
    switch (mode) {
      case 'marketplace':
        return l10n.homeNearTermTitleMarketplace;
      case 'scheduled':
        return l10n.homeNearTermTitleScheduled;
      default:
        return l10n.homeNearTermTitleInstant;
    }
  }

  static Widget _detailRow({
    required HeyCabyColorTokens colors,
    required HeyCabyTypography typo,
    required AppLocalizations l10n,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: typo.labelSmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value.trim(),
                style: typo.bodySmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnap = ref.watch(nearTermRideRequestProvider);
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    return asyncSnap.when(
      data: (snap) {
        if (snap == null) return const SizedBox.shrink();
        final modeLabel =
            rideMatchingTypeShortLabel(l10n, snap.bookingMode ?? 'instant');
        final title = _titleForMode(l10n, snap.bookingMode);
        final subtitle = snap.scheduledPickupAt == null
            ? l10n.homeNearTermOpenMatchingHint
            : l10n.homeNearTermUntilPickup(
                _formatRemaining(snap.scheduledPickupAt!),
              );

        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      colors.accent.withValues(alpha: 0.22),
                      colors.accent.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_taxi_rounded,
                              color: colors.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        style: typo.titleMedium.copyWith(
                                          color: colors.text,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding:
                                          const EdgeInsetsDirectional.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.card.withValues(
                                          alpha: 0.55,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: colors.border.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        modeLabel,
                                        style: typo.labelSmall.copyWith(
                                          color: colors.text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textMid,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!_expanded &&
                                    snap.destinationAddress.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    snap.destinationAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typo.labelMedium.copyWith(
                                      color: colors.textSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          RotatedBox(
                            quarterTurns: _expanded ? 2 : 0,
                            child: Icon(
                              Icons.expand_more_rounded,
                              color: colors.textSoft,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: colors.border.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.homeNearTermTripDetails,
                          style: typo.labelLarge.copyWith(
                            color: colors.textSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _detailRow(
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                          icon: Icons.radio_button_checked,
                          iconColor: colors.success,
                          label: l10n.pickup,
                          value: snap.pickupAddress,
                        ),
                        const SizedBox(height: 8),
                        _detailRow(
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                          icon: Icons.location_on_rounded,
                          iconColor: colors.error,
                          label: l10n.destination,
                          value: snap.destinationAddress,
                        ),
                        if (snap.scheduledPickupAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.scheduledRideLabel,
                            style: typo.labelSmall.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            () {
                              final loc = MaterialLocalizations.of(context);
                              final d = snap.scheduledPickupAt!.toLocal();
                              final t = TimeOfDay.fromDateTime(d);
                              return '${loc.formatMediumDate(d)} · ${loc.formatTimeOfDay(t)}';
                            }(),
                            style: typo.bodySmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
