import 'dart:async';

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
import '../models/ride_matching_variant.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/nearby_supply_service.dart';
import '../services/rider_notification_lifecycle_service.dart';
import '../services/stale_ride_cleanup.dart';
import '../utils/map_style_helper.dart';
import 'report_screen.dart';

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen>
    with WidgetsBindingObserver {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _driverAnnotationManager;
  RealtimeChannel? _rideStatusChannel;
  _DriverSheetInfo? _driverInfo;
  _RideWaitingInfo? _waitingInfo;
  Timer? _statusRefreshTimer;
  Timer? _waitingUiTimer;
  int _lastStaleStatusMinuteTracked = -1;
  String? _lastRiderPing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToRideStatus();
      final rideId = ref.read(rideRequestProvider).rideRequestId;
      if (rideId != null) {
        ref.read(driverTrackingProvider.notifier).startTracking(rideId);
        _loadDriverInfo(rideId);
        _loadWaitingInfo(rideId);
      }
      _startStatusRefreshTimer();
      _startWaitingUiTimer();
      _syncRidePhaseWidgets();
    });
  }

  void _startWaitingUiTimer() {
    _waitingUiTimer?.cancel();
    _waitingUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _waitingInfo == null) return;
      final status = ref.read(rideRequestProvider).status ?? '';
      if (status == 'driver_arrived' || status == 'arrived') {
        setState(() {});
      }
    });
  }

  Future<void> _loadDriverInfo(String rideId) async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'driver_id, drivers(full_name, avg_rating, vehicle_plate, profile_photo_url, vehicle_category, vehicle_make, vehicle_model, vehicle_colour, vehicle_photo_urls)',
          )
          .eq('id', rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      final driver = row['drivers'];
      if (driver is! Map) return;
      final parsed = _DriverSheetInfo.fromJson(
        Map<String, dynamic>.from(driver),
        fallbackDriverLabel: AppLocalizations.of(context).driver,
      );
      setState(() => _driverInfo = parsed);
    } catch (_) {
      // Best-effort; UI still works without profile card details.
    }
  }

  Future<void> _loadWaitingInfo(String rideId) async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'driver_arrived_at, waiting_grace_seconds, waiting_rate_per_minute, chargeable_wait_seconds, waiting_fee_cents, waiting_fee_waived',
          )
          .eq('id', rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      _applyWaitingRecord(Map<String, dynamic>.from(row));
    } catch (_) {
      // Older environments may not have the waiting-fee contract yet.
    }
  }

  void _applyWaitingRecord(Map<String, dynamic> row) {
    final parsed = _RideWaitingInfo.fromJson(row);
    if (!mounted || parsed == null) return;
    setState(() => _waitingInfo = parsed);
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
            _applyWaitingRecord(Map<String, dynamic>.from(payload.newRecord));
            if (newStatus == null) return;
            ref.read(rideRequestProvider.notifier).updateStatus(newStatus);
            final rideId = ref.read(rideRequestProvider).rideRequestId;
            if (rideId != null &&
                (newStatus == 'assigned' ||
                    newStatus == 'accepted' ||
                    newStatus == 'driver_arrived' ||
                    newStatus == 'arrived' ||
                    newStatus == 'in_progress')) {
              _loadDriverInfo(rideId);
            }
            if (newStatus == 'completed' && mounted) {
              context.go('/rating');
              return;
            }
            if ((newStatus == 'pending' || newStatus == 'bidding') && mounted) {
              final mode = ref.read(rideRequestProvider).bookingMode ??
                  bookingModeStorageString(
                      ref.read(bookingProvider).effectiveRideMode);
              final path =
                  rideMatchingVariantForBookingModeString(mode).routePath;
              context.go(path);
              return;
            }
            const terminalNoActive = {
              'cancelled',
              'canceled',
              'rejected',
              'declined',
              'missed',
              'expired',
            };
            if (terminalNoActive.contains(newStatus) && mounted) {
              ref.read(rideRequestProvider.notifier).reset();
              context.go('/home');
            }
          },
        )
        .subscribe();
  }

  void _startStatusRefreshTimer() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshRideStatus(reason: 'periodic_poll'),
    );
  }

  Future<void> _refreshRideStatus({required String reason}) async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'status, updated_at, driver_arrived_at, waiting_grace_seconds, waiting_rate_per_minute, chargeable_wait_seconds, waiting_fee_cents, waiting_fee_waived',
          )
          .eq('id', rideId)
          .maybeSingle();
      if (row == null) return;
      _applyWaitingRecord(Map<String, dynamic>.from(row));
      final remoteStatus = row['status'] as String?;
      if (remoteStatus == null || remoteStatus.isEmpty) return;
      final localStatus = ref.read(rideRequestProvider).status;
      if (remoteStatus != localStatus) {
        ref.read(rideRequestProvider.notifier).updateStatus(remoteStatus);
        await _loadDriverInfo(rideId);
        unawaited(
          RiderNotificationLifecycleService.trackEvent(
            'active_ride_status_mismatch_corrected',
            payload: <String, dynamic>{
              'reason': reason,
              'local_status': localStatus,
              'remote_status': remoteStatus,
              'ride_request_id': rideId,
            },
          ),
        );
        debugPrint(
          '[ActiveRideScreen] status refresh ($reason) local=$localStatus remote=$remoteStatus',
        );
      }
      final updatedAtRaw = row['updated_at'] as String?;
      if (updatedAtRaw != null) {
        final updatedAt = DateTime.tryParse(updatedAtRaw)?.toLocal();
        if (updatedAt != null) {
          final age = DateTime.now().difference(updatedAt);
          if (age.inMinutes >= 2) {
            if (_lastStaleStatusMinuteTracked != age.inMinutes) {
              _lastStaleStatusMinuteTracked = age.inMinutes;
              unawaited(
                RiderNotificationLifecycleService.trackEvent(
                  'active_ride_status_snapshot_stale',
                  payload: <String, dynamic>{
                    'reason': reason,
                    'ride_request_id': rideId,
                    'stale_age_minutes': age.inMinutes,
                    'status': remoteStatus,
                  },
                ),
              );
            }
            debugPrint(
              '[ActiveRideScreen] status snapshot is ${age.inMinutes}m old ($reason)',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ActiveRideScreen] status refresh error ($reason): $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRideStatus(reason: 'app_resumed');
      final rideId = ref.read(rideRequestProvider).rideRequestId;
      if (rideId != null) {
        ref.read(driverTrackingProvider.notifier).startTracking(rideId);
        _loadWaitingInfo(rideId);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusRefreshTimer?.cancel();
    _waitingUiTimer?.cancel();
    _rideStatusChannel?.unsubscribe();
    ref.read(driverTrackingProvider.notifier).stopTracking();
    super.dispose();
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // 1. Hide scale bar and compass clutter
    await _mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _mapboxMap!.compass.updateSettings(CompassSettings(enabled: false));
    await _mapboxMap!.attribution
        .updateSettings(AttributionSettings(enabled: false));
    await _mapboxMap!.logo.updateSettings(LogoSettings(enabled: false));

    // 2. Show the blue pulsing GPS dot
    await _mapboxMap!.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF4285F4,
      pulsingMaxRadius: 40.0,
      showAccuracyRing: true,
    ));

    _driverAnnotationManager =
        await map.annotations.createPointAnnotationManager();
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
    final l10n = AppLocalizations.of(context);
    final colors = ref.read(colorsProvider);
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.activeRideShareError,
              style: TextStyle(color: colors.text)),
          backgroundColor: colors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
        final result = await HeyCabySupabase.client
            .from('ride_shares')
            .insert({
              'ride_request_id': rideId,
              'rider_token': identity.riderToken,
              'is_active': true,
            })
            .select('share_token')
            .single();
        shareUrl = '$kAppPublicWebOrigin/track/${result['share_token']}';
      }

      await Share.share(shareUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.rideShareCopied,
                style: TextStyle(color: colors.text)),
            backgroundColor: colors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.activeRideShareError}: $e',
              style: TextStyle(color: colors.text)),
          backgroundColor: colors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    final driverLocation = ref.watch(driverTrackingProvider).valueOrNull;
    final booking = ref.watch(bookingProvider);
    final status = ride.status ?? 'assigned';
    final etaMinutes = _estimateEtaMinutes(
      status: status,
      booking: booking,
      driverLocation: driverLocation,
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: mapStyleForTheme(ref.watch(themeProvider).id),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.48,
            minChildSize: 0.32,
            maxChildSize: 0.86,
            snap: true,
            snapSizes: const [0.48, 0.86],
            builder: (context, scrollController) {
              return _ActiveRideSheet(
                status: status,
                colors: colors,
                typo: typo,
                l10n: l10n,
                booking: booking,
                scrollController: scrollController,
                onComplete: () => context.go('/home'),
                onShare: () => _shareRide(context),
                onPingDriver: () => _openPingDriverSheet(context),
                onPickupNote: () => context.push('/chat'),
                onCancelRide: () => _openCancelFlow(context),
                driverInfo: _driverInfo,
                etaMinutes: etaMinutes,
                lastRiderPing: _lastRiderPing,
                waitingInfo: _waitingInfo,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openPingDriverSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final message = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PingDriverSheet(
        colors: ref.read(colorsProvider),
        typo: ref.read(typographyProvider),
        options: [
          l10n.activeRidePingAtPickup,
          l10n.activeRidePingWalkingThere,
          l10n.activeRidePingCantFindYou,
          l10n.activeRidePingRunningLate,
          l10n.activeRidePingConfirmPlate,
        ],
      ),
    );
    if (message == null || !context.mounted) return;
    await _sendRiderPing(context, message);
  }

  Future<void> _sendRiderPing(BuildContext context, String message) async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    final colors = ref.read(colorsProvider);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final identity = await ref.read(riderIdentityProvider.future);
      final senderId = identity.identityId ??
          HeyCabySupabase.client.auth.currentUser?.id ??
          '';
      if (senderId.isEmpty) return;
      await HeyCabySupabase.client.from('messages').insert({
        'ride_request_id': rideId,
        'sender_id': senderId,
        'sender_type': 'rider',
        'content': message,
      });
      if (!mounted) return;
      setState(() => _lastRiderPing = message);
      unawaited(HapticService.pingStandard());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.activeRidePingSent(message),
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.activeRidePingFailed,
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int? _estimateEtaMinutes({
    required String status,
    required BookingState booking,
    required DriverLocation? driverLocation,
  }) {
    if (driverLocation == null) return null;
    final target =
        status == 'in_progress' ? booking.destination : booking.pickup;
    if (target == null) return null;
    final km = NearbySupplyService.distanceKm(
      driverLocation.lat,
      driverLocation.lng,
      target.lat,
      target.lng,
    );
    // Conservative city speed profile to avoid optimistic ETAs.
    final mins = ((km / 28.0) * 60.0).ceil();
    return mins.clamp(1, 90);
  }

  Future<void> _openCancelFlow(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CancelReasonSheet(
        colors: ref.read(colorsProvider),
        typo: ref.read(typographyProvider),
      ),
    );
    if (reason == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ref.read(colorsProvider);
        final typo = ref.read(typographyProvider);
        return AlertDialog(
          backgroundColor: colors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l10n.cancelBookingTitle,
            style: typo.titleLarge.copyWith(color: colors.text),
          ),
          content: Text(
            l10n.activeRideCancelConfirmBody,
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.activeRideWaitForDriver),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.cancelRide),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    await _cancelRideFromActive(reason);
    if (!context.mounted) return;
    context.go('/home');
  }

  Future<void> _cancelRideFromActive(String reason) async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    try {
      final identity = await ref.read(riderIdentityProvider.future);
      final token = identity.riderToken;
      if (token != null && token.isNotEmpty) {
        await cancelExpiredRiderOpenRide(
          rideId: rideId,
          riderToken: token,
          cancellationReason: 'rider_cancelled_from_active:$reason',
        );
      }
      await RiderNotificationLifecycleService.trackEvent(
        'active_ride_cancelled_by_rider',
        payload: <String, dynamic>{
          'ride_request_id': rideId,
          'reason': reason,
        },
      );
    } catch (_) {
      // Keep UI responsive even if cancellation API fails.
    } finally {
      ref.read(rideRequestProvider.notifier).reset();
    }
  }
}

