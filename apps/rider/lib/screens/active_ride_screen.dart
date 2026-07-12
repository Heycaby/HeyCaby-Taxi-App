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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/rating_route_args.dart';
import '../models/ride_matching_variant.dart';
import '../models/ride_waiting_info.dart';
import '../models/taxi_terug_queue_status.dart';
import '../providers/booking_provider.dart';
import '../providers/driver_tracking_provider.dart';
import '../providers/ride_request_provider.dart';
import '../providers/taxi_terug_queue_provider.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/nearby_supply_service.dart';
import '../services/rider_driver_profile_service.dart';
import '../services/rider_notification_lifecycle_service.dart';
import '../services/rider_plate_verification_service.dart';
import '../services/rider_plate_verification_storage.dart';
import '../services/rider_ride_ping_service.dart';
import '../services/rider_ride_lifecycle_engine.dart';
import '../services/stale_ride_cleanup.dart';
import '../widgets/active_ride/active_ride_map_stack.dart';
import '../widgets/active_ride/active_ride_status_dock.dart';
import '../widgets/address_search_modal.dart';
import '../widgets/rider_driver_info_card.dart';
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
  RealtimeChannel? _rideStatusChannel;
  RiderDriverSheetInfo? _driverInfo;
  String? _assignedDriverId;
  bool _plateVerified = false;
  RideWaitingInfo? _waitingInfo;
  Timer? _statusRefreshTimer;
  Timer? _waitingUiTimer;
  int _lastStaleStatusMinuteTracked = -1;
  String? _lastRiderPing;
  int? _liveFareCents;
  final List<AddressResult> _routeStops = [];
  bool _rideCompletedCheckoutHandled = false;
  double _sheetExtent = 0.38;
  bool _driverOnMyWay = false;
  bool _driverNearPickupNotified = false;
  double? _enRouteBaselineKm;
  double? _tripBaselineKm;
  Timer? _pingPollTimer;
  static const _pingService = RiderRidePingService();

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
        unawaited(_loadPlateVerificationState(rideId));
        unawaited(RiderPlateVerificationService.syncPendingQueue());
        ref.invalidate(taxiTerugQueueStatusProvider(rideId));
        unawaited(_refreshDriverOnMyWay(rideId));
        _startPingPollTimer(rideId);
      }
      _startStatusRefreshTimer();
      _startWaitingUiTimer();
      _syncRidePhaseWidgets();
    });
  }

  void _startPingPollTimer(String rideId) {
    _pingPollTimer?.cancel();
    _pingPollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_refreshDriverOnMyWay(rideId));
    });
  }

  Future<void> _refreshDriverOnMyWay(String rideId) async {
    final ride = ref.read(rideRequestProvider);
    final identity = await ref.read(riderIdentityProvider.future);
    final onWay = await _pingService.driverOnMyWay(
      rideId,
      riderToken: ride.riderToken ?? identity.riderToken,
    );
    if (!mounted) return;
    if (onWay != _driverOnMyWay) {
      setState(() => _driverOnMyWay = onWay);
    }
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
      if (!mounted) return;
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

  Future<void> _loadWaitingInfo(String rideId) async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'driver_arrived_at, waiting_grace_seconds, waiting_rate_per_minute, chargeable_wait_seconds, waiting_fee_cents, waiting_fee_waived, quoted_fare, offered_fare, estimated_fare, final_fare, marketplace_offered_fare',
          )
          .eq('id', rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      _applyWaitingRecord(Map<String, dynamic>.from(row));
      _applyLiveFare(Map<String, dynamic>.from(row));
    } catch (_) {
      // Older environments may not have the waiting-fee contract yet.
    }
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
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'quoted_fare, offered_fare, estimated_fare, final_fare, marketplace_offered_fare, waiting_fee_cents, waiting_fee_waived',
          )
          .eq('id', rideId)
          .maybeSingle();
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
    _pauseBackgroundPolling();
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
      _startStatusRefreshTimer();
      _startPingPollTimer(rideId);
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
    unawaited(
      ref.read(riderRideLifecycleEngineProvider).applyBackendRecord(
            row,
            source: 'active_ride_waiting',
          ),
    );
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
            _applyLiveFare(Map<String, dynamic>.from(payload.newRecord));
            final rideId = ref.read(rideRequestProvider).rideRequestId;
            if (rideId != null) {
              ref.invalidate(taxiTerugQueueStatusProvider(rideId));
              unawaited(_refreshDriverOnMyWay(rideId));
            }
            if (newStatus == null) return;
            ref.read(rideRequestProvider.notifier).updateStatus(newStatus);
            if (rideId != null &&
                (newStatus == 'assigned' ||
                    newStatus == 'accepted' ||
                    newStatus == 'driver_found' ||
                    newStatus == 'driver_en_route' ||
                    newStatus == 'driver_arrived' ||
                    newStatus == 'arrived' ||
                    newStatus == 'in_progress')) {
              _loadDriverInfo(rideId);
            }
            if (newStatus == 'completed' && mounted) {
              unawaited(_onRideCompleted());
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
              unawaited(HeycabyWidgetSync.clearAll());
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
      const Duration(seconds: 10),
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
            'status, updated_at, driver_arrived_at, waiting_grace_seconds, waiting_rate_per_minute, chargeable_wait_seconds, waiting_fee_cents, waiting_fee_waived, quoted_fare, offered_fare, estimated_fare, final_fare, marketplace_offered_fare',
          )
          .eq('id', rideId)
          .maybeSingle();
      if (row == null) return;
      _applyWaitingRecord(Map<String, dynamic>.from(row));
      _applyLiveFare(Map<String, dynamic>.from(row));
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
      // Handle terminal statuses from periodic poll (backup for realtime).
      const terminalNoActive = {
        'cancelled',
        'canceled',
        'rejected',
        'declined',
        'missed',
        'expired',
      };
      if (terminalNoActive.contains(remoteStatus) && mounted) {
        unawaited(HeycabyWidgetSync.clearAll());
        ref.read(rideRequestProvider.notifier).reset();
        context.go('/home');
        return;
      }
      if (remoteStatus == 'completed' && mounted) {
        unawaited(_onRideCompleted());
        return;
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

  void _pauseBackgroundPolling() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = null;
    _pingPollTimer?.cancel();
    _pingPollTimer = null;
  }

  void _tearDownActiveRideSubscriptions() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = null;
    _waitingUiTimer?.cancel();
    _waitingUiTimer = null;
    _pingPollTimer?.cancel();
    _pingPollTimer = null;
    _rideStatusChannel?.unsubscribe();
    _rideStatusChannel = null;
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
        throw StateError(
            result is Map ? '${result['error']}' : 'route_update_failed');
      }
      ref.read(bookingProvider.notifier).setDestination(destination);
      setState(() {
        _routeStops
          ..clear()
          ..addAll(nextStops);
      });
      await _refreshRideStatus(reason: 'route_updated');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.activeRouteUpdated)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.activeRouteUpdateFailed)),
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
      await HeyCabySupabase.client.from('safety_events').insert({
        'ride_request_id': rideId,
        'event_type': eventType,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
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

    final screenH = MediaQuery.sizeOf(context).height;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          ActiveRideMapStack(
            height: screenH,
            cameraBottomPadding: screenH * 0.40 + bottomPad,
            booking: booking,
            driverLocation: driverLocation,
            status: status,
            etaMinutes: etaMinutes,
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
              initialChildSize: 0.38,
              minChildSize: 0.28,
              maxChildSize: 0.88,
              snap: true,
              snapSizes: const [0.38, 0.88],
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
                  onEditRoute: () => _editActiveRoute(context),
                  routeStops: _routeStops,
                  onSafety: () => _openSafetySheet(context),
                  onPingDriver: () => _openPingDriverSheet(context),
                  onPickupNote: () => context.push('/chat'),
                  onCancelRide: () => _openCancelFlow(context),
                  driverInfo: _driverInfo,
                  etaMinutes: etaMinutes,
                  lastRiderPing: _lastRiderPing,
                  waitingInfo: _waitingInfo,
                  liveFareCents: _liveFareCents,
                  plateVerified: _plateVerified,
                  onVerifyPlate: _onVerifyPlate,
                  taxiTerugQueue: taxiTerugQueued ? taxiTerugQueue : null,
                );
              },
            ),
          ),
          if (status != 'completed')
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

    final confirmed = await showHeyCabyConfirmSheet(
      context,
      colors: ref.read(colorsProvider),
      typography: ref.read(typographyProvider),
      title: l10n.cancelBookingTitle,
      message: l10n.activeRideCancelConfirmBody,
      dismissLabel: l10n.activeRideWaitForDriver,
      confirmLabel: l10n.cancelRide,
      icon: Icons.close_rounded,
      confirmDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final cancelled = await _cancelRideFromActive(reason);
    if (!context.mounted) return;
    if (cancelled) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cancelRideFailed)),
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
  final ScrollController scrollController;
  final VoidCallback onComplete;
  final VoidCallback onShare;
  final VoidCallback onEditRoute;
  final List<AddressResult> routeStops;
  final VoidCallback onSafety;
  final VoidCallback onPingDriver;
  final VoidCallback onPickupNote;
  final VoidCallback onCancelRide;
  final RiderDriverSheetInfo? driverInfo;
  final int? etaMinutes;
  final String? lastRiderPing;
  final RideWaitingInfo? waitingInfo;
  final int? liveFareCents;
  final bool plateVerified;
  final VoidCallback onVerifyPlate;
  final TaxiTerugQueueStatus? taxiTerugQueue;

  const _ActiveRideSheet({
    required this.status,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.booking,
    required this.scrollController,
    required this.onComplete,
    required this.onShare,
    required this.onEditRoute,
    required this.routeStops,
    required this.onSafety,
    required this.onPingDriver,
    required this.onPickupNote,
    required this.onCancelRide,
    required this.driverInfo,
    required this.etaMinutes,
    required this.lastRiderPing,
    required this.waitingInfo,
    required this.liveFareCents,
    required this.plateVerified,
    required this.onVerifyPlate,
    this.taxiTerugQueue,
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

    String heroTitle() {
      if (isCompleted) return l10n.tripComplete;
      final name = driverInfo?.fullName.trim();
      if (name != null && name.isNotEmpty) return name;
      return l10n.driver;
    }

    String? heroSubtitle() {
      if (isCompleted) return null;
      if (status == 'driver_arrived' || status == 'arrived') {
        return l10n.activeRideVerifiedTaxi;
      }
      if (status == 'in_progress') {
        return booking.destination?.displayName.split(',').first;
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
              heroTitle(),
              style: typo.headingLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
                height: 1.15,
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
                  fontWeight: FontWeight.w500,
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
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: colors.textMid,
                                size: 20,
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
