import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_map/heycaby_map.dart';
import '../providers/active_search_provider.dart';
import '../providers/location_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/recent_destinations_provider.dart';
import '../providers/near_term_ride_request_provider.dart';
import '../services/booking_flow_navigation.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/rider_notify_search_notifications.dart';
import '../services/location_service.dart';
import '../services/rider_runtime_config_service.dart';
import '../services/sound_service.dart';
import '../services/stale_ride_cleanup.dart';
import '../utils/map_style_helper.dart';
import '../constants/rider_search_window.dart';
import '../widgets/active_notify_search_card.dart';
import '../widgets/active_search_stop_dialog.dart';
import '../widgets/booking_draft_resume_card.dart';
import '../widgets/near_term_ride_home_banner.dart';
import '../widgets/rider_preride_home_banner.dart';
import '../widgets/driver_search_expired_dialog.dart';
import '../widgets/home/home_destination_section.dart';
import '../widgets/home/home_popular_airports_section.dart';
import '../widgets/home/home_smart_options_section.dart';
import '../widgets/rider_profile_home_nudge.dart';
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
  String? _currentAddress;
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
    if (await ref.read(activeSearchProvider.notifier).isGrowthModalDismissed()) {
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
        final created =
            DateTime.tryParse((m['created_at'] ?? '').toString());
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

    _annotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_mapboxMap == null) return;

    await _mapboxMap!.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF4285F4,
      pulsingMaxRadius: 40.0,
      showAccuracyRing: true,
      accuracyRingColor: 0x224285F4,
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
      if (kDebugMode) debugPrint('Location outside Netherlands bounds — not flying to it');
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
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://heycaby.nl',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final token = HeyCabySupabase.client.auth.currentSession?.accessToken;
      if (token != null && token.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/rider/nearby-supply',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final count = (response.data?['count'] as num?)?.toInt() ??
          ((response.data?['drivers'] as List?)?.length ?? 0);

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
    final bool isInNetherlands = lat >= 50.75 && lat <= 53.55 &&
                                 lng >= 3.31  && lng <= 7.23;

    if (!isInNetherlands) {
      // GPS location outside Netherlands - skip auto-fill
      // This handles simulator fake locations, VPN, or travelers
      if (kDebugMode) debugPrint('GPS location outside Netherlands bounds — skipping auto-fill');
      return;
    }

    try {
      final geo = ref.read(geocodingServiceProvider);
      final address = await geo.reverseGeocode(lat: lat, lng: lng);
      
      if (mounted && address != null) {
        setState(() {
          _currentAddress = address.displayName;
        });
        
        // Auto-fill pickup address
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

    ref.listen<AsyncValue<ActiveNotifySearch?>>(activeSearchProvider, (prev, next) {
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

    final upcoming = ref.watch(ridesTabUpcomingRequestsProvider).valueOrNull ?? const [];
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
          // Centered user pin + zone card
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentAddress != null)
                  GestureDetector(
                    onTap: () => context.go('/search'),
                    child: GlassPanel(
                      colors: colors,
                      typography: typo,
                      borderRadius: BorderRadius.circular(999),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_taxi,
                            color: colors.text,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _nearbyTaxiCount == 0
                                ? l10n.noTaxisInZone
                                : _nearbyTaxiCount == 1
                                    ? l10n.oneTaxiInZone
                                    : l10n.taxisInZone(_nearbyTaxiCount),
                            style: typo.bodyMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent,
                    border: Border.all(
                      color: colors.card,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _BottomSheet(
            colors: colors,
            typo: typo,
            l10n: l10n,
            currentAddress: _currentAddress,
            sheetController: _sheetController,
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

class _BottomSheet extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String? currentAddress;
  final DraggableScrollableController sheetController;

  const _BottomSheet({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.sheetController,
    this.currentAddress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSearchProvider).valueOrNull;

    return DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: 0.55,
      minChildSize: 0.30,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.30, 0.55, 0.85],
      builder: (_, controller) => GlassPanel(
        colors: colors,
        typography: typo,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        padding: EdgeInsets.zero,
        child: ListView(
          controller: controller,
          padding: EdgeInsets.zero,
          children: [
            _DragHandle(colors: colors),
            if (active != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
                child: ActiveNotifySearchCard(
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                  startedAt: active.startedAt,
                  bookingMode: active.bookingMode,
                  pickupSummary: active.pickupSummary,
                  destinationSummary: active.destinationSummary,
                  onClosePressed: () async {
                    final stop = await showActiveSearchStopDialog(
                      context: context,
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                    );
                    if (!context.mounted) return;
                    if (stop) {
                      await ref
                          .read(activeSearchProvider.notifier)
                          .stopSearchAndCancelRide();
                    }
                  },
                ),
              ),
            const BookingDraftResumeCard(),
            if (active == null) const NearTermRideHomeBanner(),
            HomeDestinationSection(colors: colors, typo: typo, l10n: l10n),
            HomeSmartOptionsSection(colors: colors, typo: typo, l10n: l10n),
            HomePopularAirportsSection(colors: colors, typo: typo, l10n: l10n),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 0),
              child: _RecentDestinationsSection(
                colors: colors,
                typo: typo,
                l10n: l10n,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: RiderProfileHomeNudge(),
            ),
            // Keep the last card fully above RiderShell bottom navigation.
            SizedBox(
              height: kBottomNavigationBarHeight +
                  MediaQuery.paddingOf(context).bottom +
                  16,
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  final HeyCabyColorTokens colors;

  const _DragHandle({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

const int _kRecentDestinationsCollapsedCount = 2;

class _RecentDestinationsSection extends ConsumerStatefulWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _RecentDestinationsSection({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  ConsumerState<_RecentDestinationsSection> createState() =>
      _RecentDestinationsSectionState();
}

class _RecentDestinationsSectionState
    extends ConsumerState<_RecentDestinationsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final recentAsync = ref.watch(recentDestinationsProvider);
    final colors = widget.colors;
    final typo = widget.typo;
    final l10n = widget.l10n;

    return recentAsync.when(
      data: (destinations) {
        if (destinations.isEmpty) return const SizedBox.shrink();

        final total = destinations.length;
        final hasMore = total > _kRecentDestinationsCollapsedCount;
        final visibleCount =
            !hasMore || _expanded ? total : _kRecentDestinationsCollapsedCount;
        final visible = destinations.take(visibleCount).toList();
        final hiddenCount = total - _kRecentDestinationsCollapsedCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
              child: Text(
                l10n.homeRecentTrips,
                style: typo.bodySmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...visible.map((dest) => _RecentDestinationTile(
                  destination: dest,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                  onTap: () async {
                    ref.read(bookingProvider.notifier).setDestination(
                          AddressResult(
                            displayName:
                                dest.fullAddress.split(',').first,
                            fullAddress: dest.fullAddress,
                            lat: dest.lat,
                            lng: dest.lng,
                          ),
                        );
                    await BookingFlowNavigation.prefillBookingFromIdentity(
                        ref);
                    if (!context.mounted) return;
                    final next =
                        BookingFlowNavigation.routeAfterAddressesComplete(
                      ref.read(bookingProvider),
                    );
                    context.push(next);
                  },
                )),
            if (hasMore)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 4, start: 2),
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 22,
                    color: colors.accent,
                  ),
                  label: Text(
                    _expanded
                        ? l10n.recentDestinationsShowLess
                        : l10n.recentDestinationsShowMore(hiddenCount),
                    style: typo.labelLarge.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: AlignmentDirectional.centerStart,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentDestinationTile extends ConsumerWidget {
  final RecentDestination destination;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _RecentDestinationTile({
    required this.destination,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey<String>('recent_dest_${destination.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.35,
      },
      confirmDismiss: (direction) async {
        final ok = await ref
            .read(recentDestinationsProvider.notifier)
            .removeDestination(destination.id);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.recentDestinationRemoveFailed)),
          );
        }
        return ok;
      },
      background: Container(
        margin: const EdgeInsetsDirectional.only(bottom: 8),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Semantics(
          label: l10n.recentDestinationRemoveHint,
          child: Icon(Icons.delete_outline_rounded, color: colors.onError, size: 26),
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsetsDirectional.only(bottom: 8),
          padding: const EdgeInsetsDirectional.all(12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.history, color: colors.textSoft, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.fullAddress,
                  style: typo.bodyMedium.copyWith(color: colors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSoft, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
