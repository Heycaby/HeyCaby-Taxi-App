import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heycaby_driver/app.dart';

void main() {
  testWidgets('Driver app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HeyCabyDriverApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
