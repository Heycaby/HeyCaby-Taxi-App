import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/widgets/three_state_toggle.dart';

import 'visual/visual_harness.dart';

void main() {
  testWidgets('renders redesigned status control in every status',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const DriverVisualHarness(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: ThreeStateToggle(
              currentStatus: DriverAvailabilityStatus.offline,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Pauze'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(
      find.text('Ga online om live ritaanvragen in jouw zone te zien.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Driver status offline')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Driver status break')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Driver status online')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const DriverVisualHarness(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: ThreeStateToggle(
              currentStatus: DriverAvailabilityStatus.onBreak,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Je pauze is actief. Ga online om ritten te zien.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const DriverVisualHarness(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: ThreeStateToggle(
              currentStatus: DriverAvailabilityStatus.available,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Je bent live in jouw zone.'), findsOneWidget);
    semantics.dispose();
  });
}
