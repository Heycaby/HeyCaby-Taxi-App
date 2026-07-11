import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/providers/rider_rating_summary_provider.dart';

void main() {
  test('parses exact rider rating distribution and driver comments', () {
    final summary = RiderRatingSummary.fromJson({
      'average_rating': 4.67,
      'total_ratings': 3,
      'distribution': {'5': 2, '4': 1, '3': 0, '2': 0, '1': 0},
      'comments': [
        {
          'rating': 5,
          'comment': 'Ready at pickup',
          'created_at': '2026-07-10T08:00:00Z',
        },
      ],
    });

    expect(summary.averageRating, 4.67);
    expect(summary.totalRatings, 3);
    expect(summary.fiveStarCount, 2);
    expect(summary.distribution[4], 1);
    expect(summary.comments.single.comment, 'Ready at pickup');
  });
}
