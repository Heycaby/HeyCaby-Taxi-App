# HeyCaby Driver App — Flutter Build Guide
## Complete Screen-by-Screen Implementation Reference
### Based on live Supabase audit + PWA spec + Driver-Booking-Flow.md

> **You are a Flutter developer.** This document tells you exactly what to build, in what order, connected to what data. The driver app is more operationally complex than the rider app — it has background location, real-time ride dispatch, a radar system, and a multi-step onboarding with Dutch regulatory documents. Read the Mapbox guide (`heycaby_mapbox_flutter.md`) first.

---

## BEFORE YOU BUILD

**Rule 1:** Every driver action that changes ride status goes through the Next.js API (`POST /api/driver/ride/[action]`). Never write `ride_requests.status` directly from the Flutter client.

**Rule 2:** Background location must be tested on a **physical device**. Simulator/emulator does not reflect real OS throttling behavior.

**Rule 3:** The driver app uses **Supabase Auth** (email/password). Driver JWT must be included in all API calls as `Authorization: Bearer <token>`.

**Rule 4:** The driver status (`drivers.status`) must be written to the backend **before** the UI updates. Confirm the write succeeded first.

**Rule 5:** The `booking_mode` field on `ride_requests` is read-only from the driver's perspective. Driver never writes it.

---

## NAVIGATION STRUCTURE

```
go_router routes:

Auth stack (when not logged in):
/login                  → LoginScreen
/register               → RegisterScreen

Onboarding stack:
/onboarding             → OnboardingScreen (multi-step)

Main app (after auth + onboarding complete):
/driver                 → DriverHomeScreen (tab shell)
/driver/market          → MarketScreen (tab shell)
/driver/radar           → RadarScreen (tab shell)
/driver/community       → CommunityScreen (tab shell)
/driver/earnings        → EarningsScreen (tab shell)

/driver/go-online       → GoOnlineScreen
/driver/ride/new/:id    → NewRideRequestScreen
/driver/ride/active/:id → ActiveRideScreen (en route to pickup)
/driver/ride/pickup/:id → AtPickupScreen
/driver/ride/progress/:id → RideInProgressScreen
/driver/ride/complete/:id → RideCompleteScreen
/driver/ride/rate/:id   → RateRiderScreen
/driver/profile         → DriverProfileScreen
/driver/settings        → DriverSettingsScreen
```

---

## DRIVER STATE (RIVERPOD)

```dart
// apps/driver/lib/state/driver_state_notifier.dart

enum DriverAppState {
  loggedOut,
  onboardingIncomplete,
  offline,
  goingOnline,
  onlineAvailable,
  reviewingRequest,
  acceptingRide,
  assigned,
  arrived,
  inProgress,
  completingRide,
  completed,
  onBreak,
  errorRecovery,
}

@immutable
class DriverData {
  final DriverAppState appState;
  final String? driverId;
  final String? userId;
  final String? activeRideId;
  final String? riderContactName;
  final String? riderPaymentMethod;
  final String? bookingMode;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? destinationAddress;
  final double? destinationLat;
  final double? destinationLng;
  final bool radarActive;

  const DriverData({ /* all fields */ });

  DriverData copyWith({ /* ... */ }) => DriverData(/* ... */);
  static DriverData empty() => const DriverData(appState: DriverAppState.loggedOut);
}

class DriverStateNotifier extends Notifier<DriverData> {
  @override
  DriverData build() => DriverData.empty();

  void setStatus(DriverAppState appState) =>
    state = state.copyWith(appState: appState);

  void setActiveRide({
    required String rideId,
    required String? paymentMethod,
    required String? pickupAddress,
    required double? pickupLat,
    required double? pickupLng,
    required String? destinationAddress,
    required double? destLat,
    required double? destLng,
    required String? bookingMode,
    required String? riderName,
  }) => state = state.copyWith(
    activeRideId: rideId,
    riderPaymentMethod: paymentMethod,
    pickupAddress: pickupAddress,
    pickupLat: pickupLat,
    pickupLng: pickupLng,
    destinationAddress: destinationAddress,
    destinationLat: destLat,
    destinationLng: destLng,
    bookingMode: bookingMode,
    riderContactName: riderName,
    appState: DriverAppState.assigned,
  );

  void clearActiveRide() => state = state.copyWith(
    activeRideId: null,
    riderPaymentMethod: null,
    pickupAddress: null,
    destinationAddress: null,
    bookingMode: null,
    riderContactName: null,
    appState: DriverAppState.onlineAvailable,
  );
}
```

---

## SCREEN D1 — DRIVER HOME / DASHBOARD

