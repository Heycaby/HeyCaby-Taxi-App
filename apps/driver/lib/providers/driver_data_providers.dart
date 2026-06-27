import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../models/driver_payment_ledger_item.dart';
import '../services/driver_billing_service.dart';
import '../services/driver_data_service.dart';
import '../services/driver_shift_session_service.dart';
import '../services/ride_swap_service.dart';
import 'driver_state_provider.dart';
import 'driver_location_provider.dart';

final driverDataServiceProvider = Provider<DriverDataService>((_) => DriverDataService());

/// Web founding-driver claim; home screen shows a one-time welcome when set.
final foundingDriverPostClaimProvider =
    StateProvider<ClaimFoundingDriverResult?>((ref) => null);

final rideSwapServiceProvider = Provider<RideSwapService>((_) => RideSwapService());

/// Open ride swap listings, sorted by urgency + pickup time + proximity (urgent/emergency).
final rideSwapFeedProvider = FutureProvider<List<RideSwapListing>>((ref) async {
  final svc = ref.watch(rideSwapServiceProvider);
  final raw = await svc.fetchOpenSwaps();
  final pos = ref.watch(driverLocationProvider).valueOrNull;
  return svc.sortForFeed(
    raw,
    driverLat: pos?.latitude,
    driverLng: pos?.longitude,
  );
});

/// Persisted “Niet meer tonen” for the Ritwissel intro bottom sheet; invalidate after saving.
final rideSwapIntroDismissedProvider = FutureProvider<bool>((ref) async {
  return ref.read(driverDataServiceProvider).isRideSwapIntroDismissed();
});

final driverShiftSessionServiceProvider =
    Provider<DriverShiftSessionService>((_) => DriverShiftSessionService());

/// Driver display name: `drivers.full_name` first, then auth metadata — **not** email (privacy).
final driverDisplayNameProvider = Provider<String>((ref) {
  final fromDb = ref.watch(driverProfileProvider).valueOrNull?.fullName?.trim();
  if (fromDb != null && fromDb.isNotEmpty) return fromDb;
  final user = HeyCabySupabase.client.auth.currentUser;
  if (user == null) return 'Driver';
  final meta = user.userMetadata;
  if (meta != null) {
    final name = meta['full_name'] ?? meta['name'];
    if (name is String && name.isNotEmpty) return name;
  }
  return 'Driver';
});

/// Resolved driver_id. Invalidates when user logs out.
final driverIdProvider = FutureProvider<String?>((ref) async {
  ref.watch(driverStateProvider);
  final userId = HeyCabySupabase.client.auth.currentUser?.id;
  if (userId == null) return null;
  return ref.read(driverDataServiceProvider).getDriverId();
});

/// Earnings summary. Refetch when returning to home or after ride complete.
final driverEarningsProvider = FutureProvider<DriverEarningsSummary?>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return null;
  return ref.read(driverDataServiceProvider).getEarningsSummary(id);
});

/// Zone demand for map circles. Poll every 30s from home screen via ref.invalidate.
final zoneDemandProvider = FutureProvider<List<ZoneDemand>>((ref) async {
  final service = ref.read(driverDataServiceProvider);
  return service.getZoneDemand();
});

/// Shift stats for online panel. Refetch when opening panel or going online.
final driverShiftStatsProvider = FutureProvider<DriverShiftStats?>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return null;
  return ref.read(driverDataServiceProvider).getShiftStats(id);
});

/// Trust score + category averages + flags from `driver_my_rating` view (migration 040).
final driverMyRatingProvider = FutureProvider<DriverMyRating?>((ref) async {
  await ref.watch(driverIdProvider.future);
  return ref.read(driverDataServiceProvider).getDriverMyRating();
});

/// Rate profiles for earnings modal and Driver Hub.
final driverRateProfilesProvider = FutureProvider<List<DriverRateProfile>>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return [];
  return ref.read(driverDataServiceProvider).getRateProfiles(id);
});

/// Active rate profile (is_active = true). Null if none.
final activeRateProfileProvider = FutureProvider<DriverRateProfile?>((ref) async {
  final list = await ref.watch(driverRateProfilesProvider.future);
  for (final p in list) {
    if (p.isActive) return p;
  }
  return null;
});

final driverBillingServiceProvider =
    Provider<DriverBillingService>((_) => const DriverBillingService());

/// Billing/payment status — Supabase ledger V1 (Phase E; no Go fallback).
final driverBillingStatusProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  await ref.watch(driverIdProvider.future);
  return ref.read(driverBillingServiceProvider).fetchBillingStatus();
});

