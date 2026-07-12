import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import 'test_mode.dart';

/// Renders [MapWidget] in production or a plain [Container] when [kMapboxTestMode]
/// is enabled, preventing MissingPluginException in golden tests.
class MapWidgetOrPlaceholder extends StatelessWidget {
  const MapWidgetOrPlaceholder({
    super.key,
    required this.styleUri,
    this.cameraOptions,
    this.onMapCreated,
    this.onCameraChangeListener,
    this.placeholderColor = const Color(0xFFE8EAF0),
  });

  final String styleUri;
  final CameraOptions? cameraOptions;
  final void Function(MapboxMap)? onMapCreated;
  final void Function(CameraChangedEventData)? onCameraChangeListener;
  final Color placeholderColor;

  @override
  Widget build(BuildContext context) {
    if (kMapboxTestMode) {
      return Container(color: placeholderColor);
    }
    return MapWidget(
      key: key,
      styleUri: styleUri,
      cameraOptions: cameraOptions,
      onMapCreated: onMapCreated,
      onCameraChangeListener: onCameraChangeListener,
    );
  }
}
