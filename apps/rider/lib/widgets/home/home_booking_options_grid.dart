import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../screens/location_required_screen.dart';
import '../email_modal.dart';

/// Four booking modes in a 2×2 grid — same routes and providers as before.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 12),
            child: Text(
              l10n.homeSmartOptionsTitle,
              style: typo.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _BookingOptionTile(
                  colors: colors,
                  typo: typo,
                  icon: Icons.star_rounded,
                  title: l10n.myDrivers,
                  subtitle: l10n.myDriversHomeSubtitle,
                  onTap: () => _openMyDrivers(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BookingOptionTile(
                  colors: colors,
                  typo: typo,
                  icon: Icons.groups_outlined,
                  title: l10n.marketplace,
                  subtitle: l10n.marketplaceTagline,
                  onTap: () {
                    ref.read(bookingProvider.notifier).setMarketplace();
                    context.push('/marketplace');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BookingOptionTile(
                  colors: colors,
                  typo: typo,
                  icon: Icons.keyboard_return_rounded,
                  title: l10n.homeTaxiTerugTitle,
                  subtitle: l10n.homeTaxiTerugSubtitle,
                  onTap: () async {
                    final ok = await ensureLocationForBooking(
                      context: context,
                      ref: ref,
                    );
                    if (!ok) return;
                    ref.read(bookingProvider.notifier).setTaxiTerug();
                    if (context.mounted) context.push('/marketplace');
                  },
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
                  onTap: () async {
                    final ok = await ensureLocationForBooking(
                      context: context,
                      ref: ref,
                    );
                    if (ok && context.mounted) {
                      context.push('/airport-booking');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BookingOptionTile(
                  colors: colors,
                  typo: typo,
                  icon: Icons.schedule_rounded,
                  title: l10n.homeScheduleLaterTitle,
                  subtitle: l10n.homeScheduleLaterSubtitle,
                  onTap: () async {
                    final ok = await ensureLocationForBooking(
                      context: context,
                      ref: ref,
                    );
                    if (!ok) return;
                    ref.read(bookingProvider.notifier).setScheduled();
                    if (context.mounted) context.go('/search');
                  },
                ),
              ),
            ],
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
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.accentL,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colors.accent, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: typo.bodySmall.copyWith(
                  color: colors.textMid,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
