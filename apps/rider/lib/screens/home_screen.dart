import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_map/heycaby_map.dart';
import '../providers/active_search_provider.dart';
import '../providers/location_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/recent_destinations_provider.dart';
import '../services/booking_flow_navigation.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/rider_notify_search_notifications.dart';
import '../services/location_service.dart';
import '../utils/map_style_helper.dart';
import '../constants/rider_search_window.dart';
import '../providers/saved_addresses_provider.dart';
import '../widgets/active_notify_search_card.dart';
import '../widgets/active_search_stop_dialog.dart';
import '../widgets/booking_draft_resume_card.dart';
import '../widgets/near_term_ride_home_banner.dart';
import '../widgets/rider_preride_home_banner.dart';
import '../widgets/driver_search_expired_dialog.dart';
import '../widgets/email_modal.dart';
import '../widgets/rider_profile_home_nudge.dart';
import '../widgets/saved_addresses_sheet.dart';
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
  Timer? _welcomeProfileTimer;
  Timer? _notifyWidgetSyncTimer;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).requestPermissionAndStart();
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
    _sheetController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(activeSearchProvider.notifier).expireIfStale());
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
    const limit = kRiderDriverSearchWindow;
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
      final supabase = HeyCabySupabase.client;
      
      // Calculate bounding box for 8km radius
      // 1 degree latitude ≈ 111km, 1 degree longitude ≈ 111km * cos(latitude)
      final latDelta = 8.0 / 111.0;
      final lngDelta = 8.0 / (111.0 * 0.7); // cos(52°) ≈ 0.7 for Netherlands
      
      // Schema: driver_locations uses latitude/longitude + driver_id (no status).
      // Online state lives on public.drivers.status (driver_status enum).
      final locResponse = await supabase
          .from('driver_locations')
          .select('driver_id')
          .gte('latitude', lat - latDelta)
          .lte('latitude', lat + latDelta)
          .gte('longitude', lng - lngDelta)
          .lte('longitude', lng + lngDelta);

      final locRows = locResponse as List<dynamic>;
      final driverIds = <String>{};
      for (final row in locRows) {
        final id = (row as Map<String, dynamic>)['driver_id'] as String?;
        if (id != null && id.isNotEmpty) driverIds.add(id);
      }

      if (driverIds.isEmpty) {
        if (mounted) setState(() => _nearbyTaxiCount = 0);
        return;
      }

      final driversResponse = await supabase
          .from('drivers')
          .select('id')
          .inFilter('id', driverIds.toList())
          .inFilter('status', ['available', 'on_ride']);

      if (mounted) {
        setState(() {
          _nearbyTaxiCount = (driversResponse as List).length;
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
            const RiderProfileHomeNudge(),
            if (active == null) const NearTermRideHomeBanner(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
              child: Text(
                l10n.goWhereverWhenever,
                style: typo.headingMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  height: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: _WhereToBar(colors: colors, typo: typo, l10n: l10n),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
              child: _RecentDestinationsSection(colors: colors, typo: typo, l10n: l10n),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
              child: _BookingCards(colors: colors, typo: typo, l10n: l10n),
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

class _WhereToBar extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _WhereToBar({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final pos = await LocationService.requestAndGetLocation();
                if (pos == null) {
                  if (context.mounted) context.go('/location-required');
                  return;
                }
                if (context.mounted) context.go('/search');
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: Row(
                  children: [
                    Icon(Icons.search, color: colors.textSoft, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      l10n.whereTo,
                      style: typo.headingMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _HomeButton(colors: colors, l10n: l10n),
          _ScheduleButton(colors: colors, typo: typo, l10n: l10n),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _HomeButton extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final AppLocalizations l10n;

  const _HomeButton({required this.colors, required this.l10n});

  Future<void> _handleHomeTap(BuildContext context, WidgetRef ref) async {
    final pos = await LocationService.requestAndGetLocation();
    if (pos == null) {
      if (context.mounted) context.go('/location-required');
      return;
    }
    if (!context.mounted) return;

    // Show saved addresses sheet; if rider picks one, set it as destination
    final picked = await showSavedAddressesSheet(context, ref);
    if (picked != null && context.mounted) {
      ref.read(bookingProvider.notifier).setDestination(picked);
      await BookingFlowNavigation.prefillBookingFromIdentity(ref);
      if (!context.mounted) return;
      final next = BookingFlowNavigation.routeAfterAddressesComplete(
        ref.read(bookingProvider),
      );
      context.push(next);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(savedAddressesProvider);
    final hasAddresses = addressesAsync.valueOrNull?.isNotEmpty ?? false;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleHomeTap(context, ref),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          hasAddresses ? Icons.home_rounded : Icons.home_outlined,
          color: hasAddresses ? colors.accent : colors.textMid,
          size: 22,
        ),
      ),
    );
  }
}

class _ScheduleButton extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _ScheduleButton({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final pos = await LocationService.requestAndGetLocation();
        if (pos == null) {
          if (context.mounted) context.go('/location-required');
          return;
        }
        ref.read(bookingProvider.notifier).setScheduled();
        if (context.mounted) context.go('/search');
      },
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.accentL,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, color: colors.accent, size: 16),
            const SizedBox(width: 4),
            Text(
              l10n.laterButton,
              style: typo.bodySmall.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                l10n.recentDestinations,
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

class _BookingCards extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _BookingCards({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _FavoriteDriverCard(
                title: l10n.favouriteDrivers,
                subtitle: l10n.favouriteDriversSubtitle,
                colors: colors,
                typo: typo,
                onTap: () async {
                  final identity = await ref.read(riderIdentityProvider.future);

                  if (identity.hasSession && identity.email != null) {
                    if (context.mounted) {
                      context.push('/favorites');
                    }
                  } else {
                    if (context.mounted) {
                      final success = await showEmailModal(context, ref);
                      if (success && context.mounted) {
                        context.push('/favorites');
                      }
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BookingCard(
                icon: Icons.sell_outlined,
                title: l10n.marketplace,
                subtitle: l10n.marketplaceSubtitle,
                badge: l10n.bestPrice,
                colors: colors,
                typo: typo,
                onTap: () {
                  ref.read(bookingProvider.notifier).setMarketplace();
                  context.push('/marketplace');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AirportBookingHomeCard(colors: colors, typo: typo, l10n: l10n),
      ],
    );
  }
}

class _AirportBookingHomeCard extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _AirportBookingHomeCard({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final pos = await LocationService.requestAndGetLocation();
          if (pos == null) {
            if (context.mounted) context.go('/location-required');
            return;
          }
          if (context.mounted) context.push('/airport-booking');
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                colors.accent.withValues(alpha: 0.14),
                colors.card,
              ],
            ),
            border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.flight_takeoff_rounded,
                    color: colors.accent,
                    size: 26,
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
                              l10n.homeAirportBookingTitle,
                              style: typo.titleMedium.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentL,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.homeAirportBookingBadge,
                              style: typo.labelSmall.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.homeAirportBookingSubtitle,
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: colors.textSoft, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteDriverCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _FavoriteDriverCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Driver Silhouette SVG Icon
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/driver_silhouette.svg',
                color: colors.accent,
                width: 32,
                height: 32,
              ),
            ),
            const SizedBox(height: 12),
            // Title - Favorite driver
            Text(
              title,
              style: typo.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Subtitle
            Text(
              subtitle,
              style: typo.bodySmall.copyWith(
                color: colors.textSoft,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _BookingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: colors.accent, size: 22),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accentL,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: typo.labelSmall.copyWith(color: colors.accent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: typo.titleMedium.copyWith(color: colors.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: typo.bodySmall.copyWith(color: colors.textSoft),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
