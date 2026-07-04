import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_map/heycaby_map.dart';
import '../providers/active_search_provider.dart';
import '../providers/location_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/near_term_ride_request_provider.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/rider_notify_search_notifications.dart';
import '../services/location_service.dart';
import '../services/nearby_supply_service.dart';
import '../services/rider_runtime_config_service.dart';
import '../services/sound_service.dart';
import '../services/stale_ride_cleanup.dart';
import '../utils/map_style_helper.dart';
import '../constants/rider_search_window.dart';
import '../widgets/driver_search_expired_dialog.dart';
import '../widgets/active_booking_card.dart';
import '../widgets/home/home_bottom_sheet.dart';
import '../widgets/home/home_map_overlay.dart';
import '../widgets/rider_preride_home_banner.dart';
import '../widgets/welcome_profile_modals.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;
  int _nearbyTaxiCount = 0;
  late final DraggableScrollableController _sheetController;
  Timer? _notifyExpiryTimer;
  DateTime? _notifyExpiryScheduledFor;
  Timer? _globalSearchExpiryTimer;
  bool _globalExpiryModalShowing = false;
  Timer? _welcomeProfileTimer;
  Timer? _notifyWidgetSyncTimer;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).refreshIfPermitted();
      _welcomeProfileTimer = Timer(const Duration(seconds: 3), () {
        unawaited(
          maybePresentWelcomeProfileFlow(context: context, ref: ref),
        );
      });
    });
  }

  @override
  void dispose() {
    _welcomeProfileTimer?.cancel();
    _notifyWidgetSyncTimer?.cancel();
    _notifyExpiryTimer?.cancel();
    _globalSearchExpiryTimer?.cancel();
    _sheetController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(riderRuntimeConfig.refresh());
      unawaited(ref.read(activeSearchProvider.notifier).expireIfStale());
      unawaited(_enforceGlobalSearchWindow());
    }
  }

  void _armNotifyWidgetSync(ActiveNotifySearch? s) {
    _notifyWidgetSyncTimer?.cancel();
    _notifyWidgetSyncTimer = null;
    if (s == null) return;
    void push() {
      unawaited(
        HeycabyWidgetSync.syncNotifyBackgroundSearch(
          pickup: s.pickupSummary ?? '',
          destination: s.destinationSummary ?? '',
          startedAt: s.startedAt,
        ),
      );
      unawaited(
        RiderNotifySearchNotifications.showOrUpdate(
          pickupSummary: s.pickupSummary ?? '',
          destinationSummary: s.destinationSummary ?? '',
          startedAt: s.startedAt,
        ),
      );
    }

    push();
    _notifyWidgetSyncTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => push());
  }

  void _scheduleNotifyExpiryFrom(DateTime startedAt) {
    if (_notifyExpiryScheduledFor == startedAt && _notifyExpiryTimer != null) {
      return;
    }
    _notifyExpiryScheduledFor = startedAt;
    _notifyExpiryTimer?.cancel();
    final limit = kRiderDriverSearchWindow;
    final left = limit - DateTime.now().difference(startedAt);
    if (left <= Duration.zero) {
      unawaited(_onNotifySearchWindowEnded());
      return;
    }
    _notifyExpiryTimer = Timer(left, _onNotifySearchWindowEnded);
  }

  Future<void> _onNotifySearchWindowEnded() async {
    if (!mounted) return;
    await ref.read(activeSearchProvider.notifier).clear();
    unawaited(SoundService().playRideCancelled());
    if (!mounted) return;
    if (await ref
        .read(activeSearchProvider.notifier)
        .isGrowthModalDismissed()) {
      return;
    }
    if (!mounted) return;
    await showDriverSearchExpiredDialog(
      context,
      ref,
      markGrowthModalDismissedAfter: true,
    );
  }

  Future<void> _enforceGlobalSearchWindow() async {
    if (!mounted) return;
    final identity = await ref.read(riderIdentityProvider.future);
    final token = identity.riderToken;
    if (!identity.hasSession || token == null || token.isEmpty) return;

    final now = DateTime.now();
    bool cancelledAny = false;
    try {
      final rows = await HeyCabySupabase.client
          .from('ride_requests')
          .select('id, created_at')
          .eq('rider_token', token)
          .inFilter('status', ['pending', 'bidding'])
          .order('created_at', ascending: false)
          .limit(25);
      for (final raw in (rows as List<dynamic>)) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id'] as String?;
        if (id == null) continue;
        final created = DateTime.tryParse((m['created_at'] ?? '').toString());
        if (created == null) continue;
        if (now.difference(created) <= kRiderDriverSearchWindow) continue;
        await cancelExpiredRiderOpenRide(rideId: id, riderToken: token);
        cancelledAny = true;
      }
    } catch (_) {
      return;
    }

    if (!mounted || !cancelledAny || _globalExpiryModalShowing) return;
    unawaited(SoundService().playRideCancelled());
    _globalExpiryModalShowing = true;
    try {
      await showDriverSearchExpiredDialog(
        context,
        ref,
        markGrowthModalDismissedAfter: false,
      );
    } finally {
      _globalExpiryModalShowing = false;
    }
  }

  void _armGlobalSearchExpiryTimer(List<NearTermRideSnapshot> rides) {
    _globalSearchExpiryTimer?.cancel();
    final now = DateTime.now();
    DateTime? soonestExpiry;
    for (final r in rides) {
      final expiry = r.createdAt.add(kRiderDriverSearchWindow);
      if (!expiry.isAfter(now)) continue;
      if (soonestExpiry == null || expiry.isBefore(soonestExpiry)) {
        soonestExpiry = expiry;
      }
    }
    if (soonestExpiry == null) return;
    final left = soonestExpiry.difference(now);
    if (left <= Duration.zero) {
      unawaited(_enforceGlobalSearchWindow());
      return;
    }
    _globalSearchExpiryTimer = Timer(left, () {
      unawaited(_enforceGlobalSearchWindow());
    });
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    await Future.wait([
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.compass.updateSettings(CompassSettings(enabled: false)),
      map.attribution.updateSettings(AttributionSettings(enabled: false)),
      map.logo.updateSettings(LogoSettings(enabled: false)),
    ]);

    await _mapboxMap!.setBounds(
      CameraBoundsOptions(
        bounds: CoordinateBounds(
          southwest: Point(coordinates: Position(3.31, 50.75)),
          northeast: Point(coordinates: Position(7.23, 53.55)),
          infiniteBounds: false,
        ),
        minZoom: 7.0,
        maxZoom: 18.0,
      ),
    );

    _annotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_mapboxMap == null) return;

    await _mapboxMap!.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF00A651,
      pulsingMaxRadius: 40.0,
      showAccuracyRing: true,
      accuracyRingColor: 0x2200A651,
    ));

    await _flyToUserLocation();
  }

  Future<void> _flyToUserLocation() async {
    final loc = ref.read(locationProvider).valueOrNull;
    if (loc == null || _mapboxMap == null) return;

    if (!LocationService.isInNetherlands(loc.latitude, loc.longitude)) {
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(4.9041, 52.3676)),
          zoom: 16.0,
        ),
        MapAnimationOptions(duration: 800),
      );
      if (kDebugMode) {
        debugPrint('Location outside Netherlands bounds — not flying to it');
      }
      return;
    }

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(loc.longitude, loc.latitude)),
        zoom: 16.0,
        pitch: 0.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 800),
    );

    await _addNearbyTaxiMarkers(loc.latitude, loc.longitude);
    await _fetchNearbyTaxiCount(loc.latitude, loc.longitude);
    await _reverseGeocodeLocation(loc.latitude, loc.longitude);
    if (mounted) setState(() {});
  }

  Future<void> _addNearbyTaxiMarkers(double lat, double lng) async {
    if (_annotationManager == null) return;

    // Clear existing annotations
    await _annotationManager!.deleteAll();

    // Fetch nearby taxi count and add markers (not the user location - that's handled by the blue GPS dot)
    await _fetchNearbyTaxiCount(lat, lng);
  }

  Future<void> _fetchNearbyTaxiCount(double lat, double lng) async {
    try {
      final pickup = AddressResult(
        displayName: '',
        fullAddress: '',
        lat: lat,
        lng: lng,
      );
      final snapshots = await NearbySupplyService.loadForPickup(pickup: pickup);
      final count = snapshots.values.fold<int>(
        0,
        (sum, snapshot) => sum + snapshot.driverCount,
      );

      if (mounted) {
        setState(() {
          _nearbyTaxiCount = count;
        });
      }
    } catch (e) {
      // Error fetching taxi count
      if (mounted) {
        setState(() {
          _nearbyTaxiCount = 0;
        });
      }
    }
  }

  Future<void> _reverseGeocodeLocation(double lat, double lng) async {
    // Guard: Validate coordinates are within Netherlands bounding box
    // Netherlands bounds: lat 50.75–53.55, lng 3.31–7.23
    final bool isInNetherlands =
        lat >= 50.75 && lat <= 53.55 && lng >= 3.31 && lng <= 7.23;

    if (!isInNetherlands) {
      // GPS location outside Netherlands - skip auto-fill
      // This handles simulator fake locations, VPN, or travelers
      if (kDebugMode) {
        debugPrint(
            'GPS location outside Netherlands bounds — skipping auto-fill');
      }
      return;
    }

    try {
      final geo = ref.read(geocodingServiceProvider);
      final address = await geo.reverseGeocode(lat: lat, lng: lng);

      if (mounted && address != null) {
        ref.read(bookingProvider.notifier).setPickup(address);
      }
    } catch (e) {
      // Error reverse geocoding
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    ref.listen<AsyncValue<ActiveNotifySearch?>>(activeSearchProvider,
        (prev, next) {
      final s = next.valueOrNull;
      if (s != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _armNotifyWidgetSync(s);
          if (_sheetController.isAttached) {
            unawaited(
              _sheetController.animateTo(
                0.68,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              ),
            );
          }
          _scheduleNotifyExpiryFrom(s.startedAt);
        });
      } else {
        _notifyWidgetSyncTimer?.cancel();
        _notifyWidgetSyncTimer = null;
        _notifyExpiryTimer?.cancel();
        _notifyExpiryScheduledFor = null;
      }
    });

    final upcoming =
        ref.watch(ridesTabUpcomingRequestsProvider).valueOrNull ?? const [];
    if (upcoming.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _armGlobalSearchExpiryTimer(upcoming);
      });
    } else {
      _globalSearchExpiryTimer?.cancel();
    }

    final activeSchedule = ref.watch(activeSearchProvider).valueOrNull;
    if (activeSchedule != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleNotifyExpiryFrom(activeSchedule.startedAt);
      });
    }

    ref.listen(locationProvider, (_, next) {
      next.whenData((pos) {
        if (pos != null) unawaited(_flyToUserLocation());
      });
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          MapWidget(
            styleUri: mapStyleForTheme(ref.watch(themeProvider).id),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(4.9041, 52.3676)),
              zoom: 16.0,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),
          HomeMapOverlay(
            colors: colors,
            typo: typo,
            onLocate: () => unawaited(_flyToUserLocation()),
          ),
          _RiderMapCenterPin(
            colors: colors,
            typo: typo,
            label: l10n.pickup,
          ),
          HomeBottomSheet(
            colors: colors,
            typo: typo,
            l10n: l10n,
            sheetController: _sheetController,
            nearbyTaxiCount: _nearbyTaxiCount,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.sizeOf(context).height * 0.29,
            child: const ActiveBookingCard(),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: const RiderPrerideHomeBanner(),
          ),
        ],
      ),
    );
  }
}

