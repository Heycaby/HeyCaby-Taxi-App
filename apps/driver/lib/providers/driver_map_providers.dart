import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Zone map view: demand zones (circles with counts) or clear map.
enum MapView { demandZones, clearMap }

final mapViewProvider = StateProvider<MapView>((_) => MapView.demandZones);
