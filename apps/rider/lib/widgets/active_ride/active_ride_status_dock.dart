import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../../models/ride_waiting_info.dart';
import '../../utils/rider_journey_progress.dart';

/// Status-driven journey timeline — floats above the sheet, never buried inside it.
class ActiveRideStatusDock extends StatelessWidget {
  const ActiveRideStatusDock({
    super.key,
    required this.status,
    required this.colors,
    required this.typo,
    required this.l10n,
    this.etaMinutes,
    this.waitingInfo,
    this.quotedFareEuro,
    this.liveFareCents,
    this.plateVerified = true,
    this.onVerifyPlate,
    this.pickupLabel,
    this.destinationLabel,
    this.taxiTerugQueued = false,
    this.taxiTerugPickupMin,
    this.taxiTerugPickupMax,
    this.driverOnMyWay = false,
    this.driverLat,
    this.driverLng,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.enRouteBaselineKm,
    this.tripBaselineKm,
  });

  final String status;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final int? etaMinutes;
  final RideWaitingInfo? waitingInfo;
  final double? quotedFareEuro;
  final int? liveFareCents;
  final bool plateVerified;
  final VoidCallback? onVerifyPlate;
  final String? pickupLabel;
  final String? destinationLabel;
  final bool taxiTerugQueued;
  final int? taxiTerugPickupMin;
  final int? taxiTerugPickupMax;
  final bool driverOnMyWay;
  final double? driverLat;
  final double? driverLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? enRouteBaselineKm;
  final double? tripBaselineKm;

  bool get _isArrived =>
      status == 'driver_arrived' || status == 'arrived';

  bool get _isEnRoute => RiderJourneyProgress.isEnRouteToPickup(status);

  bool get _isInProgress => status == 'in_progress';

  bool get _pinsVisible => RiderJourneyProgress.isDriverMatched(status);

  RiderJourneyProgress get _journey => RiderJourneyProgress.compute(
        status: status,
        driverOnMyWay: driverOnMyWay,
        driverLat: driverLat,
        driverLng: driverLng,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        destLat: destLat,
        destLng: destLng,
        enRouteBaselineKm: enRouteBaselineKm,
        tripBaselineKm: tripBaselineKm,
      );

  String _headline() {
    if (taxiTerugQueued && !_isInProgress && !_isArrived) {
      return l10n.taxiTerugQueuedConfirmed;
    }
    if (_journey.isNearPickup && !_isArrived && !_isInProgress) {
      return l10n.activeRideDriverAroundCorner;
    }
    switch (status) {
      case 'driver_arrived':
      case 'arrived':
        return l10n.activeRideDriverOutside;
      case 'in_progress':
        return l10n.activeRideTripInProgressHeadline;
      case 'accepted':
      case 'assigned':
      case 'driver_found':
      case 'driver_en_route':
        if (driverOnMyWay || status == 'driver_en_route') {
          return l10n.driverOnTheWay;
        }
        return l10n.activeRideDriverFound;
      default:
        return l10n.activeRideDriverFound;
    }
  }

  String? _contextLine(int currentIndex) {
    if (taxiTerugQueued && !_isInProgress && !_isArrived) {
      return l10n.taxiTerugQueuedWaitingForDriver;
    }
    if (_isInProgress) {
      final from = pickupLabel?.trim();
      final to = destinationLabel?.trim();
      if (from != null &&
          from.isNotEmpty &&
          to != null &&
          to.isNotEmpty) {
        return '$from → $to';
      }
    }
    switch (currentIndex) {
      case 0:
        return l10n.rideTimelineStepAccepted;
      case 1:
        return l10n.rideTimelineStepEnRoute;
      case 2:
        return l10n.activeRideDriverAroundCorner;
      case 3:
        return l10n.rideTimelineStepArrived;
      case 4:
        return l10n.rideTimelineStepInProgress;
      default:
        return l10n.rideTimelineStepCompleted;
    }
  }

