import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapService {
  MapboxMap? _mapboxMap;

  void attachMap(MapboxMap map) {
    _mapboxMap = map;
  }

  void detachMap() {
    _mapboxMap = null;
  }

  MapboxMap? get map => _mapboxMap;

  Future<void> flyTo({
    required double lat,
    required double lng,
    double zoom = 14.0,
    double? bearing,
  }) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
        bearing: bearing,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<void> easeTo({
    required double lat,
    required double lng,
    double zoom = 14.0,
  }) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 500),
    );
  }
}

final mapServiceProvider = Provider<MapService>((_) => MapService());
