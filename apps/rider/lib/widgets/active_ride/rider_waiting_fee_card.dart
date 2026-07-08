import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../../models/ride_waiting_info.dart';

/// Waiting timer + live fare tick when the driver is outside (post-grace).
class RiderWaitingFeeCard extends StatelessWidget {
  const RiderWaitingFeeCard({
    super.key,
    required this.colors,
    required this.typo,
    required this.info,
    required this.l10n,
    required this.quotedFareEuro,
    this.liveFareCents,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final RideWaitingInfo info;
  final AppLocalizations l10n;
  final double? quotedFareEuro;
  final int? liveFareCents;

  String _duration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final m = (safe % 3600) ~/ 60;
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _money(int cents) => HeyCabyRideFare.formatCentsLabel(cents) ?? '€0.00';

  @override
  Widget build(BuildContext context) {
    final elapsed = info.elapsedSinceArrivalSeconds();
    final chargeable = info.chargeableSecondsNow();
    final remainingGrace = info.remainingGraceSecondsNow();
    final waitFeeCents = info.waitingFeeCentsNow();
    final baseCents = info.resolveBaseFareCents(
      quotedFareEuro: quotedFareEuro,
      liveFareCents: liveFareCents,
    );
    final totalCents = baseCents + waitFeeCents;
    final isGrace = !info.waived && chargeable == 0;
    final graceProgress = info.graceSeconds <= 0
        ? 1.0
        : (1 - (remainingGrace / info.graceSeconds)).clamp(0.0, 1.0);

    final title = info.waived
        ? l10n.activeRideWaitingFeeWaived
        : isGrace
            ? l10n.activeRideWaitingFreePickupTime
            : l10n.activeRideWaitingTime;

    final timerLabel = info.waived
        ? _money(0)
        : isGrace
            ? _duration(remainingGrace)
            : _duration(chargeable);

    final subtitle = info.waived
        ? l10n.activeRideWaitingFeeWaivedBody
        : isGrace
            ? l10n.activeRideWaitingGraceBody
            : l10n.activeRideWaitingFeeAdded(_money(waitFeeCents));

    final rate = info.ratePerMinute > 0
        ? l10n.activeRideWaitingRate(
            '€${info.ratePerMinute.toStringAsFixed(2)}/min',
          )
        : l10n.activeRideWaitingRateNotSet;

    final accent = info.waived
        ? colors.success
        : isGrace
            ? colors.accent
            : colors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.12),
            colors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: info.waived ? 1 : (isGrace ? graceProgress : 1),
                        strokeWidth: 5,
                        backgroundColor: colors.border.withValues(alpha: 0.35),
                        color: accent,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          info.waived
                              ? Icons.volunteer_activism_rounded
                              : Icons.timer_outlined,
                          color: accent,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timerLabel,
                          style: typo.labelLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      elapsed < info.graceSeconds
                          ? rate
                          : l10n.activeRideWaitingRateLive(rate),
                      style: typo.labelSmall.copyWith(
                        color: colors.textSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!info.waived && baseCents > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.bgAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.activeRideWaitingTripTotal,
                          style: typo.labelSmall.copyWith(
                            color: colors.textSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _money(totalCents),
                          style: typo.headingMedium.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (waitFeeCents > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.activeRideWaitingFeeLine(_money(waitFeeCents)),
                          style: typo.labelSmall.copyWith(
                            color: colors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.activeRideWaitingBaseFare(_money(baseCents)),
                          style: typo.labelSmall.copyWith(
                            color: colors.textSoft,
                          ),
                        ),
                      ],
                    )
                  else if (isGrace)
                    Text(
                      l10n.activeRideWaitingFreeWindow(
                        '${info.graceSeconds ~/ 60}',
                      ),
                      style: typo.labelSmall.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.end,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
