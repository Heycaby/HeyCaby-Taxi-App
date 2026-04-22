import 'package:dio/dio.dart';

/// RDW open data — kenteken → vehicle row (no API key).
///
/// - Basis kenteken: `m9d7-ebf2`
/// - **Registered taxi (authoritative):** `ggjs-hm9w` ("RDW base taxi only").
///   Vehicles on that list are licensed taxis; their [inrichting] is often
///   "MPV", "stationwagen", etc. — **not** the word "TAXI", so we must not rely
///   on [inrichting] alone.
class RdwVehicleRow {
  RdwVehicleRow._(this.raw, {this.isRegisteredTaxiDataset = false});

  final Map<String, dynamic> raw;

  /// True when this kenteken appears in RDW's taxi-only dataset (`ggjs-hm9w`).
  final bool isRegisteredTaxiDataset;

  String? get merk => raw['merk'] as String?;
  String? get handelsbenaming => raw['handelsbenaming'] as String?;
  String? get eersteKleur => raw['eerste_kleur'] as String?;
  String? get voertuigsoort => raw['voertuigsoort'] as String?;
  String? get inrichting => raw['inrichting'] as String?;
  String? get aantalZitplaatsen => raw['aantal_zitplaatsen'] as String?;
  String? get vervaldatumApk => raw['vervaldatum_apk'] as String?;
  String? get wamVerzekerd => raw['wam_verzekerd'] as String?;
  String? get datumEersteToelating => raw['datum_eerste_toelating'] as String?;

  /// Licensed taxi if listed in the taxi-only RDW set, or legacy [inrichting] text.
  bool get isTaxiVehicle {
    if (isRegisteredTaxiDataset) return true;
    final s = (inrichting ?? '').toUpperCase();
    return s.contains('TAXI') ||
        s.contains('TAXIVOERTUIG') ||
        s.contains('HUURBUS MET BESTUURDER');
  }
}

class RdwOpenDataService {
  RdwOpenDataService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Returns first matching RDW row or null if not found / error.
  ///
  /// Cross-checks [ggjs-hm9w] so real taxis are recognised even when
  /// `inrichting` does not contain "TAXI".
  Future<RdwVehicleRow?> lookupByPlate(String plate) async {
    final cleaned = plate.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.length < 4) return null;
    try {
      final res = await _dio.get<List<dynamic>>(
        'https://opendata.rdw.nl/resource/m9d7-ebf2.json',
        queryParameters: {'kenteken': cleaned},
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      final list = res.data;
      if (list == null || list.isEmpty) return null;
      final first = list.first;
      if (first is! Map<String, dynamic>) return null;

      final inTaxiDataset = await _kentekenInTaxiOnlyDataset(cleaned);
      return RdwVehicleRow._(first, isRegisteredTaxiDataset: inTaxiDataset);
    } catch (_) {
      return null;
    }
  }

  /// RDW "RDW base (taxi only)" — presence = registered passenger taxi in NL.
  Future<bool> _kentekenInTaxiOnlyDataset(String cleanedKenteken) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        'https://opendata.rdw.nl/resource/ggjs-hm9w.json',
        queryParameters: {'kenteken': cleanedKenteken},
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      final list = res.data;
      return list != null && list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
