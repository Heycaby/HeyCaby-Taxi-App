import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/go_online_screen.dart';
import 'screens/new_ride_request_screen.dart';
import 'screens/active_ride_screen.dart';
import 'screens/at_pickup_screen.dart';
import 'screens/ride_in_progress_screen.dart';
import 'screens/ride_complete_screen.dart';
import 'screens/rate_rider_screen.dart';
import 'screens/driver_chat_screen.dart';
import 'screens/scheduled_rides_screen.dart';
import 'screens/driver_score_screen.dart';
import 'screens/work_screen.dart';
import 'screens/me_screen.dart';
import 'screens/driver_tell_friend_screen.dart';
import 'screens/driver_preferences_screen.dart';
import 'screens/driver_profile_screen.dart';
import 'screens/driver_documents_screen.dart';
import 'screens/driver_veriff_screen.dart';
import 'screens/driver_support_screen.dart';
import 'screens/driver_faq_screen.dart';
import 'screens/driver_terms_screen.dart';
import 'screens/driver_privacy_screen.dart';
import 'screens/today_rides_screen.dart';
import 'screens/driver_power_mode_screen.dart';
import 'screens/driver_union_mode_screen.dart';
import 'screens/driver_return_trips_screen.dart';
import 'screens/ride_swap_screen.dart';
import 'screens/support_threads_screen.dart';
import 'screens/support_new_ticket_screen.dart';
import 'screens/support_chat_screen.dart';
import 'screens/vehicle_edit_screen.dart';
import 'utils/validation_utils.dart';
import 'widgets/driver_shell.dart';

/// Shared slide-up-and-fade transition for all full-screen route pushes.
Page<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(fade);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

final _authNotifier = _AuthNotifier();