/// Platform fee ledger — Supabase [fn_driver_billing_ledger_history] only.
final driverPaymentLedgerProvider =
    FutureProvider<List<DriverPaymentLedgerItem>>((ref) async {
  await ref.watch(driverIdProvider.future);
  final ledgerRows =
      await ref.read(driverBillingServiceProvider).fetchLedgerHistory();
  return ledgerRows.map(DriverPaymentLedgerItem.fromMap).toList();
});

/// Driver Hub badge count (open tickets + unresolved safety events). 10 = show "9+".
final driverHubBadgeCountProvider = FutureProvider<int>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  final driver = ref.watch(driverStateProvider);
  if (id == null || driver.userId == null) return 0;
  return ref.read(driverDataServiceProvider).getHubBadgeCount(id, driver.userId);
});

/// Earnings targets (daily/weekly) for Driver Hub.
final driverEarningsTargetsProvider = FutureProvider<Map<String, double>>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return {};
  return ref.read(driverDataServiceProvider).getEarningsTargets(id);
});

/// Recent tickets for Driver Hub help section.
final driverRecentTicketsProvider = FutureProvider<List<DriverTicket>>((ref) async {
  final userId = ref.watch(driverStateProvider).userId;
  return ref.read(driverDataServiceProvider).getRecentTickets(userId, limit: 3);
});

/// Scheduled rides count/cards. For home sheet and scheduled screen.
final scheduledRidesProvider = FutureProvider<List<ScheduledRide>>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return [];
  final service = ref.read(driverDataServiceProvider);
  return service.getScheduledRidesAvailable(driverId: id, tab: 'requests');
});

/// Feasible scheduled count (no overlap). Cached 60s in service.
final feasibleScheduledCountProvider = FutureProvider<int>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return 0;
  return ref.read(driverDataServiceProvider).getFeasibleScheduledCount(id);
});

/// Scheduled rides by tab: 'requests' or 'confirmed'.
final scheduledRidesByTabProvider =
    FutureProvider.family<List<ScheduledRide>, String>((ref, tab) async {
  final id = await ref.watch(driverIdProvider.future);
  final service = ref.read(driverDataServiceProvider);
  return service.getScheduledRidesAvailable(driverId: id, tab: tab);
});

/// Rides assigned to current driver (for swap post creation).
final driverAssignedRidesProvider = FutureProvider<List<ScheduledRide>>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return [];
  return ref.read(driverDataServiceProvider).getDriverAssignedRides(id);
});

/// Immediate ride requests (Now tab in Available rides).
final availableRidesNowProvider = FutureProvider<List<ScheduledRide>>((ref) async {
  final zoneId = await ref.watch(currentZoneIdProvider.future);
  return ref.read(driverDataServiceProvider).getAvailableRidesNow(zoneId: zoneId);
});

/// Marketplace ride requests (Marketplace tab in Available rides).
final availableMarketplaceRidesProvider =
    FutureProvider<List<ScheduledRide>>((ref) async {
  final zoneId = await ref.watch(currentZoneIdProvider.future);
  return ref
      .read(driverDataServiceProvider)
      .getAvailableMarketplaceRides(zoneId: zoneId);
});

/// Current zone ID from driver_locations.
final currentZoneIdProvider = FutureProvider<String?>((ref) async {
  return ref.read(driverDataServiceProvider).getCurrentZoneId();
});

/// Current zone name from driver_locations + bubble_zones.
final currentZoneNameProvider = FutureProvider<String?>((ref) async {
  return ref.read(driverDataServiceProvider).getCurrentZoneName();
});

/// Passenger comments for driver score screen.
final driverCommentsProvider = FutureProvider<List<DriverComment>>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return [];
  return ref.read(driverDataServiceProvider).getPassengerComments(id);
});

/// Hidden comment IDs (dismissed by driver).
final driverHiddenCommentIdsProvider = FutureProvider<Set<String>>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return {};
  return ref.read(driverDataServiceProvider).getHiddenCommentIds(id);
});

/// Filtered passenger comments (excluding dismissed).
final driverCommentsFilteredProvider = FutureProvider<List<DriverComment>>((ref) async {
  final comments = await ref.watch(driverCommentsProvider.future);
  final hidden = await ref.watch(driverHiddenCommentIdsProvider.future);
  return comments.where((c) => c.ratingId == null || !hidden.contains(c.ratingId!)).toList();
});

