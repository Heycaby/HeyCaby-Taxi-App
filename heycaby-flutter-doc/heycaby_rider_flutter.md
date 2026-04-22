# HeyCaby Rider App — Flutter Build Guide
## Complete Screen-by-Screen Implementation Reference
### Based on live Supabase audit + PWA spec + app review documents

> **You are a Flutter developer.** This document tells you exactly what to build, in what order, connected to what data. Read the Mapbox guide (`heycaby_mapbox_flutter.md`) first and verify the map works before touching any screen here.

---

## BEFORE YOU BUILD

**Rule 1:** Never use mock data. Every piece of information shown to the rider comes from the live Supabase project (`fvrprxguoternoxnyhoj`).

**Rule 2:** Every string goes through `AppLocalizations`. No hardcoded English or Dutch strings in widgets.

**Rule 3:** Use `EdgeInsetsDirectional` everywhere — not `EdgeInsets.only(left/right)`. This is required for Arabic RTL support.

**Rule 4:** Ride creation happens **only** when the rider taps "Find my driver" on the Trip Summary screen. No earlier.

**Rule 5:** `rider_identities` is the canonical identity table. Do not use `rider_profiles` as an auth source.

---

## NAVIGATION STRUCTURE

```
go_router routes:

/                       → HomeScreen (tab shell)
/rides                  → RidesScreen (tab shell)
/account                → AccountScreen (tab shell)

/search                 → AddressSearchScreen (full page, no map)
/confirm                → ConfirmDestinationScreen
/options                → BookingOptionsScreen
/payment                → PaymentScreen
/summary                → TripSummaryScreen
/searching/:rideId      → SearchingScreen
/active/:rideId         → ActiveRideScreen
/inprogress/:rideId     → InProgressScreen
/complete/:rideId       → CompleteScreen
/rate/:rideId           → RateScreen
/rides/:id              → RideDetailScreen
/favorites              → FavoriteDriversScreen
/verify                 → VerificationScreen (modal)
```

---

## SCREEN 1 — HOME SCREEN

**File:** `apps/rider/lib/screens/home_screen.dart`
**Map coverage:** 55% (sheet covers 45%)
**Map state:** Neighbourhood zoom (~14), follows GPS slowly, shows driver ambient dots

### What the map shows:
- Blue pulsing GPS dot at rider's position (Mapbox location puck — see Mapbox guide Part 6)
- Small ambient car icons from `driver_locations` for nearby online drivers — subtle, not tappable
- No route line, no destination pin

### Sheet layout (top to bottom):
1. Drag handle (40×4px, centred, muted colour)
2. "Where to?" search bar (see exact design below)
3. Recent destinations (max 2 rows from `recent_destinations` table)
4. Two side-by-side booking cards:
   - Card A: "Favourite Drivers" (chauffeur icon)
   - Card B: "Marketplace" (price tag / scales icon)

### The "Where to?" bar — exact layout:
```
┌─────────────────────────────────────────────────────────┐
│  🔍  Where to?                       [🏠]  [📅 Later]  │
└─────────────────────────────────────────────────────────┘
```

Three independent tap zones:
- Left area (🔍 + "Where to?" text): navigate to `/search`
- 🏠 button: fetch home address from `saved_addresses WHERE type='home'`, pre-fill destination, go to `/confirm`
- 📅 Later button: `store.setBookingMode('scheduled')`, navigate to `/search`

The 🏠 and 📅 buttons must call `e.stopPropagation()` equivalent in Flutter (`absorbing: true` on a GestureDetector wrapper around the main tap area).

### Recent destinations rows:
- Source: `GET /api/rider/recent-destinations?rider_identity_id=...`
- Show max 2, ordered by `created_at DESC`
- Each row: 🕐 icon + label (bold) + city (muted) + distance (right-aligned, muted)
- Tap: pre-fill destination coordinates → navigate to `/confirm`

### Booking cards:
```dart
// Favourite Drivers card
BookingCard(
  icon: Icons.person, // Replace with custom chauffeur SVG
  title: l10n.favouriteDrivers,
  subtitle: l10n.favouriteDriversSubtitle,
  onTap: () {
    ref.read(bookingProvider.notifier).setBookingMode(BookingMode.instant);
    context.go('/search');
  },
)

// Marketplace card
BookingCard(
  icon: Icons.sell_outlined,
  title: l10n.marketplace,
  subtitle: l10n.marketplaceSubtitle,
  badge: l10n.bestPrice, // "Best price" badge
  onTap: () {
    ref.read(bookingProvider.notifier).setBookingMode(BookingMode.marketplace);
    context.go('/search');
  },
)
```

