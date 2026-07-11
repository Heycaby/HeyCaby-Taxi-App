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
      padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 14),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BookingOptionTile(
                  colors: colors,
                  typo: typo,
                  icon: Icons.star_rounded,
                  title: l10n.myDrivers,
                  subtitle: l10n.myDriversHomeSubtitle,
                  onTap: () => unawaited(_openMyDrivers(context, ref)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BookingOptionTile(
                  colors: colors,
                  typo: typo,
                  icon: Icons.flight_takeoff_rounded,
                  title: l10n.homeAirportBookingTitle,
                  subtitle: l10n.homeAirportBookingSubtitle,
                  onTap: () => unawaited(_openAirport(context, ref)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _BookingOptionTile(
            colors: colors,
            typo: typo,
            icon: Icons.schedule_rounded,
            title: l10n.homeScheduleLaterTitle,
            subtitle: l10n.homeScheduleLaterSubtitle,
            onTap: () => unawaited(_openScheduled(context, ref)),
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
