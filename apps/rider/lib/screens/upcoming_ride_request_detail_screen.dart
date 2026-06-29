import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../widgets/booking/booking_flow_screen_header.dart';
import '../models/ride_matching_variant.dart';
import '../providers/active_search_provider.dart';
import '../providers/near_term_ride_request_provider.dart';
import '../providers/ride_request_provider.dart';
import '../services/sound_service.dart';
import '../services/stale_ride_cleanup.dart';

/// Full-screen details for an open `ride_requests` row from the Rides → Upcoming tab.
class UpcomingRideRequestDetailScreen extends ConsumerStatefulWidget {
  const UpcomingRideRequestDetailScreen({super.key, required this.snap});

  final NearTermRideSnapshot snap;

  @override
  ConsumerState<UpcomingRideRequestDetailScreen> createState() =>
      _UpcomingRideRequestDetailScreenState();
}

class _UpcomingRideRequestDetailScreenState
    extends ConsumerState<UpcomingRideRequestDetailScreen> {
  Timer? _poll;
  Map<String, dynamic>? _row;
  Map<String, dynamic>? _driver;

  String get _rideId => widget.snap.id;

  @override
  void initState() {
    super.initState();
    _row = {
      'pickup_address': widget.snap.pickupAddress,
      'destination_address': widget.snap.destinationAddress,
      'status': widget.snap.status,
      'scheduled_pickup_at': widget.snap.scheduledPickupAt?.toIso8601String(),
      'booking_mode': widget.snap.bookingMode,
    };
    unawaited(_refresh());
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final identity = await ref.read(riderIdentityProvider.future);
    if (!identity.hasSession || identity.riderToken == null) return;
    try {
      final raw = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'id, status, pickup_address, destination_address, scheduled_pickup_at, '
            'booking_mode, driver_id, created_at',
          )
          .eq('id', _rideId)
          .eq('rider_token', identity.riderToken!)
          .maybeSingle();
      if (!mounted) return;
      if (raw == null) {
        context.pop();
        return;
      }
      final m = Map<String, dynamic>.from(raw as Map);
      Map<String, dynamic>? drv;
      final driverId = m['driver_id'] as String?;
      if (driverId != null && driverId.isNotEmpty) {
        try {
          final d = await HeyCabySupabase.client
              .from('drivers')
              .select('name, photo_url')
              .eq('id', driverId)
              .maybeSingle();
          if (d != null) {
            drv = Map<String, dynamic>.from(d as Map);
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _row = m;
          _driver = drv;
        });
      }
    } catch (_) {}
  }

  Future<void> _openLiveSearch() async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(rideRequestProvider.notifier)
        .attachRideRequestForMatchingFlow(_rideId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rideBookingFailed)),
      );
      return;
    }
    final mode = ref.read(rideRequestProvider).bookingMode ?? widget.snap.bookingMode;
    final path = rideMatchingVariantForBookingModeString(mode).routePath;
    context.push(path);
  }

  Future<void> _goActive() async {
    final ok = await ref
        .read(rideRequestProvider.notifier)
        .attachRideRequestForMatchingFlow(_rideId);
    if (!mounted) return;
    if (!ok) return;
    context.go('/active');
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context);
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          l10n.cancelRide,
          style: typo.titleMedium.copyWith(color: colors.text),
        ),
        content: Text(
          l10n.cancelRideConfirm,
          style: typo.bodyMedium.copyWith(color: colors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.cancelRide),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final identity = await ref.read(riderIdentityProvider.future);
    final token = identity.riderToken;
    if (token == null) return;
    await cancelExpiredRiderOpenRide(
      rideId: _rideId,
      riderToken: token,
      cancellationReason: 'rider_cancelled_from_rides',
    );
    final rr = ref.read(rideRequestProvider);
    if (rr.rideRequestId == _rideId) {
      ref.read(rideRequestProvider.notifier).reset();
    }
    ref.invalidate(ridesTabUpcomingRequestsProvider);
    ref.invalidate(nearTermRideRequestProvider);
    ref.invalidate(activeSearchProvider);
    unawaited(SoundService().playRideCancelled());
    if (mounted) context.pop();
  }

  Future<void> _editAddresses() async {
    final l10n = AppLocalizations.of(context);
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          l10n.upcomingRideEditBookAgain,
          style: typo.titleMedium.copyWith(color: colors.text),
        ),
        content: Text(
          l10n.upcomingRideEditBookAgainSubtitle,
          style: typo.bodyMedium.copyWith(color: colors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.upcomingRideEditBookAgain),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final ok = await ref
        .read(rideRequestProvider.notifier)
        .attachRideRequestForMatchingFlow(_rideId);
    if (!ok || !mounted) return;
    final identity = await ref.read(riderIdentityProvider.future);
    final token = identity.riderToken;
    if (token == null) return;
    await cancelExpiredRiderOpenRide(
      rideId: _rideId,
      riderToken: token,
      cancellationReason: 'rider_editing_addresses',
    );
    unawaited(SoundService().playRideCancelled());
    ref.read(rideRequestProvider.notifier).reset();
    ref.invalidate(ridesTabUpcomingRequestsProvider);
    ref.invalidate(nearTermRideRequestProvider);
    if (mounted) context.go('/search');
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final row = _row;
    if (row == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              BookingFlowScreenHeader(
                colors: colors,
                typo: typo,
                title: l10n.upcomingRideDetailTitle,
                icon: Icons.schedule_rounded,
                onBack: () => context.pop(),
              ),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      );
    }

    final status = (row['status'] as String?) ?? widget.snap.status;
    final pickup = (row['pickup_address'] as String?) ?? widget.snap.pickupAddress;
    final dest =
        (row['destination_address'] as String?) ?? widget.snap.destinationAddress;
    final isMatching = status == 'pending' || status == 'bidding';
    final isDriverAssigned = status == 'assigned' ||
        status == 'accepted' ||
        status == 'driver_arrived' ||
        status == 'driver_found' ||
        status == 'in_progress';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.upcomingRideDetailTitle,
              icon: Icons.schedule_rounded,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: RefreshIndicator(
        color: colors.accent,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 32),
          children: [
            if (isMatching) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.all(16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.text.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.upcomingRideMatchingProgressTitle,
                            style: typo.titleSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.upcomingRideMatchingProgressBody,
                      style: typo.bodyMedium.copyWith(
                        color: colors.textMid,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _openLiveSearch,
                      icon: const Icon(Icons.radar_rounded),
                      label: Text(l10n.upcomingRideOpenLiveSearch),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (isDriverAssigned) ...[
              FilledButton.icon(
                onPressed: _goActive,
                icon: const Icon(Icons.directions_car_rounded),
                label: Text(l10n.upcomingRideGoToActive),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              l10n.yourRoute,
              style: typo.labelLarge.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _AddressCard(
              colors: colors,
              typo: typo,
              icon: Icons.trip_origin_rounded,
              address: pickup,
            ),
            const SizedBox(height: 10),
            _AddressCard(
              colors: colors,
              typo: typo,
              icon: Icons.flag_rounded,
              address: dest,
            ),
            if (_driver != null) ...[
              const SizedBox(height: 24),
              Text(
                l10n.upcomingRideDriverSection,
                style: typo.labelLarge.copyWith(
                  color: colors.textMid,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsetsDirectional.all(14),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    if ((_driver!['photo_url'] as String?)?.isNotEmpty == true)
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(
                          _driver!['photo_url'] as String,
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colors.accentL,
                        child: Icon(Icons.person, color: colors.accent),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (_driver!['name'] as String?)?.trim().isNotEmpty == true
                            ? (_driver!['name'] as String).trim()
                            : l10n.driver,
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
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _editAddresses,
              icon: Icon(Icons.edit_location_alt_rounded, color: colors.accent),
              label: Text(l10n.upcomingRideEditBookAgain),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _confirmCancel,
              icon: Icon(Icons.cancel_outlined, color: colors.error),
              label: Text(
                l10n.cancelRide,
                style: typo.labelLarge.copyWith(color: colors.error),
              ),
            ),
          ],
        ),
      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.address,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              address,
              style: typo.bodyMedium.copyWith(color: colors.text, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
