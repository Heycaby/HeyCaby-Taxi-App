import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show Scaffold, Widget, Page, FadeTransition, SlideTransition;
import 'package:flutter/animation.dart'
    show Curves, Tween, Offset, CurvedAnimation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'
    show GoRouter, GoRouterState, CustomTransitionPage, GoRoute, ShellRoute;

import 'providers/booking_provider.dart';
import 'providers/ride_request_provider.dart';
import 'services/booking_flow_navigation.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rides_screen.dart';
import 'screens/account_screen.dart';
import 'screens/rider_tell_friend_screen.dart';
import 'screens/search_screen.dart';
import 'screens/marketplace_matching_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/airport_booking_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/vehicle_category_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/trip_summary_screen.dart';
import 'screens/searching_screen.dart';
import 'models/rating_route_args.dart';
import 'models/ride_matching_variant.dart';
import 'screens/active_ride_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/rating_screen.dart';
import 'widgets/rider_driver_info_card.dart';
import 'screens/report_screen.dart';
import 'providers/near_term_ride_request_provider.dart';
import 'screens/ride_detail_screen.dart';
import 'screens/upcoming_ride_request_detail_screen.dart';
import 'screens/location_required_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/rider_announcement_web_screen.dart';
import 'utils/rider_home_banner_actions.dart';
import 'screens/rider_support_screen.dart';
import 'screens/rider_support_threads_screen.dart';
import 'screens/rider_support_new_ticket_screen.dart';
import 'screens/rider_support_chat_screen.dart';
import 'screens/rider_support_yaz_screen.dart';
import 'screens/rider_receipt_screen.dart';
import 'screens/taxi_terug_screen.dart';
import 'screens/saved_addresses_screen.dart';
import 'widgets/rider_shell.dart';
import 'providers/ride_history_provider.dart';

/// Smooth slide-up-and-fade transition used for all full-screen pushes.
/// 280 ms forward / 220 ms reverse keeps it snappy while feeling premium.
Page<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 90),
    reverseTransitionDuration: const Duration(milliseconds: 70),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.linearToEaseOut,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.012),
        end: Offset.zero,
      ).animate(fade);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

class _BookingRouteRefresh extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// Drives [GoRouter.refreshListenable] when [bookingProvider] changes.
final bookingRouteRefreshProvider = Provider<_BookingRouteRefresh>((ref) {
  final notifier = _BookingRouteRefresh();
  ref.listen<BookingState>(bookingProvider, (_, __) => notifier.tick());
  ref.onDispose(notifier.dispose);
  return notifier;
});

String? _bookingRouteRedirect(Ref ref, GoRouterState state) {
  final booking = ref.read(bookingProvider);
  final path = state.matchedLocation;

  if (path == '/summary') {
    if (booking.pickup == null || booking.destination == null) {
      return '/search';
    }
  }

  if (path == '/payment') {
    if (booking.pickup == null || booking.destination == null) {
      return '/search';
    }
    final vc = booking.vehicleCategory?.trim() ?? '';
    if (vc.isEmpty) return '/vehicle-category';
  }

  return null;
}

bool _isRideChatAllowed(String? status) {
  const activeStatuses = {
    'assigned',
    'accepted',
    'driver_found',
    'driver_en_route',
    'driver_arrived',
    'arrived',
    'in_progress',
  };
  return status != null && activeStatuses.contains(status);
}

