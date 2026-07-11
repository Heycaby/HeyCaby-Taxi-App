import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

class RiderRatingComment {
  const RiderRatingComment({
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  final int rating;
  final String comment;
  final DateTime? createdAt;

  factory RiderRatingComment.fromJson(Map<String, dynamic> json) {
    return RiderRatingComment(
      rating: (json['rating'] as num?)?.round() ?? 0,
      comment: (json['comment'] as String? ?? '').trim(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class RiderRatingSummary {
  const RiderRatingSummary({
    required this.averageRating,
    required this.totalRatings,
    required this.distribution,
    required this.comments,
  });

  final double averageRating;
  final int totalRatings;
  final Map<int, int> distribution;
  final List<RiderRatingComment> comments;

  int get fiveStarCount => distribution[5] ?? 0;
  bool get hasRatings => totalRatings > 0;

  factory RiderRatingSummary.fromJson(Map<String, dynamic> json) {
    final rawDistribution =
        (json['distribution'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawComments = json['comments'] as List? ?? const [];
    return RiderRatingSummary(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (json['total_ratings'] as num?)?.round() ?? 0,
      distribution: {
        for (var star = 1; star <= 5; star++)
          star: (rawDistribution['$star'] as num?)?.round() ?? 0,
      },
      comments: rawComments
          .whereType<Map>()
          .map((item) => RiderRatingComment.fromJson(
                item.cast<String, dynamic>(),
              ))
          .where((item) => item.comment.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final riderRatingSummaryProvider =
    FutureProvider.autoDispose<RiderRatingSummary>((ref) async {
  final response =
      await HeyCabySupabase.client.rpc('fn_rider_my_rating_summary');
  final json = (response as Map).cast<String, dynamic>();
  if (json['ok'] != true) {
    throw StateError(json['error'] as String? ?? 'rating_summary_failed');
  }
  return RiderRatingSummary.fromJson(json);
});
