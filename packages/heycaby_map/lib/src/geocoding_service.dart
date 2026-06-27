import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_models/heycaby_models.dart';

class GeocodingService {
  static const _searchBaseUrl = 'https://api.mapbox.com/search/searchbox/v1';

  final Dio _dio;
  final String _accessToken;

  GeocodingService({required String accessToken})
      : _accessToken = accessToken,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ));

  String? _sessionToken;

  void startSession() {
    _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
  }

  void endSession() {
    _sessionToken = null;
  }

  Future<List<AddressResult>> search({
    required String query,
    double? proximityLat,
    double? proximityLng,
    String? bbox,
    String country = 'NL',
    /// Mapbox `language` (e.g. device locale). Defaults to Dutch for NL-first product.
    String language = 'nl',
  }) async {
    // Minimum 3 characters required (Mapbox best practice)
    if (query.trim().length < 3) return [];
    
    // Start session if not already started
    _sessionToken ??= DateTime.now().millisecondsSinceEpoch.toString();
    
    try {
      final params = <String, dynamic>{
        'q': query,
        'access_token': _accessToken,
        'session_token': _sessionToken,
        'country': country,
        'language': language,
        'limit': 6,
        if (proximityLat != null && proximityLng != null)
          'proximity': '$proximityLng,$proximityLat',
      };

      final res = await _dio.get<Map<String, dynamic>>(
        '$_searchBaseUrl/suggest',
        queryParameters: params,
      );

      final suggestions = res.data?['suggestions'] as List<dynamic>? ?? [];
      return suggestions.map((s) => _suggestionToResult(s as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<AddressResult?> retrieve(String mapboxId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_searchBaseUrl/retrieve/$mapboxId',
        queryParameters: {
          'access_token': _accessToken,
          if (_sessionToken != null) 'session_token': _sessionToken,
        },
      );
      
      // End session after retrieval (Mapbox best practice)
      endSession();
      
      final features = res.data?['features'] as List<dynamic>? ?? [];
      if (features.isEmpty) return null;
      final feature = features.first as Map<String, dynamic>;
      final coords = (feature['geometry'] as Map)['coordinates'] as List;
      final props = feature['properties'] as Map<String, dynamic>;
      return AddressResult(
        displayName: props['name'] as String? ?? '',
        fullAddress: props['full_address'] as String? ?? props['name'] as String? ?? '',
        lat: (coords[1] as num).toDouble(),
        lng: (coords[0] as num).toDouble(),
        mapboxId: mapboxId,
        city: _extractCity(props),
      );
    } catch (_) {
      return null;
    }
  }

  Future<AddressResult?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json',
        queryParameters: {
          'access_token': _accessToken,
          'limit': 1,
        },
      );
      final features = res.data?['features'] as List<dynamic>? ?? [];
      if (features.isEmpty) return null;
      final feature = features.first as Map<String, dynamic>;
      final neighborhood = _neighborhoodFromFeature(feature);
      return AddressResult(
        displayName: feature['text'] as String? ?? '',
        fullAddress: feature['place_name'] as String? ?? '',
        lat: lat,
        lng: lng,
        city: neighborhood,
      );
    } catch (_) {
      return null;
    }
  }

  /// Neighbourhood or district label (e.g. De Pijp, Amsterdam-Zuid).
  String? _neighborhoodFromFeature(Map<String, dynamic> feature) {
    final context = feature['context'] as List<dynamic>?;
    if (context == null) return null;
    String? neighborhood;
    String? place;
    for (final raw in context) {
      if (raw is! Map) continue;
      final id = raw['id'] as String? ?? '';
      final text = raw['text'] as String?;
      if (text == null || text.isEmpty) continue;
      if (id.startsWith('neighborhood.')) neighborhood = text;
      if (id.startsWith('place.') || id.startsWith('locality.')) place = text;
    }
    return neighborhood ?? place;
  }

  AddressResult _suggestionToResult(Map<String, dynamic> s) {
    return AddressResult(
      displayName: s['name'] as String? ?? '',
      fullAddress: s['full_address'] as String? ?? s['place_formatted'] as String? ?? '',
      lat: 0.0,
      lng: 0.0,
      mapboxId: s['mapbox_id'] as String?,
      city: s['place_formatted'] as String?,
    );
  }

  String? _extractCity(Map<String, dynamic> props) {
    final context = props['context'] as Map<String, dynamic>?;
    return context?['place']?['name'] as String?;
  }
}

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  return GeocodingService(accessToken: token);
});