bool _isActiveRideStatus(String? status) {
  const activeStatuses = {
    'assigned',
    'accepted',
    'driver_found',
    'driver_en_route',
    'driver_arrived',
    'arrived',
    'in_progress',
  };
  return status != null && activeStatuses.contains(status);
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(bookingRouteRefreshProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => _bookingRouteRedirect(ref, state),
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => _page(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/location-required',
        pageBuilder: (_, state) => _page(state, const LocationRequiredScreen()),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, state) {
          final extra = state.extra;
          final args = extra is BookingSearchRouteArgs ? extra : null;
          return _page(state, SearchScreen(args: args));
        },
      ),
      GoRoute(
        path: '/taxi-terug',
        pageBuilder: (_, state) => _page(state, const TaxiTerugScreen()),
      ),
      GoRoute(
        path: '/marketplace',
        pageBuilder: (_, state) => _page(state, const MarketplaceScreen()),
      ),
      GoRoute(
        path: '/airport-booking',
        pageBuilder: (_, state) => _page(state, const AirportBookingScreen()),
      ),
      GoRoute(
        path: '/favorites',
        pageBuilder: (_, state) => _page(state, const FavoritesScreen()),
      ),
      GoRoute(
        path: '/saved-addresses',
        pageBuilder: (_, state) => _page(state, const SavedAddressesScreen()),
      ),
      // Legacy compatibility only (deep links, old bookmarks, stale docs).
      // Canonical flow is search → smart next; consider removing once unused.
      GoRoute(
        path: '/confirm',
        redirect: (context, state) {
          final b = ref.read(bookingProvider);
          if (b.pickup == null || b.destination == null) return '/search';
          return BookingFlowNavigation.routeAfterAddressesComplete(b);
        },
      ),
      GoRoute(
        path: '/booking-options',
        redirect: (context, state) {
          final b = ref.read(bookingProvider);
          if (b.pickup == null || b.destination == null) return '/search';
          return BookingFlowNavigation.routeAfterAddressesComplete(b);
        },
      ),
      GoRoute(
        path: '/vehicle-category',
        pageBuilder: (_, state) => _page(
          state,
          VehicleCategoryScreen(
            returnToSummaryAfterSave:
                state.extra == kBookingReturnToSummaryExtra,
          ),
        ),
      ),
      GoRoute(
        path: '/payment',
        pageBuilder: (_, state) => _page(
          state,
          PaymentScreen(
            returnToSummaryAfterSave:
                state.extra == kBookingReturnToSummaryExtra,
          ),
        ),
      ),
      GoRoute(
        path: '/summary',
        pageBuilder: (_, state) => _page(state, const TripSummaryScreen()),
      ),
      GoRoute(
        path: '/searching',
        pageBuilder: (_, state) => _page(
          state,
          const SearchingScreen(variant: RideMatchingVariant.instant),
        ),
      ),
      GoRoute(
        path: '/marketplace-matching',
        pageBuilder: (_, state) => _page(
          state,
          const MarketplaceMatchingScreen(),
        ),
      ),
      GoRoute(
        path: '/scheduled-matching',
        pageBuilder: (_, state) => _page(
          state,
          const SearchingScreen(variant: RideMatchingVariant.scheduled),
        ),
      ),
      GoRoute(
        path: '/active',
        redirect: (context, state) {
          final ride = ref.read(rideRequestProvider);
          final hasRide = (ride.rideRequestId?.trim().isNotEmpty ?? false);
          if (hasRide && _isActiveRideStatus(ride.status)) {
            return null;
          }
          if (hasRide &&
              (ride.status == 'pending' || ride.status == 'bidding')) {
            return rideMatchingVariantForBookingModeString(ride.bookingMode)
                .routePath;
          }
          return '/home';
        },
        pageBuilder: (_, state) => _page(state, const ActiveRideScreen()),
      ),
      GoRoute(
        path: '/chat',
        redirect: (context, state) {
          final rideStatus = ref.read(rideRequestProvider).status;
          if (!_isRideChatAllowed(rideStatus)) {
            return '/home';
          }
          return null;
        },
        pageBuilder: (_, state) => _page(state, const ChatScreen()),
      ),
      GoRoute(
        path: '/rating',
        pageBuilder: (_, state) {
          final extra = state.extra;
          RatingRouteArgs? routeArgs;
          if (extra is RatingRouteArgs) {
            routeArgs = extra;
          } else if (extra is RiderDriverSheetInfo) {
            routeArgs = RatingRouteArgs(driverInfo: extra);
          }
          return _page(
            state,
            RatingScreen(routeArgs: routeArgs),
          );
        },
      ),
      GoRoute(
        path: '/report',
        pageBuilder: (_, state) {
          final extra = state.extra;
          String? ridesRowId;
          var fromActiveRide = false;
          if (extra is ReportRouteArgs) {
            ridesRowId = extra.ridesRowId;
            fromActiveRide = extra.fromActiveRide;
          } else if (extra is String) {
            ridesRowId = extra;
          }
          return _page(
            state,
            ReportScreen(
              prefilledRidesRowId: ridesRowId,
              fromActiveRide: fromActiveRide,
            ),
          );
        },
      ),
      GoRoute(
        path: '/ride-detail',
        pageBuilder: (context, state) {
          final ride = state.extra;
          if (ride is! RideHistoryItem) {
            return _page(state, const Scaffold());
          }
          return _page(state, RideDetailScreen(ride: ride));
        },
      ),
      GoRoute(
        path: '/receipt/:rideId',
        redirect: (context, state) {
          final rideId = state.pathParameters['rideId'];
          if (rideId == null || rideId.trim().isEmpty) return '/rides';
          return null;
        },
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId']!;
          return _page(state, RiderReceiptScreen(rideRequestId: rideId));
        },
      ),
      GoRoute(
        path: '/upcoming-ride',
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! NearTermRideSnapshot) {
            return _page(state, const Scaffold());
          }
          return _page(state, UpcomingRideRequestDetailScreen(snap: extra));
        },
      ),
      GoRoute(
        path: '/faq',
        pageBuilder: (_, state) => _page(state, const FaqScreen()),
      ),
      GoRoute(
        path: '/terms',
        pageBuilder: (_, state) => _page(state, const TermsScreen()),
      ),
      GoRoute(
        path: '/privacy',
        pageBuilder: (_, state) => _page(state, const PrivacyScreen()),
      ),
      GoRoute(
        path: '/announcement-web',
        pageBuilder: (_, state) {
          final extra = state.extra;
          if (extra is! RiderAnnouncementWebRouteArgs) {
            return _page(state, const Scaffold());
          }
          return _page(
            state,
            RiderAnnouncementWebScreen(url: extra.url, title: extra.title),
          );
        },
      ),
      GoRoute(
        path: '/support',
        pageBuilder: (_, state) => _page(state, const RiderSupportScreen()),
      ),
      GoRoute(
        path: '/support/threads',
        pageBuilder: (_, state) =>
            _page(state, const RiderSupportThreadsScreen()),
      ),
      GoRoute(
        path: '/support/new',
        pageBuilder: (_, state) =>
            _page(state, const RiderSupportNewTicketScreen()),
      ),
      GoRoute(
        path: '/support/yaz',
        pageBuilder: (_, state) => _page(state, const RiderSupportYazScreen()),
      ),
      GoRoute(
        path: '/support/chat/:ticketId',
        redirect: (context, state) {
          final ticketId = state.pathParameters['ticketId'];
          if (ticketId == null || ticketId.trim().isEmpty) {
            return '/support';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final ticketId = state.pathParameters['ticketId']!;
          return _page(state, RiderSupportChatScreen(ticketId: ticketId));
        },
      ),
      ShellRoute(
        builder: (context, state, child) => RiderShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/rides', builder: (_, __) => const RidesScreen()),
          GoRoute(
            path: '/tell-friend',
            builder: (_, __) => const RiderTellFriendScreen(),
          ),
          GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
          GoRoute(
            path: '/settings',
            builder: (_, __) =>
                const AccountScreen(mode: AccountScreenMode.settings),
          ),
        ],
      ),
    ],
  );
});
