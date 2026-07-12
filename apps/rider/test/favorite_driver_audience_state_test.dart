import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/providers/booking_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('favorites first keeps one coherent audience state', () {
    final notifier = container.read(bookingProvider.notifier);

    notifier.setMarketplaceDriverAudience(
      MarketplaceDriverAudience.myDriversOnly,
    );
    notifier.setFavoritesFirst(true);

    final booking = container.read(bookingProvider);
    expect(booking.favoritesFirst, isTrue);
    expect(booking.favoritesOnly, isFalse);
    expect(
      booking.marketplaceDriverAudience,
      MarketplaceDriverAudience.myDriversFirst,
    );
    expect(booking.selectedDriverId, isNull);
  });

  test('favorites audience clears a stale direct-driver target', () {
    final notifier = container.read(bookingProvider.notifier);

    notifier.setPreferredDriver('driver-a');
    notifier.setMarketplaceDriverAudience(
      MarketplaceDriverAudience.myDriversOnly,
    );

    final booking = container.read(bookingProvider);
    expect(booking.selectedDriverId, isNull);
    expect(booking.favoritesFirst, isTrue);
    expect(booking.favoritesOnly, isTrue);
  });

  test('specific driver clears stale favorite-network flags', () {
    final notifier = container.read(bookingProvider.notifier);

    notifier.setMarketplaceDriverAudience(
      MarketplaceDriverAudience.myDriversOnly,
    );
    notifier.setPreferredDriver('driver-b');

    final booking = container.read(bookingProvider);
    expect(booking.selectedDriverId, 'driver-b');
    expect(booking.favoritesFirst, isFalse);
    expect(booking.favoritesOnly, isFalse);
    expect(
      booking.marketplaceDriverAudience,
      MarketplaceDriverAudience.everyone,
    );
  });
}
