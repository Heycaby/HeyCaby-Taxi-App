import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offer boost adopts backend truth and avoids Taxi Terug reseeding', () {
    final source = File('lib/providers/marketplace_offers_provider.dart')
        .readAsStringSync();

    expect(source, contains("'fn_rider_boost_marketplace_offer'"));
    expect(source, contains("raw['new_fare']"));
    expect(source, contains("raw['booking_mode'] != 'terug'"));

    final rpcStart = source.indexOf("'fn_rider_boost_marketplace_offer'");
    final localMutation = source.indexOf(
      'setMarketplaceBidEuro(acceptedFare)',
      rpcStart,
    );
    expect(rpcStart, greaterThanOrEqualTo(0));
    expect(localMutation, greaterThan(rpcStart));
  });
}
