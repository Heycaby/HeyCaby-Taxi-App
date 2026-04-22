import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/booking_provider.dart';
import '../providers/marketplace_pricing_provider.dart';
import '../services/booking_flow_navigation.dart';
import '../widgets/address_search_modal.dart';
import '../services/location_service.dart';

/// Premium Marketplace Screen — million-dollar Bolt/Uber-grade design.
/// Zero hardcoded colours or fonts — all values come from design tokens.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  int _bidAmount = 50;
  bool _isSubmitting = false;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAddressSearch(AddressType type) async {
    final pos = await LocationService.requestAndGetLocation();
    if (pos == null) {
      if (mounted) context.go('/location-required');
      return;
    }
    if (!mounted) return;
    final result = await showAddressSearchModal(context, ref, type);
    if (result != null) {
      if (type == AddressType.pickup) {
        ref.read(bookingProvider.notifier).setPickup(result);
      } else {
        ref.read(bookingProvider.notifier).setDestination(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final hasAddresses = booking.pickup != null && booking.destination != null;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
                colors: colors,
                typo: typo,
                l10n: l10n,
                pulseCtrl: _pulseCtrl),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 0),
                children: [
                  _HeroBanner(colors: colors, typo: typo, l10n: l10n)
                      .animate()
                      .fadeIn(duration: 320.ms, curve: Curves.easeOut)
                      .slideY(begin: 0.05, end: 0, duration: 320.ms),
                  const SizedBox(height: 24),
                  _RouteCard(
                    booking: booking,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onPickup: () => _openAddressSearch(AddressType.pickup),
                    onDestination: () =>
                        _openAddressSearch(AddressType.destination),
                  )
                      .animate(delay: 60.ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.05, end: 0, duration: 320.ms),
                  const SizedBox(height: 24),
                  _MarketplaceLiveInsights(
                    bidAmount: _bidAmount,
                    hasAddresses: hasAddresses,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  )
                      .animate(delay: 90.ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.05, end: 0, duration: 320.ms),
                  const SizedBox(height: 14),
                  _PriceComparison(
                    bidAmount: _bidAmount,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  )
                      .animate(delay: 120.ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.05, end: 0, duration: 320.ms),
                  const SizedBox(height: 24),
                  _BidSlider(
                    bidAmount: _bidAmount,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onChanged: (v) => setState(() => _bidAmount = v),
                  )
                      .animate(delay: 180.ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.05, end: 0, duration: 320.ms),
                  const SizedBox(height: 24),
                  _QuickBids(
                    bidAmount: _bidAmount,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onSelect: (v) {
                      HapticService.selectionClick();
                      setState(() => _bidAmount = v);
                    },
                  )
                      .animate(delay: 240.ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.05, end: 0, duration: 320.ms),
                  const SizedBox(height: 28),
                ],
              ),
            ),
            _SubmitFooter(
              isSubmitting: _isSubmitting,
              hasAddresses: hasAddresses,
              bidAmount: _bidAmount,
              colors: colors,
              typo: typo,
              l10n: l10n,
              onTap: () async {
                HapticService.mediumTap();
                ref
                    .read(bookingProvider.notifier)
                    .setMarketplaceBidEuro(_bidAmount);
                ref.read(bookingProvider.notifier).setMarketplace();
                setState(() => _isSubmitting = true);
                try {
                  await BookingFlowNavigation.prefillBookingFromIdentity(ref);
                  if (!context.mounted) return;
                  final next = BookingFlowNavigation.routeAfterAddressesComplete(
                    ref.read(bookingProvider),
                  );
                  context.push(next);
                } finally {
                  if (context.mounted) {
                    setState(() => _isSubmitting = false);
                  }
                }
              },
            )
                .animate(delay: 280.ms)
                .fadeIn(duration: 320.ms)
                .slideY(begin: 0.06, end: 0, duration: 320.ms),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final AnimationController pulseCtrl;

  const _Header({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        HeyCabySpacing.screenEdge,
        HeyCabySpacing.component,
        HeyCabySpacing.screenEdge,
        HeyCabySpacing.component,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticService.lightTap();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.bgAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: colors.text, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.marketplace,
                  style: typo.headingLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.offerFare,
                  style: typo.bodySmall.copyWith(color: colors.textSoft),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: colors.success
                        .withValues(alpha: 0.3 + pulseCtrl.value * 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.85 + pulseCtrl.value * 0.3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.marketplaceLiveBadge,
                    style: typo.bodySmall.copyWith(
                      color: colors.success,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontSize: 11,
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

// ── Hero Banner ───────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _HeroBanner(
      {required this.colors, required this.typo, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.accent.withValues(alpha: 0.22),
                  colors.accent.withValues(alpha: 0.07),
                  colors.bgAlt.withValues(alpha: 0.4),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.accent.withValues(alpha: 0.32)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(Icons.local_offer_rounded,
                      color: colors.onAccent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.marketplaceSubtitle,
                        style: typo.titleMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.marketplaceHeroTagline,
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
          ),
          PositionedDirectional(
            end: -28,
            top: -32,
            child: IgnorePointer(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Route Card ────────────────────────────────────────────────────────────────
class _RouteCard extends StatelessWidget {
  final BookingState booking;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onPickup;
  final VoidCallback onDestination;

  const _RouteCard({
    required this.booking,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onPickup,
    required this.onDestination,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.success.withValues(alpha: 0.85),
                      colors.accent.withValues(alpha: 0.5),
                      colors.error.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(21, 18, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route_rounded,
                          color: colors.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.marketplaceYourRoute,
                        style: typo.labelLarge.copyWith(
                          color: colors.textSoft,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticService.lightTap();
                        onPickup();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 2),
                        child: _AddressRow(
                          dotColor: colors.success,
                          icon: Icons.radio_button_checked,
                          label: booking.pickup?.displayName ?? l10n.pickup,
                          isSet: booking.pickup != null,
                          colors: colors,
                          typo: typo,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                        start: 11, top: 4, bottom: 4),
                    child: Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.success.withValues(alpha: 0.35),
                            colors.border,
                            colors.error.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticService.lightTap();
                        onDestination();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 2),
                        child: _AddressRow(
                          dotColor: colors.error,
                          icon: Icons.location_on,
                          label: booking.destination?.displayName ??
                              l10n.destination,
                          isSet: booking.destination != null,
                          colors: colors,
                          typo: typo,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final Color dotColor;
  final IconData icon;
  final String label;
  final bool isSet;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _AddressRow({
    required this.dotColor,
    required this.icon,
    required this.label,
    required this.isSet,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: dotColor, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: typo.bodyMedium.copyWith(
              color: isSet ? colors.text : colors.textSoft,
              fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: colors.textSoft, size: 20),
      ],
    );
  }
}

// ── Live insights: single minimal panel (typical + match) ───────────────────
class _MarketplaceInsightsPanel extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final Widget child;

  const _MarketplaceInsightsPanel({
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: colors.bgAlt.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}

class _MarketplaceLiveInsights extends ConsumerWidget {
  final int bidAmount;
  final bool hasAddresses;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _MarketplaceLiveInsights({
    required this.bidAmount,
    required this.hasAddresses,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  static const double _statRowHeight = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasAddresses) return const SizedBox.shrink();

    final asyncRef = ref.watch(marketplaceReferenceFareEuroProvider);

    return asyncRef.when(
      loading: () => _MarketplaceInsightsPanel(
        colors: colors,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                l10n.marketplacePricingLoading,
                style: typo.bodySmall.copyWith(
                  color: colors.textSoft,
                  height: 1.3,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => _MarketplaceInsightsPanel(
        colors: colors,
        child: _InsightMessageRow(
          colors: colors,
          typo: typo,
          message: l10n.marketplaceTypicalUnavailable,
        ),
      ),
      data: (refFare) {
        if (refFare == null) {
          return _MarketplaceInsightsPanel(
            colors: colors,
            child: _InsightMessageRow(
              colors: colors,
              typo: typo,
              message: l10n.marketplaceTypicalUnavailable,
            ),
          );
        }
        final match = marketplaceMatchPercent(refFare, bidAmount);
        final typical = formatMarketplaceEuro(refFare);
        final bidStr = formatMarketplaceEuro(bidAmount.toDouble());
        final caption = match >= 100
            ? l10n.marketplaceMatchChanceStrong
            : l10n.marketplaceMatchChanceBody(bidStr, '$match');

        final statStyle = typo.headingSmall.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: -0.3,
        );
        final labelStyle = typo.labelSmall.copyWith(
          color: colors.textSoft,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          height: 1.2,
        );

        return _MarketplaceInsightsPanel(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.marketplaceLiveBadge,
                      style: typo.labelSmall.copyWith(
                        color: colors.textSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.marketplaceStandardPrice,
                          style: labelStyle,
                        ),
                        const SizedBox(height: 6),
                        Text(typical, style: statStyle),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 14,
                    ),
                    child: SizedBox(
                      height: _statRowHeight,
                      child: VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colors.border.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.marketplaceMatchChanceTitle,
                          style: labelStyle,
                          textAlign: TextAlign.end,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$match%',
                          style: statStyle.copyWith(
                            color: match >= 85
                                ? colors.success
                                : match >= 50
                                    ? colors.accent
                                    : colors.text,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                caption,
                style: typo.bodySmall.copyWith(
                  color: colors.textSoft,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightMessageRow extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String message;

  const _InsightMessageRow({
    required this.colors,
    required this.typo,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: colors.textSoft,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: typo.bodySmall.copyWith(
              color: colors.textSoft,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _marketplaceComparisonDivider(HeyCabyColorTokens colors) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(
      height: 44,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: colors.border.withValues(alpha: 0.55),
      ),
    ),
  );
}

Widget _marketplaceComparisonMetric({
  required HeyCabyTypography typo,
  required HeyCabyColorTokens colors,
  required String label,
  required String value,
  TextStyle? valueStyle,
  String? subtitle,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        label,
        style: typo.labelSmall.copyWith(
          color: colors.textSoft,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: valueStyle ??
            typo.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: typo.bodySmall.copyWith(
            color: colors.textSoft,
            fontWeight: FontWeight.w500,
            fontSize: 10,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ],
  );
}

// ── Price Comparison ──────────────────────────────────────────────────────────
class _PriceComparison extends ConsumerWidget {
  final int bidAmount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _PriceComparison({
    required this.bidAmount,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRef = ref.watch(marketplaceReferenceFareEuroProvider);

    return asyncRef.when(
      loading: () => _buildComparison(
        refPrice: null,
        isLoading: true,
      ),
      error: (_, __) => _buildComparison(
        refPrice: null,
        isLoading: false,
      ),
      data: (refPrice) => _buildComparison(
        refPrice: refPrice,
        isLoading: false,
      ),
    );
  }

  Widget _buildComparison({
    required double? refPrice,
    required bool isLoading,
  }) {
    final p = refPrice;
    final hasRef = p != null && p > 0;
    final savingsEuro =
        hasRef ? marketplaceSavingsEuro(p, bidAmount).round() : 0;
    final savingsPercent =
        hasRef ? marketplaceSavingsPercent(p, bidAmount) : 0;
    final matchPct = hasRef ? marketplaceMatchPercent(p, bidAmount) : null;

    final typicalDisplay =
        isLoading ? '…' : (hasRef ? formatMarketplaceEuro(p) : '—');
    final bidDisplay = isLoading
        ? '…'
        : formatMarketplaceEuro(bidAmount.toDouble());

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _marketplaceComparisonMetric(
                  typo: typo,
                  colors: colors,
                  label: l10n.marketplaceStandardPrice,
                  value: typicalDisplay,
                  valueStyle: typo.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: hasRef ? colors.textSoft : colors.text,
                    decoration:
                        hasRef ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: colors.textSoft,
                  ),
                ),
              ),
              _marketplaceComparisonDivider(colors),
              Expanded(
                child: _marketplaceComparisonMetric(
                  typo: typo,
                  colors: colors,
                  label: l10n.marketplaceYourBid,
                  value: bidDisplay,
                  valueStyle: typo.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ),
              _marketplaceComparisonDivider(colors),
              Expanded(
                child: _marketplaceComparisonMetric(
                  typo: typo,
                  colors: colors,
                  label: l10n.marketplaceYourSavings,
                  value: savingsEuro > 0 ? '€$savingsEuro' : '€0',
                  subtitle: savingsPercent > 0
                      ? l10n.marketplaceSavingsVsTypicalPercent(
                          '$savingsPercent',
                        )
                      : null,
                  valueStyle: typo.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: savingsEuro > 0 ? colors.accent : colors.textSoft,
                  ),
                ),
              ),
            ],
          ),
          if (matchPct != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  l10n.marketplaceMatchChanceTitle,
                  style: typo.labelSmall.copyWith(
                    color: colors.textSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (matchPct / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: colors.border.withValues(alpha: 0.35),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        matchPct >= 85
                            ? colors.success
                            : matchPct >= 50
                                ? colors.accent
                                : colors.textSoft,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$matchPct%',
                  style: typo.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ],
          if (savingsEuro > 0 && savingsPercent > 0) ...[
            const SizedBox(height: 12),
            Text(
              l10n.marketplaceSavingsBanner('$savingsPercent'),
              style: typo.bodySmall.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bid Slider ────────────────────────────────────────────────────────────────
class _BidSlider extends StatelessWidget {
  final int bidAmount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ValueChanged<int> onChanged;

  const _BidSlider({
    required this.bidAmount,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.marketplaceYourBid,
                style: typo.bodySmall.copyWith(
                  color: colors.textSoft,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.accentL,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_rounded,
                        size: 14, color: colors.accent),
                    const SizedBox(width: 6),
                    Text(
                      l10n.marketplaceDragToAdjustHint,
                      style: typo.bodySmall.copyWith(
                        color: colors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '€',
                    style: typo.headingMedium.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
                ),
                Text(
                  '$bidAmount',
                  style: typo.headingLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 72,
                    height: 1.0,
                    letterSpacing: -2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: colors.accent,
              inactiveTrackColor: colors.border.withValues(alpha: 0.85),
              thumbColor: colors.accent,
              overlayColor: colors.accent.withValues(alpha: 0.18),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 22),
            ),
            child: Slider(
              value: bidAmount.toDouble(),
              min: 20,
              max: 100,
              divisions: 16,
              onChanged: (v) {
                HapticService.selectionClick();
                onChanged(v.round());
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.marketplaceBidRangeMin(20),
                style: typo.bodySmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                l10n.marketplaceBidRangeMax(100),
                style: typo.bodySmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick Bids ────────────────────────────────────────────────────────────────
class _QuickBids extends StatelessWidget {
  final int bidAmount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ValueChanged<int> onSelect;

  const _QuickBids({
    required this.bidAmount,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const quickBids = [35, 50, 65, 80];
    final labels = [
      l10n.marketplaceQuickBudget,
      l10n.marketplaceQuickPopular,
      l10n.marketplaceQuickFaster,
      l10n.marketplaceQuickExpress,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 14),
          child: Text(
            l10n.marketplaceQuickSelect,
            style: typo.bodySmall.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Row(
          children: List.generate(quickBids.length, (i) {
            final amount = quickBids[i];
            final label = labels[i];
            final isSelected = bidAmount == amount;
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                    end: i < quickBids.length - 1 ? 10 : 0),
                child: GestureDetector(
                  onTap: () => onSelect(amount),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.accent : colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isSelected ? colors.accent : colors.border,
                        width: isSelected ? 2 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    colors.accent.withValues(alpha: 0.32),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '€$amount',
                          style: typo.bodyMedium.copyWith(
                            color: isSelected
                                ? colors.onAccent
                                : colors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: typo.bodySmall.copyWith(
                            color: isSelected
                                ? colors.onAccent.withValues(alpha: 0.88)
                                : colors.textSoft,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Submit Footer ─────────────────────────────────────────────────────────────
class _SubmitFooter extends StatelessWidget {
  final bool isSubmitting;
  final bool hasAddresses;
  final int bidAmount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _SubmitFooter({
    required this.isSubmitting,
    required this.hasAddresses,
    required this.bidAmount,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = hasAddresses && !isSubmitting;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        HeyCabySpacing.screenEdge,
        16,
        HeyCabySpacing.screenEdge,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border:
            Border(top: BorderSide(color: colors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasAddresses) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: colors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: colors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.marketplaceSetPickupDestinationHint,
                      style: typo.bodySmall.copyWith(
                        color: colors.warning,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: isEnabled ? onTap : null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: colors.bgAlt,
                disabledForegroundColor: colors.textSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colors.onAccent),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.send_rounded,
                          color: isEnabled ? colors.onAccent : colors.textSoft,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${l10n.postToMarketplace} · €$bidAmount',
                          style: typo.labelLarge.copyWith(
                            color: isEnabled
                                ? colors.onAccent
                                : colors.textSoft,
                            fontWeight: FontWeight.w700,
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
