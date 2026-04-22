import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';

import '../providers/booking_provider.dart';
import 'booking/trip_summary_details_section.dart';
import 'booking/trip_summary_route_section.dart';

/// Route + pickup time + vehicle / payment for scheduled matching.
///
/// Use [sheetMode] with a [scrollController] for a draggable sheet; use
/// `sheetMode: false` for embedding in a parent [ScrollView].
class ScheduledMatchingDetailsPanel extends StatelessWidget {
  final BookingState booking;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ScrollController? scrollController;
  final void Function(bool isPickup) onEditAddress;
  final bool sheetMode;
  final bool showSectionTitle;

  const ScheduledMatchingDetailsPanel({
    super.key,
    required this.booking,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onEditAddress,
    this.scrollController,
    this.sheetMode = true,
    this.showSectionTitle = true,
  }) : assert(
          !sheetMode || scrollController != null,
          'sheetMode requires scrollController',
        );

  List<Widget> _buildChildren(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final whenText = booking.scheduledAt == null
        ? null
        : DateFormat.yMMMEd(locale).add_Hm().format(booking.scheduledAt!.toLocal());

    return [
      if (sheetMode)
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      if (showSectionTitle) ...[
        Text(
          l10n.scheduledRideDetailsSheetTitle,
          style: typo.titleMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
      ],
      TripSummaryRouteCard(
        booking: booking,
        colors: colors,
        typo: typo,
        l10n: l10n,
        onEditAddress: onEditAddress,
      ),
      if (whenText != null) ...[
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, color: colors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.scheduledFor(whenText),
                  style: typo.bodyLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      TripSummaryDetailSection(
        booking: booking,
        colors: colors,
        typo: typo,
        l10n: l10n,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final children = _buildChildren(context);
    if (!sheetMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 28),
        children: children,
      ),
    );
  }
}
