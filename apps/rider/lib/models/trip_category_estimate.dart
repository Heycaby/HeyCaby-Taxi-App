import 'package:flutter/foundation.dart';

/// One row from [fn_estimate_trip_category_prices] (Supabase).
@immutable
class TripCategoryEstimate {
  const TripCategoryEstimate({
    required this.categoryKey,
    required this.label,
    required this.priceEuro,
  });

  final String categoryKey;
  final String label;
  final double priceEuro;

  static TripCategoryEstimate? tryParseMap(Map<String, dynamic> m) {
    final cat = m['category']?.toString().trim();
    if (cat == null || cat.isEmpty) return null;
    final label = m['label']?.toString().trim() ?? cat;
    final p = m['price'];
    final price = p is num ? p.toDouble() : double.tryParse('$p');
    if (price == null) return null;
    return TripCategoryEstimate(
      categoryKey: cat,
      label: label,
      priceEuro: price,
    );
  }
}
