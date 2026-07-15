import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/providers/driver_data_providers.dart';
import 'package:heycaby_driver/widgets/driver_hub_saved_by_riders_section.dart';

void main() {
  group('savedByRidersInlineCopy', () {
    test('returns null when summary is empty', () {
      expect(savedByRidersInlineCopy(null), isNull);
      expect(
        savedByRidersInlineCopy(
          const DriverFavoriteSummary(
            totalSavedByRiders: 0,
            addedThisWeek: 0,
            recent: [],
          ),
        ),
        isNull,
      );
    });

    test('includes count, week delta, and up to two names', () {
      final copy = savedByRidersInlineCopy(
        DriverFavoriteSummary(
          totalSavedByRiders: 3,
          addedThisWeek: 1,
          recent: [
            DriverFavoriteRecent(
              riderFirstName: 'Anna',
              addedAt: DateTime(2026, 7, 14),
            ),
            DriverFavoriteRecent(
              riderFirstName: 'Sam',
              addedAt: DateTime(2026, 7, 13),
            ),
            DriverFavoriteRecent(
              riderFirstName: 'Bo',
              addedAt: DateTime(2026, 7, 12),
            ),
          ],
        ),
      );

      expect(copy, isNotNull);
      expect(copy!.countLine, contains('3'));
      expect(copy.countLine, contains('+1'));
      expect(copy.namesLine, 'Anna, Sam');
    });
  });
}
