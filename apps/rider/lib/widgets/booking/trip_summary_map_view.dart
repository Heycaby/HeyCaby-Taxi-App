import 'dart:math' show sin, cos, sqrt, atan2, pi;

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

/// Top map slice on the trip summary screen: route line, markers, distance/ETA.
class TripSummaryMapView extends ConsumerStatefulWidget {
  const TripSummaryMapView({
    super.key,
    required this.height,
    required this.onRouteMetricsChanged,
  });

  final double height;
  final void Function(double distanceKm, int etaMinutes) onRouteMetricsChanged;

  @override
  ConsumerState<TripSummaryMapView> createState() => _TripSummaryMapViewState();
}

class _TripSummaryMapViewState extends ConsumerState<TripSummaryMapView> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _lineManager;
  PointAnnotationManager? _pointManager;

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    await _mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _mapboxMap!.compass.updateSettings(CompassSettings(enabled: false));
    await _mapboxMap!.attribution.updateSettings(AttributionSettings(enabled: false));
    await _mapboxMap!.logo.updateSettings(LogoSettings(enabled: false));

    await _mapboxMap!.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF4285F4,
      pulsingMaxRadius: 40.0,
      showAccuracyRing: true,
    ));

    _lineManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
    _pointManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    await _fitRoute();
  }

  Future<void> _fitRoute() async {
    if (_mapboxMap == null) return;
    final booking = ref.read(bookingProvider);
    final pickup = booking.pickup;
    final destination = booking.destination;
    if (pickup == null || destination == null) return;

    final haversineKm = _haversineKm(
      pickup.lat, pickup.lng, destination.lat, destination.lng,
    );
    final haversineEta = ((haversineKm / 30) * 60).ceil();
    widget.onRouteMetricsChanged(haversineKm, haversineEta);

    final minLat = pickup.lat < destination.lat ? pickup.lat : destination.lat;
    final maxLat = pickup.lat > destination.lat ? pickup.lat : destination.lat;
    final minLng = pickup.lng < destination.lng ? pickup.lng : destination.lng;
    final maxLng = pickup.lng > destination.lng ? pickup.lng : destination.lng;

    final latPadding = (maxLat - minLat) * 0.3;
    final lngPadding = (maxLng - minLng) * 0.3;

    final camera = await _mapboxMap!.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest:
            Point(coordinates: Position(minLng - lngPadding, minLat - latPadding)),
        northeast:
            Point(coordinates: Position(maxLng + lngPadding, maxLat + latPadding)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 40, left: 20, bottom: 40, right: 20),
      null, null, null, null,
    );

    await _mapboxMap!.setCamera(camera);
    await _drawRouteLine(pickup, destination);
    await _addMarkers(pickup, destination);

    if (mounted) setState(() {});
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

  Future<void> _drawRouteLine(
    AddressResult pickup,
    AddressResult destination,
  ) async {
    if (_lineManager == null) return;
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
      return;
    }

    if (route != null) {
      final line = PolylineAnnotationOptions(
        geometry: LineString(
          coordinates:
              route.coordinates.map((c) => Position(c[0], c[1])).toList(),
        ),
        lineColor: ref.read(colorsProvider).accent.toARGB32(),
        lineWidth: 4,
      );
      await _lineManager!.create(line);
      widget.onRouteMetricsChanged(route.distanceKm, route.durationMinutes);
    } else {
      final line = PolylineAnnotationOptions(
        geometry: LineString(coordinates: [
          Position(pickup.lng, pickup.lat),
          Position(destination.lng, destination.lat),
        ]),
        lineColor: ref.read(colorsProvider).accent.toARGB32(),
        lineWidth: 4,
      );
      await _lineManager!.create(line);
    }

    if (mounted) setState(() {});
  }

  Future<void> _addMarkers(
    AddressResult pickup,
    AddressResult destination,
  ) async {
    if (_pointManager == null) return;
    final colors = ref.read(colorsProvider);
    await _pointManager!.deleteAll();
    await _pointManager!.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(pickup.lng, pickup.lat)),
      iconImage: 'marker-15',
      iconSize: 1.5,
      iconColor: colors.success.toARGB32(),
    ));
    await _pointManager!.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(destination.lng, destination.lat)),
      iconImage: 'marker-15',
      iconSize: 1.5,
      iconColor: colors.error.toARGB32(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: MapWidget(
        styleUri: mapStyleForTheme(ref.watch(themeProvider).id),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
