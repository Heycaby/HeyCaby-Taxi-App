import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Router registered routes', () {
    const registeredRoutes = [
      '/splash',
      '/location-required',
      '/search',
      '/marketplace',
      '/favorites',
      '/confirm',
      '/booking-options',
      '/vehicle-category',
      '/payment',
      '/summary',
      '/searching',
      '/marketplace-matching',
      '/scheduled-matching',
      '/active',
      '/chat',
      '/rating',
      '/report',
      '/ride-detail',
      '/faq',
      '/terms',
      '/privacy',
      '/home',
      '/rides',
      '/account',
    ];

    test('all navigation targets exist in router', () {
      const navigationTargets = [
        '/splash',
        '/location-required',
        '/search',
        '/marketplace',
        '/favorites',
        '/confirm',
        '/booking-options',
        '/vehicle-category',
        '/payment',
        '/summary',
        '/searching',
        '/marketplace-matching',
        '/scheduled-matching',
        '/active',
        '/chat',
        '/rating',
        '/report',
        '/ride-detail',
        '/faq',
        '/terms',
        '/privacy',
        '/home',
        '/rides',
        '/account',
      ];

      for (final target in navigationTargets) {
        expect(
          registeredRoutes.contains(target),
          true,
          reason: 'Route $target is not registered in router',
        );
      }
    });

    test('no duplicate routes', () {
      expect(registeredRoutes.toSet().length, registeredRoutes.length);
    });

    test('all routes start with /', () {
      for (final route in registeredRoutes) {
        expect(route.startsWith('/'), true, reason: 'Route $route does not start with /');
      }
    });

    test('initial route is /splash', () {
      expect(registeredRoutes.contains('/splash'), true);
    });

    test('shell routes include all tab destinations', () {
      expect(registeredRoutes.contains('/home'), true);
      expect(registeredRoutes.contains('/rides'), true);
      expect(registeredRoutes.contains('/account'), true);
    });

    test('booking flow routes are complete (legacy paths redirect)', () {
      const bookingFlow = [
        '/search',
        '/confirm',
        '/booking-options',
        '/vehicle-category',
        '/payment',
        '/summary',
        '/searching',
        '/marketplace-matching',
        '/scheduled-matching',
      ];
      for (final route in bookingFlow) {
        expect(registeredRoutes.contains(route), true, reason: 'Booking flow route $route missing');
      }
    });

    test('legal and info screen routes exist', () {
      expect(registeredRoutes.contains('/faq'), true);
      expect(registeredRoutes.contains('/terms'), true);
      expect(registeredRoutes.contains('/privacy'), true);
    });
  });
}
