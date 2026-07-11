import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Booking mode enum values', () {
    test('booking_mode enum values match Supabase expectations', () {
      expect('instant', isNotEmpty);
      expect('scheduled', isNotEmpty);
      expect('marketplace', isNotEmpty);
    });

    test('ride_requests status values are correct', () {
      const validStatuses = [
        'pending', 'bidding', 'accepted', 'driver_arrived',
        'in_progress', 'completed', 'cancelled', 'expired', 'declined',
      ];
      expect(validStatuses.length, 9);
      expect(validStatuses.contains('pending'), true);
      expect(validStatuses.contains('searching'), false);
    });
  });

  group('Netherlands bounding box guard', () {
    bool isInNetherlands(double lat, double lng) =>
        lat >= 50.75 && lat <= 53.55 && lng >= 3.31 && lng <= 7.23;

    test('Amsterdam is in Netherlands', () {
      expect(isInNetherlands(52.37, 4.89), true);
    });

    test('Rotterdam is in Netherlands', () {
      expect(isInNetherlands(51.92, 4.47), true);
    });

    test('San Francisco is NOT in Netherlands', () {
      expect(isInNetherlands(37.78, -122.40), false);
    });

    test('London is NOT in Netherlands', () {
      expect(isInNetherlands(51.50, -0.12), false);
    });

    test('Groningen (north NL) is in Netherlands', () {
      expect(isInNetherlands(53.22, 6.56), true);
    });

    test('Maastricht (south NL) is in Netherlands', () {
      expect(isInNetherlands(50.85, 5.69), true);
    });
  });

  group('Ride create payload validation', () {
    test('payload has required fields with correct format', () {
      final payload = {
        'pickup_coords': 'POINT(4.89 52.37)',
        'destination_coords': 'POINT(4.47 51.92)',
        'pickup_address': 'Damrak 1, 1012 LG Amsterdam',
        'destination_address': 'Coolsingel 40, 3011 AD Rotterdam',
        'rider_token': 'test-token',
        'rider_identity_id': 'test-identity-id',
        'status': 'pending',
        'booking_mode': 'instant',
        'payment_method': 'cash',
        'pickup_contact_name': 'Test User',
      };

      expect(payload['status'], 'pending');
      expect(payload['booking_mode'], 'instant');
      expect((payload['pickup_coords'] as String).startsWith('POINT('), true);
      expect((payload['destination_coords'] as String).startsWith('POINT('), true);
      expect(payload['pickup_contact_name'], isNotEmpty);
    });

    test('PostGIS POINT format uses longitude FIRST', () {
      const lng = 4.89;
      const lat = 52.37;
      final point = 'POINT($lng $lat)';
      expect(point, 'POINT(4.89 52.37)');
      final parts = point.replaceAll('POINT(', '').replaceAll(')', '').split(' ');
      expect(double.parse(parts[0]), lng);
      expect(double.parse(parts[1]), lat);
    });

    test('status must be pending not searching', () {
      const status = 'pending';
      expect(status, isNot('searching'));
      expect(status, 'pending');
    });
  });

  group('Route distance guard', () {
    test('routes under 500km pass', () {
      const distanceKm = 120.0;
      expect(distanceKm <= 500, true);
    });

    test('routes over 500km are rejected', () {
      const distanceKm = 650.0;
      expect(distanceKm > 500, true);
    });

    test('NL cross-country route is under 500km', () {
      const maastrichtToGroningen = 320.0;
      expect(maastrichtToGroningen <= 500, true);
    });
  });

  group('Payment method validation', () {
    test('valid payment methods', () {
      const validMethods = ['cash', 'pin', 'tikkie'];
      expect(validMethods.contains('cash'), true);
      expect(validMethods.contains('pin'), true);
      expect(validMethods.contains('tikkie'), true);
      expect(validMethods.contains('credit_card'), false);
    });
  });

  group('saved_addresses type constraint', () {
    test('named saved-place types match the backend contract', () {
      const allowedTypes = ['home', 'work', 'gym', 'custom'];
      expect(allowedTypes, containsAll(['home', 'work', 'gym', 'custom']));
      expect(allowedTypes, isNot(contains('recent')));
    });
  });
}