### Nearby drivers (ambient map dots):
```dart
// Fetch once on screen load, refresh every 30s
Future<void> _loadNearbyDrivers() async {
  final count = await ref.read(riderApiProvider).getDriversNearby(
    lat: _currentLat,
    lng: _currentLng,
    radiusKm: 5,
  );
  // Show ambient count in a pill on the map if count > 0
}
```

### Riverpod providers used:
- `bookingProvider` — read/write booking state
- `riderIdentityProvider` — read `rider_token` and `rider_identity_id`
- `currentLocationProvider` — GPS position
- `recentDestinationsProvider` — from API

---

## SCREEN 2 — ADDRESS SEARCH

**File:** `apps/rider/lib/screens/address_search_screen.dart`
**Map:** Hidden completely. Full-screen white/surface.
**Type:** Full-screen page pushed via `context.go('/search')`

### Layout:
1. Top bar: ← back | "Your route" title | ↕ swap button
2. Pickup field (pre-filled from GPS, blue dot icon, editable)
3. Destination field (auto-focused on mount, 🔍 icon, ✕ clear button)
4. Suggestions list:
   - Recent destinations first (filtered by current query)
   - Mapbox Search API results (after 3+ chars, 300ms debounce)

### Debounce implementation:
```dart
Timer? _debounce;

void _onQueryChanged(String query) {
  _debounce?.cancel();
  if (query.length < 3) {
    // Show recents only
    setState(() => _showingRecents = true);
    return;
  }
  _debounce = Timer(const Duration(milliseconds: 300), () {
    _performSearch(query);
  });
}

Future<void> _performSearch(String query) async {
  final geocoding = ref.read(geocodingServiceProvider);
  final results = await geocoding.search(
    query: query,
    proximityLat: _currentLat,
    proximityLng: _currentLng,
  );
  if (mounted) setState(() => _searchResults = results);
}
```

### On destination selected:
```dart
Future<void> _onResultSelected(AddressResult result) async {
  // If result has no coordinates yet (from suggest API), retrieve them
  AddressResult final_result = result;
  if (result.lat == 0 && result.lng == 0) {
    final retrieved = await ref.read(geocodingServiceProvider).retrieve(result.mapboxId ?? '');
    if (retrieved != null) final_result = retrieved;
  }

  ref.read(bookingProvider.notifier).setDestination(final_result);
  // Add to recent destinations
  await ref.read(riderApiProvider).addRecentDestination(
    destination: {
      'label': final_result.displayName,
      'full_address': final_result.fullAddress,
      'latitude': final_result.lat,
      'longitude': final_result.lng,
    },
    riderIdentityId: ref.read(riderIdentityProvider).identityId ?? '',
  );
  context.go('/confirm');
}
```

### Start search session when field focuses:
```dart
Focus(
  onFocusChange: (focused) {
    if (focused) ref.read(geocodingServiceProvider).startSession();
  },
  child: TextField(
    onChanged: _onQueryChanged,
    // ...
  ),
)
```

---

## SCREEN 3 — CONFIRM DESTINATION

**File:** `apps/rider/lib/screens/confirm_destination_screen.dart`
**Map coverage:** 68% (sheet covers 32%)
**Map state:** Route line from pickup to destination, fitted bounds, locked

### Map elements:
- Blue pulsing circle at pickup (location puck, see Mapbox guide)
- Gold destination pin at destination
- Route polyline connecting them (see Mapbox guide Part 7)
- Floating back arrow (top left) and search button (top right) over the map

### Getting the route:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadRoute();
  });
}

