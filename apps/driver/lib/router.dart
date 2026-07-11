import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
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
import 'screens/driver_tariff_editor_screen.dart';
import 'screens/driver_hotspots_screen.dart';
import 'screens/driver_community_hub_screen.dart';
import 'screens/driver_community_channel_feed_screen.dart';
import 'screens/driver_tell_friend_screen.dart';
import 'screens/driver_preferences_screen.dart';
import 'screens/driver_profile_screen.dart';
import 'screens/driver_settings_screen.dart';
import 'screens/driver_documents_screen.dart';
import 'screens/driver_veriff_screen.dart';
import 'screens/driver_fleet_allowlist_screen.dart';
import 'screens/driver_fleet_allowlist_vehicle_screen.dart';
import 'screens/driver_shift_handover_audit_screen.dart';
import 'screens/driver_support_screen.dart';
import 'screens/driver_faq_screen.dart';
import 'screens/driver_terms_screen.dart';
import 'screens/driver_privacy_screen.dart';
import 'screens/driver_indemnification_screen.dart';
import 'screens/driver_app_suggestion_screen.dart';
import 'screens/today_rides_screen.dart';
import 'screens/driver_return_trips_screen.dart';
import 'screens/driver_journey_intent_screen.dart';
import 'screens/driver_taxi_thru_screen.dart';
import 'screens/ride_swap_screen.dart';
import 'screens/support_threads_screen.dart';
import 'screens/support_new_ticket_screen.dart';
import 'screens/support_chat_screen.dart';
import 'screens/support_lee_screen.dart';
import 'screens/vehicle_edit_screen.dart';
import 'screens/driver_billing_screen.dart';
import 'screens/driver_billing_history_screen.dart';
import 'screens/driver_finance_screen.dart';
import 'screens/driver_runtime_gate_screen.dart';
import 'screens/driver_my_rides_screen.dart';
import 'screens/driver_plate_onboarding_screen.dart';
import 'screens/driver_ride_detail_screen.dart';
import 'l10n/driver_strings.dart';
import 'utils/validation_utils.dart';
import 'widgets/driver_shell.dart';

/// Shell stack: zero-duration page — tab/detail swaps feel instant (no MaterialPage fade).
Page<void> _shellPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

/// Full-screen modal-style routes: very short fade-only transition.
Page<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 48),
    reverseTransitionDuration: const Duration(milliseconds: 36),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(opacity: fade, child: child);
    },
  );
}

/// One crisp haptic per navigation change. **Two instances required:** Flutter asserts if the
/// same [NavigatorObserver] is attached to more than one [Navigator] (root + shell).
final _rootNavigationHaptics = _DriverNavigationHapticsObserver();
final _shellNavigationHaptics = _DriverNavigationHapticsObserver();

class _DriverNavigationHapticsObserver extends NavigatorObserver {
  bool _skipFirstRouteEvent = true;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _tick() {
    if (_skipFirstRouteEvent) {
      _skipFirstRouteEvent = false;
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastAt).inMilliseconds < 42) return;
    _lastAt = now;
    HapticService.selectionClick();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _tick();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _tick();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _tick();
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
  observers: <NavigatorObserver>[_rootNavigationHaptics],
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
    final loc = state.matchedLocation;
    final isPublicRoute = _publicRoutes.any((r) => loc.startsWith(r));

