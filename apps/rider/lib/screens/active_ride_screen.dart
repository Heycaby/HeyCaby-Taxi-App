import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/rating_route_args.dart';
import '../models/ride_matching_variant.dart';
import '../models/ride_waiting_info.dart';
import '../models/taxi_terug_queue_status.dart';
import '../providers/booking_provider.dart';
import '../providers/driver_tracking_provider.dart';
import '../providers/ride_request_provider.dart';
import '../providers/rider_ride_unread_messages_provider.dart';
import '../providers/taxi_terug_queue_provider.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/rider_eta_service.dart';
import '../services/nearby_supply_service.dart';
import '../services/rider_driver_profile_service.dart';
import '../services/rider_notification_lifecycle_service.dart';
import '../services/rider_notify_live_activity.dart';
import '../services/rider_plate_verification_service.dart';
import '../services/rider_plate_verification_storage.dart';
import '../services/rider_ride_lifecycle_engine.dart';
import '../services/rider_ride_snapshot_service.dart';
import '../services/rider_runtime_config_service.dart';
import '../services/stale_ride_cleanup.dart';
import '../widgets/active_ride/active_ride_map_stack.dart';
import '../widgets/active_ride/active_ride_status_dock.dart';
import '../widgets/address_search_modal.dart';
import '../widgets/rider_driver_info_card.dart';
import '../widgets/rider_prepay_card.dart';
import '../widgets/rider_trip_pin_card.dart';
import '../widgets/taxi_terug_queue_banner.dart';
import '../widgets/ride_pay_driver_sheet.dart';
import '../widgets/rate_driver_sheet.dart';
import 'report_screen.dart';

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen>
    with WidgetsBindingObserver {
  static const _kSheetPeek = 0.22;
  static const _kSheetCollapsed = 0.40;
  static const _kSheetExpanded = 0.85;
  static const _kMapDockMaxExtent = 0.34;
  static const _kEmbeddedTimelineMinExtent = 0.48;
  RiderDriverSheetInfo? _driverInfo;
  String? _assignedDriverId;
  bool _plateVerified = false;
  RideWaitingInfo? _waitingInfo;
  Timer? _waitingUiTimer;
  int _lastStaleStatusMinuteTracked = -1;
  String? _lastRiderPing;
  int? _liveFareCents;
  final List<AddressResult> _routeStops = [];
  ActiveRideRouteState? _activeRouteState;
  bool _rideCompletedCheckoutHandled = false;
  double _sheetExtent = 0.40;
  bool _driverOnMyWay = false;
  bool _driverNearPickupNotified = false;
  double? _enRouteBaselineKm;
  double? _tripBaselineKm;
  String? _lastBackendRecordRevision;
  String? _communicationRideId;
  Future<RideCommunicationPermissions>? _communicationPermissions;

  // Cached ETA from Mapbox routing (real traffic-aware travel time).
  int? _cachedEtaMinutes;
  String? _etaCacheKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initOrRestore());
  }

  Future<void> _initOrRestore() async {
    if (!mounted) return;
    var rideId = ref.read(rideRequestProvider).rideRequestId;

    // If no ride in memory, try restoring from server (cold start, deep link, Rides tab).
    if (rideId == null || rideId.isEmpty) {
      final restored = await ref
          .read(rideRequestProvider.notifier)
          .tryRestoreActiveRideRequest();
      if (!mounted) return;
      if (!restored) {
        context.go('/home');
        return;
      }
      final ride = ref.read(rideRequestProvider);
      // If the restored ride is pending/bidding, redirect to matching screen.
      if (ride.status == 'pending' || ride.status == 'bidding') {
        context.go(rideMatchingVariantForBookingModeString(ride.bookingMode)
            .routePath);
        return;
      }
      if (!_isActiveRideStatus(ride.status)) {
        context.go('/home');
        return;
      }
      rideId = ride.rideRequestId;
    }

    if (rideId == null) {
      if (!mounted) return;
      context.go('/home');
      return;
    }

    ref.read(driverTrackingProvider.notifier).startTracking(rideId);
    _loadDriverInfo(rideId);
    unawaited(_loadPlateVerificationState(rideId));
    unawaited(RiderPlateVerificationService.syncPendingQueue());
    ref.invalidate(taxiTerugQueueStatusProvider(rideId));
    final projected = ref.read(riderRideBackendRecordProvider);
    if (projected?.rideRequestId == rideId) {
      unawaited(_applyBackendRideRecord(projected!));
    }
    unawaited(
      ref
          .read(riderRideLifecycleEngineProvider)
          .refreshRideState(source: 'active_ride_init'),
    );
    _startWaitingUiTimer();
    _syncRidePhaseWidgets();
  }

  bool _isActiveRideStatus(String? status) {
    const activeStatuses = {
      'assigned',
      'accepted',
      'driver_found',
      'driver_en_route',
      'driver_arrived',
      'arrived',
      'in_progress',
    };
    return status != null && activeStatuses.contains(status);
  }

  void _updateJourneyBaselines({
    required String status,
    required BookingState booking,
    required DriverLocation? driverLocation,
  }) {
    final pickup = booking.pickup;
    final destination = booking.destination;
    if (driverLocation == null || pickup == null) return;

    final distToPickup = NearbySupplyService.distanceKm(
      driverLocation.lat,
      driverLocation.lng,
      pickup.lat,
      pickup.lng,
    );

    if ((_driverOnMyWay ||
            status == 'driver_en_route' ||
            status == 'accepted' ||
            status == 'assigned' ||
            status == 'driver_found') &&
        status != 'in_progress' &&
        status != 'driver_arrived' &&
        status != 'arrived') {
      _enRouteBaselineKm ??= distToPickup;
      if (_enRouteBaselineKm != null && distToPickup > _enRouteBaselineKm!) {
        _enRouteBaselineKm = distToPickup;
      }
    }

    if (status == 'in_progress' && destination != null) {
      final distToDest = NearbySupplyService.distanceKm(
        driverLocation.lat,
        driverLocation.lng,
        destination.lat,
        destination.lng,
      );
      _tripBaselineKm ??= booking.routeDistanceKm;
      _tripBaselineKm ??= NearbySupplyService.distanceKm(
        pickup.lat,
        pickup.lng,
        destination.lat,
        destination.lng,
      );
      if (_tripBaselineKm != null && distToDest > _tripBaselineKm!) {
        _tripBaselineKm = distToDest;
      }
    }
  }

  void _startWaitingUiTimer() {
    _waitingUiTimer?.cancel();
    _waitingUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!context.mounted) return;
      final status = ref.read(rideRequestProvider).status ?? '';
      final waiting = _waitingInfo;
      if (waiting == null) return;
      if (status == 'driver_arrived' || status == 'arrived') {
        final booking = ref.read(bookingProvider);
        final total = waiting.totalFareCentsNow(
          quotedFareEuro: booking.quotedFareEuro,
          liveFareCents: _liveFareCents,
        );
        setState(() => _liveFareCents = total > 0 ? total : _liveFareCents);
      }
    });
  }

  Future<void> _startMaskedDriverCall(String rideId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.maskedCallTitle),
        content: Text(l10n.maskedCallBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.maskedCallNow),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result =
        await const MaskedRideCallingService().startCall(rideId: rideId);
    if (!mounted) return;
    setState(() {
      _communicationPermissions =
          const MaskedRideCallingService().permissions(rideId: rideId);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(result.ok ? l10n.maskedCallQueued : l10n.maskedCallUnavailable),
    ));
  }

  Future<void> _loadDriverInfo(String rideId) async {
    try {
      final identity = await ref.read(riderIdentityProvider.future);
      final map = await RiderDriverProfileService.fetchForRide(
        rideRequestId: rideId,
        riderToken: identity.riderToken,
      );
      if (!mounted || map == null) return;
      final parsed = RiderDriverSheetInfo.fromJson(
        map,
        fallbackDriverLabel: AppLocalizations.of(context).driver,
      );
      setState(() {
        _driverInfo = parsed;
        _assignedDriverId = map['driver_id'] as String?;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Driver info load error: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> _loadPlateVerificationState(String rideId) async {
    final serverVerified =
        await RiderPlateVerificationService.isVerifiedOnServer(rideId);
    if (serverVerified) {
      await RiderPlateVerificationStorage.removeForRide(rideId);
      if (mounted) setState(() => _plateVerified = true);
      return;
    }

    final localVerified =
        await RiderPlateVerificationStorage.isVerifiedForRide(rideId);
    if (mounted) setState(() => _plateVerified = localVerified);
  }

  Future<void> _onVerifyPlate() async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null || _plateVerified) return;

    final status = ref.read(rideRequestProvider).status ?? 'assigned';
    final expectedPlate = (_driverInfo?.vehiclePlate ?? '').trim();
    final record = RiderPlateVerificationRecord(
      rideRequestId: rideId,
      driverId: _assignedDriverId,
      expectedPlate: expectedPlate,
      rideStatus: status,
      verifiedAt: DateTime.now().toUtc(),
    );

    await RiderPlateVerificationStorage.save(record);

    final synced = await RiderPlateVerificationService.attestOnServer(
      rideRequestId: rideId,
      expectedPlate: expectedPlate,
    );
    if (synced) {
      await RiderPlateVerificationStorage.removeForRide(rideId);
    }

    if (!mounted) return;

    final colors = ref.read(colorsProvider);
    final l10n = AppLocalizations.of(context);
    setState(() => _plateVerified = true);
    unawaited(HapticService.success());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? l10n.activeRidePlateVerifiedSaved
              : l10n.activeRidePlateVerifiedOffline,
          style: TextStyle(color: colors.text),
        ),
        backgroundColor: colors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  AddressResult _addressFromRouteStop(ActiveRideRouteStop stop) {
    final short = stop.address.split(',').first.trim();
    return AddressResult(
      displayName: short.isEmpty ? stop.address : short,
      fullAddress: stop.address,
      lat: stop.lat,
      lng: stop.lng,
    );
  }

  void _applyActiveRouteFromRow(Map<String, dynamic> row) {
    var route = ActiveRideRouteState.fromRideRow(row);
    if (route.destinationAddress.isEmpty) return;
    if ((route.bookedDestinationAddress == null ||
            route.bookedDestinationAddress!.isEmpty) &&
        route.routeRevision == 0) {
      route = ActiveRideRouteState(
        destinationAddress: route.destinationAddress,
        destinationLat: route.destinationLat,
        destinationLng: route.destinationLng,
        bookedDestinationAddress: route.destinationAddress,
        bookedDestinationLat: route.destinationLat,
        bookedDestinationLng: route.destinationLng,
        stops: route.stops,
        routeRevision: route.routeRevision,
      );
    }

    final destination =
        route.destinationLat != null && route.destinationLng != null
            ? AddressResult(
                displayName: route.destinationAddress.split(',').first.trim(),
                fullAddress: route.destinationAddress,
                lat: route.destinationLat!,
                lng: route.destinationLng!,
              )
            : null;

    if (destination != null) {
      ref.read(bookingProvider.notifier).setDestination(destination);
    }

    if (!mounted) return;
    setState(() {
      _activeRouteState = route;
      _routeStops
        ..clear()
        ..addAll(route.stops.map(_addressFromRouteStop));
    });
  }

  void _applyLiveFare(Map<String, dynamic> row) {
    final cents = HeyCabyRideFare.resolveCentsFromRow(row);
    if (!mounted) return;
    setState(() => _liveFareCents = cents);
  }

  String? _fareDueLabel() {
    if (_liveFareCents != null && _liveFareCents! > 0) {
      return HeyCabyRideFare.formatCentsLabel(_liveFareCents);
    }
    final booking = ref.read(bookingProvider);
    return HeyCabyRideFare.formatEuroLabel(booking.quotedFareEuro);
  }

  Future<void> _refreshFareForCheckout() async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    try {
      final row = await RiderRideSnapshotService.fetch(
        rideRequestId: rideId,
        riderToken: ref.read(rideRequestProvider).riderToken,
      );
      if (!mounted || row == null) return;
      _applyLiveFare(Map<String, dynamic>.from(row));
    } catch (_) {
      // Booking fallback still applies in _fareDueLabel.
    }
  }

  void _maybeNotifyDriverNearPickup({
    required double distanceKm,
    required String status,
  }) {
    if (_driverNearPickupNotified || !mounted) return;
    final enRoute = status == 'driver_en_route' ||
        status == 'accepted' ||
        status == 'assigned' ||
        status == 'driver_found' ||
        _driverOnMyWay;
    if (!enRoute ||
        status == 'driver_arrived' ||
        status == 'arrived' ||
        status == 'in_progress' ||
        distanceKm > 1.0) {
      return;
    }
    _driverNearPickupNotified = true;
    unawaited(HapticService.success());
    final l10n = AppLocalizations.of(context);
    final colors = ref.read(colorsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.near_me_rounded, color: colors.onAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.activeRideDriverAroundCorner,
                style: TextStyle(
                    color: colors.onAccent, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _onRideCompleted() async {
    if (_rideCompletedCheckoutHandled || !mounted) return;
    _rideCompletedCheckoutHandled = true;
    unawaited(HeycabyWidgetSync.clearAll());
    ref.read(rideRequestProvider.notifier).updateStatus('completed');
    unawaited(ref.read(driverTrackingProvider.notifier).refreshNow());
    await _refreshFareForCheckout();

    if (!mounted) return;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.read(bookingProvider);
    final ride = ref.read(rideRequestProvider);
    final rideId = ride.rideRequestId;
    if (rideId == null) {
      _rideCompletedCheckoutHandled = false;
      context.go('/home');
      return;
    }
    final identity = await ref.read(riderIdentityProvider.future);
    if (!mounted) return;
    final result = await showRidePayDriverSheet(
      context,
      colors: colors,
      typography: typo,
      l10n: l10n,
      rideId: rideId,
      riderToken: ride.riderToken ?? identity.riderToken,
      fareLabel: _fareDueLabel(),
      initialMethod:
          RidePaymentMethod.fromBookingMethods(booking.paymentMethods),
    );
    if (!mounted) return;
    if (result == null || !result.confirmed) {
      _rideCompletedCheckoutHandled = false;
      return;
    }
    _tearDownActiveRideSubscriptions();
    await showPostPaymentThankYouThenRate(
      context,
      routeArgs: RatingRouteArgs(
        rideRequestId: rideId,
        riderToken: ride.riderToken ?? identity.riderToken,
        driverInfo: _driverInfo,
      ),
    );
  }

  void _applyWaitingRecord(Map<String, dynamic> row) {
    final parsed = RideWaitingInfo.fromJson(row);
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
      unawaited(
        ref.read(riderRideLifecycleEngineProvider).fanOutFromCurrentState(
              source: 'active_ride_widgets',
            ),
      );
      return;
    }
    if (st == 'assigned' ||
        st == 'accepted' ||
        st == 'driver_found' ||
        st == 'driver_en_route' ||
        st == 'driver_arrived' ||
        st == 'arrived') {
      await HeycabyWidgetSync.refreshInstantDriverFromRide(
        rideId: id,
        pickup: booking.pickup?.displayName ?? '',
        etaMinutes: _estimateEtaMinutes(
          status: st,
          booking: booking,
          driverLocation: ref.read(driverTrackingProvider).valueOrNull,
        ),
      );
      unawaited(
        ref.read(riderRideLifecycleEngineProvider).fanOutFromCurrentState(
              source: 'active_ride_widgets',
            ),
      );
    }
  }

  Future<void> _applyBackendRideRecord(
    RiderRideBackendRecord projection,
  ) async {
    if (!mounted) return;
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null || projection.rideRequestId != rideId) return;

    final revision = '$rideId|${projection.revision}';
    if (_lastBackendRecordRevision == revision) return;
    _lastBackendRecordRevision = revision;

    final row = projection.record;
    _applyWaitingRecord(row);
    _applyLiveFare(row);
    _applyActiveRouteFromRow(row);
    ref.invalidate(taxiTerugQueueStatusProvider(rideId));

    final driverOnMyWay = row['driver_on_my_way'] == true;
    if (driverOnMyWay != _driverOnMyWay && mounted) {
      setState(() => _driverOnMyWay = driverOnMyWay);
    }

    final remoteStatus =
        (row['provider_status'] ?? row['status'])?.toString().toLowerCase();
    if (remoteStatus == null || remoteStatus.isEmpty) return;

    if (_isActiveRideStatus(remoteStatus)) {
      await _loadDriverInfo(rideId);
    }
    if (!mounted) return;

    if (remoteStatus == 'completed') {
      unawaited(_onRideCompleted());
      return;
    }
    if (remoteStatus == 'pending' || remoteStatus == 'bidding') {
      final mode = ref.read(rideRequestProvider).bookingMode ??
          bookingModeStorageString(ref.read(bookingProvider).effectiveRideMode);
      context.go(rideMatchingVariantForBookingModeString(mode).routePath);
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
    if (terminalNoActive.contains(remoteStatus)) {
      unawaited(RiderNotifyLiveActivity.end());
      unawaited(HeycabyWidgetSync.clearAll());
      ref.read(rideRequestProvider.notifier).reset();
      context.go('/home');
      return;
    }

    final updatedAt =
        DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toLocal();
    if (updatedAt == null) return;
    final age = DateTime.now().difference(updatedAt);
    if (age.inMinutes < 2 || _lastStaleStatusMinuteTracked == age.inMinutes) {
      return;
    }
    _lastStaleStatusMinuteTracked = age.inMinutes;
    unawaited(
      RiderNotificationLifecycleService.trackEvent(
        'active_ride_status_snapshot_stale',
        payload: <String, dynamic>{
          'reason': projection.source,
          'ride_request_id': rideId,
          'stale_age_minutes': age.inMinutes,
          'status': remoteStatus,
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final rideId = ref.read(rideRequestProvider).rideRequestId;
      if (rideId != null) {
        ref.read(driverTrackingProvider.notifier).startTracking(rideId);
      }
    }
  }

  void _tearDownActiveRideSubscriptions() {
    _waitingUiTimer?.cancel();
    _waitingUiTimer = null;
    ref.read(driverTrackingProvider.notifier).stopTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tearDownActiveRideSubscriptions();
    super.dispose();
  }

  Future<void> _shareRide(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final colors = ref.read(colorsProvider);
    final shareBox = context.findRenderObject();
    final shareOrigin = shareBox is RenderBox && shareBox.hasSize
        ? shareBox.localToGlobal(Offset.zero) & shareBox.size
        : Rect.fromCenter(
            center: MediaQuery.sizeOf(context).center(Offset.zero),
            width: 1,
            height: 1,
          );
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
      final result = await HeyCabySupabase.client.rpc(
        'fn_rider_create_share_token',
        params: {
          'p_ride_request_id': rideId,
          'p_rider_token': identity.riderToken,
        },
      );

      if (result is! Map || result['ok'] != true) {
        throw StateError('share_not_authorized');
      }
      final shareToken = result['share_token'] as String?;
      if (shareToken == null || shareToken.isEmpty) {
        throw StateError('share_token_missing');
      }
      final shareUrl = '$kAppPublicWebOrigin/track/$shareToken';

      await Share.share(shareUrl, sharePositionOrigin: shareOrigin);
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
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.activeRideShareError,
              style: TextStyle(color: colors.text)),
          backgroundColor: colors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editActiveRoute(BuildContext context) async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    final l10n = AppLocalizations.of(context);
    if (_activeRouteState?.hasPendingRouteChange == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.activeRouteWaitingDriver)),
      );
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.activeRouteEditTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(l10n.activeRouteEditBody),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: Text(l10n.activeRouteChangeDestination),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, 'destination'),
              ),
              ListTile(
                enabled: _routeStops.length < 3,
                leading: const Icon(Icons.add_location_alt_rounded),
                title: Text(l10n.activeRouteAddStop),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, 'stop'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    final selected = await showAddressSearchModal(
      context,
      ref,
      AddressType.destination,
    );
    if (selected == null || !context.mounted) return;
    final currentDestination = ref.read(bookingProvider).destination;
    final destination = action == 'destination' ? selected : currentDestination;
    if (destination == null) return;
    final nextStops = List<AddressResult>.from(_routeStops);
    if (action == 'stop') nextStops.add(selected);
    final priorRoute = _activeRouteState;
    final bookedAddress =
        priorRoute?.bookedDestinationAddress ?? currentDestination?.fullAddress;
    final bookedLat =
        priorRoute?.bookedDestinationLat ?? currentDestination?.lat;
    final bookedLng =
        priorRoute?.bookedDestinationLng ?? currentDestination?.lng;
    try {
      final result = await HeyCabySupabase.client.rpc(
        'fn_rider_update_active_route',
        params: {
          'p_ride_request_id': rideId,
          'p_destination_address': destination.fullAddress,
          'p_destination_lat': destination.lat,
          'p_destination_lng': destination.lng,
          'p_stops': nextStops
              .map((stop) => {
                    'address': stop.fullAddress,
                    'lat': stop.lat,
                    'lng': stop.lng,
                  })
              .toList(growable: false),
        },
      );
      if (result is! Map || result['ok'] != true) {
        final error =
            result is Map ? '${result['error']}' : 'route_update_failed';
        final message = switch (error) {
          'pending_route_change' => l10n.activeRouteWaitingDriver,
          'duplicate_request' => l10n.activeRouteDuplicateRequest,
          'no_change' => l10n.activeRouteNoChange,
          _ => l10n.activeRouteUpdateFailed,
        };
        throw StateError(message);
      }
      final isPending = result['pending'] == true;
      if (isPending) {
        await ref
            .read(riderRideLifecycleEngineProvider)
            .refreshRideState(source: 'active_route_pending');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.activeRouteWaitingDriver)),
        );
        return;
      }
      ref.read(bookingProvider.notifier).setDestination(destination);
      setState(() {
        _routeStops
          ..clear()
          ..addAll(nextStops);
        _activeRouteState = ActiveRideRouteState(
          destinationAddress: destination.fullAddress,
          destinationLat: destination.lat,
          destinationLng: destination.lng,
          bookedDestinationAddress: bookedAddress,
          bookedDestinationLat: bookedLat,
          bookedDestinationLng: bookedLng,
          stops: nextStops
              .map(
                (stop) => ActiveRideRouteStop(
                  address: stop.fullAddress,
                  lat: stop.lat,
                  lng: stop.lng,
                ),
              )
              .toList(growable: false),
          routeRevision: (priorRoute?.routeRevision ?? 0) + 1,
        );
      });
      await ref
          .read(riderRideLifecycleEngineProvider)
          .refreshRideState(source: 'active_route_updated');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.activeRouteUpdated)),
      );
    } catch (e) {
      if (!context.mounted) return;
      final message = e is StateError && e.message.isNotEmpty
          ? e.message
          : l10n.activeRouteUpdateFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _openSafetySheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              0,
              12,
              MediaQuery.of(ctx).padding.bottom + 12,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      l10n.safetySheetTitle,
                      style: typo.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ),
                  _SafetySheetRow(
                    icon: Icons.share_outlined,
                    iconColor: colors.accent,
                    label: l10n.safetySheetShareTrip,
                    subtitle: l10n.safetySheetShareTripSubtitle,
                    colors: colors,
                    typo: typo,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _shareRide(context);
                    },
                  ),
                  _SafetySheetRow(
                    icon: Icons.flag_outlined,
                    iconColor: colors.warning,
                    label: l10n.safetySheetReport,
                    subtitle: l10n.safetySheetReportSubtitle,
                    colors: colors,
                    typo: typo,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      context.push('/report',
                          extra: const ReportRouteArgs(fromActiveRide: true));
                    },
                  ),
                  _SafetySheetRow(
                    icon: Icons.emergency_rounded,
                    iconColor: colors.error,
                    label: l10n.safetySheetEmergency,
                    subtitle: l10n.safetySheetEmergencySubtitle,
                    colors: colors,
                    typo: typo,
                    isEmergency: true,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      unawaited(_logSafetyEvent('emergency_call_112'));
                      launchUrl(Uri.parse('tel:112'));
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(l10n.safetySheetCancel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logSafetyEvent(String eventType) async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    try {
      await HeyCabySupabase.client.rpc(
        'fn_rider_log_safety_event',
        params: {
          'p_ride_request_id': rideId,
          'p_event_type': eventType,
        },
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    ref.listen<RiderRideBackendRecord?>(
      riderRideBackendRecordProvider,
      (previous, next) {
        if (next != null) unawaited(_applyBackendRideRecord(next));
      },
    );
    ref.listen<RideRequestState>(rideRequestProvider, (prev, next) {
      final st = next.status ?? '';
      if (st == 'in_progress' ||
          st == 'assigned' ||
          st == 'accepted' ||
          st == 'driver_found' ||
          st == 'driver_en_route' ||
          st == 'driver_arrived' ||
          st == 'arrived') {
        _syncRidePhaseWidgets();
      }
    });

    // Listen to driver location updates: map marker, widgets, Live Activity ETA.
    ref.listen<AsyncValue<DriverLocation?>>(
      driverTrackingProvider,
      (previous, current) {
        current.whenData((location) async {
          if (location == null) return;
          final ride = ref.read(rideRequestProvider);
          final status = ride.status ?? '';
          final booking = ref.read(bookingProvider);

          if (mounted) {
            final pickup = booking.pickup;
            if (pickup != null) {
              final distToPickup = NearbySupplyService.distanceKm(
                location.lat,
                location.lng,
                pickup.lat,
                pickup.lng,
              );
              _maybeNotifyDriverNearPickup(
                distanceKm: distToPickup,
                status: status,
              );
            }
            setState(() {
              _updateJourneyBaselines(
                status: status,
                booking: booking,
                driverLocation: location,
              );
            });
          }

          if (status == 'in_progress') {
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
            unawaited(
              ref.read(riderRideLifecycleEngineProvider).fanOutFromCurrentState(
                    source: 'active_ride_location',
                  ),
            );
            return;
          }

          if (status == 'assigned' ||
              status == 'accepted' ||
              status == 'driver_found' ||
              status == 'driver_en_route') {
            final eta = _estimateEtaMinutes(
              status: status,
              booking: booking,
              driverLocation: location,
            );
            await HeycabyWidgetSync.syncDriverEnRouteEta(
              etaMinutes: eta,
              pickup: booking.pickup?.displayName ?? '',
            );
            unawaited(
              ref.read(riderRideLifecycleEngineProvider).fanOutFromCurrentState(
                    source: 'active_ride_location',
                  ),
            );
          }
        });
      },
    );

    final ride = ref.watch(rideRequestProvider);
    final driverLocation = ref.watch(driverTrackingProvider).valueOrNull;
    final booking = ref.watch(bookingProvider);
    final status = ride.status ?? 'assigned';
    final taxiTerugQueue = ride.rideRequestId == null
        ? null
        : ref
            .watch(taxiTerugQueueStatusProvider(ride.rideRequestId!))
            .valueOrNull;
    final taxiTerugQueued = taxiTerugQueue?.queuedTaxiTerug == true;
    final etaMinutes = _estimateEtaMinutes(
      status: status,
      booking: booking,
      driverLocation: driverLocation,
    );
    final chatUnreadCount = ride.rideRequestId == null
        ? 0
        : ref.watch(riderRideUnreadMessageCountProvider(ride.rideRequestId!));
    if (ride.rideRequestId != null &&
        _communicationRideId != ride.rideRequestId) {
      _communicationRideId = ride.rideRequestId;
      _communicationPermissions = const MaskedRideCallingService()
          .permissions(rideId: ride.rideRequestId!);
    }

    final screenH = MediaQuery.sizeOf(context).height;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final showMapStatusDock =
        status != 'completed' && _sheetExtent < _kMapDockMaxExtent;
    final showEmbeddedTimeline =
        status != 'completed' && _sheetExtent >= _kEmbeddedTimelineMinExtent;
    final prepayMode = riderPrepayModeFromBackend(
      ride.bookingMode,
      booking.effectiveRideMode,
    );
    final prepayEnabled = riderPrepayVisibleForRideStatus(status) &&
        ride.rideRequestId != null &&
        riderPrepayEnabledForMode(
          riderRuntimeConfig.current,
          prepayMode,
        );

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          ActiveRideMapStack(
            height: screenH,
            cameraBottomPadding: screenH * _sheetExtent + bottomPad + 8,
            booking: booking,
            driverLocation: driverLocation,
            status: status,
            etaMinutes: etaMinutes,
          ),
          if (status != 'completed')
            Positioned(
              left: 16,
              bottom: screenH * _sheetExtent + 16,
              child: _MapSafetyButton(
                colors: colors,
                typo: typo,
                label: l10n.safety,
                onTap: () => _openSafetySheet(context),
              ),
            ),
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              final extent = notification.extent;
              if ((extent - _sheetExtent).abs() > 0.01) {
                setState(() => _sheetExtent = extent);
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: _kSheetCollapsed,
              minChildSize: _kSheetPeek,
              maxChildSize: _kSheetExpanded,
              snap: true,
              snapSizes: const [
                _kSheetPeek,
                _kSheetCollapsed,
                _kSheetExpanded,
              ],
              builder: (context, scrollController) {
                return _ActiveRideSheet(
                  status: status,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                  booking: booking,
                  rideId: ride.rideRequestId,
                  riderToken: ride.riderToken,
                  prepayEnabled: prepayEnabled,
                  prepayMode: prepayMode,
                  scrollController: scrollController,
                  showDetailSections: status == 'completed' ||
                      _sheetExtent >= _kEmbeddedTimelineMinExtent,
                  showEmbeddedTimeline: showEmbeddedTimeline,
                  onComplete: () => context.go('/home'),
                  onShare: () => _shareRide(context),
                  onEditRoute: () => _editActiveRoute(context),
                  routeStops: _routeStops,
                  activeRouteState: _activeRouteState,
                  onSafety: () => _openSafetySheet(context),
                  onPingDriver: () => _openPingDriverSheet(context),
                  onPickupNote: () => context.push('/chat'),
                  communicationPermissions: _communicationPermissions,
                  onMaskedCall: ride.rideRequestId == null
                      ? null
                      : () => _startMaskedDriverCall(ride.rideRequestId!),
                  chatUnreadCount: chatUnreadCount,
                  onCancelRide: status == 'in_progress'
                      ? () => _openEarlyEndFlow(context)
                      : () => _openCancelFlow(context),
                  driverInfo: _driverInfo,
                  etaMinutes: etaMinutes,
                  lastRiderPing: _lastRiderPing,
                  waitingInfo: _waitingInfo,
                  liveFareCents: _liveFareCents,
                  plateVerified: _plateVerified,
                  onVerifyPlate: _onVerifyPlate,
                  taxiTerugQueue: taxiTerugQueued ? taxiTerugQueue : null,
                  driverOnMyWay: _driverOnMyWay,
                  driverLat: driverLocation?.lat,
                  driverLng: driverLocation?.lng,
                  enRouteBaselineKm: _enRouteBaselineKm,
                  tripBaselineKm: _tripBaselineKm,
                );
              },
            ),
          ),
          if (showMapStatusDock)
            Positioned(
              left: 16,
              right: 16,
              bottom: screenH * _sheetExtent + 10,
              child: ActiveRideStatusDock(
                status: status,
                colors: colors,
                typo: typo,
                l10n: l10n,
                etaMinutes: etaMinutes,
                waitingInfo: _waitingInfo,
                quotedFareEuro: booking.quotedFareEuro,
                liveFareCents: _liveFareCents,
                plateVerified: _plateVerified,
                onVerifyPlate: _onVerifyPlate,
                pickupLabel: activeRideShortPlaceLabel(
                  booking.pickup?.displayName,
                  l10n.activeRidePickupNotSet,
                ),
                destinationLabel: activeRideShortPlaceLabel(
                  booking.destination?.displayName,
                  l10n.activeRideDestinationNotSet,
                ),
                taxiTerugQueued: taxiTerugQueued,
                taxiTerugPickupMin: taxiTerugQueue?.pickupAvailableMin,
                taxiTerugPickupMax: taxiTerugQueue?.pickupAvailableMax,
                driverOnMyWay: _driverOnMyWay,
                driverLat: driverLocation?.lat,
                driverLng: driverLocation?.lng,
                pickupLat: booking.pickup?.lat,
                pickupLng: booking.pickup?.lng,
                destLat: booking.destination?.lat,
                destLng: booking.destination?.lng,
                enRouteBaselineKm: _enRouteBaselineKm,
                tripBaselineKm: _tripBaselineKm,
              ),
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
      await HeyCabyRideChatMessages.send(
        rideId: rideId,
        idempotencyKey: HeyCabyRideChatMessages.newIdempotencyKey(),
        content: message,
        messageType: 'ping',
      );
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

  /// Returns cached ETA if available, or null. Triggers async refresh.
  int? _estimateEtaMinutes({
    required String status,
    required BookingState booking,
    required DriverLocation? driverLocation,
  }) {
    if (driverLocation == null) return null;
    final target =
        status == 'in_progress' ? booking.destination : booking.pickup;
    if (target == null || !target.hasValidCoords) return null;
    if (driverLocation.lat == 0 && driverLocation.lng == 0) return null;

    final cacheKey = '$status:${driverLocation.lat.toStringAsFixed(4)},'
        '${driverLocation.lng.toStringAsFixed(4)}:'
        '${target.lat.toStringAsFixed(4)},${target.lng.toStringAsFixed(4)}';
    if (_etaCacheKey == cacheKey) return _cachedEtaMinutes;

    // Cache miss — kick off async fetch, return stale value meanwhile.
    _etaCacheKey = cacheKey;
    unawaited(_refreshEta(status, booking, driverLocation, cacheKey));
    return _cachedEtaMinutes;
  }

  Future<void> _refreshEta(
    String status,
    BookingState booking,
    DriverLocation driverLocation,
    String cacheKey,
  ) async {
    final target =
        status == 'in_progress' ? booking.destination : booking.pickup;
    if (target == null || !target.hasValidCoords) return;

    final eta = await RiderEtaService.etaMinutes(
      fromLat: driverLocation.lat,
      fromLng: driverLocation.lng,
      toLat: target.lat,
      toLng: target.lng,
    );
    if (_etaCacheKey == cacheKey && mounted) {
      _cachedEtaMinutes = eta;
      setState(() {});
    }
  }

  Future<void> _openCancelFlow(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: colors.text.withValues(alpha: 0.48),
      builder: (ctx) => _BoltCancelRideDialog(
        colors: colors,
        typo: typo,
        l10n: l10n,
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final cancelled = await _cancelRideFromActive(l10n.reportOther);
    if (!context.mounted) return;
    if (cancelled) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cancelRideFailed)),
      );
    }
  }

  Future<void> _openEarlyEndFlow(BuildContext context) async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final confirmed = await showHeyCabyConfirmSheet(
      context,
      colors: colors,
      typography: typo,
      title: 'End this trip early?',
      message:
          'This creates a support case and preserves the ride, location, contact, and payment timeline. It does not automatically cancel or refund the trip.',
      dismissLabel: 'Keep riding',
      confirmLabel: 'Request early end',
      icon: Icons.support_agent_rounded,
    );
    if (confirmed != true || !mounted) return;
    final ride = ref.read(rideRequestProvider);
    final rideId = ride.rideRequestId;
    if (rideId == null) return;
    try {
      await const RideVerificationService().openCase(
        rideId: rideId,
        riderToken: ride.riderToken,
        caseType: 'end_trip_early',
        reason: 'Rider requested an early trip end from the active ride screen',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your request is recorded. The ride and payment remain protected while support reviews it.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not create the support case yet. Please try again.',
          ),
        ),
      );
    }
  }

  Future<bool> _cancelRideFromActive(String reason) async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return false;
    try {
      final identity = await ref.read(riderIdentityProvider.future);
      final token = identity.riderToken;
      final cancelled = await cancelExpiredRiderOpenRide(
        rideId: rideId,
        riderToken: token,
        cancellationReason: 'rider_cancelled_from_active:$reason',
      );
      if (!cancelled) return false;
      await RiderNotificationLifecycleService.trackEvent(
        'active_ride_cancelled_by_rider',
        payload: <String, dynamic>{
          'ride_request_id': rideId,
          'reason': reason,
        },
      );
      ref.read(rideRequestProvider.notifier).reset();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _ActiveRideSheet extends StatelessWidget {
  final String status;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final BookingState booking;
  final String? rideId;
  final String? riderToken;
  final bool prepayEnabled;
  final BookingMode prepayMode;
  final ScrollController scrollController;
  final bool showDetailSections;
  final bool showEmbeddedTimeline;
  final VoidCallback onComplete;
  final VoidCallback onShare;
  final VoidCallback onEditRoute;
  final List<AddressResult> routeStops;
  final ActiveRideRouteState? activeRouteState;
  final VoidCallback onSafety;
  final VoidCallback onPingDriver;
  final VoidCallback onPickupNote;
  final Future<RideCommunicationPermissions>? communicationPermissions;
  final VoidCallback? onMaskedCall;
  final int chatUnreadCount;
  final VoidCallback onCancelRide;
  final RiderDriverSheetInfo? driverInfo;
  final int? etaMinutes;
  final String? lastRiderPing;
  final RideWaitingInfo? waitingInfo;
  final int? liveFareCents;
  final bool plateVerified;
  final VoidCallback onVerifyPlate;
  final TaxiTerugQueueStatus? taxiTerugQueue;
  final bool driverOnMyWay;
  final double? driverLat;
  final double? driverLng;
  final double? enRouteBaselineKm;
  final double? tripBaselineKm;

  const _ActiveRideSheet({
    required this.status,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.booking,
    required this.rideId,
    required this.riderToken,
    required this.prepayEnabled,
    required this.prepayMode,
    required this.scrollController,
    required this.showDetailSections,
    required this.showEmbeddedTimeline,
    required this.onComplete,
    required this.onShare,
    required this.onEditRoute,
    required this.routeStops,
    this.activeRouteState,
    required this.onSafety,
    required this.onPingDriver,
    required this.onPickupNote,
    this.communicationPermissions,
    this.onMaskedCall,
    this.chatUnreadCount = 0,
    required this.onCancelRide,
    required this.driverInfo,
    required this.etaMinutes,
    required this.lastRiderPing,
    required this.waitingInfo,
    required this.liveFareCents,
    required this.plateVerified,
    required this.onVerifyPlate,
    this.taxiTerugQueue,
    this.driverOnMyWay = false,
    this.driverLat,
    this.driverLng,
    this.enRouteBaselineKm,
    this.tripBaselineKm,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'completed';
    String paymentLabel() {
      if (booking.paymentMethods.isEmpty) return l10n.pinSubtitle;
      final raw = booking.paymentMethods.first.trim();
      if (raw.isEmpty) return l10n.pinSubtitle;
      if (raw.toLowerCase() == 'pin') return 'PIN';
      return raw
          .split(RegExp(r'[_\s]+'))
          .where((word) => word.isNotEmpty)
          .map(
              (word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');
    }

    String categoryLabel() {
      final cat = booking.vehicleCategory?.trim();
      if (cat == null || cat.isEmpty) return l10n.vehicleStandard;
      return cat[0].toUpperCase() + cat.substring(1);
    }

    String fareLabel() {
      if (liveFareCents != null && liveFareCents! > 0) {
        return HeyCabyRideFare.formatCentsLabel(liveFareCents) ?? '...';
      }
      final quote = booking.quotedFareEuro;
      return HeyCabyRideFare.formatEuroLabel(quote) ?? '...';
    }

    String heroHeadline() {
      if (isCompleted) return l10n.tripComplete;
      if (taxiTerugQueue != null && taxiTerugQueue!.queuedTaxiTerug) {
        return l10n.taxiTerugQueuedConfirmed;
      }
      switch (status) {
        case 'driver_arrived':
        case 'arrived':
          return l10n.activeRideDriverOutside;
        case 'in_progress':
          if (etaMinutes != null) {
            return l10n.activeRideArrivingIn(etaMinutes!.toString());
          }
          return l10n.activeRideTripInProgressHeadline;
        case 'accepted':
        case 'assigned':
        case 'driver_found':
        case 'driver_en_route':
          if (etaMinutes != null) {
            return l10n.activeRidePickupIn(etaMinutes!.toString());
          }
          if (driverOnMyWay || status == 'driver_en_route') {
            return l10n.driverOnTheWay;
          }
          return l10n.activeRideDriverFound;
        default:
          return l10n.activeRideDriverFound;
      }
    }

    String? heroSubtitle() {
      if (isCompleted) return null;
      final name = driverInfo?.fullName.trim();
      if (name != null && name.isNotEmpty) {
        return '$name · ${categoryLabel()}';
      }
      return categoryLabel();
    }

    return GlassPanel(
      colors: colors,
      typography: typo,
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      tintColor: colors.card,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.border.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (taxiTerugQueue != null && taxiTerugQueue!.queuedTaxiTerug) ...[
              const SizedBox(height: 12),
              TaxiTerugQueueBanner(
                status: taxiTerugQueue!,
                colors: colors,
                typo: typo,
                l10n: l10n,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              heroHeadline(),
              style: typo.headingLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.4,
              ),
            ),
            if (heroSubtitle() != null) ...[
              const SizedBox(height: 4),
              Text(
                heroSubtitle()!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.bodyMedium.copyWith(
                  color: colors.textMid,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: driverInfo != null && !isCompleted
                  ? RiderDriverInfoCard(
                      key: ValueKey<String>(
                        '${driverInfo!.vehiclePlate}_${driverInfo!.fullName}',
                      ),
                      driverInfo: driverInfo!,
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                    )
                  : isCompleted
                      ? const SizedBox.shrink()
                      : _DriverCardSkeleton(
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                        ),
            ),
            if (prepayEnabled && rideId != null) ...[
              const SizedBox(height: 12),
              RiderPrepayCard(
                rideId: rideId!,
                riderToken: riderToken,
                mode: prepayMode,
                colors: colors,
                typography: typo,
                l10n: l10n,
              ),
            ],
            if (rideId != null &&
                (status == 'driver_arrived' || status == 'arrived')) ...[
              const SizedBox(height: 12),
              RiderTripPinCard(
                rideId: rideId!,
                riderToken: riderToken,
                colors: colors,
                typography: typo,
              ),
            ],
            if ((status == 'driver_arrived' || status == 'arrived') &&
                !isCompleted &&
                plateVerified) ...[
              const SizedBox(height: 10),
              _ActiveRidePlateVerifyBanner(
                colors: colors,
                typo: typo,
                l10n: l10n,
                verified: plateVerified,
                onVerify: onVerifyPlate,
              ),
            ],
            if (!isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: colors.bgAlt,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: onPickupNote,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            14,
                            12,
                            14,
                            12,
                          ),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: colors.textMid,
                                    size: 20,
                                  ),
                                  if (chatUnreadCount > 0)
                                    Positioned(
                                      right: -6,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.accent,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          chatUnreadCount > 9
                                              ? '9+'
                                              : '$chatUnreadCount',
                                          textAlign: TextAlign.center,
                                          style: typo.labelSmall.copyWith(
                                            color: colors.onAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.activeRidePickupNotes,
                                  style: typo.bodyMedium.copyWith(
                                    color: colors.textMid,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: colors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onPingDriver,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.bolt_rounded,
                          color: colors.onAccent,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (lastRiderPing != null && lastRiderPing!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _LastPingStrip(
                text: l10n.activeRideLastPing(lastRiderPing!),
                colors: colors,
                typo: typo,
              ),
            ],
            if (showEmbeddedTimeline) ...[
              const SizedBox(height: 18),
              ActiveRideStatusDock(
                embeddedInSheet: true,
                status: status,
                colors: colors,
                typo: typo,
                l10n: l10n,
                etaMinutes: etaMinutes,
                waitingInfo: waitingInfo,
                quotedFareEuro: booking.quotedFareEuro,
                liveFareCents: liveFareCents,
                plateVerified: plateVerified,
                onVerifyPlate: onVerifyPlate,
                pickupLabel: activeRideShortPlaceLabel(
                  booking.pickup?.displayName,
                  l10n.activeRidePickupNotSet,
                ),
                destinationLabel: activeRideShortPlaceLabel(
                  booking.destination?.displayName,
                  l10n.activeRideDestinationNotSet,
                ),
                taxiTerugQueued: taxiTerugQueue?.queuedTaxiTerug == true,
                taxiTerugPickupMin: taxiTerugQueue?.pickupAvailableMin,
                taxiTerugPickupMax: taxiTerugQueue?.pickupAvailableMax,
                driverOnMyWay: driverOnMyWay,
                driverLat: driverLat,
                driverLng: driverLng,
                pickupLat: booking.pickup?.lat,
                pickupLng: booking.pickup?.lng,
                destLat: booking.destination?.lat,
                destLng: booking.destination?.lng,
                enRouteBaselineKm: enRouteBaselineKm,
                tripBaselineKm: tripBaselineKm,
              ),
            ],
            if (showDetailSections) ...[
              const SizedBox(height: 18),
              _SectionCard(
                title: l10n.yourRoute,
                rightActionLabel: l10n.tripSummaryEdit,
                onRightAction: onEditRoute,
                colors: colors,
                typo: typo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeRouteState?.hasPendingRouteChange == true) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.warning.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.hourglass_top_rounded,
                                color: colors.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.activeRouteWaitingDriver,
                                style: typo.bodySmall.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (activeRouteState?.hasRouteEdits == true) ...[
                      _RiderRouteEditBadges(
                        colors: colors,
                        typo: typo,
                        l10n: l10n,
                        route: activeRouteState!,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _RouteRow(
                      icon: Icons.place_rounded,
                      iconColor: colors.warning,
                      text: booking.pickup?.fullAddress ??
                          l10n.activeRidePickupNotSet,
                      typo: typo,
                      colors: colors,
                    ),
                    const SizedBox(height: 10),
                    for (final stop in routeStops) ...[
                      _RouteRow(
                        icon: Icons.more_horiz_rounded,
                        iconColor: colors.accent,
                        text: stop.fullAddress,
                        typo: typo,
                        colors: colors,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (activeRouteState?.pendingRouteChange != null)
                      for (final stop
                          in activeRouteState!.pendingRouteChange!.stops.where(
                        (pendingStop) => !routeStops.any(
                          (confirmed) =>
                              confirmed.fullAddress.trim() ==
                              pendingStop.address.trim(),
                        ),
                      )) ...[
                        _RouteRow(
                          icon: Icons.more_horiz_rounded,
                          iconColor: colors.warning,
                          text: stop.address,
                          typo: typo,
                          colors: colors,
                          muted: true,
                          trailingLabel: l10n.activeRoutePendingStop,
                        ),
                        const SizedBox(height: 10),
                      ],
                    _RouteRow(
                      icon: Icons.flag_rounded,
                      iconColor: colors.success,
                      text: booking.destination?.fullAddress ??
                          l10n.activeRideDestinationNotSet,
                      typo: typo,
                      colors: colors,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!isCompleted)
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
                              style:
                                  typo.bodyMedium.copyWith(color: colors.text),
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
              if (!isCompleted) const SizedBox(height: 12),
              _SectionCard(
                title: l10n.chatMoreOptions,
                colors: colors,
                typo: typo,
                child: Column(
                  children: [
                    _MoreActionRow(
                      icon: Icons.shield_outlined,
                      label: l10n.safety,
                      colors: colors,
                      typo: typo,
                      onTap: onSafety,
                    ),
                    const SizedBox(height: 10),
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
                    if (communicationPermissions != null &&
                        onMaskedCall != null)
                      FutureBuilder<RideCommunicationPermissions>(
                        future: communicationPermissions,
                        builder: (context, snapshot) {
                          if (snapshot.data?.canCall != true) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _MoreActionRow(
                              icon: Icons.call_outlined,
                              label: l10n.maskedCallDriver,
                              colors: colors,
                              typo: typo,
                              onTap: onMaskedCall!,
                            ),
                          );
                        },
                      ),
                    if (!isCompleted) ...[
                      const SizedBox(height: 10),
                      _MoreActionRow(
                        icon: Icons.close_rounded,
                        label: status == 'in_progress'
                            ? 'End trip early'
                            : l10n.cancelRide,
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
  final VoidCallback? onRightAction;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.rightActionLabel,
    this.onRightAction,
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
                Semantics(
                  button: true,
                  child: InkWell(
                    onTap: onRightAction,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Text(
                        rightActionLabel!,
                        style: typo.labelMedium.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
  final bool muted;
  final String? trailingLabel;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.typo,
    required this.colors,
    this.muted = false,
    this.trailingLabel,
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
            style: typo.bodyMedium.copyWith(
              color: muted ? colors.textMid : colors.text,
              fontWeight: muted ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        if (trailingLabel != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trailingLabel!,
              style: typo.labelSmall.copyWith(
                color: colors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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

/// Trust-forward placeholder shown while the assigned driver's details load,
/// so the plate/vehicle surface never appears as an empty gap.
class _DriverCardSkeleton extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _DriverCardSkeleton({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.text.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.loading,
                      style: typo.labelSmall.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _bar(double.infinity, 36),
                const SizedBox(height: 8),
                _bar(120, 12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(radius: 18, backgroundColor: colors.accentL),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(100, 11),
                          const SizedBox(height: 6),
                          _bar(72, 9),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 88,
            height: 72,
            decoration: BoxDecoration(
              color: colors.text.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: colors.textSoft.withValues(alpha: 0.6),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRidePlateVerifyBanner extends StatelessWidget {
  const _ActiveRidePlateVerifyBanner({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.verified,
    required this.onVerify,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final bool verified;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    if (verified) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colors.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.activeRidePlateVerifiedSaved,
                style: typo.labelMedium.copyWith(
                  color: colors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: colors.accentL.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: colors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.activeRideVerifyPlate,
              style: typo.bodySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onVerify,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              l10n.activeRideVerifyPlateButton,
              style: typo.labelMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetySheetRow extends StatelessWidget {
  const _SafetySheetRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.typo,
    required this.onTap,
    this.isEmergency = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final bool isEmergency;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: typo.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isEmergency ? iconColor : colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: typo.bodySmall.copyWith(
                        color: colors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: colors.textSoft, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapSafetyButton extends StatelessWidget {
  const _MapSafetyButton({
    required this.colors,
    required this.typo,
    required this.label,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card.withValues(alpha: 0.96),
      elevation: 4,
      shadowColor: colors.text.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, color: colors.text, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiderRouteEditBadges extends StatelessWidget {
  const _RiderRouteEditBadges({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.route,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ActiveRideRouteState route;

  @override
  Widget build(BuildContext context) {
    final badges = <String>[];
    if (route.destinationChanged) {
      badges.add(l10n.activeRouteDestinationChanged);
    }
    if (route.stopCount > 0) {
      badges.add(l10n.activeRouteStopsAdded(route.stopCount));
    }
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in badges)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
            ),
            child: Text(
              label,
              style: typo.labelLarge.copyWith(
                color: colors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _BoltCancelRideDialog extends StatelessWidget {
  const _BoltCancelRideDialog({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: Icon(Icons.close_rounded, color: colors.textSoft),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: colors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.cancelBookingTitle,
              textAlign: TextAlign.center,
              style: typo.titleLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.activeRideCancelConfirmBody,
              textAlign: TextAlign.center,
              style: typo.bodyMedium.copyWith(
                color: colors.textMid,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  l10n.cancelRide,
                  style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.bgAlt,
                  foregroundColor: colors.text,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  l10n.activeRideWaitForDriver,
                  style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