**File:** `apps/driver/lib/screens/driver_home_screen.dart`
**Map coverage:** 55% (sheet 45%)
**Map state:** Neighbourhood level, driver GPS, ambient demand dots, zone boundary

### Map elements:
- 🚗 Driver position — car icon (top-down), rotates with `heading` from `driver_locations`
- 🔵 Ambient `pending` ride_requests nearby — small pulsing dots (not tappable)
- 🔷 Zone boundary — hex outline of `current_zone_id` from `bubble_zones`
- Zone demand badge — small pill: "4 requests nearby"
- If `status = offline` — map has 60% grey overlay to signal inactive

### Sheet layout (45%):
```dart
Column(children: [
  // 1. Drag handle
  _DragHandle(),

  // 2. Status pill (MOST IMPORTANT ELEMENT)
  _StatusPill(
    status: driverState.appState,
    zoneName: currentZoneName,
    onTap: () => context.go('/driver/go-online'),
  ),

  // 3. Today's summary (compact 3-column row)
  _TodaySummaryRow(
    tripCount: todayTripCount,
    hoursOnline: todayHoursOnline,
    estimatedEarnings: todayEstimatedEarnings,
  ),

  // 4. Incoming ride slot (only if a ride request has been pushed to this driver)
  if (incomingRide != null)
    _IncomingRideCard(
      ride: incomingRide!,
      onTap: () => context.go('/driver/ride/new/${incomingRide!.id}'),
    ),

  // 5. Radar status row (if radar_enabled = true)
  if (radarEnabled)
    _RadarStatusRow(onTap: () => context.go('/driver/radar')),

  // 6. Bottom action row
  _BottomActionRow(
    onEarnings: () => context.go('/driver/earnings'),
    onRadar: () => context.go('/driver/radar'),
    onProfile: () => context.go('/driver/profile'),
  ),
])
```

### Status pill visual states:
```dart
// Available (online): green fill, white text "Online"
// Offline: red fill, white text "Offline"
// On break: amber fill, white text "On break"
// On ride: blue fill, white text "On a ride"
// Large, pill-shaped, prominent — tapping it goes to GoOnline screen
```

### Subscription compliance checks on mount:
```dart
void _verifyDriverEligibility() {
  final driver = ref.read(driverDataProvider);

  if (driver.subscriptionActive == false) {
    _showBanner('Subscription expired. Renew to go online.');
    return;
  }
  if (driver.minProfileRequirementsMet == false) {
    _showBanner('Complete your profile to go online.');
    return;
  }
  if (driver.complianceStatus == 'suspended') {
    _showBanner('Account suspended. Contact support.');
    return;
  }
}
```

### Incoming ride via Realtime:
```dart
// Subscribe to ride_requests where driver is notified
// When a new pending request arrives for this driver, show the _IncomingRideCard
// The card auto-dismisses after 30 seconds
_incomingTimer = Timer(const Duration(seconds: 30), () {
  setState(() => _incomingRide = null);
});
```

---

## SCREEN D2 — GO ONLINE / STATUS TOGGLE

**File:** `apps/driver/lib/screens/go_online_screen.dart`
**Map:** Hidden. Full-screen page.

### Layout:
1. Current status display (large icon + status label + "online since X")
2. Three status cards (large tap targets):
   - 🟢 "Go Online" → `status = available`
   - ☕ "Take a Break" → `status = on_break`
   - 🔴 "End Shift" → `status = offline`

3. Pre-shift checklist (first time going online each day):
   ```dart
   // Show once per day using SharedPreferences
   // ✅ Vehicle documents valid?
   // ✅ Chauffeurspas on you?
   // ✅ Phone charged and mounted?
   // "I'm ready" button to confirm
   ```

4. Auto-accept settings (collapsible):
   ```dart
   // Toggle: drivers.auto_accept_enabled
   // Slider: drivers.auto_accept_min_fare
   // Slider: drivers.auto_accept_min_score
   ```

### Status change — MUST write to backend first:
```dart
Future<void> _changeStatus(String newStatus) async {
  // Disable all taps immediately
  setState(() => _loading = true);

  try {
    // Step 1: Write to backend FIRST
    await ref.read(driverApiProvider).setStatus(status: newStatus);

    // Step 2: Start/stop location service based on status
    if (newStatus == 'available') {
      await DriverLocationService.start();
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onlineAvailable);
    } else if (newStatus == 'offline') {
      await DriverLocationService.stop();
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.offline);
    } else if (newStatus == 'on_break') {
      // Location continues — just stop receiving rides
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onBreak);
    }

    // Step 3: Navigate back to home
    context.go('/driver');

  } on DioException {
    // Step 4: On failure — do NOT update local state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update status. Try again.')),
    );
  } finally {
    setState(() => _loading = false);
  }
}
```

