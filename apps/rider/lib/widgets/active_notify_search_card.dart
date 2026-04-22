import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../constants/rider_search_window.dart';
import '../utils/ride_matching_labels.dart';

/// Theme-aware background "notify me" search card with ride-type label and details.
class ActiveNotifySearchCard extends StatefulWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final DateTime startedAt;
  final String bookingMode;
  final String? pickupSummary;
  final String? destinationSummary;
  final Future<void> Function() onClosePressed;

  const ActiveNotifySearchCard({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.startedAt,
    required this.bookingMode,
    this.pickupSummary,
    this.destinationSummary,
    required this.onClosePressed,
  });

  @override
  State<ActiveNotifySearchCard> createState() => _ActiveNotifySearchCardState();
}

class _ActiveNotifySearchCardState extends State<ActiveNotifySearchCard> {
  Timer? _tick;
  bool _detailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    final l10n = widget.l10n;

    final elapsed = DateTime.now().difference(widget.startedAt);
    final totalSec = kRiderDriverSearchWindow.inSeconds;
    final elapsedSec = elapsed.inSeconds.clamp(0, totalSec);
    final progress = totalSec == 0 ? 0.0 : elapsedSec / totalSec;
    final remaining = kRiderDriverSearchWindow - elapsed;
    final minutesLeft = remaining.isNegative
        ? 0
        : (remaining.inSeconds / 60).ceil().clamp(0, 30);

    final typeLabel = rideMatchingTypeShortLabel(l10n, widget.bookingMode);
    final hasRoute = (widget.pickupSummary != null &&
            widget.pickupSummary!.trim().isNotEmpty) ||
        (widget.destinationSummary != null &&
            widget.destinationSummary!.trim().isNotEmpty);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: hasRoute
            ? () => setState(() => _detailsExpanded = !_detailsExpanded)
            : null,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: ColoredBox(color: colors.accent),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 44, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: colors.accent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              typeLabel,
                              style: typo.labelSmall.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (hasRoute) ...[
                            const Spacer(),
                            Icon(
                              _detailsExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: colors.textSoft,
                              size: 22,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              color: colors.accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.activeSearchWidget,
                                  style: typo.titleMedium.copyWith(
                                    color: colors.text,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.activeSearchBannerSubtitle,
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textMid,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_detailsExpanded && hasRoute) ...[
                        const SizedBox(height: 12),
                        Divider(height: 1, color: colors.border),
                        const SizedBox(height: 10),
                        Text(
                          l10n.homeNearTermTripDetails,
                          style: typo.labelLarge.copyWith(
                            color: colors.textSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.pickupSummary != null &&
                            widget.pickupSummary!.trim().isNotEmpty)
                          _routeLine(
                            colors: colors,
                            typo: typo,
                            icon: Icons.radio_button_checked,
                            iconColor: colors.success,
                            label: l10n.pickup,
                            text: widget.pickupSummary!.trim(),
                          ),
                        if (widget.destinationSummary != null &&
                            widget.destinationSummary!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _routeLine(
                            colors: colors,
                            typo: typo,
                            icon: Icons.location_on_rounded,
                            iconColor: colors.error,
                            label: l10n.destination,
                            text: widget.destinationSummary!.trim(),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      Text(
                        l10n.activeSearchCardHint,
                        style: typo.bodySmall.copyWith(
                          color: colors.textSoft,
                          height: 1.5,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor:
                              colors.border.withValues(alpha: 0.35),
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.activeSearchMinutesLeft(minutesLeft),
                        style: typo.labelLarge.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  top: 2,
                  end: 2,
                  child: IconButton(
                    onPressed: () async {
                      await widget.onClosePressed();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSoft,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _routeLine({
    required HeyCabyColorTokens colors,
    required HeyCabyTypography typo,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String text,
  }) {
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
                text,
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
}
