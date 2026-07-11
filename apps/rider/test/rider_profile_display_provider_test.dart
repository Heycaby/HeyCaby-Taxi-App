import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/providers/rider_profile_display_provider.dart';

void main() {
  group('formatRiderDisplayName', () {
    test('title-cases each word', () {
      expect(formatRiderDisplayName('james'), 'James');
      expect(formatRiderDisplayName('JAMES SMITH'), 'James Smith');
      expect(formatRiderDisplayName('  anna   marie '), 'Anna Marie');
    });

    test('returns empty for blank input', () {
      expect(formatRiderDisplayName(''), '');
      expect(formatRiderDisplayName('   '), '');
    });
  });
}