---

## SCREEN D3 — NEW RIDE REQUEST (INCOMING)

**File:** `apps/driver/lib/screens/new_ride_request_screen.dart`
**Map coverage:** 60% (sheet 40%, no drag — locked during countdown)
**Map state:** Driver position + pickup pin + dashed route line from driver to pickup

### Map elements:
- 🚗 Driver own position
- 📍 Pickup pin (accent colour, larger)
- Dashed route line driver → pickup (shows distance visually)
- ETA label on route: "~4 min"

### The 30-second countdown — CRITICAL:

```dart
int _countdown = 30;
Timer? _countdownTimer;

@override
void initState() {
  super.initState();
  _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    setState(() {
      _countdown--;
      if (_countdown <= 0) {
        timer.cancel();
        _onExpired();
      }
    });
  });
}

@override
void dispose() {
  _countdownTimer?.cancel();
  super.dispose();
}

void _onExpired() {
  // Auto-decline logged, request moves to next driver
  context.go('/driver');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.requestExpired)),
  );
}
```

### Sheet layout (40%):
1. **Countdown ring** (large circular progress, countdown from 30 to 0)
2. **Booking mode badge**: ⚡ Instant / 🔄 Marketplace / 📅 Scheduled
3. **Rider info row:**
   - 👤 Rider name (`pickup_contact_name`)
   - If this driver is in rider's favourites: ⭐ "Your favourite rider" badge
4. **Route card:**
   - 📍 Pickup: `pickup_address` (bold, shortened)
   - 🏁 Destination: `destination_address` (muted, shortened)
   - 📏 Distance: `estimated_distance_km` km
   - ⏱ Est. ride: `estimated_duration_min` min
   - 🚗 Your ETA to pickup (calculated from driver current position)
5. **Fare row:**
   - 💰 Amount (from `estimated_price` or `offered_fare`)
   - 💳 Payment method icon
   - If marketplace: 🏷️ discount badge
6. **Two CTAs (equal width, side by side):**
   - ✅ "Accept" (primary green)
   - ✕ "Decline" (secondary/muted)

### Accept ride — button lock + idempotency:
```dart
bool _isAccepting = false;

Future<void> _acceptRide() async {
  if (_isAccepting) return;
  setState(() => _isAccepting = true);
  _countdownTimer?.cancel();

  try {
    await ref.read(driverApiProvider).acceptRide(
      rideRequestId: widget.rideId,
    );

    // Store active ride in state
    ref.read(driverStateProvider.notifier).setActiveRide(
      rideId: widget.rideId,
      paymentMethod: _rideData?.paymentMethod,
      pickupAddress: _rideData?.pickupAddress,
      pickupLat: _rideData?.pickupLat,
      pickupLng: _rideData?.pickupLng,
      destinationAddress: _rideData?.destinationAddress,
      destLat: _rideData?.destinationLat,
      destLng: _rideData?.destinationLng,
      bookingMode: _rideData?.bookingMode,
      riderName: _rideData?.pickupContactName,
    );

    context.go('/driver/ride/active/${widget.rideId}');

  } on DioException catch (e) {
    if (e.response?.statusCode == 409) {
      // Ride already taken by another driver — race condition
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This ride was accepted by another driver.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.connectionProblem)),
      );
    }
    context.go('/driver');
  }
  // Do not set _isAccepting = false in finally — button stays locked after tap
}
```

---

## SCREEN D4 — ACTIVE RIDE (NAVIGATING TO PICKUP)

**File:** `apps/driver/lib/screens/active_ride_nav_screen.dart`
**Map coverage:** 68% (sheet 32% default, drag to 55% for details)
**Map state:** Driver live position + pickup pin + solid route line + ETA bubble

### Map updates:
- Driver position updates from `flutter_background_service` location stream
- Route redraws as driver moves (throttled to once per 10 seconds)
- ETA bubble on driver marker updates each location change

### Sheet at 32%:
1. Drag handle
2. Navigation summary: 📍 pickup address + 🕐 ETA + 📏 distance remaining
3. Rider name + payment method icon (compact)
4. Action icons: 💬 Chat | 📞 Call
5. "I've Arrived" button (full width, primary)

### Sheet expanded to 55%:
- Full pickup address
- Booking mode badge
- If scheduled: original scheduled time
- 🚩 "Report issue" link

