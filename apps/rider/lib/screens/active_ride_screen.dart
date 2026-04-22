import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/booking_provider.dart';
import '../providers/driver_tracking_provider.dart';
import '../providers/ride_request_provider.dart';
import '../services/heycaby_widget_sync.dart';
import '../utils/map_style_helper.dart';
import 'report_screen.dart';

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _driverAnnotationManager;
  RealtimeChannel? _rideStatusChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToRideStatus();
      final rideId = ref.read(rideRequestProvider).rideRequestId;
      if (rideId != null) {
        ref.read(driverTrackingProvider.notifier).startTracking(rideId);
      }
      _syncRidePhaseWidgets();
    });
  }

  Future<void> _syncRidePhaseWidgets() async {
    final ride = ref.read(rideRequestProvider);
    final booking = ref.read(bookingProvider);
    final id = ride.rideRequestId;
    if (id == null) return;
    final st = ride.status ?? '';
    if (st == 'in_progress') {
      final pu = booking.pickup;
      final de = booking.destination;
      if (pu != null && de != null) {
        await HeycabyWidgetSync.ensureOnRideBaselineKm(
          pickupLat: pu.lat,
          pickupLng: pu.lng,
          destLat: de.lat,
          destLng: de.lng,
        );
      }
      return;
    }
    if (st == 'assigned' ||
        st == 'accepted' ||
        st == 'driver_arrived' ||
        st == 'arrived') {
      await HeycabyWidgetSync.refreshInstantDriverFromRide(
        rideId: id,
        pickup: booking.pickup?.displayName ?? '',
      );
    }
  }

  void _subscribeToRideStatus() {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;

    _rideStatusChannel = HeyCabySupabase.client
        .channel('ride_status:$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus == null) return;
            ref.read(rideRequestProvider.notifier).updateStatus(newStatus);
            if (newStatus == 'completed' && mounted) {
              context.go('/rating');
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _rideStatusChannel?.unsubscribe();
    ref.read(driverTrackingProvider.notifier).stopTracking();
    super.dispose();
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    
    // 1. Hide scale bar and compass clutter
    await _mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _mapboxMap!.compass.updateSettings(CompassSettings(enabled: false));
    await _mapboxMap!.attribution.updateSettings(AttributionSettings(enabled: false));
    await _mapboxMap!.logo.updateSettings(LogoSettings(enabled: false));
    
    // 2. Show the blue pulsing GPS dot
    await _mapboxMap!.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF4285F4,
      pulsingMaxRadius: 40.0,
      showAccuracyRing: true,
    ));
    
    _driverAnnotationManager = await map.annotations.createPointAnnotationManager();
    _centerOnPickup();
  }

  Future<void> _centerOnPickup() async {
    if (_mapboxMap == null) return;
    final booking = ref.read(bookingProvider);
    if (booking.pickup == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            booking.pickup!.lng,
            booking.pickup!.lat,
          ),
        ),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _shareRide(BuildContext context) async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;

    try {
      final identity = await ref.read(riderIdentityProvider.future);
      final existing = await HeyCabySupabase.client
          .from('ride_shares')
          .select('share_token')
          .eq('ride_request_id', rideId)
          .eq('is_active', true)
          .maybeSingle();

      String shareUrl;
      if (existing != null) {
        shareUrl = '$kAppPublicWebOrigin/track/${existing['share_token']}';
      } else {
        final result = await HeyCabySupabase.client.from('ride_shares').insert({
          'ride_request_id': rideId,
          'rider_token': identity.riderToken,
          'is_active': true,
        }).select('share_token').single();
        shareUrl = '$kAppPublicWebOrigin/track/${result['share_token']}';
      }

      await Share.share(shareUrl);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        final colors = ref.read(colorsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.rideShareCopied, style: TextStyle(color: colors.text)),
            backgroundColor: colors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Silently fail on share error
    }
  }

  Future<void> _updateDriverMarker(DriverLocation location) async {
    if (_driverAnnotationManager == null) return;
    
    // Clear existing annotations and add new one
    await _driverAnnotationManager!.deleteAll();
    await _driverAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: location.point,
        iconSize: 1.5,
        iconImage: 'car-15', // Mapbox default car icon
        iconRotate: location.heading ?? 0,
        iconAnchor: IconAnchor.CENTER,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    ref.listen<RideRequestState>(rideRequestProvider, (prev, next) {
      final st = next.status ?? '';
      if (st == 'in_progress' ||
          st == 'assigned' ||
          st == 'accepted' ||
          st == 'driver_arrived' ||
          st == 'arrived') {
        _syncRidePhaseWidgets();
      }
    });

    // Listen to driver location updates: map marker + lock-screen widget D.
    ref.listen<AsyncValue<DriverLocation?>>(
      driverTrackingProvider,
      (previous, current) {
        current.whenData((location) async {
          if (location != null && _driverAnnotationManager != null) {
            _updateDriverMarker(location);
          }
          if (location == null) return;
          final ride = ref.read(rideRequestProvider);
          if (ride.status != 'in_progress') return;
          final booking = ref.read(bookingProvider);
          final dest = booking.destination;
          if (dest == null) return;
          final city = dest.displayName.split(',').last.trim();
          await HeycabyWidgetSync.syncOnRideProgress(
            destination: dest.displayName,
            destinationCity: city.isEmpty ? dest.displayName : city,
            destLat: dest.lat,
            destLng: dest.lng,
            driverLat: location.lat,
            driverLng: location.lng,
          );
        });
      },
    );

    final ride = ref.watch(rideRequestProvider);
    final status = ride.status ?? 'assigned';

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: mapStyleForTheme(ref.watch(themeProvider).id),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActiveRideSheet(
              status: status,
              colors: colors,
              typo: typo,
              l10n: l10n,
              onComplete: () => context.go('/home'),
              onShare: () => _shareRide(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRideSheet extends StatelessWidget {
  final String status;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onComplete;
  final VoidCallback onShare;

  const _ActiveRideSheet({
    required this.status,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onComplete,
    required this.onShare,
  });

  String _statusLabel(AppLocalizations l10n) {
    switch (status) {
      case 'assigned':
        return l10n.driverAssigned;
      case 'arrived':
        return l10n.driverArrived;
      case 'in_progress':
        return l10n.tripInProgress;
      case 'completed':
        return l10n.tripComplete;
      default:
        return l10n.driverOnTheWay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _StatusBadge(
            status: status,
            label: _statusLabel(l10n),
            colors: colors,
            typo: typo,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: l10n.chat,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.push('/chat'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.share_outlined,
                  label: l10n.shareRide,
                  colors: colors,
                  typo: typo,
                  onTap: onShare,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.flag_outlined,
                  label: l10n.reportIssue,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.push(
                        '/report',
                        extra: const ReportRouteArgs(fromActiveRide: true),
                      ),
                ),
              ),
            ],
          ),
          if (status == 'completed') ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/rating');
                },
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                child: Text(
                  l10n.rideComplete,
                  style: typo.labelLarge.copyWith(color: colors.onAccent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _StatusBadge({
    required this.status,
    required this.label,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = status == 'completed';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isComplete ? colors.success.withValues(alpha: 0.12) : colors.accentL,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isComplete ? colors.success : colors.accent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: typo.labelSmall.copyWith(
                  color: isComplete ? colors.success : colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.bgAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.textMid, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: typo.labelSmall.copyWith(color: colors.textMid),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
