import 'dart:math' show max, min, sin, cos, sqrt, atan2, pi;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_map/heycaby_map.dart';

import '../../providers/booking_provider.dart';
import '../../utils/map_style_helper.dart';
import 'trip_summary_map_pins.dart';

/// Default map center when coordinates are not ready (Rotterdam — HeyCaby home market).
const _kDefaultLng = 4.4777;
const _kDefaultLat = 51.9244;

/// Top map on trip summary: route line + animated pins, frames both endpoints.
class TripSummaryMapView extends ConsumerStatefulWidget {
  const TripSummaryMapView({
    super.key,
    required this.height,
    required this.onRouteMetricsChanged,
    this.cameraBottomPadding = 210,
    this.pickupFocused = false,
  });

  final double height;
  final void Function(double distanceKm, int etaMinutes) onRouteMetricsChanged;
  final double cameraBottomPadding;

  /// When true (driver search), zoom on pickup only — no route line or drop-off pin.
  final bool pickupFocused;

  @override
  ConsumerState<TripSummaryMapView> createState() => _TripSummaryMapViewState();
}

class _TripSummaryMapViewState extends ConsumerState<TripSummaryMapView> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _lineManager;
  bool _styleReady = false;
  bool _drawing = false;
  int _cameraTick = 0;

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    await Future.wait([
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.compass.updateSettings(CompassSettings(enabled: false)),
      map.attribution.updateSettings(AttributionSettings(enabled: false)),
      map.logo.updateSettings(LogoSettings(enabled: false)),
      map.location.updateSettings(LocationComponentSettings(enabled: false)),
    ]);

    await map.setBounds(
      CameraBoundsOptions(
        bounds: CoordinateBounds(
          southwest: Point(coordinates: Position(3.31, 50.75)),
          northeast: Point(coordinates: Position(7.23, 53.55)),
          infiniteBounds: false,
        ),
        minZoom: 7.5,
        maxZoom: 18.0,
      ),
    );

    await _tryDrawRoute();
  }

  void _onCameraChange(CameraChangedEventData _) {
    if (!mounted) return;
    setState(() => _cameraTick++);
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    _styleReady = true;
    _lineManager = null;
    await _tryDrawRoute();
  }

  Future<void> _ensureLineManager() async {
    final map = _mapboxMap;
    if (map == null) return;
    _lineManager ??= await map.annotations.createPolylineAnnotationManager();
  }

  Future<void> _tryDrawRoute() async {
    if (!_styleReady || _mapboxMap == null || _drawing) {
      return;
    }
    final booking = ref.read(bookingProvider);
    if (booking.pickup == null) return;
    if (!widget.pickupFocused && booking.destination == null) return;

    _drawing = true;
    try {
      await _ensureLineManager();
      if (widget.pickupFocused) {
        await _drawPickupSearchView(pickup: booking.pickup!);
      } else {
        await _drawRouteAndPins(
          pickup: booking.pickup!,
          destination: booking.destination!,
        );
      }
    } finally {
      _drawing = false;
    }
  }

  Future<void> _drawPickupSearchView({required AddressResult pickup}) async {
    final map = _mapboxMap;
    if (map == null) return;

    await _lineManager?.deleteAll();
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(pickup.lng, pickup.lat)),
        zoom: 15.6,
        padding: MbxEdgeInsets(
          top: 72,
          left: 48,
          bottom: widget.cameraBottomPadding,
          right: 48,
        ),
      ),
      MapAnimationOptions(duration: 350, startDelay: 0),
    );

    if (mounted) setState(() => _cameraTick++);
  }

  Future<void> _drawRouteAndPins({
    required AddressResult pickup,
    required AddressResult destination,
  }) async {
    final map = _mapboxMap;
    if (map == null || _lineManager == null) return;

    final haversineKm = _haversineKm(
      pickup.lat,
      pickup.lng,
      destination.lat,
      destination.lng,
    );
    final haversineEta = ((haversineKm / 30) * 60).ceil();
    widget.onRouteMetricsChanged(haversineKm, haversineEta);

    final routePoints = await _drawRouteLine(pickup, destination);
    await _fitCamera(pickup, destination, routePoints);

    if (mounted) setState(() => _cameraTick++);
  }

  Future<void> _fitCamera(
    AddressResult pickup,
    AddressResult destination,
    List<Position> routePoints,
  ) async {
    final map = _mapboxMap;
    if (map == null) return;

    var minLat = min(pickup.lat, destination.lat);
    var maxLat = max(pickup.lat, destination.lat);
    var minLng = min(pickup.lng, destination.lng);
    var maxLng = max(pickup.lng, destination.lng);

    for (final p in routePoints) {
      minLat = min(minLat, p.lat.toDouble());
      maxLat = max(maxLat, p.lat.toDouble());
      minLng = min(minLng, p.lng.toDouble());
      maxLng = max(maxLng, p.lng.toDouble());
    }

    final latSpan = max(maxLat - minLat, 0.008);
    final lngSpan = max(maxLng - minLng, 0.008);
    final tripKm = _haversineKm(
      pickup.lat,
      pickup.lng,
      destination.lat,
      destination.lng,
    );

    final westPad = max(lngSpan * 0.14, 0.012);
    final eastPad = max(lngSpan * 0.14, 0.012);
    final northPad = max(latSpan * 0.20, 0.014);
    final southPad = max(latSpan * 0.26, 0.018);

    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(
          coordinates: Position(minLng - westPad, minLat - southPad),
        ),
        northeast: Point(
          coordinates: Position(maxLng + eastPad, maxLat + northPad),
        ),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(
        top: 96,
        left: 64,
        bottom: widget.cameraBottomPadding,
        right: 64,
      ),
      null,
      null,
      null,
      null,
    );

    final boundsZoom = camera.zoom ?? _minZoomForTripKm(tripKm);
    final zoom = (boundsZoom - 0.2).clamp(7.5, 16.0);

    await map.flyTo(
      CameraOptions(
        center: camera.center,
        zoom: zoom,
        bearing: camera.bearing,
        pitch: camera.pitch,
      ),
      MapAnimationOptions(duration: 500, startDelay: 0),
    );
  }

  double _minZoomForTripKm(double km) {
    if (km < 2) return 14.6;
    if (km < 8) return 13.4;
    if (km < 25) return 12.0;
    if (km < 60) return 11.0;
    if (km < 120) return 10.0;
    return 9.2;
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (earthRadius * c * 10).round() / 10;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  Future<List<Position>> _drawRouteLine(
    AddressResult pickup,
    AddressResult destination,
  ) async {
    if (_lineManager == null) return const [];
    await _lineManager!.deleteAll();

    final routingService = RoutingService(
      accessToken: const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    );

    final route = await routingService.fetchRoute(
      fromLat: pickup.lat,
      fromLng: pickup.lng,
      toLat: destination.lat,
      toLng: destination.lng,
    );

    if (route != null && route.distanceKm > 500) {
      debugPrint(
        'Route distance ${route.distanceKm}km exceeds 500km - invalid pickup location',
      );
      if (mounted) {
        final colors = ref.read(colorsProvider);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.connectionProblem),
            backgroundColor: colors.error,
          ),
        );
        ref.read(bookingProvider.notifier).clearPickup();
        context.go('/search');
      }
      return const [];
    }

    final colors = ref.read(colorsProvider);
    final lineColor = colors.success.toARGB32();
    List<Position> geometry = [
      Position(pickup.lng, pickup.lat),
      Position(destination.lng, destination.lat),
    ];

    if (route != null) {
      geometry = route.coordinates.map((c) => Position(c[0], c[1])).toList();
      widget.onRouteMetricsChanged(route.distanceKm, route.durationMinutes);
    }

    await _lineManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: geometry),
        lineColor: lineColor,
        lineWidth: 5.5,
        lineOpacity: 0.92,
      ),
    );

    return geometry;
  }

  CameraOptions _initialCamera(BookingState booking) {
    final pickup = booking.pickup;
    final destination = booking.destination;
    if (pickup != null && destination != null) {
      final centerLat = (pickup.lat + destination.lat) / 2;
      final centerLng = (pickup.lng + destination.lng) / 2;
      final spanKm = _haversineKm(
        pickup.lat,
        pickup.lng,
        destination.lat,
        destination.lng,
      );
      return CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: _zoomForDistanceKm(spanKm) - 0.3,
      );
    }
    if (pickup != null) {
      return CameraOptions(
        center: Point(coordinates: Position(pickup.lng, pickup.lat)),
        zoom: widget.pickupFocused ? 15.6 : 14.3,
      );
    }
    return CameraOptions(
      center: Point(coordinates: Position(_kDefaultLng, _kDefaultLat)),
      zoom: 12.5,
    );
  }

  double _zoomForDistanceKm(double km) => _minZoomForTripKm(km);

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    final colors = ref.watch(colorsProvider);
    final pickup = booking.pickup;
    final destination = booking.destination;

    ref.listen<BookingState>(bookingProvider, (prev, next) {
      final prevPickup = prev?.pickup;
      final prevDest = prev?.destination;
      final nextPickup = next.pickup;
      final nextDest = next.destination;
      final changed = prevPickup?.lat != nextPickup?.lat ||
          prevPickup?.lng != nextPickup?.lng ||
          prevDest?.lat != nextDest?.lat ||
          prevDest?.lng != nextDest?.lng;
      if (!changed) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryDrawRoute());
    });

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapWidget(
            styleUri: mapStyleForTheme(ref.watch(themeProvider).id),
            cameraOptions: _initialCamera(booking),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onCameraChangeListener: _onCameraChange,
          ),
          TripSummaryMapPinsOverlay(
            mapboxMap: _mapboxMap,
            pickupLat: pickup?.lat,
            pickupLng: pickup?.lng,
            destinationLat:
                widget.pickupFocused ? null : destination?.lat,
            destinationLng:
                widget.pickupFocused ? null : destination?.lng,
            pickupColor: colors.warning,
            dropoffColor: colors.success,
            cameraTick: _cameraTick,
          ),
        ],
      ),
    );
  }
}
