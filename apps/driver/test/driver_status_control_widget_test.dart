import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/widgets/three_state_toggle.dart';

import 'visual/visual_harness.dart';

void main() {
  testWidgets('renders redesigned status control in every status',
      (tester) async {
    DriverStrings.useLocale(const Locale('en'));
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

    expect(find.text(DriverStrings.offline), findsOneWidget);
    expect(find.text(DriverStrings.onBreak), findsOneWidget);
    expect(find.text(DriverStrings.online), findsOneWidget);
    expect(find.text(DriverStrings.statusControlOfflineHint), findsOneWidget);
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

    expect(find.text(DriverStrings.statusControlBreakHint), findsOneWidget);

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

    expect(find.text(DriverStrings.statusControlOnlineHint), findsOneWidget);
    semantics.dispose();
  });
}