### "I've Arrived":
```dart
Future<void> _markArrived() async {
  setState(() => _loading = true);
  try {
    await ref.read(driverApiProvider).markArrived(
      rideRequestId: widget.rideId,
    );
    ref.read(driverStateProvider.notifier).setStatus(DriverAppState.arrived);
    context.go('/driver/ride/pickup/${widget.rideId}');
  } on DioException {
    // Show error, stay on this screen
  } finally {
    setState(() => _loading = false);
  }
}
```

**Effect on rider:** Rider's app detects `status = driver_arrived` via Realtime, status pill turns green.

---

## SCREEN D5 — AT PICKUP

**File:** `apps/driver/lib/screens/at_pickup_screen.dart`
**Map coverage:** 65% (sheet 35%, no drag)
**Map state:** Street level zoom (~17), green arrival ring animation around driver

### Wait timer:
```dart
// Start counting when screen mounts
int _waitSeconds = 0;
Timer? _waitTimer;

@override
void initState() {
  super.initState();
  _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    setState(() => _waitSeconds++);
  });
}

String get _waitDisplay {
  final m = _waitSeconds ~/ 60;
  final s = _waitSeconds % 60;
  return 'Waiting: ${m}:${s.toString().padLeft(2, '0')}';
}
```

### Sheet layout:
1. Drag handle
2. 🟢 "Waiting for rider..." status banner (pulsing)
3. Rider name (large, bold)
4. "Paying by: [icon] [method]"
5. Full pickup address
6. Wait timer display
7. 💬 Chat | 📞 Call icons
8. "Start Ride" button (full width, primary)
9. "Rider didn't show" text button (danger colour) — only visible after 5 minutes wait

### Start ride:
```dart
Future<void> _startRide() async {
  setState(() => _loading = true);
  try {
    await ref.read(driverApiProvider).startRide(rideRequestId: widget.rideId);
    ref.read(driverStateProvider.notifier).setStatus(DriverAppState.inProgress);
    context.go('/driver/ride/progress/${widget.rideId}');
  } on DioException {
    // Show error
  } finally {
    setState(() => _loading = false);
  }
}
```

### No-show flow:
```dart
// Show after _waitSeconds >= 300 (5 minutes)
Future<void> _reportNoShow() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Confirm no-show?'),
      content: Text('This will be logged. Are you sure?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Wait longer')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Confirm no-show')),
      ],
    ),
  );

  if (confirmed != true) return;

  await ref.read(driverApiProvider).reportNoShow(payload: {
    'ride_request_id': widget.rideId,
    'driver_id': driverId,
  });
  ref.read(driverStateProvider.notifier).clearActiveRide();
  DriverLocationService.keepRunning(); // Stay online
  context.go('/driver');
  // Toast: "No-show reported. You're back online."
}
```

---

## SCREEN D6 — RIDE IN PROGRESS

**File:** `apps/driver/lib/screens/ride_in_progress_screen.dart`
**Map coverage:** 70% (sheet 30% minimal, drag to 50% for details)
**Map state:** Driver moving toward destination, route driver→destination, ETA bubble

### Keep UI minimal — driver is driving:

Sheet at 30%:
1. Drag handle
2. 🏁 Destination address (bold)
3. ETA pill: "Arriving in 8 min" (large, prominent)
4. Distance remaining
5. "Complete Ride" button (full width, primary)

Sheet expanded to 50%:
- Rider name + payment reminder
- 💬 Chat button
- Full destination address
- 🚩 "Report issue" link

### Complete ride:
```dart
bool _isCompleting = false;

Future<void> _completeRide() async {
  if (_isCompleting) return;  // Prevent double-tap
  setState(() => _isCompleting = true);

  try {
    await ref.read(driverApiProvider).completeRide(
      rideRequestId: widget.rideId,
    );
    ref.read(driverStateProvider.notifier).setStatus(DriverAppState.completed);
    context.go('/driver/ride/complete/${widget.rideId}');
  } on DioException {
    setState(() => _isCompleting = false);
    // Show error — rider stays in progress
  }
  // Do not unlock button in finally — keep locked after successful tap
}
```

**Effect on rider:** Rider's `CompleteScreen` appears automatically via Realtime.

---

## SCREEN D7 — RIDE COMPLETE

**File:** `apps/driver/lib/screens/ride_complete_screen.dart`
**Map coverage:** 60% (sheet 40%, no drag)
**Map state:** Destination pin with ✅ badge, street level zoom

### Sheet layout:
1. Drag handle
2. ✅ Animated checkmark
3. "Ride completed!" heading
4. Trip summary: pickup → destination, distance, duration

