import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../providers/recent_destinations_provider.dart';
import '../../providers/saved_addresses_provider.dart';
import '../../providers/saved_trips_provider.dart';
import '../../services/booking_flow_navigation.dart';
import '../../services/booking_saved_place_shortcut.dart';

const int _kMaxSavedAddresses = 4;
const int _kMaxRecentDestinations = 4;
const int _kMaxSavedTrips = 2;

/// Saved addresses, recent destinations, and saved trips in one compact row.
class HomeQuickPlacesSection extends ConsumerWidget {
  const HomeQuickPlacesSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  String _labelForSaved(SavedAddress address) {
    switch (address.type) {
      case 'home':
        return l10n.savedAddressLabelHome;
      case 'work':
        return l10n.savedAddressLabelWork;
      case 'gym':
        return l10n.savedAddressLabelGym;
      default:
        return address.label.trim().isNotEmpty
            ? address.label
            : l10n.savedAddressLabelCustom;
    }
  }

  IconData _iconForSaved(SavedAddress address) {
    switch (address.type) {
      case 'home':
        return Icons.home_outlined;
      case 'work':
        return Icons.work_outline_rounded;
      case 'gym':
        return Icons.fitness_center_outlined;
      default:
        return Icons.bookmark_outline_rounded;
    }
  }

  IconData _iconForRecent(RecentDestination dest) {
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

  String _titleFromAddress(String fullAddress) {
    return fullAddress.split(',').first.trim();
  }

  String _subtitleFromAddress(String fullAddress) {
    final parts = fullAddress.split(',');
    if (parts.length < 2) return '';
    return parts.sublist(1).join(',').trim();
  }

  bool _samePlace(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  Future<void> _openRecentDestination(
    BuildContext context,
    WidgetRef ref,
    RecentDestination dest,
  ) async {
    ref.read(bookingProvider.notifier).setDestination(
          AddressResult(
            displayName: _titleFromAddress(dest.fullAddress),
            fullAddress: dest.fullAddress,
            lat: dest.lat,
            lng: dest.lng,
          ),
        );
    await BookingFlowNavigation.prefillBookingFromIdentity(ref);
    if (!context.mounted) return;
    context.push(
      BookingFlowNavigation.routeAfterAddressesComplete(ref.read(bookingProvider)),
    );
  }

  Future<void> _rebookSavedTrip(
    BuildContext context,
    WidgetRef ref,
    SavedTrip trip,
  ) async {
    ref.read(bookingProvider.notifier)
      ..setPickup(trip.pickup)
      ..setDestination(trip.destination);
    await BookingFlowNavigation.prefillBookingFromIdentity(ref);
    if (!context.mounted) return;
    context.push(
      BookingFlowNavigation.routeAfterAddressesComplete(ref.read(bookingProvider)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedAddressesProvider);
    final recentAsync = ref.watch(recentDestinationsProvider);
    final tripsAsync = ref.watch(savedTripsProvider);

    final saved = savedAsync.valueOrNull ?? const <SavedAddress>[];
    final recent = recentAsync.valueOrNull ?? const <RecentDestination>[];
    final trips = tripsAsync.valueOrNull ?? const <SavedTrip>[];

    final savedAddresses = saved.take(_kMaxSavedAddresses).toList();
    final savedAddressStrings =
        savedAddresses.map((a) => a.fullAddress).toSet();

    final recentFiltered = recent
        .where(
          (dest) => !savedAddressStrings.any(
            (savedAddress) => _samePlace(savedAddress, dest.fullAddress),
          ),
        )
        .take(_kMaxRecentDestinations)
        .toList();

    final savedTrips = trips.take(_kMaxSavedTrips).toList();

    if (savedAddresses.isEmpty &&
        recentFiltered.isEmpty &&
        savedTrips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.homeQuickPlacesTitle,
                    style: typo.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/saved-addresses?from=search'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.homeQuickPlacesManage,
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
              itemCount: savedAddresses.length +
                  recentFiltered.length +
                  savedTrips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index < savedAddresses.length) {
                  final address = savedAddresses[index];
                  return _RecentPlaceChip(
                    colors: colors,
                    typo: typo,
                    icon: _iconForSaved(address),
                    title: _labelForSaved(address),
                    subtitle: _subtitleFromAddress(address.fullAddress),
                    onTap: () => bookInstantRideToDestination(
                      context,
                      ref,
                      addressResultFromSaved(address),
                    ),
                  );
                }

                final recentIndex = index - savedAddresses.length;
                if (recentIndex < recentFiltered.length) {
                  final dest = recentFiltered[recentIndex];
                  return _RecentPlaceChip(
                    colors: colors,
                    typo: typo,
                    icon: _iconForRecent(dest),
                    title: _titleFromAddress(dest.fullAddress),
                    subtitle: _subtitleFromAddress(dest.fullAddress),
                    onTap: () => _openRecentDestination(context, ref, dest),
                  );
                }

                final trip = savedTrips[index - savedAddresses.length - recentFiltered.length];
                return Align(
                  alignment: Alignment.center,
                  child: _SavedTripChip(
                    colors: colors,
                    typo: typo,
                    pickupLabel: _titleFromAddress(trip.pickupAddress),
                    destLabel: _titleFromAddress(trip.destinationAddress),
                    onTap: () => _rebookSavedTrip(context, ref, trip),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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

class _SavedTripChip extends StatelessWidget {
  const _SavedTripChip({
    required this.colors,
    required this.typo,
    required this.pickupLabel,
    required this.destLabel,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String pickupLabel;
  final String destLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniDot(color: colors.accent, border: null),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 70),
                child: Text(
                  pickupLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.labelSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: colors.textSoft,
                ),
              ),
              _MiniDot(
                color: colors.card,
                border: colors.accent,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 70),
                child: Text(
                  destLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.labelSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDot extends StatelessWidget {
  const _MiniDot({required this.color, this.border});

  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border != null ? Border.all(color: border!, width: 2) : null,
      ),
    );
  }
}
