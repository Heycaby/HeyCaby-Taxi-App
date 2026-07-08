import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

void main() {
  test('resolveEuroFromRow skips zero and prefers final_fare', () {
    expect(
      HeyCabyRideFare.resolveEuroFromRow({
        'final_fare': 0,
        'quoted_fare': 42.5,
      }),
      42.5,
    );
  });

  test('resolveEuroFromRow includes marketplace_offered_fare', () {
    expect(
      HeyCabyRideFare.resolveEuroFromRow({
        'marketplace_offered_fare': 100,
      }),
      100.0,
    );
  });

  test('resolveCentsFromRow adds waiting fee in cents', () {
    expect(
      HeyCabyRideFare.resolveCentsFromRow({
        'offered_fare': 10,
        'waiting_fee_cents': 250,
      }),
      1250,
    );
  });

  test('fareSnapshotForInsert mirrors quote across columns', () {
    expect(
      HeyCabyRideFare.fareSnapshotForInsert(99.5),
      {
        'offered_fare': 99.5,
        'quoted_fare': 99.5,
        'estimated_fare': 99.5,
      },
    );
  });
}