/// Today's ride list for Earnings sub-tab.
final todayRidesProvider = FutureProvider<List<TodayRide>>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return [];
  return ref.read(driverDataServiceProvider).getTodayRides(id);
});

/// All rides for the current driver (history list for My Rides tab).
final myRidesProvider = FutureProvider<List<MyRideSummary>>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return [];
  return ref.read(driverDataServiceProvider).getMyRides(id);
});

/// Detail payload for one ride entry in My Rides.
final myRideDetailsProvider =
    FutureProvider.family<MyRideDetails?, String>((ref, rideId) async {
  if (rideId.trim().isEmpty) return null;
  return ref.read(driverDataServiceProvider).getMyRideDetails(rideId);
});

/// Last 7 days daily earnings for weekly chart.
final weeklyDailyEarningsProvider = FutureProvider<List<double>>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return List.filled(7, 0.0);
  return ref.read(driverDataServiceProvider).getWeeklyDailyEarnings(id);
});

/// Community posts by channel.
final communityPostsProvider = FutureProvider.family<List<CommunityPost>, String>((ref, channel) async {
  return ref.read(driverDataServiceProvider).getCommunityPosts(channel);
});

/// Same source as [communityPostsProvider] but a higher limit for the full-channel feed screen.
final communityChannelFeedProvider =
    FutureProvider.family<List<CommunityPost>, String>((ref, channel) async {
  return ref.read(driverDataServiceProvider).getCommunityPosts(channel, limit: 100);
});

/// Driver notifications for Community bell sheet (latest first).
final communityNotificationsProvider =
    FutureProvider<List<DriverNotificationItem>>((ref) async {
  try {
    return await ref.read(driverApiProvider).getNotifications(unreadOnly: false, limit: 40);
  } catch (_) {
    // Do not fail the community screen if backend auth/session for this endpoint is stale.
    return const [];
  }
});

/// Unread count for the Community bell badge.
final communityUnreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final all = await ref.watch(communityNotificationsProvider.future);
  return all.where((n) => n.isUnread).length;
});

/// Driver profile for Me tab.
final driverProfileProvider = FutureProvider<DriverProfile?>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return null;
  return ref.read(driverDataServiceProvider).getDriverProfile(id);
});

/// Dutch compliance + documents (Wpv 2000) — reads extended `drivers` columns.
final driverComplianceProvider = FutureProvider<DriverComplianceSnapshot?>((ref) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return null;
  return ref.read(driverDataServiceProvider).getDriverCompliance(id);
});

/// Return trips (driver_return_trips view).
final driverReturnTripsProvider = FutureProvider<List<DriverReturnTrip>>((ref) async {
  return ref.read(driverDataServiceProvider).getReturnTrips();
});

/// Filtered return trips — only rides heading toward driver's home zone or city.
final filteredReturnTripsProvider = FutureProvider<List<DriverReturnTrip>>((ref) async {
  final all = await ref.watch(driverReturnTripsProvider.future);
  final profile = await ref.watch(driverProfileProvider.future);
  final headingHomeZoneId = profile?.headingHomeZoneId;
  final homeCity = profile?.homeCity;

  if (headingHomeZoneId == null || headingHomeZoneId.isEmpty) return all;

  final cityLower = homeCity?.toLowerCase().trim();
  return all.where((ride) {
    if (ride.destinationZoneId != null && ride.destinationZoneId == headingHomeZoneId) return true;
    final destCity = ride.destinationCity?.toLowerCase().trim();
    if (cityLower != null && cityLower.isNotEmpty && destCity != null && destCity.isNotEmpty) {
      return destCity == cityLower;
    }
    return false;
  }).toList();
});

/// Latest community post for home sheet preview.
final latestCommunityPostProvider = FutureProvider<CommunityPost?>((ref) async {
  return ref.read(driverDataServiceProvider).getLatestCommunityPost();
});

/// Top requested app ideas from driver suggestion board.
final topDriverAppSuggestionsProvider = FutureProvider<List<DriverTopAppSuggestion>>((ref) async {
  return ref.read(driverDataServiceProvider).getTopAppSuggestions(limit: 8);
});

/// Finance + Tax metrics for a selected date range.
final driverFinanceMetricsProvider =
    FutureProvider.family<DriverFinanceMetrics, DriverFinanceRange>((ref, range) async {
  final id = await ref.watch(driverIdProvider.future);
  if (id == null) return const DriverFinanceMetrics();
  return ref.read(driverDataServiceProvider).getFinanceMetrics(
        driverId: id,
        range: range,
      );
});