Future<void> _loadRoute() async {
  final booking = ref.read(bookingProvider);
  if (booking.pickup == null || booking.destination == null) return;

  final route = await ref.read(directionsServiceProvider).getRoute(
    fromLat: booking.pickup!.lat,
    fromLng: booking.pickup!.lng,
    toLat: booking.destination!.lat,
    toLng: booking.destination!.lng,
  );

  if (route != null && _mapboxMap != null) {
    await RouteLayer.drawRoute(_mapboxMap!, route);
    setState(() {
      _distanceKm = route.distanceKm;
      _durationMin = route.durationMin;
    });
  }
}
```

### Sheet layout (32% height):
1. Drag handle (visual only)
2. **Full pickup address** (bold) — street + number + postcode + city
3. **Full destination address** (bold) — street + number + postcode + city
4. Route meta: 📏 `12.4 km · ⏱ 18 min`
5. "Confirm destination" button (full width, primary)

> **CRITICAL:** Show FULL addresses. Not just "Dransdorf" — show "Dransdorf 12, 53121 Bonn". The `AddressResult.fullAddress` field contains the complete address. Use it.

---

## SCREEN 4 — BOOKING OPTIONS

**File:** `apps/rider/lib/screens/booking_options_screen.dart`
**Map coverage:** 35% (sheet 65%, scrollable)
**Map state:** Same route from Screen 3, locked

### Sheet layout:
1. Drag handle
2. Compact route pill (tappable → back to Screen 3)
3. "How do you want to book?" heading
4. **Option cards (radio-select — neither selected on load):**

**Card A — Favourite Drivers:**
```dart
BookingOptionCard(
  icon: Icons.person, // chauffeur icon
  title: l10n.favouriteDrivers,
  subtitle: hasFavourites
    ? l10n.favouriteDriversSubtitleWithCount(favouriteCount)
    : l10n.noFavouritesYet,
  selected: bookingMode == BookingMode.instant,
  checkmark: true,  // Circle checkmark top-right
  onTap: hasFavourites
    ? () => _selectMode(BookingMode.instant)
    : () => _showNoFavouritesExplanation(),
)
```

**Card B — Marketplace:**
```dart
BookingOptionCard(
  icon: Icons.sell_outlined,
  title: l10n.marketplace,
  subtitle: l10n.marketplaceSubtitle, // "Drivers heading your way — save up to 40%"
  badge: l10n.bestPrice,
  selected: bookingMode == BookingMode.marketplace,
  checkmark: true,
  onTap: () => _selectMode(BookingMode.marketplace),
)
```

**Card selection visual states:**
```dart
// UNSELECTED: neutral border, normal background, empty circle outline top-right
// SELECTED: gold/accent border, accent background fill (10% opacity), filled circle with tick
// Neither card is selected when screen first appears
```

**Favourites-only toggle** (shows only if Favourite Drivers is selected AND rider has ≥1 favourite):
```dart
if (bookingMode == BookingMode.instant && hasFavourites)
  SwitchListTile(
    title: Text(l10n.favouritesOnly),
    value: ref.watch(bookingProvider).favoritesOnly,
    onChanged: (val) =>
      ref.read(bookingProvider.notifier).setFavoritesOnly(val),
  )
```

**Scheduled date/time picker** (shows only if `bookingMode == BookingMode.scheduled`):
```dart
if (bookingMode == BookingMode.scheduled)
  _ScheduledTimePicker(
    onChanged: (dt) =>
      ref.read(bookingProvider.notifier).setScheduledAt(dt),
  )
```

**Rider name field (required):**
```dart
TextFormField(
  initialValue: ref.read(riderIdentityProvider).bookingName,
  decoration: InputDecoration(
    prefixIcon: Icon(Icons.person_outline),
    hintText: l10n.namePlaceholder,
  ),
  onChanged: (val) =>
    ref.read(bookingProvider.notifier).setPickupContactName(val),
)
```

**Continue button:** Disabled until a booking mode is selected AND name is filled.

---

## SCREEN 5 — PAYMENT

**File:** `apps/rider/lib/screens/payment_screen.dart`
**Map coverage:** 58% (sheet 42%, map slightly dimmed)
**Map state:** Same route, locked, 15% white overlay on map

### Sheet layout:
1. Drag handle
2. 🤝 icon + "How will you pay?" + ⓘ info button
3. Explanation text: "HeyCaby is free. Pay your driver directly on arrival."
4. **Three payment method cards (radio-select):**

```dart
final methods = ['cash', 'pin', 'tikkie'];

// Check which methods driver accepts (from booking context if driver pre-assigned)
// Default: show all three

