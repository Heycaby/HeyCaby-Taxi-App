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
  Timer? _statusRefreshTimer;
  int _lastStaleStatusMinuteTracked = -1;

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
      }
      _startStatusRefreshTimer();
      _syncRidePhaseWidgets();
    });
  }

  Future<void> _loadDriverInfo(String rideId) async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'driver_id, drivers(full_name, avg_rating, vehicle_plate, profile_photo_url, vehicle_category, vehicle_make, vehicle_model, vehicle_color, vehicle_photo_urls, is_founding_driver, founding_number)',
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
          .select('status, updated_at')
          .eq('id', rideId)
          .maybeSingle();
      if (row == null) return;
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
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusRefreshTimer?.cancel();
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActiveRideSheet(
              status: status,
              colors: colors,
              typo: typo,
              l10n: l10n,
              booking: booking,
              onComplete: () => context.go('/home'),
              onShare: () => _shareRide(context),
              onChat: () => context.push('/chat'),
              onCancelRide: () => _openCancelFlow(context),
              driverInfo: _driverInfo,
              etaMinutes: etaMinutes,
            ),
          ),
        ],
      ),
    );
  }

  int? _estimateEtaMinutes({
    required String status,
    required BookingState booking,
    required DriverLocation? driverLocation,
  }) {
    if (driverLocation == null) return null;
    final target = status == 'in_progress' ? booking.destination : booking.pickup;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
  final VoidCallback onComplete;
  final VoidCallback onShare;
  final VoidCallback onChat;
  final VoidCallback onCancelRide;
  final _DriverSheetInfo? driverInfo;
  final int? etaMinutes;

  const _ActiveRideSheet({
    required this.status,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.booking,
    required this.onComplete,
    required this.onShare,
    required this.onChat,
    required this.onCancelRide,
    required this.driverInfo,
    required this.etaMinutes,
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
    final sheetHeight = MediaQuery.of(context).size.height * 0.66;
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
      height: sheetHeight,
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
            _StatusBadge(
              status: status,
              label: _statusLabel(l10n),
              colors: colors,
              typo: typo,
              l10n: l10n,
              etaMinutes: etaMinutes,
            ),
            const SizedBox(height: 16),
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
                  key: ValueKey<String>('${driverInfo!.vehiclePlate}_${driverInfo!.fullName}_$status'),
                  driverInfo: driverInfo!,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                ),
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
                  Icon(Icons.chat_bubble_outline, color: colors.textMid, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.activeRidePickupNotes,
                      style: typo.bodyMedium.copyWith(color: colors.textMid),
                    ),
                  ),
                  IconButton(
                    onPressed: onChat,
                    icon: Icon(Icons.arrow_forward_rounded, color: colors.textSoft),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: l10n.chat,
                    subtitle: l10n.activeRideChatSubtitle,
                    colors: colors,
                    typo: typo,
                    onTap: onChat,
                    badgeLabel:
                        (driverInfo?.isFoundingDriver ?? false) ? l10n.activeRideFoundingShort : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.share_outlined,
                    label: l10n.shareRide,
                    subtitle: l10n.activeRideShareSubtitle,
                    colors: colors,
                    typo: typo,
                    onTap: onShare,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: isCompleted ? Icons.flag_outlined : Icons.support_agent,
                    label: isCompleted ? l10n.reportIssue : l10n.support,
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
                    text: booking.pickup?.fullAddress ?? l10n.activeRidePickupNotSet,
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
                      Icon(Icons.contactless_rounded, color: colors.textMid, size: 20),
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
                    onTap: onChat,
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
                color:
                    widget.isDanger ? widget.colors.error : widget.colors.textMid,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: widget.typo.bodyMedium.copyWith(
                    color:
                        widget.isDanger ? widget.colors.error : widget.colors.text,
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
                  style: widget.typo.bodyMedium.copyWith(color: widget.colors.text),
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

class _AnimatedEtaLabel extends StatelessWidget {
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _AnimatedEtaLabel({
    required this.label,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: child,
      ),
      child: Text(
        label,
        style: typo.labelSmall.copyWith(
          color: colors.textMid,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final int? etaMinutes;

  const _StatusBadge({
    required this.status,
    required this.label,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.etaMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = status == 'completed';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isComplete
                ? colors.success.withValues(alpha: 0.12)
                : colors.accentL,
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
        if (etaMinutes != null && status != 'completed')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.bgAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            child: _AnimatedEtaLabel(
              label: l10n.eta(etaMinutes!.toString()),
              colors: colors,
              typo: typo,
            ),
          ),
      ],
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
  final String? badgeLabel;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.typo,
    required this.onTap,
    this.badgeLabel,
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
                ? widget.colors.bgAlt.withValues(
                    alpha: HeyCabyMotion.pressedBackgroundAlpha,
                  )
                : widget.colors.bgAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pressed
                  ? widget.colors.accent.withValues(
                      alpha: HeyCabyMotion.pressedBorderAlpha,
                    )
                  : widget.colors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.badgeLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.colors.accentL,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    widget.badgeLabel!,
                    style: widget.typo.labelSmall.copyWith(
                      color: widget.colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Icon(widget.icon, color: widget.colors.textMid, size: 19),
              const SizedBox(height: 7),
              Text(
                widget.label,
                style: widget.typo.labelMedium.copyWith(
                  color: widget.colors.text,
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
                  style: widget.typo.bodySmall.copyWith(color: widget.colors.textSoft),
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

class _DriverSheetInfo {
  final String fullName;
  final String? profilePhotoUrl;
  final String? vehiclePlate;
  final String? vehicleCategory;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehiclePhotoUrl;
  final bool isFoundingDriver;
  final int? foundingNumber;
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
    this.isFoundingDriver = false,
    this.foundingNumber,
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
      vehicleColor: json['vehicle_color'] as String?,
      vehiclePhotoUrl: firstPhoto,
      isFoundingDriver: (json['is_founding_driver'] as bool?) ?? false,
      foundingNumber: (json['founding_number'] as num?)?.toInt(),
      rating: rating,
    );
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
    final carLine = [
      if ((driverInfo.vehicleMake ?? '').trim().isNotEmpty) driverInfo.vehicleMake!.trim(),
      if ((driverInfo.vehicleModel ?? '').trim().isNotEmpty)
        driverInfo.vehicleModel!.trim(),
      if ((driverInfo.vehicleColor ?? '').trim().isNotEmpty)
        '(${driverInfo.vehicleColor!.trim()})',
    ].join(' ');
    final fallbackCarLine = (driverInfo.vehicleCategory ?? '').trim();
    final plate = (driverInfo.vehiclePlate ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.activeRidePlateNumber,
            style: typo.labelSmall.copyWith(color: colors.textSoft),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.accent.withValues(alpha: 0.45), width: 1.4),
            ),
            child: Text(
              plate.isEmpty ? l10n.activeRideUnknownPlate : plate.toUpperCase(),
              style: typo.titleLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
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
                  if (driverInfo.isFoundingDriver)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 1.5),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: colors.onAccent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverInfo.fullName,
                      style: typo.bodyLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      carLine.isNotEmpty ? carLine : fallbackCarLine,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 72,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
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
                        size: 28,
                      ),
              ),
              if (driverInfo.rating != null) ...[
                const SizedBox(width: 8),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: colors.warning),
                    const SizedBox(width: 2),
                    Text(
                      driverInfo.rating!.toStringAsFixed(1),
                      style: typo.labelMedium.copyWith(color: colors.text),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (driverInfo.isFoundingDriver) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.accentL,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                driverInfo.foundingNumber != null
                    ? '${l10n.activeRideFoundingMember} #${driverInfo.foundingNumber}'
                    : l10n.activeRideFoundingMember,
                style: typo.labelSmall.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
