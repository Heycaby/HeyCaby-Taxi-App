import 'package:heycaby_driver/services/driver_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaxiTerugQualifyResult', () {
    test('parses qualified payload from fn_terugtaxi_qualify', () {
      final result = TaxiTerugQualifyResult.fromJson({
        'qualified': true,
        'reason': 'qualified',
        'destination_label': 'Rotterdam',
        'progress_toward_home_km': 42.5,
        'progress_ratio': 0.31,
      });

      expect(result.qualified, isTrue);
      expect(result.reason, 'qualified');
      expect(result.destinationLabel, 'Rotterdam');
      expect(result.progressTowardHomeKm, 42.5);
      expect(result.progressRatio, 0.31);
    });

    test('parses not qualified payload', () {
      final result = TaxiTerugQualifyResult.fromJson({
        'qualified': false,
        'reason': 'wrong_direction',
      });

      expect(result.qualified, isFalse);
      expect(result.reason, 'wrong_direction');
      expect(result.destinationLabel, isNull);
    });
  });
}
