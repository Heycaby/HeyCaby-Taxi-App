import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

class DriverRatingSummary {
  const DriverRatingSummary({
    required this.averageRating,
    required this.totalRatings,
    required this.distribution,
  });

  final double averageRating;
  final int totalRatings;
  final Map<int, int> distribution;

  int get fiveStarCount => distribution[5] ?? 0;

  factory DriverRatingSummary.fromJson(Map<String, dynamic> json) {
    final rawDistribution =
        (json['distribution'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DriverRatingSummary(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (json['total_ratings'] as num?)?.round() ?? 0,
      distribution: {
        for (var star = 1; star <= 5; star++)
          star: (rawDistribution['$star'] as num?)?.round() ?? 0,
      },
    );
  }
}

final driverRatingSummaryProvider =
    FutureProvider.autoDispose<DriverRatingSummary>((ref) async {
  final response =
      await HeyCabySupabase.client.rpc('fn_driver_my_rating_summary');
  final json = (response as Map).cast<String, dynamic>();
  if (json['ok'] != true) {
    throw StateError(json['error'] as String? ?? 'rating_summary_failed');
  }
  return DriverRatingSummary.fromJson(json);
});