class _RiderMapCenterPin extends StatefulWidget {
  const _RiderMapCenterPin({
    required this.colors,
    required this.typo,
    required this.label,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;

  @override
  State<_RiderMapCenterPin> createState() => _RiderMapCenterPinState();
}

class _RiderMapCenterPinState extends State<_RiderMapCenterPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomOffset = MediaQuery.sizeOf(context).height * 0.18;
    return IgnorePointer(
      child: Center(
        child: Transform.translate(
          offset: Offset(0, -bottomOffset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PickupPinLabel(
                colors: widget.colors,
                typo: widget.typo,
                label: widget.label,
              ),
              const SizedBox(height: 7),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final t = Curves.easeOutCubic.transform(
                    _pulseController.value,
                  );
                  final bob = -2.5 +
                      (Curves.easeInOutSine.transform(
                            (_pulseController.value * 2) % 1,
                          ) *
                          5);
                  return Transform.translate(
                    offset: Offset(0, bob),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned(
                            top: 26,
                            child: Transform.scale(
                              scale: 0.72 + (t * 0.62),
                              child: Opacity(
                                opacity: (0.32 * (1 - t)).clamp(0.0, 0.32),
                                child: Container(
                                  width: 54,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.colors.accent,
                                    border: Border.all(
                                      color: widget.colors.accent
                                          .withValues(alpha: 0.32),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 42,
                            child: Transform.scale(
                              scale: 0.9 + (t * 0.2),
                              child: Opacity(
                                opacity: (0.18 * (1 - t)).clamp(0.0, 0.18),
                                child: Container(
                                  width: 30,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.colors.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: const Size(42, 54),
                            painter: _RiderPinPainter(
                              fill: widget.colors.accent,
                              border: widget.colors.onAccent,
                              shadow: widget.colors.text.withValues(
                                alpha: 0.18,
                              ),
                              pulse: t,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupPinLabel extends StatelessWidget {
  const _PickupPinLabel({
    required this.colors,
    required this.typo,
    required this.label,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.my_location_rounded,
            color: colors.accent,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: typo.labelMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderPinPainter extends CustomPainter {
  const _RiderPinPainter({
    required this.fill,
    required this.border,
    required this.shadow,
    required this.pulse,
  });

  final Color fill;
  final Color border;
  final Color shadow;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.68,
        0,
        size.height * 0.50,
        0,
        size.height * 0.30,
      )
      ..cubicTo(0, size.height * 0.12, size.width * 0.17, 0, size.width / 2, 0)
      ..cubicTo(size.width * 0.83, 0, size.width, size.height * 0.12,
          size.width, size.height * 0.30)
      ..cubicTo(
        size.width,
        size.height * 0.50,
        size.width * 0.80,
        size.height * 0.68,
        size.width / 2,
        size.height,
      )
      ..close();

    canvas.drawShadow(path, shadow, 8, true);
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.31),
      size.width * (0.17 + pulse * 0.025),
      Paint()
        ..color = border.withValues(alpha: 0.92 - pulse * 0.2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.31),
      size.width * (0.29 + pulse * 0.12),
      Paint()
        ..color = border.withValues(alpha: 0.13 * (1 - pulse))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _RiderPinPainter oldDelegate) {
    return fill != oldDelegate.fill ||
        border != oldDelegate.border ||
        shadow != oldDelegate.shadow ||
        pulse != oldDelegate.pulse;
  }
}