PaymentCard(icon: Icons.money, label: l10n.cash, value: 'cash', ...)
PaymentCard(icon: Icons.credit_card, label: l10n.pin, value: 'pin', ...)
PaymentCard(icon: Icons.phone_android, label: l10n.tikkie, value: 'tikkie', ...)
```

5. Community pledge text (small, muted):
   `l10n.communityPledge` — "Only book when you're ready and at your location. Our drivers pay for fuel on every call-out."
6. "Find my driver" button (full width, primary)

> **Note:** This screen does NOT create the ride. The "Find my driver" button navigates to TripSummaryScreen.

### ⓘ info modal:
```dart
void _showInfoModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.howHeyCabyWorks, style: TextTheme.titleLarge),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.check_circle, text: l10n.zeroCommission),
          _InfoRow(icon: Icons.check_circle, text: l10n.driverEarns100),
          _InfoRow(icon: Icons.warning_amber, text: l10n.noShowWarning),
        ],
      ),
    ),
  );
}
```

---

## SCREEN 6 — TRIP SUMMARY

**File:** `apps/rider/lib/screens/trip_summary_screen.dart`
**Map coverage:** 60% (sheet 40%)
**Map state:** Same route, locked, no new map elements

This screen is local-only. No ride exists in the database yet.

### Sheet layout:
1. Drag handle
2. Full pickup address → Full destination address (with postcodes)
3. Route summary: distance · duration · estimated fare
4. Payment method chosen (icon + label)
5. Booking mode badge (⚡ Instant / 🔄 Marketplace / 📅 Scheduled)
6. Rider name (from booking state)
7. Two buttons:
   - ← "Edit" (secondary, goes back)
   - "Find my driver" (primary, full width, triggers ride creation)

### The "Find my driver" button — CRITICAL IMPLEMENTATION:

```dart
bool _isCreating = false;
CancelToken? _cancelToken;

@override
void dispose() {
  _cancelToken?.cancel('Screen disposed');
  super.dispose();
}

Future<void> _onFindMyDriver() async {
  if (_isCreating) return;  // Prevent duplicate taps

  final booking = ref.read(bookingProvider);
  final identity = await SecureStorage.getRiderIdentity();
  final riderToken = identity['rider_token'];
  final identityId = identity['rider_identity_id'];

  if (riderToken == null || identityId == null) {
    context.go('/verify');
    return;
  }

  setState(() => _isCreating = true);
  _cancelToken = CancelToken();

  try {
    // Unique idempotency key — prevents duplicate rides if network retries
    final idempotencyKey = '${identityId}_${DateTime.now().millisecondsSinceEpoch}';

    final result = await ref.read(riderApiProvider).createRide(
      payload: {
        'pickup_address': booking.pickup!.fullAddress,
        'pickup_lat': booking.pickup!.lat,
        'pickup_lng': booking.pickup!.lng,
        'destination_address': booking.destination!.fullAddress,
        'destination_lat': booking.destination!.lat,
        'destination_lng': booking.destination!.lng,
        'booking_mode': booking.bookingMode.name,
        'payment_method': booking.paymentMethod,
        'rider_token': riderToken,
        'rider_identity_id': identityId,
        'pickup_contact_name': booking.pickupContactName,
        'favorites_only': booking.favoritesOnly,
        'estimated_distance_km': booking.estimatedDistanceKm,
        'estimated_duration_min': booking.estimatedDurationMin,
        if (booking.scheduledAt != null)
          'scheduled_pickup_at': booking.scheduledAt!.toIso8601String(),
      },
      idempotencyKey: idempotencyKey,
    );

    final rideId = result['ride_id'] as String? ?? result['id'] as String;
    ref.read(bookingProvider.notifier).setActiveRide(rideId, null);
    context.go('/searching/$rideId');

  } on DioException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.connectionProblem)),
    );
  } finally {
    if (mounted) setState(() => _isCreating = false);
  }
}
```

---

## SCREEN 7 — SEARCHING FOR DRIVER

**File:** `apps/rider/lib/screens/searching_screen.dart`
**Map coverage:** 72% (sheet 28% PEEK at bottom)
**Map state:** Pickup location with pulsing ring animation, zone hex outline (marketplace only)

### Pulse ring animation on pickup pin:
```dart
// Draw an animated circle around the pickup point using CircleAnnotation
// Animate scale from 1.0 to 2.5 and opacity from 0.6 to 0 on repeat
// This is done via a custom annotation + periodic setState animation
```

### Sheet at 28%:
1. Spinning loader (CircularProgressIndicator, accent colour)
2. "Finding your driver..." heading
3. Context line based on mode:
   - Instant: ⚡ "Favourite drivers have first priority"
   - Marketplace: 🔄 "Matching with nearby drivers"
4. "Cancel" text link at bottom

### Supabase Realtime subscription:
```dart
@override
void initState() {
  super.initState();
  _subscribeToRide();
}

void _subscribeToRide() {
  _channel = Supabase.instance.client
    .channel('ride:${widget.rideId}')
    .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'ride_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.rideId,
      ),
      callback: (payload) {
        final status = payload.newRecord['status'] as String;
        final driverId = payload.newRecord['driver_id'] as String?;
        _onRideStatusUpdate(status, driverId);
      },
    )
    .subscribe();

  // Start 3-minute timeout timer
  _timeoutTimer = Timer(const Duration(minutes: 3), _onTimeout);
}