    if (!isLoggedIn && !isPublicRoute) return '/login';
    // Logged-in users re-enter through splash (runtime decides next step).
    if (isLoggedIn && loc.startsWith('/login')) return '/splash';

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
      path: '/driver/onboarding/plate',
      pageBuilder: (_, state) =>
          _page(state, const DriverPlateOnboardingScreen()),
    ),
    GoRoute(
      path: '/driver/go-online',
      pageBuilder: (_, state) => _page(state, const GoOnlineScreen()),
    ),
    GoRoute(
      path: '/driver/runtime-gate',
      pageBuilder: (_, state) {
        final args = state.extra;
        if (args is! DriverRuntimeGateArgs) {
          return _page(
            state,
            DriverRuntimeGateScreen(
              args: DriverRuntimeGateArgs(
                title: DriverStrings.runtimeUnknownBlockedTitle,
                body: DriverStrings.runtimeUnknownBlockedBody,
              ),
            ),
          );
        }
        return _page(state, DriverRuntimeGateScreen(args: args));
      },
    ),
    ShellRoute(
      observers: <NavigatorObserver>[_shellNavigationHaptics],
      builder: (context, state, child) => DriverShell(child: child),
      routes: [
        GoRoute(
          path: '/driver',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverHomeScreen()),
        ),
        GoRoute(
          path: '/driver/work',
          pageBuilder: (_, state) => _shellPage(state, const WorkScreen()),
        ),
        GoRoute(
          path: '/driver/tariffs',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverTariffEditorScreen()),
        ),
        GoRoute(
          path: '/driver/hotspots',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverHotspotsScreen()),
        ),
        GoRoute(
          path: '/driver/me',
          pageBuilder: (_, state) => _shellPage(
            state,
            DriverProfileScreen(
              initialAction: state.uri.queryParameters['action'],
              returnAfterAction: state.uri.queryParameters['return'] == '1',
            ),
          ),
        ),
        GoRoute(
          path: '/driver/settings',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverSettingsScreen()),
        ),
        GoRoute(
          path: '/driver/community',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverCommunityHubScreen()),
        ),
        GoRoute(
          path: '/driver/community/feed',
          pageBuilder: (_, state) {
            final raw = state.uri.queryParameters['channel'] ?? 'general';
            final channel =
                raw == 'announcements' ? 'announcements' : 'general';
            return _shellPage(
              state,
              DriverCommunityChannelFeedScreen(channel: channel),
            );
          },
        ),
        GoRoute(
          path: '/driver/tell-friend',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverTellFriendScreen()),
        ),
        GoRoute(
          path: '/driver/my-rides',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverMyRidesScreen()),
        ),
        GoRoute(
          path: '/driver/my-rides/:rideId',
          redirect: (_, state) {
            if (!isValidUuid(state.pathParameters['rideId'])) {
              return '/driver/my-rides';
            }
            return null;
          },
          pageBuilder: (_, state) => _shellPage(
            state,
            DriverRideDetailScreen(rideId: state.pathParameters['rideId']!),
          ),
        ),
        GoRoute(
          path: '/driver/preferences',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverPreferencesScreen()),
        ),
        GoRoute(
          path: '/driver/billing',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverBillingScreen()),
        ),
        GoRoute(
          path: '/driver/billing/history',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverBillingHistoryScreen()),
        ),
        GoRoute(
          path: '/driver/finance',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverFinanceScreen()),
        ),
        GoRoute(
          path: '/driver/vehicle',
          pageBuilder: (_, state) =>
              _shellPage(state, const VehicleEditScreen()),
        ),
        GoRoute(
          path: '/driver/profile',
          redirect: (_, __) => '/driver/me',
        ),
        GoRoute(
          path: '/driver/documents',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverDocumentsScreen()),
        ),
        GoRoute(
          path: '/driver/veriff',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverVeriffScreen()),
        ),
        GoRoute(
          path: '/driver/admin/shift-handovers',
          pageBuilder: (_, state) => _shellPage(
            state,
            const DriverShiftHandoverAuditScreen(),
          ),
        ),
        GoRoute(
          path: '/driver/fleet/allowlist',
          pageBuilder: (_, state) => _shellPage(
            state,
            const DriverFleetAllowlistScreen(),
          ),
        ),
        GoRoute(
          path: '/driver/fleet/allowlist/:vehicleId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['vehicleId'])) {
              return '/driver/fleet/allowlist';
            }
            return null;
          },
          pageBuilder: (_, state) {
            final vehicleId = state.pathParameters['vehicleId']!;
            final plate =
                state.extra is String ? state.extra! as String : vehicleId;
            return _shellPage(
              state,
              DriverFleetAllowlistVehicleScreen(
                vehicleId: vehicleId,
                plateDisplay: plate,
              ),
            );
          },
        ),
        GoRoute(
          path: '/driver/support',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverSupportScreen()),
        ),
        GoRoute(
          path: '/driver/support/threads',
          pageBuilder: (_, state) =>
              _shellPage(state, const SupportThreadsScreen()),
        ),
        GoRoute(
          path: '/driver/support/new',
          pageBuilder: (_, state) =>
              _shellPage(state, const SupportNewTicketScreen()),
        ),
        GoRoute(
          path: '/driver/support/lee',
          pageBuilder: (_, state) =>
              _shellPage(state, const SupportLeeScreen()),
        ),
        GoRoute(
          path: '/driver/support/chat/:ticketId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['ticketId'])) {
              return '/driver/support';
            }
            return null;
          },
          pageBuilder: (_, state) {
            final ticketId = state.pathParameters['ticketId']!;
            return _shellPage(state, SupportChatScreen(ticketId: ticketId));
          },
        ),
        GoRoute(
          path: '/driver/faq',
          pageBuilder: (_, state) => _shellPage(state, const DriverFaqScreen()),
        ),
        GoRoute(
          path: '/driver/terms',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverTermsScreen()),
        ),
        GoRoute(
          path: '/driver/privacy',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverPrivacyScreen()),
        ),
        GoRoute(
          path: '/driver/indemnification',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverIndemnificationScreen()),
        ),
        GoRoute(
          path: '/driver/rides/today',
          pageBuilder: (_, state) {
            final filter = state.uri.queryParameters['filter'];
            final initialFilter = switch (filter) {
              'upcoming' => TodayFilter.upcoming,
              'completed' => TodayFilter.completed,
              'cancelled' => TodayFilter.cancelled,
              _ => TodayFilter.all,
            };
            return _shellPage(
              state,
              TodayRidesScreen(initialFilter: initialFilter),
            );
          },
        ),
        GoRoute(
          path: '/driver/help-articles',
          pageBuilder: (_, state) => _shellPage(state, const DriverFaqScreen()),
        ),
        GoRoute(
          path: '/driver/app-suggestion',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverAppSuggestionScreen()),
        ),
        GoRoute(
          path: '/driver/return-trips',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverReturnTripsScreen()),
        ),
        GoRoute(
          path: '/driver/journey-intent',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverJourneyIntentScreen()),
        ),
        GoRoute(
          path: '/driver/taxi-thru',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverTaxiThruScreen()),
        ),
        GoRoute(
          path: '/driver/ride/new/:rideId',
          redirect: (context, state) {
            if (!isValidUuid(state.pathParameters['rideId'])) return '/driver';
            return null;
          },
          pageBuilder: (_, state) {
            final rideId = state.pathParameters['rideId']!;
            final extra = state.extra;
            final urgent = extra is Map && extra['urgent'] is bool
                ? extra['urgent'] as bool
                : true;
            final inviteId =
                extra is Map ? extra['inviteId']?.toString() : null;
            return _page(
              state,
              NewRideRequestScreen(
                rideId: rideId,
                inviteId: inviteId,
                urgent: urgent,
              ),
            );
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
          pageBuilder: (_, state) =>
              _shellPage(state, const ScheduledRidesScreen()),
        ),
        GoRoute(
          path: '/driver/ride-swap',
          pageBuilder: (_, state) => _shellPage(state, const RideSwapScreen()),
        ),
        GoRoute(
          path: '/driver/score',
          pageBuilder: (_, state) =>
              _shellPage(state, const DriverScoreScreen()),
        ),
      ],
    ),
  ],
);
