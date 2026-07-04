import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';

import '../providers/booking_provider.dart';
import 'booking/trip_summary_details_section.dart';
import 'booking/trip_summary_route_section.dart';

/// Full-screen scheduled matching: premium layout, clear home + options (no delayed FAB).
class ScheduledMatchingFullscreen extends StatelessWidget {
  const ScheduledMatchingFullscreen({
    super.key,
    required this.booking,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onBackToHome,
    required this.onTripOptions,
    required this.onCancelRide,
    required this.onEditRoute,
  });

  final BookingState booking;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onBackToHome;
  final VoidCallback onTripOptions;
  final VoidCallback onCancelRide;
  final void Function(bool isPickup) onEditRoute;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final whenText = booking.scheduledAt == null
        ? null
        : DateFormat.yMMMEd(locale)
            .add_Hm()
            .format(booking.scheduledAt!.toLocal());
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PremiumHeader(
            colors: colors,
            typo: typo,
            l10n: l10n,
            onBackToHome: onBackToHome,
            onCancelRide: onCancelRide,
            onTripOptions: onTripOptions,
          ),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _StatusHeroGlass(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                      whenText: whenText,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TripSummaryRouteCard(
                          booking: booking,
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                          onEditAddress: onEditRoute,
                        ),
                        const SizedBox(height: 18),
                        TripSummaryDetailSection(
                          booking: booking,
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          _BottomActionBar(
            colors: colors,
            typo: typo,
            l10n: l10n,
            bottomInset: bottomInset,
            onBackToHome: onBackToHome,
            onTripOptions: onTripOptions,
          ),
        ],
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onBackToHome,
    required this.onCancelRide,
    required this.onTripOptions,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onBackToHome;
  final VoidCallback onCancelRide;
  final VoidCallback onTripOptions;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, top + 4, 8, 16),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticService.lightTap();
                    onBackToHome();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.scheduledMatchingBackToHome,
                          style: typo.labelLarge.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.scheduledMatchingMoreMenuTooltip,
                onPressed: () {
                  HapticService.lightTap();
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => _MoreMenuSheet(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                      onTripOptions: () {
                        Navigator.pop(ctx);
                        onTripOptions();
                      },
                      onCancelRide: () {
                        Navigator.pop(ctx);
                        onCancelRide();
                      },
                    ),
                  );
                },
                icon: Icon(Icons.more_horiz_rounded, color: colors.text),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.scheduledRideDetailsSheetTitle,
                  style: typo.displaySmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.matchingTitleScheduled,
                  style: typo.titleMedium.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreMenuSheet extends StatelessWidget {
  const _MoreMenuSheet({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTripOptions,
    required this.onCancelRide,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTripOptions;
  final VoidCallback onCancelRide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassPanel(
        colors: colors,
        typography: typo,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.tune_rounded, color: colors.accent),
              title: Text(
                l10n.matchingAlternativesFabTooltip,
                style: typo.titleSmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: onTripOptions,
            ),
            Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
            ListTile(
              leading: Icon(Icons.close_rounded, color: colors.error),
              title: Text(
                l10n.scheduledMatchingCancelRide,
                style: typo.titleSmall.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: onCancelRide,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusHeroGlass extends StatelessWidget {
  const _StatusHeroGlass({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.whenText,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String? whenText;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      colors: colors,
      typography: typo,
      borderRadius: BorderRadius.circular(22),
      tintColor: colors.accentL.withValues(alpha: 0.92),
      borderColor: colors.accent.withValues(alpha: 0.28),
      padding: const EdgeInsetsDirectional.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.accent.withValues(alpha: 0.2),
                  colors.accent.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: colors.accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (whenText != null) ...[
                  Text(
                    l10n.scheduledFor(whenText!),
                    style: typo.titleSmall.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  l10n.scheduledMatchingSubhead,
                  style: typo.bodyLarge.copyWith(
                    color: colors.textMid,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                _ScheduledProgressRail(
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduledProgressRail extends StatelessWidget {
  const _ScheduledProgressRail({
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
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          _ScheduledProgressStep(
            colors: colors,
            typo: typo,
            icon: Icons.check_rounded,
            title: l10n.scheduledRideQueuedTitle,
            body: l10n.ridesUpcomingScheduledBadge,
            isDone: true,
            showConnector: true,
          ),
          _ScheduledProgressStep(
            colors: colors,
            typo: typo,
            icon: Icons.groups_2_rounded,
            title: l10n.ridesUpcomingMatchingBadge,
            body: l10n.scheduledMatchingHeadline,
            isDone: false,
            showConnector: false,
          ),
        ],
      ),
    );
  }
}

class _ScheduledProgressStep extends StatelessWidget {
  const _ScheduledProgressStep({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.title,
    required this.body,
    required this.isDone,
    required this.showConnector,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String title;
  final String body;
  final bool isDone;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDone ? colors.onAccent : colors.accent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? colors.accent : colors.accentL,
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 22,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: showConnector ? 10 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typo.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: typo.bodySmall.copyWith(
                    color: colors.textMid,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.bottomInset,
    required this.onBackToHome,
    required this.onTripOptions,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final double bottomInset;
  final VoidCallback onBackToHome;
  final VoidCallback onTripOptions;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      shadowColor: colors.text.withValues(alpha: 0.12),
      color: colors.card,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 16),
        // Do not use CrossAxisAlignment.stretch here: parent Material has no
        // intrinsic height, so stretch leaves unbounded max height and triggers
        // 'hasSize': is not true on the button RenderFlex chain.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: () {
                    HapticService.lightTap();
                    onBackToHome();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.text,
                    side: BorderSide(color: colors.border, width: 1.2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.scheduledMatchingBackToHome,
                    style:
                        typo.labelLarge.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    HapticService.lightTap();
                    onTripOptions();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.matchingAlternativesFabTooltip,
                    style:
                        typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
