import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../screens/location_required_screen.dart';
import '../email_modal.dart';

/// Secondary entry points — same routes and booking modes as before Phase 1.
///
/// Extension point (Phase 2+): prepend a [RideAgainHero] above this list when
/// [favoritesProvider] + last-ride enrichment is available — no new routes needed.
class HomeSmartOptionsSection extends ConsumerWidget {
  const HomeSmartOptionsSection({
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
    if (success && context.mounted) {
      context.push('/favorites');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
            child: Text(
              l10n.homeSmartOptionsTitle,
              style: typo.labelLarge.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          _SmartOptionTile(
            colors: colors,
            typo: typo,
            icon: Icons.star_rounded,
            iconTint: colors.accent,
            title: l10n.myDrivers,
            subtitle: l10n.myDriversHomeSubtitle,
            onTap: () => _openMyDrivers(context, ref),
          ),
          const SizedBox(height: 8),
          _SmartOptionTile(
            colors: colors,
            typo: typo,
            icon: Icons.savings_outlined,
            iconTint: colors.accent,
            title: l10n.marketplace,
            subtitle: l10n.marketplaceTagline,
            onTap: () {
              ref.read(bookingProvider.notifier).setMarketplace();
              context.push('/marketplace');
            },
          ),
          const SizedBox(height: 8),
          _SmartOptionTile(
            colors: colors,
            typo: typo,
            icon: Icons.flight_takeoff_rounded,
            iconTint: colors.accent,
            title: l10n.homeAirportBookingTitle,
            subtitle: l10n.homeAirportBookingSubtitle,
            onTap: () async {
              final ok =
                  await ensureLocationForBooking(context: context, ref: ref);
              if (ok && context.mounted) {
                context.push('/airport-booking');
              }
            },
          ),
          const SizedBox(height: 8),
          _SmartOptionTile(
            colors: colors,
            typo: typo,
            icon: Icons.schedule_rounded,
            iconTint: colors.accent,
            title: l10n.homeScheduleLaterTitle,
            subtitle: l10n.homeScheduleLaterSubtitle,
            onTap: () async {
              final ok =
                  await ensureLocationForBooking(context: context, ref: ref);
              if (!ok) return;
              ref.read(bookingProvider.notifier).setScheduled();
              if (context.mounted) context.go('/search');
            },
          ),
        ],
      ),
    );
  }
}

class _SmartOptionTile extends StatelessWidget {
  const _SmartOptionTile({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.iconTint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final Color iconTint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconTint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconTint, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: typo.titleMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                Icon(Icons.chevron_right_rounded, color: colors.textSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
