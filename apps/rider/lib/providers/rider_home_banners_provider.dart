import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rider_home_banner.dart';
import '../providers/rider_locale_provider.dart';
import '../services/rider_home_banners_service.dart';

/// Bump when locale changes so banners refetch in the new language.
final riderHomeBannersRefreshProvider = StateProvider<int>((ref) => 0);

/// Active server banners for the rider home sheet (refreshed on splash / pull).
final riderHomeBannersProvider =
    FutureProvider<List<RiderHomeBanner>>((ref) async {
  ref.watch(riderHomeBannersRefreshProvider);
  final localeTag = ref.watch(riderAppLocaleTagProvider);
  return riderHomeBannersService.refresh(locale: localeTag, force: true);
});

/// Highest-priority banner that should show for the current supply context.
RiderHomeBanner? pickRiderHomeBanner({
  required List<RiderHomeBanner> banners,
  required int nearbyTaxiCount,
}) {
  for (final banner in banners) {
    if (banner.onlyWhenNoSupply && nearbyTaxiCount > 0) continue;
    return banner;
  }
  return null;
}
