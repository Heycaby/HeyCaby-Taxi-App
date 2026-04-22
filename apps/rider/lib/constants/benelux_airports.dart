import 'package:heycaby_models/heycaby_models.dart';

/// Major passenger airports in the Benelux for quick drop-off booking.
/// Coordinates are approximate terminal / pickup areas.
class BeneluxAirport {
  final String iata;
  final String name;
  final String city;
  /// ISO-style: NL, BE, LU
  final String countryCode;
  final String fullAddress;
  final double lat;
  final double lng;

  const BeneluxAirport({
    required this.iata,
    required this.name,
    required this.city,
    required this.countryCode,
    required this.fullAddress,
    required this.lat,
    required this.lng,
  });

  AddressResult toAddressResult() => AddressResult(
        displayName: '$name ($iata)',
        fullAddress: fullAddress,
        lat: lat,
        lng: lng,
      );
}

/// Ordered: Netherlands, Belgium, Luxembourg (then alphabetically by city).
const List<BeneluxAirport> kBeneluxAirports = [
  // Netherlands
  BeneluxAirport(
    iata: 'AMS',
    name: 'Amsterdam Airport Schiphol',
    city: 'Schiphol',
    countryCode: 'NL',
    fullAddress: 'Schiphol Airport, 1118 CP Schiphol, Netherlands',
    lat: 52.3105,
    lng: 4.7683,
  ),
  BeneluxAirport(
    iata: 'EIN',
    name: 'Eindhoven Airport',
    city: 'Eindhoven',
    countryCode: 'NL',
    fullAddress: 'Eindhoven Airport, 5657 EA Eindhoven, Netherlands',
    lat: 51.4501,
    lng: 5.3745,
  ),
  BeneluxAirport(
    iata: 'GRQ',
    name: 'Groningen Airport Eelde',
    city: 'Eelde',
    countryCode: 'NL',
    fullAddress: 'Groningen Airport Eelde, 9761 TK Eelde, Netherlands',
    lat: 53.1197,
    lng: 6.5794,
  ),
  BeneluxAirport(
    iata: 'MST',
    name: 'Maastricht Aachen Airport',
    city: 'Beek',
    countryCode: 'NL',
    fullAddress: 'Maastricht Aachen Airport, 6199 AD Maastricht, Netherlands',
    lat: 50.9116,
    lng: 5.7681,
  ),
  BeneluxAirport(
    iata: 'RTM',
    name: 'Rotterdam The Hague Airport',
    city: 'Rotterdam',
    countryCode: 'NL',
    fullAddress: 'Rotterdam The Hague Airport, 3045 AP Rotterdam, Netherlands',
    lat: 51.9569,
    lng: 4.4372,
  ),
  // Belgium
  BeneluxAirport(
    iata: 'ANR',
    name: 'Antwerp International Airport',
    city: 'Antwerp',
    countryCode: 'BE',
    fullAddress: 'Antwerp International Airport, 2100 Antwerp, Belgium',
    lat: 51.1894,
    lng: 4.4603,
  ),
  BeneluxAirport(
    iata: 'BRU',
    name: 'Brussels Airport',
    city: 'Zaventem',
    countryCode: 'BE',
    fullAddress: 'Brussels Airport, 1930 Zaventem, Belgium',
    lat: 50.9010,
    lng: 4.4856,
  ),
  BeneluxAirport(
    iata: 'CRL',
    name: 'Brussels South Charleroi Airport',
    city: 'Charleroi',
    countryCode: 'BE',
    fullAddress: 'Brussels South Charleroi Airport, 6040 Charleroi, Belgium',
    lat: 50.4592,
    lng: 4.4538,
  ),
  BeneluxAirport(
    iata: 'LGG',
    name: 'Liège Airport',
    city: 'Liège',
    countryCode: 'BE',
    fullAddress: 'Liège Airport, 4460 Grâce-Hollogne, Belgium',
    lat: 50.6374,
    lng: 5.4432,
  ),
  BeneluxAirport(
    iata: 'OST',
    name: 'Ostend-Bruges International Airport',
    city: 'Ostend',
    countryCode: 'BE',
    fullAddress: 'Ostend-Bruges Airport, 8400 Ostend, Belgium',
    lat: 51.1987,
    lng: 2.8622,
  ),
  // Luxembourg
  BeneluxAirport(
    iata: 'LUX',
    name: 'Luxembourg Airport',
    city: 'Findel',
    countryCode: 'LU',
    fullAddress: 'Luxembourg Airport, 1110 Findel, Luxembourg',
    lat: 49.6264,
    lng: 6.2115,
  ),
];

List<BeneluxAirport> filterAirports(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List.of(kBeneluxAirports);
  return kBeneluxAirports.where((a) {
    return a.iata.toLowerCase().contains(q) ||
        a.name.toLowerCase().contains(q) ||
        a.city.toLowerCase().contains(q) ||
        a.fullAddress.toLowerCase().contains(q);
  }).toList();
}