5. **PAYMENT REMINDER — MOST PROMINENT ELEMENT ON THIS SCREEN:**
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.primaryContainer,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
  ),
  child: Row(children: [
    Icon(_paymentIcon, size: 32),
    const SizedBox(width: 12),
    Expanded(
      child: Text(
        _paymentInstructions, // See below
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
  ]),
)
```

Payment instruction text:
```dart
String get _paymentInstructions {
  switch (riderPaymentMethod) {
    case 'cash': return 'Collect €${amount} cash from rider';
    case 'pin': return 'Ask rider to tap their card';
    case 'tikkie': return 'Send rider a Tikkie request';
    default: return 'Collect payment from rider';
  }
}
```

6. "Send receipt to rider" text button → opens receipt modal
7. Two CTAs:
   - ⭐ "Rate this rider" → navigate to `/driver/ride/rate/:id`
   - "Skip" → navigate to `/driver`

---

## SCREEN D8 — RATE RIDER

**File:** `apps/driver/lib/screens/rate_rider_screen.dart`
**Map:** Hidden. Full themed background.

### Sheet layout (50% scrollable):
1. Rider card: 👤 name + booking mode badge + payment icon
2. ★★★★★ Star rating (required)
3. Optional note (max 100 chars)
4. "Report an issue" text link (muted, bottom)
5. Submit button + Skip link

### On submit:
```dart
Future<void> _submit() async {
  await ref.read(driverApiProvider).rateRider(payload: {
    'ride_request_id': widget.rideId,
    'rider_token': riderToken,
    'driver_rating_of_rider': _stars,
    'driver_rated_at': DateTime.now().toIso8601String(),
  });

  if (_reported) {
    await ref.read(driverApiProvider).reportRider(payload: {
      'reporter_type': 'driver',
      'reason': _reportReason,
      'ride_request_id': widget.rideId,
    });
  }

  ref.read(driverStateProvider.notifier).clearActiveRide();
  context.go('/driver');
}
```

---

## SCREEN D9 — RETURN RIDE RADAR

**File:** `apps/driver/lib/screens/radar_screen.dart`
**Map coverage:** 100% (full screen map + floating controls)
**Map state:** City level (~12), hex zones coloured by demand, match pins

### Map elements:
- 🚗 Driver own position
- 🔷 All bubble zones — fill colour based on demand level from `v_zone_demand` (if view exists) or calculated from recent `ride_requests`
- 📍 Radar match pins — for each `radar_matches` record for this driver
- 🏠 Home zone highlight (driver's `heading_home_zone_id` in distinct border)

### Zone colour coding:
```dart
Color _zoneColour(int demandScore) {
  if (demandScore >= 8) return Colors.orange.withOpacity(0.5);
  if (demandScore >= 4) return Colors.yellow.withOpacity(0.3);
  return Colors.grey.withOpacity(0.1);
}
```

### Floating controls:
```dart
// Top bar (semi-transparent)
Row(children: [
  BackButton(),
  Text(l10n.returnRideRadar),
  Spacer(),
  Switch(
    value: radarActive,
    onChanged: (val) => _toggleRadar(val),
  ),
])
```

### Bottom match tray (slides from 20% to 55% when matches exist):
```dart
// No matches — 20% height
Center(child: Column(children: [
  CircularProgressIndicator(),
  Text(l10n.scanningForReturnRides),
  // Auto-accept settings
]))

// Matches found — slides to 55%
Column(children: [
  Text(l10n.matchesFound(matchCount)),
  Expanded(
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemBuilder: (_, i) => _RadarMatchCard(match: matches[i]),
    ),
  ),
])
```

### Radar match card:
```dart
class _RadarMatchCard extends StatelessWidget {
  // Shows: pickup zone, direction, match score, offered fare, ETA, detour time
  // [Accept] [Skip] buttons
}
```

### Data sources:
```dart
// Subscribe to driver_radar_sessions and radar_matches via Realtime
// trigger scan-radar edge function via GET /api/auction/radar
final radarData = await ref.read(driverApiProvider).getRadar(
  lat: _currentLat,
  lng: _currentLng,
);
```

---

## SCREEN D10 — EARNINGS

**File:** `apps/driver/lib/screens/earnings_screen.dart`
**Map:** Hidden. Full stats page.

### Layout:
1. Period selector tabs: Today | This week | This month
2. Summary row: 🚗 trips | 📏 km | ⏱ hours | 💰 est. earnings
3. Trip list from `driver_trip_history` JOIN `ride_requests`:
   - Each row: 📍 pickup → 🏁 destination + km + duration + payment method icon
   - Tap: expand to show full address + rider name + date/time
4. Receipt history from `receipts` table

---

## SCREEN D11 — ONBOARDING (Multi-step)

**File:** `apps/driver/lib/screens/onboarding/onboarding_screen.dart`

The onboarding tracks progress in `driver_onboarding_steps`. Each step writes to that table and to `drivers`.

### Steps:
1. **Personal info** → writes `drivers.full_name`, `phone`, `gender`, `email`
2. **Business info** → writes `drivers.kvk_number`, `business_name`, `kvk_verified` (via KVK API call)
3. **Vehicle info** → writes `drivers.vehicle_make`, `vehicle_model`, `vehicle_year`, `vehicle_plate`, `vehicle_type`, `vehicle_colour`, `passenger_seats`
4. **Compliance documents** — each doc is uploaded and `driver_verifications` is updated:
   - Chauffeurspas (verified via `verify-chauffeurspas` edge function)
   - Rijbewijs (driver's licence)
   - VOG (certificate of good conduct)
   - Taxidiploma
   - Vehicle insurance
5. **Rates** → writes `drivers.base_fare`, `per_km_rate`, `per_min_rate`, `minimum_fare`, `waiting_time_rate_per_min`
6. **Legal declarations** → writes `drivers.tos_accepted`, `indemnification_accepted`, `data_accuracy_declared`

### Photo upload:
```dart
// Uses image_picker + Supabase Storage
Future<String?> _uploadPhoto(String path, String bucket, String fileName) async {
  final file = File(path);
  final bytes = await file.readAsBytes();
  await Supabase.instance.client.storage
    .from(bucket)
    .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/jpeg'));
  return Supabase.instance.client.storage.from(bucket).getPublicUrl(fileName);
}
```

### Progress persistence:
```dart
// Read current step from driver_onboarding_steps on screen mount
final steps = await Supabase.instance.client
  .from('driver_onboarding_steps')
  .select()
  .eq('driver_id', driverId)
  .single();

