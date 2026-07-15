import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider booking creation uses one backend command authority', () {
    final source = File(
      'lib/providers/ride_request_provider.dart',
    ).readAsStringSync();

    expect(source, contains("'fn_rider_create_ride'"));
    expect(source, contains("'request_id'"));
    expect(source, contains('_pendingCreateRequestId'));
    expect(
      RegExp(
        r'''\.from\(['"]ride_requests['"]\)\s*\.insert\(''',
        multiLine: true,
      ).hasMatch(source),
      isFalse,
    );
  });
}
