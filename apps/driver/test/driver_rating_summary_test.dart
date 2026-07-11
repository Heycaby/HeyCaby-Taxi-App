import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/providers/driver_rating_summary_provider.dart';

void main() {
  test('parses exact driver star distribution', () {
    final summary = DriverRatingSummary.fromJson({
      'average_rating': 4.94,
      'total_ratings': 50,
      'distribution': {'5': 48, '4': 1, '3': 1, '2': 0, '1': 0},
    });

    expect(summary.averageRating, 4.94);
    expect(summary.totalRatings, 50);
    expect(summary.fiveStarCount, 48);
    expect(summary.distribution[3], 1);
  });
}
