---
name: rider-flow-implementation
description: Guides the agent in understanding and modifying the Rider booking flow end-to-end, including routing, state providers, and backend ride creation, while preserving existing behavior and constraints.
---

# Rider Flow Implementation Skill

## When to use this skill

Use this skill whenever you:
- Change any Rider booking step (home, search, vehicle, payment, summary, searching, active ride, post-ride).
- Add a new step into the flow (for example, an upsell or extra confirmation screen).
- Touch providers related to booking or ride requests.

## Key architecture pieces

- Entry: `apps/rider/lib/main.dart` → `HeyCabyRiderApp` in `apps/rider/lib/app.dart`.
- Routing: `GoRouter` configuration in `apps/rider/lib/router.dart`.
- Booking state:
  - `BookingState` and `BookingNotifier` in `apps/rider/lib/providers/booking_provider.dart`.
  - Holds pickup, destination, mode, schedule, payment, vehicle category, and pickup contact name.
- Ride requests:
  - `RideRequestNotifier` in `apps/rider/lib/providers/ride_request_provider.dart`.
  - `createRide(BookingState booking)` creates the ride in Supabase and manages status.
- Identity:
  - `RiderIdentityState` and notifier in `packages/heycaby_api/lib/src/rider_identity_provider.dart`.
  - Backed by secure storage in `packages/heycaby_api/lib/src/secure_storage.dart`.

## Booking journey (A → Z)

1. **Splash / gating**
   - `SplashScreen` decides whether to go to home or `LocationRequiredScreen`.
2. **Home**
   - Screen: `apps/rider/lib/screens/home_screen.dart`.
   - Shows map, “Where to?” entry, and shortcuts to marketplace and favorites.
   - Reverse-geocodes current location and seeds `booking.pickup`.
3. **Search**
   - Screen: `apps/rider/lib/screens/search_screen.dart`.
   - Lets the rider search pickup/destination via Mapbox geocoding.
   - When both are set, a **Continue** CTA runs `prefillBookingFromIdentity` then `push(routeAfterAddressesComplete)` (shortcuts from home/marketplace may skip search).
4. **Legacy routes** `/confirm`, `/booking-options`
   - No screens — `router.dart` redirects to the same smart next step as after search (or `/search` if addresses missing). Deep links and old bookmarks keep working.
5. **Vehicle category**
   - Screen: `apps/rider/lib/screens/vehicle_category_screen.dart`.
   - Chooses vehicle category, pet-friendly, **favourites-only**, and **pickup contact name** (text field + identity prefill; on Continue also syncs to settings + `saveBookingName` like the old booking-options step).
   - Supply UI: `vehicle_category_supply_card.dart`, `nearby_category_supply_provider.dart`, `services/nearby_supply_service.dart` (live `driver_locations` + `drivers.vehicle_category`; hash fallback if RLS omits driver rows).
   - Matching: `ride_request_provider` sends `vehicle_category`, `pet_friendly`, `booking_mode`; Supabase migration `20260329180000_ride_matching_cascade.sql` (invites + RPCs); `searching_screen` expands batches; driver `RideInviteRealtimeListener` + `DriverApi.acceptRide` RPC.
6. **Payment**
   - Screen: `apps/rider/lib/screens/payment_screen.dart`.
   - Chooses payment method(s) and stores them in booking.
7. **Trip summary**
   - Screen: `apps/rider/lib/screens/trip_summary_screen.dart` + `widgets/booking/trip_summary_sheet.dart`.
   - Summary + **Find my driver** navigates to the matching route; `SearchingScreen` creates the ride. Optional **save this trip for next time** (pickup + destination → `recentDestinationsProvider.recordTripForLater` / `saved_addresses` when signed in). **Save for later** saves a local draft and exits to home.
8. **Searching**
   - Screen: `apps/rider/lib/screens/searching_screen.dart` (`RideMatchingVariant`: instant, marketplace, scheduled).
   - Instant/marketplace: radar, rotating “Did you know?” cards, delayed **notify / schedule** card. Marketplace adds `matching_marketplace_banner.dart`.
   - Scheduled: headline + `DraggableScrollableSheet` with `scheduled_matching_details_panel.dart` (route + time + detail chips); still creates ride + realtime like instant.
9. **Active ride**
    - Screen: `apps/rider/lib/screens/active_ride_screen.dart`.
    - Tracks driver, shows status, and allows chat/report.
10. **Post-ride**
    - Rating, report, ride history, and favorites screens.

## Safe modification patterns

- When adding a new step:
  - Add a route in `router.dart`.
  - Pass any needed data via typed models using `state.extra` or providers.
  - Ensure `BookingState` and `RideRequestState` transitions remain valid.
- When changing behavior:
  - Prefer updating providers and notifiers over embedding logic in widgets.
  - Keep UI widgets focused on displaying state and dispatching intents.

## Examples

- To insert an upsell screen between summary and searching:
  - Create a new screen file under `apps/rider/lib/screens/`.
  - Add a route between `/summary` and `/searching` in `router.dart`.
  - From summary, navigate to the upsell, then to searching, without changing `createRide` semantics.