  String? _etaLabel() {
    if (taxiTerugQueued &&
        !_isInProgress &&
        !_isArrived &&
        taxiTerugPickupMin != null &&
        taxiTerugPickupMax != null) {
      return l10n.taxiTerugCandidatePickupWindow(
        taxiTerugPickupMin!,
        taxiTerugPickupMax!,
      );
    }
    if (etaMinutes == null) return null;
    if (_isInProgress) {
      return l10n.activeRideArrivingIn(etaMinutes!.toString());
    }
    if (_isEnRoute || _isArrived) {
      return l10n.activeRidePickupIn(etaMinutes!.toString());
    }
    return null;
  }

  String? _tripTotalLabel() {
    if (waitingInfo == null) return null;
    final info = waitingInfo!;
    final total = info.totalFareCentsNow(
      quotedFareEuro: quotedFareEuro,
      liveFareCents: liveFareCents,
    );
    if (total <= 0) return null;
    return HeyCabyRideFare.formatCentsLabel(total);
  }

  List<_JourneyTimelineStep> _timelineSteps() {
    return [
      _JourneyTimelineStep(
        label: l10n.activeRideDriverFound,
        icon: Icons.check_rounded,
      ),
      _JourneyTimelineStep(
        label: l10n.rideTimelineStepEnRoute,
        icon: Icons.directions_car_filled_rounded,
      ),
      _JourneyTimelineStep(
        label: l10n.activeRideDriverAroundCorner,
        icon: Icons.near_me_rounded,
      ),
      _JourneyTimelineStep(
        label: l10n.activeRideTimelinePickup,
        icon: Icons.trip_origin_rounded,
        detail: pickupLabel,
      ),
      _JourneyTimelineStep(
        label: l10n.activeRideTimelineDestination,
        icon: Icons.flag_rounded,
        detail: destinationLabel,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_pinsVisible) return const SizedBox.shrink();

    final journey = _journey;
    final currentIndex = journey.stepIndex;
    final tripTotal = _tripTotalLabel();
    final contextLine = _contextLine(currentIndex);
    final showTimeline = journey.showLiveTrack;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: showTimeline
                  ? colors.accent.withValues(alpha: 0.5)
                  : _isArrived
                      ? colors.accent.withValues(alpha: 0.45)
                      : colors.border.withValues(alpha: 0.6),
              width: showTimeline ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: showTimeline
                    ? colors.accent.withValues(alpha: 0.16)
                    : colors.text.withValues(alpha: 0.1),
                blurRadius: showTimeline ? 28 : 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Column(
              key: ValueKey<String>(status),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.rideTimeline,
                            style: typo.labelSmall.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _headline(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typo.titleMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (contextLine != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              contextLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: typo.bodySmall.copyWith(
                                color: colors.textMid,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (tripTotal != null && _isArrived) ...[
                      const SizedBox(width: 10),
                      _EtaChip(
                        colors: colors,
                        typo: typo,
                        label: l10n.activeRideWaitingTripTotal,
                        value: tripTotal,
                        emphasizeValue: true,
                      ),
                    ] else if (_etaLabel() != null) ...[
                      const SizedBox(width: 10),
                      _EtaChip(
                        colors: colors,
                        typo: typo,
                        label: _isInProgress
                            ? l10n.activeRideTimelineDestination
                            : l10n.activeRideTimelinePickup,
                        value: _etaLabel()!,
                      ),
                    ],
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: showTimeline
                      ? Column(
                          key: const ValueKey('journey-timeline'),
                          children: [
                            const SizedBox(height: 12),
                            _JourneyTimeline(
                              steps: _timelineSteps(),
                              currentIndex: currentIndex,
                              trackProgress: journey.trackProgress,
                              colors: colors,
                              typo: typo,
                            ),
                            if (_isInProgress && journey.remainingKm != null) ...[
                              const SizedBox(height: 12),
                              _TripProgressBar(
                                progress: journey.liveSegmentFraction ?? 0.0,
                                remainingKm: journey.remainingKm!,
                                etaMinutes: journey.etaMinutes,
                                colors: colors,
                                typo: typo,
                                l10n: l10n,
                                destinationLabel: destinationLabel,
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('journey-timeline-hidden'),
                        ),
                ),
                if (_isArrived && waitingInfo != null) ...[
                  const SizedBox(height: 10),
                  _WaitingActionStrip(
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    info: waitingInfo!,
                    quotedFareEuro: quotedFareEuro,
                    liveFareCents: liveFareCents,
                  ),
                ],
                if (_isArrived && !plateVerified && onVerifyPlate != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton.tonal(
                      onPressed: onVerifyPlate,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        l10n.activeRideVerifyPlateButton,
                        style: typo.labelLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyTimelineStep {
  const _JourneyTimelineStep({
    required this.label,
    required this.icon,
    this.detail,
  });

  final String label;
  final IconData icon;
  final String? detail;
}

class _JourneyTimeline extends StatelessWidget {
  const _JourneyTimeline({
    required this.steps,
    required this.currentIndex,
    required this.trackProgress,
    required this.colors,
    required this.typo,
  });

  final List<_JourneyTimelineStep> steps;
  final int currentIndex;
  final double trackProgress;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stepWidth = constraints.maxWidth / steps.length;
        return SizedBox(
          height: 74,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 15,
                left: stepWidth * 0.5,
                right: stepWidth * 0.5,
                child: _TimelineTrack(
                  progress: trackProgress,
                  colors: colors,
                ),
              ),
              Row(
                children: List.generate(steps.length, (index) {
                  final step = steps[index];
                  final isDone = index < currentIndex;
                  final isCurrent = index == currentIndex;
                  final showDetail = isCurrent || isDone;
                  final detail = showDetail ? step.detail : null;

                  return SizedBox(
                    width: stepWidth,
                    child: _TimelineNode(
                      label: step.label,
                      detail: detail,
                      icon: step.icon,
                      isDone: isDone,
                      isCurrent: isCurrent,
                      colors: colors,
                      typo: typo,
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineTrack extends StatelessWidget {
  const _TimelineTrack({
    required this.progress,
    required this.colors,
  });

  final double progress;
  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.55),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: clamped <= 0 ? 0.001 : clamped),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.success,
                          colors.accent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.label,
    required this.detail,
    required this.icon,
    required this.isDone,
    required this.isCurrent,
    required this.colors,
    required this.typo,
  });

  final String label;
  final String? detail;
  final IconData icon;
  final bool isDone;
  final bool isCurrent;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isCurrent ? colors.accent : isDone ? colors.success : colors.textSoft;
    final fillColor = isDone
        ? colors.success
        : isCurrent
            ? colors.accent
            : colors.card;
    final borderColor = isDone || isCurrent
        ? activeColor
        : colors.border.withValues(alpha: 0.85);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: isCurrent ? 32 : 28,
          height: isCurrent ? 32 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: Border.all(color: borderColor, width: isCurrent ? 2 : 1.5),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isDone ? Icons.check_rounded : icon,
            size: isCurrent ? 16 : 14,
            color: isDone || isCurrent ? colors.onAccent : colors.textMid,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: typo.labelSmall.copyWith(
            color: isCurrent ? colors.text : colors.textMid,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            height: 1.1,
          ),
        ),
        if (detail != null && detail!.trim().isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            detail!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.labelSmall.copyWith(
              color: isCurrent ? colors.accent : colors.textSoft,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1.1,
            ),
          ),
        ],
      ],
    );
  }
}

class _EtaChip extends StatelessWidget {
  const _EtaChip({
    required this.colors,
    required this.typo,
    required this.label,
    required this.value,
    this.emphasizeValue = false,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final String value;
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.accentL.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: typo.labelSmall.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: (emphasizeValue ? typo.titleMedium : typo.labelLarge).copyWith(
              color: emphasizeValue ? colors.text : colors.accent,
              fontWeight: FontWeight.w900,
              fontFeatures: emphasizeValue
                  ? const [FontFeature.tabularFigures()]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live trip progress bar — shows distance remaining, ETA, and a visual
/// progress fill during the in_progress phase.
class _TripProgressBar extends StatelessWidget {
  const _TripProgressBar({
    required this.progress,
    required this.remainingKm,
    this.etaMinutes,
    required this.colors,
    required this.typo,
    required this.l10n,
    this.destinationLabel,
  });

  final double progress;
  final double remainingKm;
  final int? etaMinutes;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String? destinationLabel;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();
    final kmStr = remainingKm.toStringAsFixed(1);
    final etaStr = etaMinutes?.toString() ?? '—';

    final now = DateTime.now();
    final arrival = etaMinutes != null
        ? now.add(Duration(minutes: etaMinutes!))
        : null;
    final arrivalStr = arrival != null
        ? '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}'
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colors.accentL.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.activeRideTripProgress,
                style: typo.labelSmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '$pct%',
                style: typo.labelMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: clamped <= 0 ? 0.001 : clamped),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.accent,
                                colors.success,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 14,
                color: colors.accent,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.activeRideDistanceRemaining(kmStr),
                style: typo.labelMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: colors.accent,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.activeRideTimeRemaining(etaStr),
                style: typo.labelMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (arrivalStr != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 12,
                  color: colors.textSoft,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    destinationLabel != null
                        ? '${l10n.activeRideArrivingAround(arrivalStr)} · ${destinationLabel!}'
                        : l10n.activeRideArrivingAround(arrivalStr),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.labelSmall.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact waiting timer row — lives inside the dock when driver arrives.
class _WaitingActionStrip extends StatelessWidget {
  const _WaitingActionStrip({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.info,
    required this.quotedFareEuro,
    this.liveFareCents,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final RideWaitingInfo info;
  final double? quotedFareEuro;
  final int? liveFareCents;

  String _duration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final m = (safe % 3600) ~/ 60;
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _money(int cents) =>
      HeyCabyRideFare.formatCentsLabel(cents) ?? '€0.00';

  @override
  Widget build(BuildContext context) {
    final chargeable = info.chargeableSecondsNow();
    final remainingGrace = info.remainingGraceSecondsNow();
    final waitFeeCents = info.waitingFeeCentsNow();
    final isGrace = !info.waived && chargeable == 0;
    final graceProgress = info.graceSeconds <= 0
        ? 1.0
        : (1 - (remainingGrace / info.graceSeconds)).clamp(0.0, 1.0);

    final accent = info.waived
        ? colors.success
        : isGrace
            ? colors.accent
            : colors.warning;

    final timerLabel = info.waived
        ? '✓'
        : isGrace
            ? _duration(remainingGrace)
            : _duration(chargeable);

    final title = info.waived
        ? l10n.activeRideWaitingFeeWaived
        : isGrace
            ? l10n.activeRideWaitingFreePickupTime
            : l10n.activeRideWaitingTime;

    final detail = info.waived
        ? l10n.activeRideWaitingFeeWaivedBody
        : isGrace
            ? l10n.activeRideWaitingGraceBody
            : l10n.activeRideWaitingFeeAdded(_money(waitFeeCents));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    value: info.waived ? 1 : (isGrace ? graceProgress : 1),
                    strokeWidth: 3.5,
                    backgroundColor: colors.border.withValues(alpha: 0.35),
                    color: accent,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  timerLabel,
                  style: typo.labelMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typo.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typo.bodySmall.copyWith(color: colors.textMid),
                ),
              ],
            ),
          ),
          if (isGrace && !info.waived)
            Text(
              l10n.activeRideWaitingFreeWindow('${info.graceSeconds ~/ 60}'),
              style: typo.labelSmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

String activeRideShortPlaceLabel(String? raw, String fallback) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return fallback;
  return value.split(',').first.trim();
}