// Resume from where driver left off
final currentStep = steps['current_step'] as int? ?? 1;
```

---

## BACKGROUND LOCATION SERVICE (DRIVER ONLY)

This is the most critical and most device-specific feature. Must be tested on physical devices.

### Setup:

**Android — `AndroidManifest.xml`** (already covered in Mapbox guide, but repeating for clarity):
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:foregroundServiceType="location"
    android:exported="false"/>
```

**iOS — `Info.plist`**: Already shown in Mapbox guide. Include all three location keys.

### The background service:

```dart
// apps/driver/lib/services/driver_location_service.dart

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // This runs in a separate isolate — cannot access Flutter widgets
  DartPluginRegistrant.ensureInitialized();

  // Keep alive check
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'HeyCaby Driver',
      content: 'Locatie actief — je bent online',
    );
  }

  // Upload location every 5 seconds
  Timer.periodic(const Duration(seconds: 5), (_) async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Send to app via service.invoke for UI update
    service.invoke('location_update', {
      'lat': position.latitude,
      'lng': position.longitude,
      'heading': position.heading,
      'speed_kmh': position.speed * 3.6,
      'accuracy': position.accuracy,
      'timestamp': DateTime.now().toIso8601String(),
    });
  });

  // Listen for stop command
  service.on('stop').listen((_) => service.stopSelf());
}

class DriverLocationService {
  static final _service = FlutterBackgroundService();

  static Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: 'heycaby_driver_location',
        initialNotificationTitle: 'HeyCaby Driver',
        initialNotificationContent: 'Locatie actief',
        foregroundServiceNotificationId: 1001,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onStart,
        autoStart: false,
      ),
    );
  }

  static Future<void> start() async {
    // Request background location permission first
    final status = await Permission.locationAlways.request();
    if (!status.isGranted) {
      throw Exception('Background location permission denied');
    }
    await _service.startService();
  }

  static Future<void> stop() async {
    _service.invoke('stop');
  }

  static bool get isRunning => _service.isRunningSync();

  /// Stream of location updates from background service
  static Stream<Map<String, dynamic>?> get locationStream =>
    _service.on('location_update');
}
```

### Uploading location to backend from main isolate:
```dart
// In DriverHomeScreen — listen to location service stream
void _startLocationUploadListener() {
  DriverLocationService.locationStream.listen((data) async {
    if (data == null) return;
    await ref.read(driverApiProvider).uploadLocation(
      lat: data['lat'] as double,
      lng: data['lng'] as double,
      heading: data['heading'] as double?,
    );
    // Update local map marker
    await _markers?.setDriverMarker(
      data['lat'] as double,
      data['lng'] as double,
      heading: data['heading'] as double? ?? 0,
    );
  });
}
```

