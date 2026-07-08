import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../providers/saved_trips_provider.dart';
import '../../services/booking_flow_navigation.dart';

class HomeSavedTripsSection extends ConsumerWidget {
  const HomeSavedTripsSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  String _shortLabel(String address) {
    return address.split(',').first.trim();
  }

  Future<void> _rebook(
    BuildContext context,
    WidgetRef ref,
    SavedTrip trip,
  ) async {
    ref.read(bookingProvider.notifier)
      ..setPickup(trip.pickup)
      ..setDestination(trip.destination);
    await BookingFlowNavigation.prefillBookingFromIdentity(ref);
    if (!context.mounted) return;
    final next = BookingFlowNavigation.routeAfterAddressesComplete(
      ref.read(bookingProvider),
    );
    context.push(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(savedTripsProvider);

    return tripsAsync.when(
      data: (trips) {
        if (trips.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Text(
                  l10n.savedTripsTitle,
                  style: typo.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                  child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.only(end: 16),
                  itemCount: trips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return _SavedTripChip(
                      colors: colors,
                      typo: typo,
                      pickupLabel: _shortLabel(trip.pickupAddress),
                      destLabel: _shortLabel(trip.destinationAddress),
                      onTap: () => _rebook(context, ref, trip),
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
