import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';

/// Legacy chip — kept for any external references; prefer [TripSummaryRouteCard].
class TripSummaryStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const TripSummaryStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.accent, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.labelLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card: trip metrics + pickup + drop-off.
class TripSummaryRouteCard extends StatelessWidget {
  const TripSummaryRouteCard({
    super.key,
    required this.booking,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onEditAddress,
    this.distanceKm,
    this.etaText,
    this.priceLabel,
    this.isPriceLoading = false,
  });

  final BookingState booking;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final void Function(bool isPickup) onEditAddress;
  final double? distanceKm;
  final String? etaText;
  final String? priceLabel;
  final bool isPriceLoading;

  @override
  Widget build(BuildContext context) {
    final distanceLabel = distanceKm != null && distanceKm! > 0
        ? '${distanceKm!.toStringAsFixed(1)} km'
        : null;
    final durationLabel =
        etaText != null && etaText!.trim().isNotEmpty && etaText != '—'
            ? etaText
            : null;
    final showMetrics = distanceLabel != null ||
        durationLabel != null ||
        priceLabel != null ||
        isPriceLoading;

    final pickupFull = booking.pickup?.fullAddress ?? l10n.pickup;
    final dropoffFull = booking.destination?.fullAddress ?? l10n.destination;
    final pickupLines = _addressLines(pickupFull);
    final dropoffLines = _addressLines(dropoffFull);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showMetrics)
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 11, 16, 11),
              decoration: BoxDecoration(
                color: colors.accentL.withValues(alpha: 0.42),
                border: Border(
                  bottom: BorderSide(
                    color: colors.accent.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (distanceLabel != null)
                    _TripMetric(
                      icon: Icons.route_rounded,
                      label: distanceLabel,
                      colors: colors,
                      typo: typo,
                    ),
                  if (distanceLabel != null && durationLabel != null)
                    _MetricDot(colors: colors),
                  if (durationLabel != null)
                    _TripMetric(
                      icon: Icons.schedule_rounded,
                      label: durationLabel,
                      colors: colors,
                      typo: typo,
                    ),
                  if (priceLabel != null &&
                      (distanceLabel != null || durationLabel != null))
                    _MetricDot(colors: colors),
                  if (priceLabel != null)
                    _TripMetric(
                      icon: Icons.euro_rounded,
                      label: priceLabel!,
                      colors: colors,
                      typo: typo,
                    ),
                  if (isPriceLoading && priceLabel == null) ...[
                    if (distanceLabel != null || durationLabel != null)
                      _MetricDot(colors: colors),
                    _LivePriceRadar(colors: colors),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 18,
                    child: _RouteTimeline(colors: colors),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RouteStopRow(
                          primary: pickupLines.$1,
                          secondary: pickupLines.$2,
                          colors: colors,
                          typo: typo,
                          onTap: () {
                            HapticService.lightTap();
                            onEditAddress(true);
                          },
                        ),
                        _RouteStopRow(
                          primary: dropoffLines.$1,
                          secondary: dropoffLines.$2,
                          colors: colors,
                          typo: typo,
                          onTap: () {
                            HapticService.lightTap();
                            onEditAddress(false);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

(String primary, String? secondary) _addressLines(String full) {
  final trimmed = full.trim();
  if (trimmed.isEmpty) return ('', null);
  final comma = trimmed.indexOf(',');
  if (comma <= 0 || comma >= trimmed.length - 1) {
    return (trimmed, null);
  }
  final primary = trimmed.substring(0, comma).trim();
  final secondary = trimmed.substring(comma + 1).trim();
  if (secondary.isEmpty) return (trimmed, null);
  return (primary, secondary);
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({required this.colors});

  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.warning, width: 2.5),
            color: colors.warning.withValues(alpha: 0.22),
          ),
        ),
        Expanded(
          child: Container(
            width: 2,
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.warning.withValues(alpha: 0.28),
                  colors.border.withValues(alpha: 0.85),
                  colors.success.withValues(alpha: 0.45),
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.success,
            boxShadow: [
              BoxShadow(
                color: colors.success.withValues(alpha: 0.28),
                blurRadius: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricDot extends StatelessWidget {
  const _MetricDot({required this.colors});

  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '·',
        style: TextStyle(
          color: colors.textSoft.withValues(alpha: 0.9),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class _TripMetric extends StatelessWidget {
  const _TripMetric({
    required this.icon,
    required this.label,
    required this.colors,
    required this.typo,
  });

  final IconData icon;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colors.accent, size: 15),
        const SizedBox(width: 5),
        Text(
          label,
          style: typo.labelLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

/// A restrained live-rate signal shown only while Supabase resolves tariffs.
class _LivePriceRadar extends StatefulWidget {
  const _LivePriceRadar({required this.colors});

  final HeyCabyColorTokens colors;

  @override
  State<_LivePriceRadar> createState() => _LivePriceRadarState();
}

class _LivePriceRadarState extends State<_LivePriceRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.45;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Live fare estimate loading',
      child: SizedBox(
        width: 28,
        height: 20,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _LivePriceRadarPainter(
              progress: _controller.value,
              color: widget.colors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _LivePriceRadarPainter extends CustomPainter {
  const _LivePriceRadarPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var index = 0; index < 2; index++) {
      final phase = (progress + index * 0.5) % 1;
      canvas.drawCircle(
        center,
        3 + phase * 7,
        Paint()
          ..color = color.withValues(alpha: (1 - phase) * 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    canvas.drawCircle(center, 2.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LivePriceRadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _RouteStopRow extends StatelessWidget {
  const _RouteStopRow({
    required this.primary,
    required this.secondary,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final String primary;
  final String? secondary;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 2, 4, 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary,
                      style: typo.titleSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        letterSpacing: -0.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondary != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondary!,
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 1),
                child: Icon(
                  Icons.edit_outlined,
                  color: colors.textSoft.withValues(alpha: 0.85),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