void _onRideStatusUpdate(String status, String? driverId) {
  switch (status) {
    case 'accepted':
      _timeoutTimer?.cancel();
      ref.read(bookingProvider.notifier).setActiveRide(widget.rideId, driverId);
      context.go('/active/${widget.rideId}');
      break;
    case 'cancelled':
      _timeoutTimer?.cancel();
      _channel?.unsubscribe();
      ref.read(bookingProvider.notifier).reset();
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.rideCancelled)),
      );
      break;
  }
}

void _onTimeout() {
  setState(() => _timedOut = true);
  // Show timeout UI with "Try Marketplace" and "Cancel" options
}
```

### Cancel ride:
```dart
Future<void> _cancelRide() async {
  // Ride exists in backend — must call API
  await ref.read(riderApiProvider).cancelRide(
    rideId: widget.rideId,
    cancelledBy: 'rider',
  );
  _channel?.unsubscribe();
  ref.read(bookingProvider.notifier).reset();
  context.go('/');
}
```

---

## SCREEN 8 — ACTIVE RIDE

**File:** `apps/rider/lib/screens/active_ride_screen.dart`
**Map coverage:** 68% (sheet 32% default, drag to 60% for details)
**Map state:** Live driver car marker moving toward pickup, ETA bubble, route line

### Driver location tracking:
See Mapbox guide Part 9 for the full implementation. Subscribe to `driver_locations` via Realtime. Update car marker position and heading on each event. Throttle camera refits to every 5 seconds.

### Ride status subscription:
```dart
// Same channel pattern as SearchingScreen
// Watch for status changes:
// driver_arrived → update status pill to "Your driver is here" + green pulse
// started → map changes to pickup→destination route
// completed → navigate to /complete/:rideId
```

### Sheet at 32%:
1. Drag handle
2. Driver card: circular photo (48px) + name + ⭐ rating + vehicle pill
3. ETA pill: "Ahmed in 4 min" — updates live
4. Action row: 💬 Chat | 📞 Call
5. Status pill (auto-updates):
   - 🟡 "On the way"
   - 🟠 "Almost here" (< 2 min)
   - 🟢 "Your driver is here" (driver_arrived)
   - 🔵 "Ride in progress" (started)

### Sheet expanded to 60% (drag up):
- Driver bio (from `drivers.bio`)
- Languages (from `drivers.languages[]` as small pills)
- ✅ "Verified HeyCaby driver" badge (if `drivers.is_verified_badge = true`)
- Cancel button (danger colour, text link) — only visible before `driver_arrived` status

### Driver info source:
```dart
// GET /api/ride/:id/driver
final driverData = await ref.read(riderApiProvider).getRideDriver(
  rideId: widget.rideId,
);
```

---

## SCREEN 9 — IN PROGRESS

**File:** `apps/rider/lib/screens/in_progress_screen.dart`
**Map coverage:** 70% (sheet 30%)
**Map state:** Driver moving toward destination, route line pickup→destination

### Minimal sheet:
1. Drag handle
2. 🔵 "Ride in progress" status
3. Destination address (bold)
4. ETA to destination (updates from driver location)
5. 💬 Chat button
6. Support/report link (muted, bottom)

### Route update when ride starts:
When `status = 'started'`, clear the driver→pickup route and draw pickup→destination:
```dart
void _onRideStarted(double driverLat, double driverLng) async {
  final destination = ref.read(bookingProvider).destination!;
  final route = await ref.read(directionsServiceProvider).getRoute(
    fromLat: driverLat,
    fromLng: driverLng,
    toLat: destination.lat,
    toLng: destination.lng,
  );
  if (route != null && _mapboxMap != null) {
    await RouteLayer.drawRoute(_mapboxMap!, route, lineColor: 0xFF0288D1);
  }
}
```

---

## SCREEN 10 — COMPLETE

**File:** `apps/rider/lib/screens/complete_screen.dart`
**Map coverage:** 65% (sheet 35%)
**Map state:** Destination pin with green ✅ badge, zoom 17 (street level), locked

### Arrival animation:
On map created, fly to destination at zoom 17 and trigger a one-time scale animation on the destination pin.

### Sheet layout:
1. Drag handle
2. Animated ✅ checkmark (stroke draws in over 0.6s using AnimationController)
3. "You've arrived!" heading
4. Route summary: pickup → destination (compact)
5. "Paid directly to your driver" + payment icon
6. "Rate your driver" button (primary)
7. "Maybe later" text link

---

## SCREEN 11 — RATE DRIVER

**File:** `apps/rider/lib/screens/rate_screen.dart`
**Map coverage:** 0% (map hidden, full themed background)

### Sheet layout (55% scrollable):
1. Driver card (reuse same component from ActiveRideScreen)
2. ★★★★★ 5-star rating (required, scale animation on select)
3. Optional comment input (max 100 chars, counter at 80+)
4. Add to favourites toggle (if rating is 4 or 5 stars AND not already a favourite):
   ```dart
   if (rating >= 4 && !isAlreadyFavourite)
     _AddFavouriteToggle(driverId: driverId, driverName: driverName)
   ```
5. Submit button (primary, full width)
6. Skip text link

### Submit logic:
```dart
Future<void> _submitRating() async {
  // 1. POST rating
  await ref.read(riderApiProvider).rateRide(payload: {
    'ride_request_id': widget.rideId,
    'driver_id': driverId,
    'rider_token': riderToken,
    'rider_rating_of_driver': _stars,
    'rider_comment': _comment.isEmpty ? null : _comment,
    'rider_rated_at': DateTime.now().toIso8601String(),
  });

  // 2. Add to favourites if toggled
  if (_addToFavourites) {
    await ref.read(riderApiProvider).addFavouriteDriver(
      email: riderEmail,
      driverId: driverId,
    );
  }

  // 3. Reset and go home
  ref.read(bookingProvider.notifier).reset();
  context.go('/');
}
```

### Low-rating reason flow:
- Rating 3 → show reason chips (required before submit)
- Rating 1-2 → show "Report this driver?" modal with stronger language
- Reason options: `not_clean`, `rude`, `late`, `unsafe_driving`, `wrong_route`, `other`
- Store reasons in `ride_ratings.rider_comment` as comma-separated string (or wait for `rating_reasons` column to be added in migration 034)

---

## SCREEN 12 — RIDES LIST

**File:** `apps/rider/lib/screens/rides_screen.dart`
**Type:** Tab screen, full page, no map

```dart
// GET /api/rider/rides?rider_token=...
final rides = await ref.read(riderApiProvider).getRides(
  riderToken: riderToken,
);

