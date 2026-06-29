import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../providers/recent_destinations_provider.dart';
import '../../services/booking_flow_navigation.dart';

/// Horizontal recent destinations — compact chips after booking options.
class HomeRecentPlacesSection extends ConsumerWidget {
  const HomeRecentPlacesSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  IconData _iconFor(RecentDestination dest) {
    final lower = dest.fullAddress.toLowerCase();
    if (lower.contains('airport') ||
        lower.contains('schiphol') ||
        lower.contains('vliegveld')) {
      return Icons.flight_takeoff_rounded;
    }
    if (lower.contains('home') || lower.contains('thuis')) {
      return Icons.home_outlined;
    }
    return Icons.location_on_outlined;
  }

  String _title(RecentDestination dest) {
    final parts = dest.fullAddress.split(',');
    return parts.first.trim();
  }

  String _subtitle(RecentDestination dest) {
    final parts = dest.fullAddress.split(',');
    if (parts.length < 2) return '';
    return parts.sublist(1).join(',').trim();
  }

  Future<void> _openDestination(
    BuildContext context,
    WidgetRef ref,
    RecentDestination dest,
  ) async {
    ref.read(bookingProvider.notifier).setDestination(
          AddressResult(
            displayName: dest.fullAddress.split(',').first,
            fullAddress: dest.fullAddress,
            lat: dest.lat,
            lng: dest.lng,
          ),
        );
    await BookingFlowNavigation.prefillBookingFromIdentity(ref);
    if (!context.mounted) return;
    final next = BookingFlowNavigation.routeAfterAddressesComplete(
      ref.read(bookingProvider),
    );
    context.push(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentDestinationsProvider);

    return recentAsync.when(
      data: (destinations) {
        if (destinations.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.homeRecentPlacesTitle,
                        style: typo.titleMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/saved-addresses'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.homeRecentPlacesEdit,
                        style: typo.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.only(end: 16),
                  itemCount: destinations.length.clamp(0, 8),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final dest = destinations[index];
                    return _RecentPlaceChip(
                      colors: colors,
                      typo: typo,
                      icon: _iconFor(dest),
                      title: _title(dest),
                      subtitle: _subtitle(dest),
                      onTap: () => _openDestination(context, ref, dest),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentPlaceChip extends StatelessWidget {
  const _RecentPlaceChip({
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.accent, size: 18),
              const SizedBox(height: 8),
              Text(
                title,
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: typo.bodySmall.copyWith(
                    color: colors.textSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