### Location upload failure handling:
```dart
// Monitor for consecutive failures
int _locationFailCount = 0;

void _onLocationUploadFailed() {
  _locationFailCount++;
  if (_locationFailCount >= 3) {
    // Show persistent banner
    setState(() => _locationInterrupted = true);
    // Banner: "Location tracking interrupted. Riders may not see your position."
    // Action: "Fix Location" button → opens settings
  }
}

void _onLocationUploadSuccess() {
  _locationFailCount = 0;
  setState(() => _locationInterrupted = false);
}
```

---

## DRIVER PUSH NOTIFICATIONS

Drivers receive FCM notifications via `drivers.push_token`.

### Register on app launch:
```dart
// In main.dart for driver app
static Future<void> initializeForDriver() async {
  await Firebase.initializeApp();
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Get FCM token
  final token = await messaging.getToken();
  if (token != null) await _registerDriverToken(token);

  // Refresh listener
  messaging.onTokenRefresh.listen(_registerDriverToken);

  FirebaseMessaging.onBackgroundMessage(_handleBackground);
  FirebaseMessaging.onMessage.listen(_handleForeground);
}

static Future<void> _registerDriverToken(String token) async {
  // Write directly to drivers.push_token (column already exists in your DB)
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  await Supabase.instance.client
    .from('drivers')
    .update({'push_token': token})
    .eq('user_id', user.id);
}
```

### Notification categories:

| Trigger | Notification | Priority |
|---------|-------------|----------|
| New instant ride request | "⚡ New ride — {pickup area} · {fare}" | HIGH |
| New marketplace match | "🔄 Route match — {fare}" | HIGH |
| New scheduled ride | "📅 Scheduled ride for {time}" | MEDIUM |
| Rider cancelled | "Ride cancelled by rider" | LOW |
| Radar match | "🔄 Return ride on your route" | MEDIUM |
| Rating revealed | "⭐ Your rider rated you {stars} stars" | LOW |

---

## APP RECOVERY ON LAUNCH (DRIVER)

```dart
Future<void> _recoverStateOnLaunch() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  // Check for active ride in local state
  final savedRideId = await SharedPreferences.getInstance()
    .then((p) => p.getString('driver_active_ride_id'));

  if (savedRideId == null) {
    // Check driver status from DB
    final driver = await Supabase.instance.client
      .from('drivers')
      .select('status')
      .eq('user_id', user.id)
      .single();
    // Restore appropriate state
    return;
  }

  // Fetch current ride status
  try {
    final ride = await Supabase.instance.client
      .from('ride_requests')
      .select()
      .eq('id', savedRideId)
      .single();

    switch (ride['status'] as String) {
      case 'accepted':
        context.go('/driver/ride/active/$savedRideId');
        break;
      case 'driver_arrived':
        context.go('/driver/ride/pickup/$savedRideId');
        break;
      case 'started':
        context.go('/driver/ride/progress/$savedRideId');
        break;
      case 'completed':
        context.go('/driver/ride/complete/$savedRideId');
        break;
      default:
        await SharedPreferences.getInstance()
          .then((p) => p.remove('driver_active_ride_id'));
    }
  } catch (_) {
    // Fetch failed — show home screen
  }
}
```

---

## EXTERNAL NAVIGATION HANDOFF

On the Active Ride screen and At Pickup screen, the driver has a "Navigate" button that opens Apple Maps, Google Maps, or Waze:

```dart
// apps/driver/lib/services/navigation_handoff_service.dart
import 'package:url_launcher/url_launcher.dart';

class NavigationHandoffService {
  static Future<void> navigateTo({
    required double lat,
    required double lng,
    required String label,
  }) async {
    final encodedLabel = Uri.encodeComponent(label);

    // iOS: try Apple Maps first
    if (Platform.isIOS) {
      final appleUrl = Uri.parse('maps://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
      if (await canLaunchUrl(appleUrl)) {
        await launchUrl(appleUrl);
        return;
      }
    }

    // Android: try Google Maps
    final googleUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'
    );
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback: Waze
    final wazeUrl = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    if (await canLaunchUrl(wazeUrl)) {
      await launchUrl(wazeUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // Last resort: browser Google Maps
    await launchUrl(googleUrl);
  }
}
```

---

## REALTIME SUBSCRIPTIONS (DRIVER)

| Subscription | Table | Filter | Screen |
|-------------|-------|--------|--------|
| New incoming rides | `ride_requests` | `status = pending AND zone_id = driver_zone` | D1 HomeScreen |
| Active ride status | `ride_requests` | `id = active_ride_id` | All active ride screens |
| Bid responses | `ride_bids` | `driver_id = driver_id` | D3 MarketScreen |
| Radar matches | `radar_matches` | `driver_id = driver_id` | D9 RadarScreen |
| Community posts | `community_posts` | none | D11 CommunityScreen |
| Notifications | `notifications` | `user_id = driver_id` | All screens (badge) |