// Each row shows:
// - Date and time
// - Pickup → Destination (shortened)
// - Payment icon + amount
// - Status badge (completed/cancelled)
// Tap → navigate to /rides/:id
```

---

## SCREEN 13 — RIDE DETAIL

**File:** `apps/rider/lib/screens/ride_detail_screen.dart`
**Type:** Full page, no map

```dart
// GET /api/rider/rides/:id?rider_token=...
final ride = await ref.read(riderApiProvider).getRideById(
  id: widget.id,
  riderToken: riderToken,
);

// Show:
// - Full addresses (with postcodes)
// - Date/time
// - Driver name + vehicle
// - Payment method + amount
// - Rating given (if any)
// - Share ride link button (from ride_shares table — generate URL)
// - Report ride button → /report
```

---

## SCREEN 14 — ACCOUNT

**File:** `apps/rider/lib/screens/account_screen.dart`
**Type:** Tab screen, full page

### Sections:
1. **Identity card:** Email + "Verified" badge (if `email_verified_at != null`) or "Verify email" CTA
2. **Booking name** (editable, PATCH `/api/rider/profile`)
3. **Home address** (from `saved_addresses WHERE type='home'`, editable)
4. **Favourite drivers** → navigate to `/favorites`
5. **Preferences:** Language, theme
6. **Notifications:** On/off toggle

### Language switcher:
```dart
// Changes the app locale immediately
// Also PATCHes rider_identities.language_pref via API
DropdownButton<String>(
  value: currentLocale,
  items: const [
    DropdownMenuItem(value: 'nl', child: Text('Nederlands')),
    DropdownMenuItem(value: 'en', child: Text('English')),
    DropdownMenuItem(value: 'ar', child: Text('العربية')),
  ],
  onChanged: (locale) {
    ref.read(localeProvider.notifier).setLocale(Locale(locale!));
    // PATCH identity
  },
)
```

---

## SCREEN 15 — FAVOURITE DRIVERS

**File:** `apps/rider/lib/screens/favourite_drivers_screen.dart`
**Type:** Full page, no map

### Data source:
```dart
// GET /api/rider/favorites?email=...
// Joined with drivers table:
// - full_name, profile_photo_url, vehicle_make, vehicle_model, vehicle_type
// - status (available/on_ride/offline/on_break)
// - driver_locations (lat/lng for distance calc if status = available)
```

### Per-driver card:
- Circular photo (48px, from `profile_photo_url`)
- Name (bold)
- Vehicle: "Black Toyota Camry — Sedan"
- Status indicator:
  - 🟢 "Online — 8 km away" (if `status = available` + location available)
  - 🟡 "On a ride" (if `status = on_ride`)
  - ⚫ "Offline — last active 2 days ago" (if `status = offline`)

### Bottom CTA:
"Book a ride with favourite drivers" → sets `favoritesOnly = true`, `bookingMode = instant`, navigates to `/search`

### Email verification gate:
Before showing this screen, check `rider_identities.email_verified_at`. If null, show:
```dart
// Block screen with message:
// "Verify your email to use Favourite Drivers"
// CTA: "Verify now" → navigate to /verify
```

---

## SCREEN 16 — VERIFICATION (MODAL)

**File:** `apps/rider/lib/screens/verification_screen.dart`
**Type:** Modal bottom sheet

### Flow:
1. Email input field
2. POST `/api/rider/identity` with email → backend creates identity, sends OTP
3. 6-digit OTP input
4. POST `/api/rider/identity/verify-email` with email + code
5. On success: save `rider_token` + `rider_identity_id` to `flutter_secure_storage`
6. Dismiss modal and continue whatever flow was interrupted

---

## MARKETPLACE FLOW (SPECIAL FLOW FROM SCREEN 4)

When `bookingMode = marketplace`, after Screen 4 the flow diverges slightly:

**On Screen 5 (Payment), before tapping "Find my driver":**
Show the **offered fare input** prominently:
```dart
// GET /api/marketplace/suggested-price?from_lat=...&from_lng=...&to_lat=...&to_lng=...
final suggestion = await ref.read(riderApiProvider).getSuggestedPrice(...);

