import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('driver status control regression', () {
    final toggleSource =
        File('lib/widgets/three_state_toggle.dart').readAsStringSync();
    final homeSheetSource =
        File('lib/widgets/driver_home_sheet.dart').readAsStringSync();
    final migrationSource = File(
      '../../supabase/migrations/'
      '20260629112319_fix_driver_set_status_location_conflict.sql',
    ).readAsStringSync();

    test('keeps the redesigned three-state control labels and hints', () {
      expect(toggleSource, contains('Offline'));
      expect(toggleSource, contains('Pauze'));
      expect(toggleSource, contains('Online'));
      expect(
        toggleSource,
        contains('Ga online om live ritaanvragen in jouw zone te zien.'),
      );
      expect(homeSheetSource, contains("label: 'Ritten'"));
      expect(homeSheetSource, contains("label: 'Instellingen'"));
    });

    test('keeps haptics on status transitions and supporting actions', () {
      expect(toggleSource, contains('HapticService.selectionClick()'));
      expect(toggleSource, contains('HapticService.heavyTap()'));
      expect(toggleSource, contains('HapticService.mediumTap()'));
      expect(toggleSource, contains('HapticService.lightTap()'));
      expect(toggleSource, contains('HapticService.error()'));
      expect(homeSheetSource, contains('HapticService.selectionClick()'));
    });

    test('does not leak raw backend exceptions to drivers', () {
      expect(toggleSource, isNot(contains(r'($e)')));
      expect(toggleSource, isNot(contains('PostgrestException')));
      expect(toggleSource, contains('_failureMessageForStatus'));
      expect(
        toggleSource,
        contains('Pauze starten mislukt. Controleer je verbinding'),
      );
      expect(
        toggleSource,
        contains('Offline gaan mislukt. Controleer je verbinding'),
      );
    });

    test('keeps driver location upsert conflict target aligned with schema',
        () {
      expect(migrationSource, contains('ON CONFLICT (user_id) DO UPDATE'));
      expect(migrationSource, isNot(contains('ON CONFLICT (driver_id) DO')));
    });
  });
}
