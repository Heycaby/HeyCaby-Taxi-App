import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';

/// Shown on the scheduled matching screen: ride is queued for drivers.
class ScheduledRideQueuedNotice extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final DateTime? scheduledPickupAt;

  const ScheduledRideQueuedNotice({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    this.scheduledPickupAt,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final whenText = scheduledPickupAt == null
        ? null
        : DateFormat.yMMMEd(locale).add_Hm().format(scheduledPickupAt!.toLocal());

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: colors.accentL,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_rounded, color: colors.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.scheduledRideQueuedTitle,
                    style: typo.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    whenText != null
                        ? l10n.scheduledRideQueuedSubtitleWithTime(whenText)
                        : l10n.scheduledRideQueuedSubtitle,
                    style: typo.bodyMedium.copyWith(
                      color: colors.textMid,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
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