---

## BUILD ORDER

```
Step 1  → Supabase Auth (login/register) — test with real account
Step 2  → Onboarding multi-step — personal + vehicle + documents + rates
Step 3  → GoOnline screen — status toggle writes to backend FIRST
Step 4  → Background location service — TEST ON PHYSICAL DEVICE IMMEDIATELY
Step 5  → Driver home screen — status pill + map + ambient demand
Step 6  → New ride request screen — 30s countdown + accept/decline
Step 7  → Active ride screen (navigating to pickup) — live GPS route
Step 8  → At pickup screen — wait timer + start ride + no-show
Step 9  → Ride in progress screen — route to destination + complete
Step 10 → Ride complete screen — PAYMENT REMINDER PROMINENT + receipt
Step 11 → Rate rider screen
Step 12 → Market screen — Nu / Gepland / Markt tabs + accept-first + bid
Step 13 → Radar screen — hex map + match cards
Step 14 → Earnings screen
Step 15 → Community screen
Step 16 → Profile + Settings screens
Step 17 → Push notification registration
Step 18 → External navigation handoff (Apple Maps / Google Maps / Waze)
Step 19 → App recovery on launch
Step 20 → Full end-to-end test on TWO REAL PHONES simultaneously
```

---

## SYNC TEST (DRIVER SIDE)

Before marking any screen done:

```
[ ] Driver goes online → appears on rider's map within 10s
[ ] Rider creates ride → Driver receives notification within 5s
[ ] Driver accepts → Rider sees driver dot within 3s
[ ] Driver dot moves → Rider map updates within 5s
[ ] Driver taps "Arrived" → Rider gets push notification
[ ] Driver taps "Start ride" → Rider status updates within 2s
[ ] Driver taps "Complete" → Rider Complete screen appears within 3s
[ ] No-show reported → security_events row logged in DB
[ ] Marketplace: driver bids → rider sees bid in bids screen
[ ] Radar: driver accepts match → system queues for after current drop-off
[ ] Background location: lock phone → location still uploads every 5s
[ ] App killed and relaunched mid-ride → returns to correct ride screen
[ ] Network drops mid-ride → reconnects and resumes when restored
```

---

## DRIVER-RIDER SYNC REFERENCE

The most important moments from the driver's side:

| Driver taps | Rider sees | Latency target |
|-------------|-----------|----------------|
| Accept | Searching → Active Ride, driver dot appears | < 3s |
| I've Arrived | Status pill → "Your driver is here" + push | < 2s |
| Start Ride | Status pill → "Ride in progress" | < 2s |
| Complete Ride | Ride Complete screen appears | < 3s |
| Rate submitted | `ratings_revealed_at` set in DB | immediate |

If any of these exceed their latency target consistently, the Realtime subscription is not set up correctly or the Supabase Realtime publication does not include the `ride_requests` table. Check Supabase Realtime settings in the dashboard.

---

## MARKET SCREEN (TABS)

**File:** `apps/driver/lib/screens/market_screen.dart`

Three tabs:
1. **Nu (Now)** — instant ride requests currently available in driver's zone
2. **Gepland (Scheduled)** — upcoming scheduled rides the driver can claim
3. **Markt (Marketplace)** — marketplace bids the driver can compete for

Each tab reads from `ride_requests` filtered by `booking_mode` and `status`:
```dart
// Nu tab
final instantRides = await Supabase.instance.client
  .from('ride_requests')
  .select('*, ride_bids(*)')
  .eq('booking_mode', 'instant')
  .eq('status', 'pending')
  .order('created_at', ascending: false);

// Gepland tab
final scheduledRides = await Supabase.instance.client
  .from('ride_requests')
  .select()
  .eq('booking_mode', 'scheduled')
  .eq('status', 'pending')
  .gte('scheduled_pickup_at', DateTime.now().toIso8601String());

// Markt tab
final marketRides = await Supabase.instance.client
  .from('ride_requests')
  .select('*, ride_bids(*)')
  .eq('booking_mode', 'marketplace')
  .eq('status', 'bidding');
```

---

*HeyCaby Driver Flutter Build Guide — March 2026*
*Based on live Supabase audit of HeyCaby production.*
*Read heycaby_mapbox_flutter.md and heycaby_rider_flutter.md alongside this document.*
*Background location MUST be tested on physical devices — not simulators.*
*Backend unchanged. Flutter UI only.*