class _ActiveRideSheet extends StatelessWidget {
  final String status;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final BookingState booking;
  final ScrollController scrollController;
  final VoidCallback onComplete;
  final VoidCallback onShare;
  final VoidCallback onPingDriver;
  final VoidCallback onPickupNote;
  final VoidCallback onCancelRide;
  final _DriverSheetInfo? driverInfo;
  final int? etaMinutes;
  final String? lastRiderPing;
  final _RideWaitingInfo? waitingInfo;

  const _ActiveRideSheet({
    required this.status,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.booking,
    required this.scrollController,
    required this.onComplete,
    required this.onShare,
    required this.onPingDriver,
    required this.onPickupNote,
    required this.onCancelRide,
    required this.driverInfo,
    required this.etaMinutes,
    required this.lastRiderPing,
    required this.waitingInfo,
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
    final isCompleted = status == 'completed';
    String paymentLabel() {
      if (booking.paymentMethods.isEmpty) return l10n.pinSubtitle;
      return booking.paymentMethods.first.replaceAll('_', ' ');
    }

    String categoryLabel() {
      final cat = booking.vehicleCategory?.trim();
      if (cat == null || cat.isEmpty) return l10n.vehicleStandard;
      return cat[0].toUpperCase() + cat.substring(1);
    }

    String fareLabel() {
      final fare = booking.estimatedFareEuro ??
          booking.tripPriceBandMaxEuro ??
          booking.tripPriceBandMinEuro ??
          (booking.marketplaceBidEuro?.toDouble());
      if (fare == null) return '—';
      return '€${fare.toStringAsFixed(2)}';
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(22, 16, 22, 22),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
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
            _RideConfidenceHeader(
              status: status,
              label: _statusLabel(l10n),
              colors: colors,
              typo: typo,
              l10n: l10n,
              etaMinutes: etaMinutes,
              driverInfo: driverInfo,
              fareLabel: fareLabel(),
              paymentLabel: paymentLabel(),
              categoryLabel: categoryLabel(),
            ),
            const SizedBox(height: 14),
            if (driverInfo != null) ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _DriverInfoCard(
                  key: ValueKey<String>(
                      '${driverInfo!.vehiclePlate}_${driverInfo!.fullName}_$status'),
                  driverInfo: driverInfo!,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (lastRiderPing != null && lastRiderPing!.trim().isNotEmpty) ...[
              _LastPingStrip(
                text: l10n.activeRideLastPing(lastRiderPing!),
                colors: colors,
                typo: typo,
              ),
              const SizedBox(height: 12),
            ],
            if ((status == 'driver_arrived' || status == 'arrived') &&
                waitingInfo != null) ...[
              _RiderWaitingFeeCard(
                colors: colors,
                typo: typo,
                info: waitingInfo!,
                l10n: l10n,
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.bgAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      color: colors.textMid, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.activeRidePickupNotes,
                      style: typo.bodyMedium.copyWith(color: colors.textMid),
                    ),
                  ),
                  IconButton(
                    onPressed: onPickupNote,
                    icon: Icon(Icons.arrow_forward_rounded,
                        color: colors.textSoft),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.55,
              children: [
                _ActionButton(
                  icon: Icons.touch_app_rounded,
                  label: l10n.activeRidePingDriver,
                  subtitle: l10n.activeRidePingSubtitle,
                  colors: colors,
                  typo: typo,
                  onTap: onPingDriver,
                  isPrimary: true,
                ),
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: l10n.activeRidePickupNote,
                  subtitle: l10n.activeRideChatSubtitle,
                  colors: colors,
                  typo: typo,
                  onTap: onPickupNote,
                ),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: l10n.shareRide,
                  subtitle: l10n.activeRideShareSubtitle,
                  colors: colors,
                  typo: typo,
                  onTap: onShare,
                ),
                _ActionButton(
                  icon:
                      isCompleted ? Icons.flag_outlined : Icons.shield_outlined,
                  label: isCompleted ? l10n.reportIssue : l10n.safety,
                  subtitle: isCompleted
                      ? l10n.activeRideReportSubtitle
                      : l10n.activeRideSupportSubtitle,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.push(
                    isCompleted ? '/report' : '/support',
                    extra: isCompleted
                        ? const ReportRouteArgs(fromActiveRide: true)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.yourRoute,
              rightActionLabel: l10n.tripSummaryEdit,
              colors: colors,
              typo: typo,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RouteRow(
                    icon: Icons.place_rounded,
                    iconColor: colors.success,
                    text: booking.pickup?.fullAddress ??
                        l10n.activeRidePickupNotSet,
                    typo: typo,
                    colors: colors,
                  ),
                  const SizedBox(height: 10),
                  _RouteRow(
                    icon: Icons.flag_rounded,
                    iconColor: colors.accent,
                    text: booking.destination?.fullAddress ??
                        l10n.activeRideDestinationNotSet,
                    typo: typo,
                    colors: colors,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: l10n.paymentMethod,
              colors: colors,
              typo: typo,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.activeRideCategoryLabel(categoryLabel()),
                    style: typo.bodySmall.copyWith(color: colors.textMid),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.contactless_rounded,
                          color: colors.textMid, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          paymentLabel(),
                          style: typo.bodyMedium.copyWith(color: colors.text),
                        ),
                      ),
                      Text(
                        fareLabel(),
                        style: typo.labelLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: l10n.chatMoreOptions,
              colors: colors,
              typo: typo,
              child: Column(
                children: [
                  _MoreActionRow(
                    icon: Icons.ios_share_rounded,
                    label: l10n.activeRideShareDetails,
                    colors: colors,
                    typo: typo,
                    onTap: onShare,
                  ),
                  const SizedBox(height: 10),
                  _MoreActionRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: l10n.activeRideContactDriver,
                    colors: colors,
                    typo: typo,
                    onTap: onPickupNote,
                  ),
                  if (!isCompleted) ...[
                    const SizedBox(height: 10),
                    _MoreActionRow(
                      icon: Icons.close_rounded,
                      label: l10n.cancelRide,
                      colors: colors,
                      typo: typo,
                      isDanger: true,
                      onTap: onCancelRide,
                    ),
                  ],
                  if (isCompleted) ...[
                    const SizedBox(height: 10),
                    _MoreActionRow(
                      icon: Icons.flag_outlined,
                      label: l10n.reportIssue,
                      colors: colors,
                      typo: typo,
                      onTap: () => context.push(
                        '/report',
                        extra: const ReportRouteArgs(fromActiveRide: true),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isCompleted) ...[
              const SizedBox(height: 16),
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
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? rightActionLabel;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.rightActionLabel,
    required this.colors,
    required this.typo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: typo.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (rightActionLabel != null)
                Text(
                  rightActionLabel!,
                  style: typo.labelMedium.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final HeyCabyTypography typo;
  final HeyCabyColorTokens colors;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.typo,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: typo.bodyMedium.copyWith(color: colors.text),
          ),
        ),
      ],
    );
  }
}

class _MoreActionRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final bool isDanger;

  const _MoreActionRow({
    required this.icon,
    required this.label,
    required this.colors,
    required this.typo,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  State<_MoreActionRow> createState() => _MoreActionRowState();
}

class _MoreActionRowState extends State<_MoreActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onHighlightChanged: (v) => setState(() => _pressed = v),
      onTap: () {
        HapticService.selectionClick();
        widget.onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedScale(
        scale: _pressed ? HeyCabyMotion.rowPressScale : 1,
        duration: HeyCabyMotion.pressDuration,
        curve: HeyCabyMotion.pressCurve,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isDanger
                    ? widget.colors.error
                    : widget.colors.textMid,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: widget.typo.bodyMedium.copyWith(
                    color: widget.isDanger
                        ? widget.colors.error
                        : widget.colors.text,
                    fontWeight:
                        widget.isDanger ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.colors.textSoft,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelReasonSheet extends StatefulWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _CancelReasonSheet({
    required this.colors,
    required this.typo,
  });

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reasons = <String>[
      l10n.activeRideCancelReasonLongPickup,
      l10n.activeRideCancelReasonBetterAlternative,
      l10n.activeRideCancelReasonDriverNotCloser,
      l10n.activeRideCancelReasonDriverAskedCancel,
      l10n.activeRideCancelReasonPriceDispute,
      l10n.activeRideCancelReasonOutsideAppPayment,
      l10n.reportOther,
    ];
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: widget.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: widget.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: widget.colors.text),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.whatWentWrong,
                    style: widget.typo.titleLarge.copyWith(
                      color: widget.colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...reasons.map((reason) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  reason,
                  style: widget.typo.bodyMedium
                      .copyWith(color: widget.colors.text),
                ),
                trailing: Icon(
                  reason == _selectedReason
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: reason == _selectedReason
                      ? widget.colors.accent
                      : widget.colors.textSoft,
                ),
                onTap: () => setState(() => _selectedReason = reason),
              );
            }),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _selectedReason == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedReason),
                child: Text(l10n.submit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideConfidenceHeader extends StatelessWidget {
  final String status;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final int? etaMinutes;
  final _DriverSheetInfo? driverInfo;
  final String fareLabel;
  final String paymentLabel;
  final String categoryLabel;

  const _RideConfidenceHeader({
    required this.status,
    required this.label,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.etaMinutes,
    required this.driverInfo,
    required this.fareLabel,
    required this.paymentLabel,
    required this.categoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = status == 'completed';
    final isArrived = status == 'driver_arrived' || status == 'arrived';
    final isInProgress = status == 'in_progress';
    final title = switch (status) {
      'driver_arrived' || 'arrived' => l10n.activeRideDriverOutside,
      'in_progress' => etaMinutes != null
          ? l10n.activeRideArrivingIn(etaMinutes!.toString())
          : l10n.tripInProgress,
      'completed' => l10n.tripComplete,
      _ => etaMinutes != null
          ? l10n.activeRidePickupIn(etaMinutes!.toString())
          : label,
    };
    final vehicle = driverInfo?.naturalVehicleLabel.trim() ?? '';
    final phaseIcon = isComplete
        ? Icons.check_circle_rounded
        : isInProgress
            ? Icons.route_rounded
            : isArrived
                ? Icons.location_on_rounded
                : Icons.local_taxi_rounded;
    final phaseBody = isComplete
        ? l10n.tripComplete
        : isInProgress
            ? l10n.activeRideVerifyPlate
            : isArrived
                ? l10n.activeRideWaitingGraceBody
                : (vehicle.isNotEmpty ? vehicle : l10n.activeRideVerifyPlate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            colors.bgAlt,
            colors.accentL.withValues(alpha: 0.42),
          ],
          stops: const [0, 0.58, 1],
        ),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.16),
                  ),
                ),
                child: Icon(
                  phaseIcon,
                  color: isComplete ? colors.success : colors.accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PhasePill(
                          colors: colors,
                          typo: typo,
                          label: label,
                          tone: isComplete ? colors.success : colors.accent,
                        ),
                        if (etaMinutes != null && !isComplete)
                          _PhasePill(
                            colors: colors,
                            typo: typo,
                            label: '${etaMinutes!} min',
                            tone: colors.text,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Text(
                        title,
                        key: ValueKey(title),
                        style: typo.headingMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phaseBody,
                      style: typo.bodyMedium.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PhaseMetric(
                  colors: colors,
                  typo: typo,
                  label: l10n.fareEstimate,
                  value: fareLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PhaseMetric(
                  colors: colors,
                  typo: typo,
                  label: l10n.paymentMethod,
                  value: paymentLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PhaseMetric(
                  colors: colors,
                  typo: typo,
                  label: l10n.vehicleLabel,
                  value: categoryLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final Color tone;

  const _PhasePill({
    required this.colors,
    required this.typo,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: tone.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: typo.labelSmall.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseMetric extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final String value;

  const _PhaseMetric({
    required this.colors,
    required this.typo,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.labelSmall.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastPingStrip extends StatelessWidget {
  final String text;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _LastPingStrip({
    required this.text,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accentL,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.accent, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: typo.bodySmall.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderWaitingFeeCard extends StatelessWidget {
  const _RiderWaitingFeeCard({
    required this.colors,
    required this.typo,
    required this.info,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final _RideWaitingInfo info;
  final AppLocalizations l10n;

  String _duration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = (safe % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
    return '$m:$s';
  }

  String _money(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final elapsed = info.elapsedSinceArrivalSeconds();
    final chargeable = info.chargeableSecondsNow();
    final remainingGrace = info.remainingGraceSecondsNow();
    final feeCents = info.waitingFeeCentsNow();
    final isGrace = !info.waived && chargeable == 0;
    final title = info.waived
        ? l10n.activeRideWaitingFeeWaived
        : isGrace
            ? l10n.activeRideWaitingFreePickupTime
            : l10n.activeRideWaitingTime;
    final main = info.waived
        ? _money(0)
        : isGrace
            ? _duration(remainingGrace)
            : _duration(chargeable);
    final subtitle = info.waived
        ? l10n.activeRideWaitingFeeWaivedBody
        : isGrace
            ? l10n.activeRideWaitingGraceBody
            : l10n.activeRideWaitingFeeAdded(_money(feeCents));
    final rate = info.ratePerMinute > 0
        ? l10n.activeRideWaitingRate(
            '€${info.ratePerMinute.toStringAsFixed(2)}/min',
          )
        : l10n.activeRideWaitingRateNotSet;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: info.waived
            ? colors.success.withValues(alpha: 0.1)
            : colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: info.waived
              ? colors.success.withValues(alpha: 0.24)
              : colors.warning.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: info.waived ? colors.success : colors.warning,
                width: 2,
              ),
            ),
            child: Icon(
              info.waived
                  ? Icons.volunteer_activism_rounded
                  : Icons.timer_outlined,
              color: info.waived ? colors.success : colors.warning,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: typo.titleMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      main,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: typo.bodySmall.copyWith(color: colors.textMid),
                ),
                const SizedBox(height: 6),
                Text(
                  elapsed < info.graceSeconds
                      ? rate
                      : l10n.activeRideWaitingRateLive(rate),
                  style: typo.labelSmall.copyWith(
                    color: colors.textSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PingDriverSheet extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final List<String> options;

  const _PingDriverSheet({
    required this.colors,
    required this.typo,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.activeRidePingDriver,
              style: typo.titleLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.activeRidePingSheetSubtitle,
              style: typo.bodyMedium.copyWith(color: colors.textMid),
            ),
            const SizedBox(height: 14),
            ...options.map((message) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    HapticService.selectionClick();
                    Navigator.of(context).pop(message);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bgAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: colors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            style: typo.bodyMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.send_rounded,
                          color: colors.textSoft,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.typo,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onHighlightChanged: (v) => setState(() => _pressed = v),
      onTap: () {
        HapticService.lightTap();
        widget.onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedScale(
        scale: _pressed ? HeyCabyMotion.cardPressScale : 1,
        duration: HeyCabyMotion.pressDuration,
        curve: HeyCabyMotion.pressCurve,
        child: AnimatedContainer(
          duration: HeyCabyMotion.pressDuration,
          curve: HeyCabyMotion.pressCurve,
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: _pressed
                ? (widget.isPrimary
                    ? widget.colors.accent.withValues(alpha: 0.9)
                    : widget.colors.bgAlt.withValues(
                        alpha: HeyCabyMotion.pressedBackgroundAlpha,
                      ))
                : (widget.isPrimary
                    ? widget.colors.accent
                    : widget.colors.bgAlt),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isPrimary
                  ? widget.colors.accent
                  : (_pressed
                      ? widget.colors.accent.withValues(
                          alpha: HeyCabyMotion.pressedBorderAlpha,
                        )
                      : widget.colors.border),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: widget.isPrimary
                    ? widget.colors.onAccent
                    : widget.colors.textMid,
                size: 19,
              ),
              const SizedBox(height: 7),
              Text(
                widget.label,
                style: widget.typo.labelMedium.copyWith(
                  color: widget.isPrimary
                      ? widget.colors.onAccent
                      : widget.colors.text,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              AnimatedOpacity(
                duration: HeyCabyMotion.pressDuration,
                opacity: _pressed ? HeyCabyMotion.pressedSubtitleOpacity : 1,
                child: Text(
                  widget.subtitle,
                  style: widget.typo.bodySmall.copyWith(
                    color: widget.isPrimary
                        ? widget.colors.onAccent.withValues(alpha: 0.82)
                        : widget.colors.textSoft,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideWaitingInfo {
  const _RideWaitingInfo({
    required this.arrivedAt,
    required this.graceSeconds,
    required this.ratePerMinute,
    required this.frozenChargeableSeconds,
    required this.frozenFeeCents,
    required this.waived,
  });

  final DateTime arrivedAt;
  final int graceSeconds;
  final double ratePerMinute;
  final int frozenChargeableSeconds;
  final int frozenFeeCents;
  final bool waived;

  static _RideWaitingInfo? fromJson(Map<String, dynamic> json) {
    final arrivedRaw = json['driver_arrived_at']?.toString();
    final arrivedAt = arrivedRaw == null ? null : DateTime.tryParse(arrivedRaw);
    if (arrivedAt == null) return null;
    final graceRaw = json['waiting_grace_seconds'];
    final rateRaw = json['waiting_rate_per_minute'];
    final chargeableRaw = json['chargeable_wait_seconds'];
    final feeRaw = json['waiting_fee_cents'];
    return _RideWaitingInfo(
      arrivedAt: arrivedAt.toUtc(),
      graceSeconds:
          graceRaw is num ? graceRaw.toInt().clamp(0, 3600).toInt() : 120,
      ratePerMinute:
          rateRaw is num ? rateRaw.toDouble().clamp(0, 9999).toDouble() : 0,
      frozenChargeableSeconds: chargeableRaw is num
          ? chargeableRaw.toInt().clamp(0, 86400).toInt()
          : 0,
      frozenFeeCents:
          feeRaw is num ? feeRaw.toInt().clamp(0, 99999999).toInt() : 0,
      waived: json['waiting_fee_waived'] == true,
    );
  }

  int elapsedSinceArrivalSeconds({DateTime? now}) {
    final end = (now ?? DateTime.now()).toUtc();
    final seconds = end.difference(arrivedAt).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  int remainingGraceSecondsNow() {
    final remaining = graceSeconds - elapsedSinceArrivalSeconds();
    return remaining < 0 ? 0 : remaining;
  }

  int chargeableSecondsNow() {
    if (frozenChargeableSeconds > 0) return frozenChargeableSeconds;
    final chargeable = elapsedSinceArrivalSeconds() - graceSeconds;
    return chargeable < 0 ? 0 : chargeable;
  }

  int waitingFeeCentsNow() {
    if (waived) return 0;
    if (frozenFeeCents > 0) return frozenFeeCents;
    return ((chargeableSecondsNow() / 60) * ratePerMinute * 100).round();
  }
}

class _DriverSheetInfo {
  final String fullName;
  final String? profilePhotoUrl;
  final String? vehiclePlate;
  final String? vehicleCategory;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehiclePhotoUrl;
  final double? rating;

  const _DriverSheetInfo({
    required this.fullName,
    this.profilePhotoUrl,
    this.vehiclePlate,
    this.vehicleCategory,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.vehiclePhotoUrl,
    this.rating,
  });

  factory _DriverSheetInfo.fromJson(
    Map<String, dynamic> json, {
    required String fallbackDriverLabel,
  }) {
    final ratingRaw = json['avg_rating'];
    final rating = ratingRaw is num ? ratingRaw.toDouble() : null;
    String? firstPhoto;
    final rawPhotos = json['vehicle_photo_urls'];
    if (rawPhotos is List && rawPhotos.isNotEmpty) {
      final first = rawPhotos.first;
      if (first is String && first.trim().isNotEmpty) {
        firstPhoto = first.trim();
      }
    }
    return _DriverSheetInfo(
      fullName: (json['full_name'] as String?)?.trim().isNotEmpty == true
          ? (json['full_name'] as String).trim()
          : fallbackDriverLabel,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleCategory: json['vehicle_category'] as String?,
      vehicleMake: json['vehicle_make'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor:
          (json['vehicle_colour'] ?? json['vehicle_color']) as String?,
      vehiclePhotoUrl: firstPhoto,
      rating: rating,
    );
  }

  String get naturalVehicleLabel {
    final color = (vehicleColor ?? '').trim();
    final make = (vehicleMake ?? '').trim();
    final model = (vehicleModel ?? '').trim();
    final parts = [
      if (color.isNotEmpty) color,
      if (make.isNotEmpty) make,
      if (model.isNotEmpty) model,
    ];
    if (parts.isNotEmpty) return parts.join(' ');
    return (vehicleCategory ?? '').trim();
  }
}

class _DriverInfoCard extends StatelessWidget {
  final _DriverSheetInfo driverInfo;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _DriverInfoCard({
    super.key,
    required this.driverInfo,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final carLine = driverInfo.naturalVehicleLabel;
    final category = (driverInfo.vehicleCategory ?? '').trim();
    final seatCount = category.toLowerCase().contains('taxibus') ? '8' : '4';
    final plate = (driverInfo.vehiclePlate ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.activeRidePlateNumber,
                      style: typo.labelSmall.copyWith(
                        color: colors.textSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.text.withValues(alpha: 0.16),
                          width: 1.2,
                        ),
                      ),
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          plate.isEmpty
                              ? l10n.activeRideUnknownPlate
                              : plate.toUpperCase(),
                          style: typo.titleLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      carLine.isNotEmpty ? carLine : l10n.vehicleStandard,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _VehicleChip(
                          label: category.isNotEmpty
                              ? category[0].toUpperCase() +
                                  category.substring(1)
                              : l10n.vehicleStandard,
                          colors: colors,
                          typo: typo,
                        ),
                        _VehicleChip(
                          label: l10n.activeRideSeatsMax(seatCount),
                          colors: colors,
                          typo: typo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 116,
                height: 86,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: colors.text.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: (driverInfo.vehiclePhotoUrl != null &&
                        driverInfo.vehiclePhotoUrl!.isNotEmpty)
                    ? Image.network(
                        driverInfo.vehiclePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.directions_car_filled_rounded,
                          color: colors.textSoft,
                          size: 28,
                        ),
                      )
                    : Icon(
                        Icons.directions_car_filled_rounded,
                        color: colors.textSoft,
                        size: 40,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: colors.accentL,
                    backgroundImage: (driverInfo.profilePhotoUrl != null &&
                            driverInfo.profilePhotoUrl!.isNotEmpty)
                        ? NetworkImage(driverInfo.profilePhotoUrl!)
                        : null,
                    child: (driverInfo.profilePhotoUrl == null ||
                            driverInfo.profilePhotoUrl!.isEmpty)
                        ? Icon(Icons.person, color: colors.accent)
                        : null,
                  ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverInfo.fullName,
                      style: typo.bodyLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.activeRideVerifiedTaxi,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                    ),
                  ],
                ),
              ),
              if (driverInfo.rating != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, size: 17, color: colors.warning),
                      const SizedBox(width: 3),
                      Text(
                        driverInfo.rating!.toStringAsFixed(1),
                        style: typo.labelMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.activeRideVerifyPlate,
            style: typo.displayMedium.copyWith(color: colors.textSoft),
          ),
        ],
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _VehicleChip({
    required this.label,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: typo.labelSmall.copyWith(
          color: colors.textMid,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
