import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../screens/location_required_screen.dart';
import '../email_modal.dart';

/// Home booking modes — Taxi Terug first; marketplace remains in codebase but
/// is not surfaced on the home sheet.
class HomeBookingOptionsGrid extends ConsumerWidget {
  const HomeBookingOptionsGrid({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  Future<void> _openMyDrivers(BuildContext context, WidgetRef ref) async {
    final identity = await ref.read(riderIdentityProvider.future);
    if (!context.mounted) return;
    if (identity.hasSession && identity.email != null) {
      context.push('/favorites');
      return;
    }
    final success = await showEmailModal(context, ref);
    if (success && context.mounted) context.push('/favorites');
  }

  Future<void> _openTaxiTerug(BuildContext context, WidgetRef ref) async {
    final ok = await ensureLocationForBooking(
      context: context,
      ref: ref,
    );
    if (!ok) return;
    ref.read(bookingProvider.notifier).setTaxiTerug();
    if (context.mounted) context.push('/taxi-terug');
  }

  Future<void> _openAirport(BuildContext context, WidgetRef ref) async {
    final ok = await ensureLocationForBooking(
      context: context,
      ref: ref,
    );
    if (ok && context.mounted) {
      context.push('/airport-booking');
    }
  }

  Future<void> _openScheduled(BuildContext context, WidgetRef ref) async {
    final ok = await ensureLocationForBooking(
      context: context,
      ref: ref,
    );
    if (!ok) return;
    ref.read(bookingProvider.notifier).setScheduled();
    if (context.mounted) context.go('/search');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 12),
            child: Text(
              l10n.homeSmartOptionsTitle,
              style: typo.titleLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          _BookingOptionTile(
            colors: colors,
            typo: typo,
            icon: Icons.keyboard_return_rounded,
            title: l10n.homeTaxiTerugTitle,
            subtitle: l10n.homeTaxiTerugSubtitle,
            featured: true,
            onTap: () => unawaited(_openTaxiTerug(context, ref)),
          ),
          const SizedBox(height: 12),
          _RiderQuickActionsRow(
            colors: colors,
            typo: typo,
            myDriversLabel: l10n.myDrivers,
            myDriversSubtitle: l10n.myDriversHomeSubtitle,
            airportLabel: l10n.homeAirportBookingTitle,
            airportSubtitle: l10n.homeAirportBookingBadge,
            scheduleLabel: l10n.homeScheduleLaterTitle,
            scheduleSubtitle: l10n.homeScheduleLaterSubtitle,
            onMyDriversTap: () => unawaited(_openMyDrivers(context, ref)),
            onAirportTap: () => unawaited(_openAirport(context, ref)),
            onScheduleTap: () => unawaited(_openScheduled(context, ref)),
          ),
        ],
      ),
    );
  }
}

class _BookingOptionTile extends StatelessWidget {
  const _BookingOptionTile({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.featured = false,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final titleStyle = featured
        ? typo.titleLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.2,
          )
        : typo.titleMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
            height: 1.2,
          );
    final subtitleStyle = featured
        ? typo.bodyLarge.copyWith(
            color: colors.textMid,
            fontWeight: FontWeight.w500,
            height: 1.4,
          )
        : typo.bodyMedium.copyWith(
            color: colors.textMid,
            fontWeight: FontWeight.w500,
            height: 1.35,
          );
    final iconSize = featured ? 44.0 : 38.0;
    final iconGlyph = featured ? 24.0 : 21.0;

    return Material(
      color: featured ? colors.accentL.withValues(alpha: 0.35) : colors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: featured
                  ? colors.accent.withValues(alpha: 0.28)
                  : colors.border,
            ),
          ),
          padding: EdgeInsetsDirectional.fromSTEB(
            featured ? 16 : 14,
            featured ? 16 : 14,
            featured ? 16 : 14,
            featured ? 16 : 14,
          ),
          child: featured
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: colors.accent, size: iconGlyph),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: titleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: subtitleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.accent,
                      size: 22,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: colors.accentL,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, color: colors.accent, size: iconGlyph),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: subtitleStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Driver-home quick-actions row — one card, three circular icon tiles.
class _RiderQuickActionsRow extends StatelessWidget {
  const _RiderQuickActionsRow({
    required this.colors,
    required this.typo,
    required this.myDriversLabel,
    required this.myDriversSubtitle,
    required this.airportLabel,
    required this.airportSubtitle,
    required this.scheduleLabel,
    required this.scheduleSubtitle,
    required this.onMyDriversTap,
    required this.onAirportTap,
    required this.onScheduleTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String myDriversLabel;
  final String myDriversSubtitle;
  final String airportLabel;
  final String airportSubtitle;
  final String scheduleLabel;
  final String scheduleSubtitle;
  final VoidCallback onMyDriversTap;
  final VoidCallback onAirportTap;
  final VoidCallback onScheduleTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RiderHomeQuickActionTile(
              colors: colors,
              typo: typo,
              icon: Icons.star_rounded,
              label: myDriversLabel,
              subtitle: myDriversSubtitle,
              onTap: onMyDriversTap,
            ),
          ),
          Expanded(
            child: _RiderHomeQuickActionTile(
              colors: colors,
              typo: typo,
              icon: Icons.flight_takeoff_rounded,
              label: airportLabel,
              subtitle: airportSubtitle,
              onTap: onAirportTap,
            ),
          ),
          Expanded(
            child: _RiderHomeQuickActionTile(
              colors: colors,
              typo: typo,
              icon: Icons.schedule_rounded,
              label: scheduleLabel,
              subtitle: scheduleSubtitle,
              onTap: onScheduleTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderHomeQuickActionTile extends StatelessWidget {
  const _RiderHomeQuickActionTile({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 4,
            vertical: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.bgAlt,
                ),
                child: Icon(
                  icon,
                  color: colors.text,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: typo.labelSmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: typo.labelSmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
