import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../constants/rider_search_window.dart';
import '../../models/ride_matching_variant.dart';
import 'matching_recovery_sheet.dart';
import 'matching_search_did_you_know.dart';

/// Minimal pull-up sheet while searching for a driver.
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
    this.onTryTaxiTerug,
    this.marketplaceBidCount = 0,
    this.showOptionsHint = false,
    this.waveCountdown,
    this.expired = false,
    this.onTryAgain,
    this.onNotifyMe,
    this.onSchedule,
    this.onMarketplace,
    this.onDismiss,
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
  final VoidCallback? onTryTaxiTerug;
  final int marketplaceBidCount;
  final bool showOptionsHint;
  final String? waveCountdown;
  final bool expired;
  final VoidCallback? onTryAgain;
  final VoidCallback? onNotifyMe;
  final VoidCallback? onSchedule;
  final VoidCallback? onMarketplace;
  final VoidCallback? onDismiss;

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
        onDismiss: onDismiss,
        initiallyExpanded: false,
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return GlassPanel(
      colors: colors,
      typography: typo,
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      tintColor: colors.card,
      borderColor: colors.border.withValues(alpha: 0.28),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsetsDirectional.fromSTEB(20, 10, 20, 16 + bottomInset),
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (pickup.isNotEmpty || destination.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MatchingSearchRouteSummary(
              colors: colors,
              typo: typo,
              pickup: pickup,
              destination: destination,
            ),
          ],
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.border.withValues(alpha: 0.34)),
          const SizedBox(height: 16),
          if (showOptionsHint && onTryTaxiTerug != null)
            _NoSupplyTaxiTerugRow(
              colors: colors,
              typo: typo,
              l10n: l10n,
              title: title,
              body: subtitle,
              onTryTaxiTerug: onTryTaxiTerug!,
            )
          else
            _MatchingStatusBlock(
              colors: colors,
              typo: typo,
              title: title,
              subtitle: subtitle,
              waveCountdown: waveCountdown,
            ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.02, 1.0),
              minHeight: 4,
              backgroundColor: colors.border.withValues(alpha: 0.30),
              color: colors.accent,
            ),
          ),
          if (!expired) ...[
            const SizedBox(height: 16),
            MatchingSearchDidYouKnowStrip(
              colors: colors,
              typo: typo,
              l10n: l10n,
            ),
          ],
          if ((variant == RideMatchingVariant.marketplace ||
                  variant == RideMatchingVariant.terug) &&
              marketplaceBidCount > 0) ...[
            const SizedBox(height: 14),
            Text(
              l10n.matchingStatusOffers,
              style: typo.labelLarge.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (showOptionsHint && onSeeOptions != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onSeeOptions,
                style: TextButton.styleFrom(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.searchSeeOptions,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
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

class _MatchingStatusBlock extends StatelessWidget {
  const _MatchingStatusBlock({
    required this.colors,
    required this.typo,
    required this.title,
    required this.subtitle,
    required this.waveCountdown,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String subtitle;
  final String? waveCountdown;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stackCountdown = constraints.maxWidth < 350 || scale > 1.2;
        final countdown = waveCountdown == null
            ? null
            : _WaveCountdownPill(
                colors: colors,
                typo: typo,
                label: waveCountdown!,
              );

        return Semantics(
          liveRegion: true,
          label: '$title. $subtitle',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.accentL.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.local_taxi_outlined,
                      color: colors.accent,
                      size: 21,
                    ),
                    PositionedDirectional(
                      end: 6,
                      bottom: 6,
                      child: _SearchingLiveDot(color: colors.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typo.titleLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodyMedium.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        letterSpacing: 0,
                      ),
                    ),
                    if (stackCountdown && countdown != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: countdown,
                      ),
                    ],
                  ],
                ),
              ),
              if (!stackCountdown && countdown != null) ...[
                const SizedBox(width: 10),
                countdown,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WaveCountdownPill extends StatelessWidget {
  const _WaveCountdownPill({
    required this.colors,
    required this.typo,
    required this.label,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: typo.titleSmall.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _SearchingLiveDot extends StatefulWidget {
  const _SearchingLiveDot({required this.color});

  final Color color;

  @override
  State<_SearchingLiveDot> createState() => _SearchingLiveDotState();
}

class _SearchingLiveDotState extends State<_SearchingLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.7 + (_controller.value * 0.5);
        return SizedBox(
          width: 10,
          height: 10,
          child: Center(
            child: Container(
              width: 6 * pulse,
              height: 6 * pulse,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoSupplyTaxiTerugRow extends StatelessWidget {
  const _NoSupplyTaxiTerugRow({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.title,
    required this.body,
    required this.onTryTaxiTerug,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String title;
  final String body;
  final VoidCallback onTryTaxiTerug;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 7),
              child: _SearchingLiveDot(color: colors.warning),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typo.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: typo.bodyMedium.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TaxiTerugPromoCard(
          colors: colors,
          typo: typo,
          title: l10n.homeTaxiTerugTitle,
          subtitle: l10n.searchNoSupplyTaxiTerugCardSubtitle,
          onTap: onTryTaxiTerug,
        ),
      ],
    );
  }
}

class _TaxiTerugPromoCard extends StatelessWidget {
  const _TaxiTerugPromoCard({
    required this.colors,
    required this.typo,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.bg.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border.withValues(alpha: 0.48)),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.accentL.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.keyboard_return_rounded,
                  color: colors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.labelLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.textSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// Destination is the hero; pickup stays secondary.
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
    final primary = destination.isNotEmpty ? destination : pickup;
    final secondary = destination.isNotEmpty ? pickup : '';

    if (primary.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: secondary.isNotEmpty ? 46 : 22,
          child: CustomPaint(
            painter: _RouteGlyphPainter(
              color: colors.accent,
              lineColor: colors.border,
              showOrigin: secondary.isNotEmpty,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (secondary.isNotEmpty) ...[
                Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.bodyMedium.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(
                primary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.titleLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteGlyphPainter extends CustomPainter {
  const _RouteGlyphPainter({
    required this.color,
    required this.lineColor,
    required this.showOrigin,
  });

  final Color color;
  final Color lineColor;
  final bool showOrigin;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final startY = showOrigin ? 5.0 : size.height / 2;
    final endY = showOrigin ? size.height - 5 : size.height / 2;
    if (showOrigin) {
      canvas.drawLine(
        Offset(x, startY + 4),
        Offset(x, endY - 4),
        Paint()
          ..color = lineColor
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        Offset(x, startY),
        3,
        Paint()..color = lineColor,
      );
    }
    canvas.drawCircle(Offset(x, endY), 4.5, Paint()..color = color);
    canvas.drawCircle(
      Offset(x, endY),
      1.7,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteGlyphPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.showOrigin != showOrigin;
}