const _publicRoutes = ['/splash', '/login'];

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: _authNotifier,
  errorBuilder: (context, state) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText.rich(
          TextSpan(
            style: const TextStyle(fontSize: 14, height: 1.4),
            children: [
              const TextSpan(
                text: 'Navigation error\n\n',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              TextSpan(text: state.error?.toString() ?? state.uri.toString()),
            ],
          ),
        ),
      ),
    ),
  ),
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null;
    final isPublicRoute =
        _publicRoutes.any((r) => state.matchedLocation.startsWith(r));

    if (!isLoggedIn && !isPublicRoute) return '/login';
    if (isLoggedIn && state.matchedLocation == '/login') return '/driver';

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (_, state) => _page(state, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (_, state) => _page(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/driver/go-online',
      pageBuilder: (_, state) => _page(state, const GoOnlineScreen()),
    ),
    ShellRoute(
      builder: (context, state, child) => DriverShell(child: child),
      routes: [
        GoRoute(
          path: '/driver',
          builder: (_, __) => const DriverHomeScreen(),
        ),
        GoRoute(
          path: '/driver/work',
          builder: (_, __) => const WorkScreen(),
        ),
        GoRoute(
          path: '/driver/me',
          builder: (_, __) => const DriverProfileScreen(),
        ),
        GoRoute(
          path: '/driver/community',
          builder: (_, __) => const MeScreen(),
        ),
        GoRoute(
          path: '/driver/tell-friend',
          builder: (_, __) => const DriverTellFriendScreen(),
        ),
        GoRoute(
          path: '/driver/preferences',
          builder: (_, __) => const DriverPreferencesScreen(),
        ),
        GoRoute(
          path: '/driver/vehicle',
          builder: (_, __) => const VehicleEditScreen(),
        ),
        GoRoute(
          path: '/driver/profile',
          redirect: (_, __) => '/driver/me',
        ),
        GoRoute(
          path: '/driver/documents',
          builder: (_, __) => const DriverDocumentsScreen(),
        ),
        GoRoute(
          path: '/driver/veriff',
          builder: (_, __) => const DriverVeriffScreen(),
        ),
        GoRoute(
          path: '/driver/support',
          builder: (_, __) => const DriverSupportScreen(),
        ),
        GoRoute(
          path: '/driver/support/threads',
          builder: (_, __) => const SupportThreadsScreen(),
        ),
        GoRoute(
          path: '/driver/support/new',
          builder: (_, __) => const SupportNewTicketScreen(),
        ),
        GoRoute(
          path: '/driver/support/chat/:ticketId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['ticketId'])) {
              return '/driver/support';
            }
            return null;
          },
          builder: (_, state) {
            final ticketId = state.pathParameters['ticketId']!;
            return SupportChatScreen(ticketId: ticketId);
          },
        ),
        GoRoute(
          path: '/driver/faq',
          builder: (_, __) => const DriverFaqScreen(),
        ),
        GoRoute(
          path: '/driver/terms',
          builder: (_, __) => const DriverTermsScreen(),
        ),
        GoRoute(
          path: '/driver/privacy',
          builder: (_, __) => const DriverPrivacyScreen(),
        ),
        GoRoute(
          path: '/driver/rides/today',
          builder: (_, __) => const TodayRidesScreen(),
        ),
        GoRoute(
          path: '/driver/help-articles',
          builder: (_, __) => const DriverFaqScreen(),
        ),
        GoRoute(
          path: '/driver/power-mode',
          builder: (_, __) => const DriverPowerModeScreen(),
        ),
        GoRoute(
          path: '/driver/union-mode',
          builder: (_, __) => const DriverUnionModeScreen(),
        ),
        GoRoute(
          path: '/driver/return-trips',
          builder: (_, __) => const DriverReturnTripsScreen(),
        ),
        GoRoute(
          path: '/driver/ride/new/:rideId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['rideId'])) return '/driver';
            return null;
          },
          pageBuilder: (_, state) {
            final rideId = state.pathParameters['rideId']!;
            return _page(state, NewRideRequestScreen(rideId: rideId));
          },
        ),
        GoRoute(
          path: '/driver/ride/active/:rideId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['rideId'])) return '/driver';
            return null;
          },
          pageBuilder: (_, state) {
            final rideId = state.pathParameters['rideId']!;
            return _page(state, ActiveRideScreen(rideId: rideId));
          },
        ),
        GoRoute(
          path: '/driver/ride/pickup/:rideId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['rideId'])) return '/driver';
            return null;
          },
          pageBuilder: (_, state) {
            final rideId = state.pathParameters['rideId']!;
            return _page(state, AtPickupScreen(rideId: rideId));
          },
        ),
        GoRoute(
          path: '/driver/ride/progress/:rideId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['rideId'])) return '/driver';
            return null;
          },
          pageBuilder: (_, state) {
            final rideId = state.pathParameters['rideId']!;
            return _page(state, RideInProgressScreen(rideId: rideId));
          },
        ),
        GoRoute(
          path: '/driver/ride/complete/:rideId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['rideId'])) return '/driver';
            return null;
          },
          pageBuilder: (_, state) {
            final rideId = state.pathParameters['rideId']!;
            return _page(state, RideCompleteScreen(rideId: rideId));
          },
        ),
        GoRoute(
          path: '/driver/ride/rate/:rideId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['rideId'])) return '/driver';
            return null;
          },
          pageBuilder: (_, state) {
            final rideId = state.pathParameters['rideId']!;
            return _page(state, RateRiderScreen(rideId: rideId));
          },
        ),
        GoRoute(
          path: '/driver/chat/:rideId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['rideId'])) return '/driver';
            return null;
          },
          pageBuilder: (_, state) {
            final rideId = state.pathParameters['rideId']!;
            return _page(state, DriverChatScreen(rideId: rideId));
          },
        ),
        GoRoute(
          path: '/driver/scheduled-rides',
          builder: (_, __) => const ScheduledRidesScreen(),
        ),
        GoRoute(
          path: '/driver/ride-swap',
          builder: (_, __) => const RideSwapScreen(),
        ),
        GoRoute(
          path: '/driver/score',
          builder: (_, __) => const DriverScoreScreen(),
        ),
      ],
    ),
  ],
);