// Show:
// - "Average driver rate: €{suggestion}" (calculated from nearby driver rates)
// - +/- fare adjuster with match probability
// - "72% chance of getting a driver" (recalculated as fare changes)
```

Match probability calculation:
```dart
// Simple client-side estimate:
// Get count of drivers in zone from GET /api/drivers-nearby
// Get driver rate data from GET /api/auction/search
// Probability = (drivers accepting at this fare / total drivers) * 100
double _calculateMatchProbability(double offeredFare, List<dynamic> nearbyDrivers) {
  if (nearbyDrivers.isEmpty) return 0;
  final accepting = nearbyDrivers
    .where((d) => (d['minimum_fare'] as num?)?.toDouble() ?? 0 <= offeredFare)
    .length;
  return (accepting / nearbyDrivers.length * 100).clamp(0, 100);
}
```

**After "Find my driver":**
Use `POST /api/auction/post` instead of `POST /api/ride/create`:
```dart
final result = await ref.read(riderApiProvider).postAuction(payload: {
  'pickup_lat': pickup.lat,
  'pickup_lng': pickup.lng,
  'pickup_address': pickup.fullAddress,
  'dest_lat': destination.lat,
  'dest_lng': destination.lng,
  'dest_address': destination.fullAddress,
  'offered_fare': offeredFare,
  'rider_token': riderToken,
  'rider_identity_id': identityId,
  'favorites_only': false,
  'pickup_contact_name': contactName,
});
```

---

## BOOKING STATE (RIVERPOD)

```dart
// packages/heycaby_api/lib/src/booking_notifier.dart

enum BookingMode { instant, scheduled, marketplace }
enum BookingState {
  idle, editingTrip, tripReview, creatingRide,
  searching, driverAssigned, driverArriving,
  inProgress, completed, notifyMe,
}

@immutable
class BookingData {
  final BookingState state;
  final BookingMode bookingMode;
  final AddressResult? pickup;
  final AddressResult? destination;
  final double? estimatedDistanceKm;
  final double? estimatedDurationMin;
  final bool favoritesOnly;
  final DateTime? scheduledAt;
  final String paymentMethod;
  final String pickupContactName;
  final String? activeRideId;
  final String? assignedDriverId;

  const BookingData({
    this.state = BookingState.idle,
    this.bookingMode = BookingMode.instant,
    this.pickup,
    this.destination,
    this.estimatedDistanceKm,
    this.estimatedDurationMin,
    this.favoritesOnly = false,
    this.scheduledAt,
    this.paymentMethod = 'cash',
    this.pickupContactName = '',
    this.activeRideId,
    this.assignedDriverId,
  });

  BookingData copyWith({ /* all fields */ }) => BookingData(/* ... */);

  static BookingData empty() => const BookingData();
}

class BookingNotifier extends Notifier<BookingData> {
  @override
  BookingData build() => BookingData.empty();

  void setPickup(AddressResult pickup) =>
    state = state.copyWith(pickup: pickup, state: BookingState.editingTrip);

  void setDestination(AddressResult dest) =>
    state = state.copyWith(destination: dest);

  void setBookingMode(BookingMode mode) =>
    state = state.copyWith(bookingMode: mode);

  void setFavoritesOnly(bool val) =>
    state = state.copyWith(favoritesOnly: val);

  void setPaymentMethod(String method) =>
    state = state.copyWith(paymentMethod: method);

  void setPickupContactName(String name) =>
    state = state.copyWith(pickupContactName: name);

  void setScheduledAt(DateTime? dt) =>
    state = state.copyWith(scheduledAt: dt);

  void setActiveRide(String rideId, String? driverId) =>
    state = state.copyWith(
      activeRideId: rideId,
      assignedDriverId: driverId,
      state: BookingState.searching,
    );

  void transitionTo(BookingState newState) =>
    state = state.copyWith(state: newState);

  void reset() => state = BookingData.empty();
}
```

---

## APP RECOVERY ON LAUNCH

When the app launches, check if there is an active ride and restore the correct screen:

```dart
// In startup provider
Future<StartupResult> checkActiveRide(Ref ref) async {
  final identity = await SecureStorage.getRiderIdentity();
  if (identity['rider_token'] == null) return StartupResult.unauthenticated;

  // Check local state for activeRideId
  final prefs = await SharedPreferences.getInstance();
  final activeRideId = prefs.getString('active_ride_id');
  if (activeRideId == null) return StartupResult.authenticated;

  // Fetch current ride status from backend
  try {
    final ride = await ref.read(riderApiProvider).getRideById(
      id: activeRideId,
      riderToken: identity['rider_token']!,
    );
    final status = ride['status'] as String;

    switch (status) {
      case 'pending':
        return StartupResult.resumeSearching(activeRideId);
      case 'accepted':
      case 'driver_arrived':
        return StartupResult.resumeActive(activeRideId);
      case 'started':
        return StartupResult.resumeInProgress(activeRideId);
      default:
        await prefs.remove('active_ride_id');
        return StartupResult.authenticated;
    }
  } catch (_) {
    return StartupResult.authenticated;
  }
}
```

---

## BUILD ORDER

Follow this sequence. Test on a real phone after each step.

```
Step 1  → Set up Mapbox (see mapbox guide), verify map renders
Step 2  → Build BookingNotifier + SecureStorage
Step 3  → HomeScreen — map + sheet + search bar (wired)
Step 4  → AddressSearchScreen — Mapbox geocoding + suggestions
Step 5  → ConfirmDestinationScreen — route line + full addresses
Step 6  → BookingOptionsScreen — two cards, no auto-select, checkmarks
Step 7  → PaymentScreen — three method cards + info modal
Step 8  → TripSummaryScreen — local review + "Find my driver" with idempotency
Step 9  → SearchingScreen — Realtime subscription + pulse animation
Step 10 → ActiveRideScreen — driver location tracking + status updates
Step 11 → InProgressScreen — route switches to destination
Step 12 → CompleteScreen — arrival animation + receipt link
Step 13 → RateScreen — stars + add favourite + report flow
Step 14 → RidesScreen + RideDetailScreen
Step 15 → AccountScreen + FavouriteDriversScreen
Step 16 → VerificationScreen
Step 17 → App recovery on launch
Step 18 → Marketplace flow (post auction, match probability UI)
Step 19 → Full end-to-end test with real Supabase data
Step 20 → Arabic RTL test (change device language to Arabic)
```

---

## SYNC TEST (RIDER SIDE)

Before marking any screen done, test these with a driver phone simultaneously:

```
[ ] Rider creates ride → Driver phone gets notification within 5s
[ ] Driver accepts → Rider map shows driver dot within 3s
[ ] Driver dot moves → Rider map updates within 5s
[ ] Driver taps "Arrived" → Rider status pill turns green within 2s
[ ] Driver taps "Start ride" → Rider status updates within 2s
[ ] Driver taps "Complete" → Rider sees Complete screen within 3s
[ ] Both submit ratings → ride_ratings.ratings_revealed_at is set
[ ] Favourites flow: rider with favourite driver → correct notification goes to that driver
[ ] Network drop during searching → reconnects and continues when restored
[ ] App restart mid-ride → correct screen shown (not home)
```

---

*HeyCaby Rider Flutter Build Guide — March 2026*
*Based on live Supabase audit of HeyCaby production.*
*Read heycaby_mapbox_flutter.md before building any screen.*
*Backend (Next.js + Supabase) unchanged. Flutter UI only.*
