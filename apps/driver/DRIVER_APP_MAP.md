# HeyCaby Driver App — Map & Build Order

Reference: `heycaby-flutter-doc/heycaby_driver_flutter.md`, `heycaby-flutter-doc/heycaby_flutter_spec.md` (Part 6).

---

## Rules (from spec)

| Rule | Meaning |
|------|--------|
| **R1** | Every driver action that changes ride status goes through API (`POST /api/driver/ride/[action]`). Never write `ride_requests.status` directly from Flutter. |
| **R2** | Background location must be tested on a **physical device**. |
| **R3** | Driver app uses **Supabase Auth** (email/password). JWT in all API calls as `Authorization: Bearer <token>`. |
| **R4** | Driver status (`drivers.status`) is written to backend **before** UI updates. |
| **R5** | `booking_mode` on `ride_requests` is read-only for driver. |

---

## Navigation (go_router)

```
Auth (not logged in):
  /login                    → LoginScreen
  /register                 → RegisterScreen

Onboarding:
  /onboarding                → OnboardingScreen (multi-step)

Main (after auth + onboarding):
  /driver                    → DriverHomeScreen (tab)
  /driver/market             → MarketScreen (tab)
  /driver/radar               → RadarScreen (tab)
  /driver/community          → CommunityScreen (tab)
  /driver/earnings            → EarningsScreen (tab)

  /driver/go-online          → GoOnlineScreen
  /driver/ride/new/:id       → NewRideRequestScreen (30s countdown, Accept/Decline)
  /driver/ride/active/:id    → ActiveRideScreen (navigating to pickup, "I've Arrived")
  /driver/ride/pickup/:id    → AtPickupScreen (waiting, "Start Ride", no-show after 5 min)
  /driver/ride/progress/:id  → RideInProgressScreen (en route, "Complete Ride")
  /driver/ride/complete/:id  → RideCompleteScreen (payment reminder, rate rider)
  /driver/ride/rate/:id      → RateRiderScreen
  /driver/profile            → DriverProfileScreen
  /driver/settings           → DriverSettingsScreen
```

---

## Driver state (Riverpod)

- **DriverAppState**: `loggedOut` | `onboardingIncomplete` | `offline` | `goingOnline` | `onlineAvailable` | `reviewingRequest` | `acceptingRide` | `assigned` | `arrived` | `inProgress` | `completingRide` | `completed` | `onBreak` | `errorRecovery`
- **DriverData**: appState, driverId, userId, activeRideId, riderContactName, riderPaymentMethod, bookingMode, pickup/destination address + coords, radarActive
- **DriverStateNotifier**: setStatus, setActiveRide, clearActiveRide

---

## Screens (build order)

| Phase | Screen | Purpose |
|-------|--------|--------|
| **1** | Login, Register | Supabase Auth |
| **1** | DriverHomeScreen | Dashboard: status pill, today summary, incoming ride card, radar row, bottom actions |
| **1** | GoOnlineScreen | Status toggle: Go Online / Take Break / End Shift; pre-shift checklist; auto-accept settings |
| **1** | DriverShell | Tabs: Home, Market, Radar, Community, Earnings |
| **2** | NewRideRequestScreen | Incoming request: map (driver + pickup + route), 30s countdown, Accept/Decline |
| **2** | ActiveRideScreen | Nav to pickup: map, ETA, "I've Arrived" |
| **2** | AtPickupScreen | Wait timer, "Start Ride", "Rider didn't show" (after 5 min) |
| **2** | RideInProgressScreen | To destination, "Complete Ride" |
| **2** | RideCompleteScreen | Payment reminder, rate rider / skip |
| **2** | RateRiderScreen | Stars + optional note, submit |
| **3** | MarketScreen, RadarScreen, CommunityScreen, EarningsScreen | Tab content |
| **3** | OnboardingScreen | Multi-step: personal, business, vehicle, docs, rates, legal |
| **3** | DriverProfileScreen, DriverSettingsScreen | Profile & settings |

---

## Backend touchpoints

- **Auth**: Supabase Auth (email/password). Session → JWT on all API calls.
- **Driver API** (Dio + Bearer token): `setStatus`, `uploadLocation`, `acceptRide`, `markArrived`, `startRide`, `completeRide`, `reportNoShow`, `rateRider`, `createReceipt`, radar/auction endpoints.
- **Supabase Realtime**: `ride_requests` (incoming for driver), `driver_locations` (own position), `radar_matches`, etc.
- **Supabase tables**: `drivers`, `driver_documents`, `driver_onboarding_steps`, `ride_requests`, `driver_locations`, `ride_ratings`, `receipts`, …

---

## Shared packages (from monorepo)

- **heycaby_api**: Supabase client, DriverApi (with auth interceptor), secure storage
- **heycaby_models**: Shared models if any
- **heycaby_ui**: Theme tokens, typography, colors
- **heycaby_map**: MapService, Geocoding, Routing (for driver nav)
- **heycaby_utils**: Validators, formatters
- **heycaby_l10n**: (driver can share or have own ARB later)

---

## Current implementation status

- [x] Map document (this file)
- [x] DriverApi in heycaby_api (Bearer token)
- [x] apps/driver scaffold (main, app, router, shell)
- [x] Driver state provider (DriverData, DriverAppState)
- [x] Login / Register screens (Supabase Auth)
- [x] Driver home screen (dashboard + status pill + today summary)
- [x] Go online screen (status: available / on_break / offline via API)
- [x] Driver shell with tabs: Home, Market, Radar, Community, Earnings
- [x] Placeholder tab screens (Market, Radar, Community, Earnings)
- [x] New ride request screen (30s countdown, Accept/Decline)
- [x] Active ride → At pickup → In progress → Complete → Rate rider flow
- [ ] Radar, earnings, onboarding, profile/settings








# HeyCaby Driver — Driver App Feature Build Guide
## Version 3 — Based on live screenshots + founder brief
### Step-by-step for the Flutter developer

---

## WHAT YOU ARE LOOKING AT IN THE SCREENSHOTS

**Screenshot 1 (Your app — home screen):**
Map at top, blue GPS dot visible, earnings pill at top ("€0.00 | Offline"), hamburger menu top-left, calendar button on the right side of the map, "Slide to go online" slider in the sheet, Scheduled rides card, Driver rating card, Today's rides card, Driver Talk card, three-tab nav (Home / Work / Me).

**Screenshot 2 (Your app — earnings floating card):**
Tapping the earnings pill opens a floating white card with eye icon, "€0.00 Today", "Offline" status, the slide-to-go-online control again (duplicated — this is wrong), and a "View details" link.

**Screenshot 3 (Bolt reference — earnings target):**
Shows a donut chart (€88.91 earnings vs deductions), then a bottom sheet with "Earnings Target" toggle (Daily/Weekly), a target input field, an expenses section, and a gold CTA button.

**Screenshot 4 (Bolt reference — safety toolkit):**
Bottom sheet with "Safety toolkit" title, Emergency call (red, always active), Share trip details (greyed, active rides only), Audio recording (greyed, active rides only).

**Screenshot 5 (Bolt reference — driver help):**
Full screen. "Get help with a trip" section showing recent unanswered rides, "Contact support" section with three rows (Send message, Messages, Browse help articles), "Guidance Centre" with illustrated cards.

---

## THE CHANGES — PLAIN ENGLISH SUMMARY

Here is what changes and why, before you write a single line of code.

1. Replace "Slide to go online" with a three-state swipeable toggle (Offline → Break → Online)
2. The floating earnings card no longer duplicates the toggle — it shows rates and a rate profile switcher instead
3. Remove the calendar floating button from the map
4. Replace it with a "Driver Hub" button — one button that opens a modal with all driver tools
5. Replace the "Driver rating" card with a "Return trips" card
6. The Driver Hub contains: earnings target, rate profile switcher, safety toolkit, help & support, Driver Power Mode (AI suggestions to increase earnings), Driver Union Mode (market intelligence)
7. Remove the hamburger menu — all navigation is bottom-based
8. Today's rides card stays but shows zone-based data when tapped (not exact addresses)
9. Scheduled rides card now filters out overlapping rides using backend logic
10. Community screen no longer has a Profile tab — Profile lives in the "Me" bottom tab

---

## PART 1 — SWIPEABLE THREE-STATE ONLINE TOGGLE

### What it is

Replace the current "Slide to go online" slider with a three-position swipe control. Think of it like a physical gear shift — three positions, each clearly visible as you swipe.

The three states from left to right are:

**Left (red) — Offline.** Driver is not visible to riders. No ride requests received.

**Middle (amber) — Break.** Driver is paused. No new rides. Counts toward break time for Dutch compliance. After a break they resume from here.

**Right (gold) — Online.** Driver is visible and receiving ride requests.

The whole control is one wide pill shape. The thumb (the draggable circle) sits at the current position. As you drag, the background colour behind the thumb fills in — red on the left, amber in the middle, gold on the right. Each zone has a label: "Offline", "Break", "Online". The currently active zone label is white and bold. The other two are faint grey.

### Flutter implementation

Use the `flutter_animate` package for smooth position transitions. The actual drag logic uses `GestureDetector` with `onHorizontalDragUpdate` and `onHorizontalDragEnd`.

```dart
// packages to add:
// flutter_animate: ^4.5.0 (already listed)

class ThreeStateToggle extends StatefulWidget {
  final DriverStatus currentStatus;
  final void Function(DriverStatus) onStatusChanged;
  const ThreeStateToggle({required this.currentStatus, required this.onStatusChanged, super.key});
  @override State<ThreeStateToggle> createState() => _ThreeStateToggleState();
}

class _ThreeStateToggleState extends State<ThreeStateToggle> {
  double _thumbPosition = 0.0; // 0.0 = offline, 0.5 = break, 1.0 = online
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _thumbPosition = _statusToPosition(widget.currentStatus);
  }

  double _statusToPosition(DriverStatus s) {
    if (s == DriverStatus.available) return 1.0;
    if (s == DriverStatus.onBreak) return 0.5;
    return 0.0;
  }

  DriverStatus _positionToStatus(double p) {
    if (p > 0.66) return DriverStatus.available;
    if (p > 0.33) return DriverStatus.onBreak;
    return DriverStatus.offline;
  }

  Color _colorForPosition(double p) {
    final colors = ref.read(colorsProvider);
    if (p > 0.66) return colors.accent;       // gold
    if (p > 0.33) return colors.warning;      // amber
    return colors.error;                       // red
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    // Build the pill with three zone labels and a draggable thumb
    // Full implementation: LayoutBuilder to get width, GestureDetector for drag
  }
}
```

### What happens on release

When the driver releases the thumb it snaps to the nearest of the three positions. An `AnimationController` with a spring curve handles the snap.

When it snaps to a new position that is different from the current status, write to the backend FIRST:

```dart
Future<void> _onStatusSnapped(DriverStatus newStatus) async {
  // WRITE BACKEND FIRST — then update UI
  final success = await ref.read(driverApiProvider).setStatus(newStatus.name);
  if (success && mounted) {
    ref.read(driverStateProvider.notifier).setStatus(newStatus);
  } else {
    // Snap back to old position on failure
    setState(() => _thumbPosition = _statusToPosition(widget.currentStatus));
  }
}
```

The Supabase `drivers.status` enum values are: `available`, `on_break`, `offline`, `on_ride`. Your toggle maps to the first three.

### End shift confirmation

When the driver drags from any state all the way to the far left (offline), if they have been online for more than 30 minutes, show a confirmation dialog before proceeding:

"End your shift? You have been driving for 3h 20m and completed 6 rides today."

Two buttons: "Cancel" (ghost button) and "End shift" (black, not gold — this is a finality action). Only after confirming does the backend write happen.

If the driver has been online for less than 30 minutes, no confirmation dialog — just go offline immediately.

### PART 1 — REFINEMENTS (Swipe-to-reveal, feedback, labels, timestamps)

**Swipe-to-reveal behaviour:** The control should feel like a swipe-to-reveal: as the driver swipes, the state (and its colour) is revealed. Use a single draggable track with three contiguous segments (Offline = red, Break = amber, Online = gold). The thumb position drives which segment is active; the filled portion of the track reveals the current segment (e.g. `Stack` + `ClipRect` or fractional width so the segment under the thumb is clearly visible). Swiping right reveals Break then Online; swiping left reveals Break then Offline.

**Labels — always visible:** Place all three labels **below** the sliding track in one row: "Offline" | "Break" | "Online". The active label is bold/accent; inactive labels are grey (`colors.textSoft`). This way no label is ever covered by the thumb. Use `DriverStrings.offline`, `DriverStrings.onBreak`, `DriverStrings.online`.

**Tactile feedback:**
- **Snap to Break:** Trigger `HapticFeedback.mediumImpact()` or `heavyImpact()` so it feels like a lock/notch.
- **Snap to Online:** Play sound via `SoundService().playNotification()` or `SoundService().playTripComplete()`.
- **Snap to Offline:** Optional `HapticFeedback.lightImpact()`.
- Use a decisive snap animation (e.g. `Curves.easeOutBack`) so the thumb clearly locks into position.

**Timestamps for proof:** Every status change must have a timestamp drivers can use as proof (compliance/disputes). Store `status_changed_at` in the backend when `setStatus` is called (e.g. on `drivers` or a small log table). In the app, after a successful status write, store the time (e.g. in `DriverData`) and show it in the status pill or online widget, e.g. "Online · since 14:32", "Break · since 15:00", "Offline · since 16:45". Optionally show "Last changed: [date], HH:mm" in the earnings card or Driver Hub.

---

## PART 2 — THE ONLINE WIDGET (WHEN DRIVER IS ACTIVE)

### Current problem

Screenshot 2 shows the floating earnings card duplicates the slide-to-go-online control. This is confusing and wastes the most valuable screen real estate in the app.

### The fix

When the driver taps the earnings pill, the floating card no longer shows the toggle. Instead it shows two things:

**Section 1 — Shift summary (same as before):**
Three metric cards in a row: "Online" (hours), "Rides" (count), "Earned" (amount). These come from `drivers.shift_total_online_minutes`, `drivers.shift_rides_today`, `drivers.shift_earnings_today`.

**Section 2 — Rate profile switcher (new):**
Two or three chips labelled with the driver's saved rate profile names: "Standard", "Peak", "Airport". The active profile chip is gold-filled. The others are white with a gold border. Tapping a chip calls `fn_switch_rate_profile(driver_id, profile_id)` which atomically updates rates in the database.

Below the chips, a single line shows the active profile's rates: "€2.00/km · €0.35/min · €2.50 start" in small grey text.

This is genuinely useful to a driver. Before going to pick up an airport run at 6am they tap "Airport" and their rates switch. When they come back to city work they tap "Standard". One tap, backend updated, no menus.

**Rate profiles Supabase table:** `driver_rate_profiles` — already created in the last migration. Has `profile_name`, `base_fare`, `per_km_rate`, `per_min_rate`, `minimum_fare`, `waiting_rate`, `is_active`. When a driver first opens the app and has no profiles, show a "Set up your rates" prompt that creates their first profile from the values already in `drivers.base_fare`, `drivers.per_km_rate`, etc.

### Dutch break compliance banner

If `drivers.continuous_driving_started_at` is more than 4 hours and 15 minutes ago (meaning the driver is 15 minutes from the legal 4.5-hour limit), show a banner inside this card:

"Break recommended in 15 minutes — Dutch law requires 30 min break after 4.5 hours."

Banner is amber background, dark text, small calendar icon. Not a blocking dialog — just a banner.

At exactly 4.5 hours, the banner turns red: "Break required now — please take a 30-minute break."

Still not blocking. Just strongly visible. The driver is a professional and makes their own decision.

---

## PART 3 — REMOVE THE CALENDAR BUTTON. ADD THE DRIVER HUB BUTTON.

### Remove

Delete the floating calendar icon button from the right side of the map. It is redundant — the Scheduled Rides card in the sheet already handles this.

### Add: Driver Hub button

In the same position (right side of map, roughly centre height), place a new button. It is a round white button, same style as the recenter button, with a small grid/compass icon (use `HugeIcons.strokeRoundedGrid01` or similar). This is the Driver Hub.

A small red dot badge appears on this button whenever there is something new (unread support message, safety alert, earnings milestone reached). The badge count comes from:
- Unread `tickets` where `user_type = 'driver'` and `user_id = driver.id` and status is not resolved
- Unresolved `driver_safety_events` where `resolved = false`

```dart
Positioned(
  right: 16,
  top: mapHeight * 0.42, // vertical centre of map
  child: Stack(
    children: [
      _MapFloatingButton(
        icon: HugeIcons.strokeRoundedGrid01,
        onTap: _openDriverHub,
      ),
      if (hubBadgeCount > 0)
        Positioned(
          top: 0, right: 0,
          child: _BadgeDot(count: hubBadgeCount),
        ),
    ],
  ),
)
```

### The Driver Hub modal

Tapping the Driver Hub button opens a bottom sheet at 85% height. White background. Drag handle at top. Title "Driver hub" in 22px bold Inter.

The modal has four sections plus two navigation rows. Each section is separated by a thin divider. At the bottom: **Driver Power Mode** — list tile with lightning icon, chevron; **Driver Union Mode** — list tile with group icon, chevron; tapping pushes the respective screen (PART 7B, PART 7C).

---

## PART 4 — DRIVER HUB — SECTION 1: EARNINGS TARGET

This is modelled on Bolt's earnings target screen (Screenshot 3) but accessed from inside the hub rather than being a separate screen.

**What it shows:**

A donut chart (use `fl_chart: ^0.68.0`, `PieChart` widget) showing today's progress toward the daily target. Gold segment = earned, light grey segment = remaining to target.

In the centre of the donut: the earned amount "€24.50" in 22px bold, and "of €150 target" in 12px grey below.

Below the chart: two chips — "Daily" and "Weekly". Selected chip has gold underline. Toggling switches between showing today's progress vs this week's progress.

A "Set target" text link in small gold below the chart. Tapping opens a small sheet with a number input. Driver types their daily target, taps "Save". This writes to `driver_earnings_targets` (table created in last migration) with `target_type = 'daily'` or `'weekly'`.

**Supabase query for this section:**
```dart
// Get current targets
final targets = await supabase
  .from('driver_earnings_targets')
  .select()
  .eq('driver_id', driverId);

// Get today's earnings (from function created in last migration)
final earnings = await supabase
  .rpc('get_driver_earnings_summary', params: {'p_driver_id': driverId});
```

---

## PART 5 — DRIVER HUB — SECTION 2: RATE PROFILE SWITCHER

Same as described in Part 2 — the rate chips appear here too for drivers who opened the hub without tapping the earnings pill.

Label: "Active rates" in 12px grey.

Three chips max (Standard, Peak, Airport). Below: today's total calculated at active rates.

A "Manage rates" small text link navigates to a full rates management screen where the driver can edit profile names and amounts.

---

## PART 6 — DRIVER HUB — SECTION 3: SAFETY TOOLKIT

Directly inspired by Bolt's safety toolkit (Screenshot 4). Three rows with icons:

**Emergency call — always active, red.**
Icon: red alert bell. Label: "Emergency call" in red 15px medium. Subtitle: "Call 112 — local authorities" in grey. Tapping calls `url_launcher` with `tel:112`. Also logs a `driver_safety_events` row with `event_type = 'emergency_call'`.

**Share trip details — active only during a ride.**
Icon: share icon. Label: "Share trip details". Subtitle: "Available during active trips" when no ride active, or "Share your current ride" when active. When active, tapping generates a `ride_shares` link (table already exists) and opens the system share sheet via `Share.share(url)` from the `share_plus` package.

**Audio recording — active only during a ride.**
Icon: waveform icon. Label: "Audio recording". Subtitle: "Available during active trips" when inactive. During a ride, tapping starts a local audio recording using `record: ^5.0.0` package. Files are stored locally on device (not uploaded — privacy and storage cost). A red recording indicator appears on the map overlay while active. Logs a `driver_safety_events` row with `event_type = 'audio_recording'`.

**Important rule:** "Share trip details" and "Audio recording" are greyed out and non-tappable when `driverStateProvider.status != DriverStatus.onRide`. When a ride starts, they become active. This is exactly how Bolt does it.

```dart
// Safety toolkit row widget
_SafetyRow(
  icon: Icons.waveform,
  label: l10n.audioRecording,
  subtitle: isOnRide ? l10n.tapToRecord : l10n.availableDuringRide,
  isActive: isOnRide,
  onTap: isOnRide ? _startAudioRecording : null,
)
```

---

## PART 7 — DRIVER HUB — SECTION 4: HELP & SUPPORT

Modelled on Bolt's Driver Help screen (Screenshot 5) but as a section inside the hub rather than a separate screen.

**Subsection — Recent trips with issues:**
Shows last 2 tickets from the `tickets` table where `user_type = 'driver'` and `user_id = driver.user_id`. Each row shows: the date, the ride area (not exact address — zone name), and the status. If `status = 'open'` and no response received, show "Awaiting response" in amber. If the driver has not responded, show "You did not respond" in red — exactly like Bolt's screenshot.

A "See all" chevron link on the right opens a full tickets list screen.

**Subsection — Contact support:**
Three rows, exactly like Bolt's screenshot:
1. "Send a message" — opens a new ticket compose sheet. Writes to `tickets` table with `category = 'driver_support'`, `user_type = 'driver'`.
2. "Messages" — opens the conversation view for the most recent open ticket.
3. "Browse help articles" — opens an in-app WebView pointing to your help documentation URL (configure in `app_config` table).

Each row is a simple list tile: icon on left, label, chevron on right. White background. Thin dividers between rows.

**Supabase query:**
```dart
final recentTickets = await supabase
  .from('tickets')
  .select()
  .eq('user_type', 'driver')
  .eq('user_id', driver.userId)
  .order('created_at', ascending: false)
  .limit(3);
```

---

## PART 7B — DRIVER POWER MODE

Smart assistant that analyzes demand, location, time, pricing, return routes, ride patterns — gives real-time suggestions to earn more. Full spec in [driver-design.md](apps/driver/driver-design.md) PART 7B.

**Driver Hub:** List tile "Driver Power Mode" with lightning icon; tap → Power Mode screen.

**Power Mode screen:** Header "POWER MODE / AI suggestions to increase earnings". Six card types:
1. **High Demand Nearby** — zone, +% demand, distance, estimated earnings, [Navigate]
2. **Smart Price Suggestion** — current vs recommended rate, reason, [Apply] [Ignore]
3. **Return Trip Opportunity** — passenger waiting, fare, discount, [Accept ride] (connects to Return Discount)
4. **Surge Opportunity** — event ending, venue, surge %, recommended positioning
5. **Idle Warning** — idle time, move to zone, estimated wait
6. **Goal Tracker** — target, current, remaining, estimated rides

Backend: `driver_locations`, `ride_requests`, `demand_zones`, `driver_rate_profiles`, `return_discount_setting`, `driver_earnings_targets`. Realtime: `supabase.channel("driver_power")`. Route: `/driver/power-mode`.

---

## PART 7C — DRIVER UNION MODE

Data-driven coordination for drivers — collective intelligence through anonymous market signals. Full spec in [driver-design.md](apps/driver/driver-design.md) PART 7C.

**Driver Hub:** List tile "Driver Union Mode" with group icon; tap → Union Mode market dashboard.

**Union Mode screen:** Five sections: (1) Market Balance — passengers vs drivers, demand level (green/amber/red); (2) Average Driver Price — market vs your price, % difference; (3) Zone Saturation Map — driver density heat layer, "Too many drivers" vs "High opportunity"; (4) Collective Surge Signal — rejection-based minimum fare suggestion; (5) Community Intelligence — anonymous driver signals (police, events, road closures). Backend: `driver_locations`, `driver_rates`, `zone_demand`, `driver_density`, `market_prices`, `driver_signals`. Realtime: `supabase.channel("market_signals")`. Route: `/driver/union-mode`.

---

## PART 8 — HOME SCREEN SHEET CARD CHANGES

### Bottom sheet layout (order)

Keep this order from top to bottom: (1) Status toggle (swipe-to-reveal), (2) Scheduled rides card, (3) Two-column grid, (4) Driver Talk card. Only the grid content changes: left = Return trips, right = Today's rides.

### Remove: "Driver rating" card
Delete the left card in the 2-column grid that shows "Driver rating / —". This is replaced by the Return Trips card.

### Add: "Return trips" card (left card)
Label: "Return trips" in 12px grey at top. A count number below: "3 available" in 22px bold. A small arrow icon pointing back-left (suggesting return direction).

**Tapping opens the Smart Return Ride Marketplace** — a full screen that helps drivers fill empty return rides with passengers going the same direction. See PART 8B in driver-design.md for full spec. Connected to the Return Discount slider in the Driver Control Panel.

Each return trip card shows: pickup zone → destination zone, fare, estimated distance, booking mode badge. Very similar to the Scheduled Rides card layout.

**The filtering logic in Flutter (not SQL — the view already returns all pending rides):**
```dart
// Filter driver_return_trips view further:
// Show rides where destination_zone_id matches driver's heading_home_zone_id
// OR destination city matches driver's home city (from their profile)
// This gives the driver rides that take them back where they came from
final returnTrips = allPendingRides
  .where((r) => r.destinationZoneId == driver.headingHomeZoneId
    || r.destinationCity == driver.homeCity)
  .toList();
```

The `drivers.heading_home_zone_id` column already exists in your schema.

### Keep: "Today's rides" card (right card)
Keep the count number. When tapped, opens a full screen that shows today's ride list from `driver_trip_history`.

**Important — privacy rule:** This screen shows **zone names**, not exact addresses. Use `pickup_zone_id` joined to `bubble_zones.name_display`, not the raw `pickup_address` from `ride_requests`. Example: "Zone: Spijkenisse Noord → Zone: Rotterdam Centrum · €18.50 · 14:23". This protects rider privacy and is simpler to read at a glance.

### Keep: "Scheduled rides" card
Update the subtitle logic. Instead of "0 rides available in your area", query the `scheduled_rides_available` view AND filter out rides that overlap using `fn_driver_has_overlap`. The count shown should be feasible rides only — ones the driver can actually take.

```dart
// Get scheduled rides count
final allScheduled = await supabase.from('scheduled_rides_available').select('id, scheduled_pickup_at, estimated_duration_min');

// Filter out overlapping ones
final feasible = <ScheduledRide>[];
for (final ride in allScheduled) {
  final hasOverlap = await supabase.rpc('fn_driver_has_overlap', params: {
    'p_driver_id': driverId,
    'p_proposed_start': ride.scheduledPickupAt.toIso8601String(),
    'p_proposed_duration_min': ride.estimatedDurationMin,
  });
  if (!hasOverlap) feasible.add(ride);
}
// Show: "${feasible.length} rides available in your area"
```

### Keep: "Driver Talk" card
This shows the most recent community post preview. Tapping goes directly to the Driver Talk channel in the community tab.

---

## PART 8B — SMART RETURN RIDE MARKETPLACE

The screen that opens when the driver taps the Return trips card. Full spec in driver-design.md PART 8B. Summary:

- **Header:** "RETURN RIDE OPPORTUNITIES" + route (e.g. Amsterdam → Rotterdam, 74 km)
- **Return Discount slider:** Same 0–40% as Driver Control Panel; shows match probability and wait time from Supabase
- **Live passenger cards:** Real ride requests going same direction; passenger price vs driver price after discount; large green Accept button (52px)
- **Backend:** Query `ride_requests` where `destination_direction = driver_direction`; Realtime channel `return_market`
- **Probability engine:** `match_probability = demand_score × discount_factor × driver_density × time_of_day`

---

## PART 9 — NAVIGATION CHANGES

### Remove: Hamburger menu (top-left drawer)
Delete the hamburger icon button entirely. Delete the drawer widget. All the things that were in the drawer (settings, documents, logout) move to the "Me" tab.

### Bottom navigation: 3 tabs

**Tab 1 — Home** (map icon)
The map, the zone demand circles, the online toggle, the sheet with cards.

**Tab 2 — Work** (briefcase icon)
Two sub-tabs at the top: "Earnings" and "Available rides". Toggle between them with two text buttons underlined in gold.

Earnings sub-tab: donut chart + weekly bar chart (fl_chart) + today's ride list (zone-based, not addresses).

Available rides sub-tab: three filter chips (Now / Scheduled / Return trips), scrollable ride cards. "Return trips" replaces the old "Marketplace" label since that is what drivers care about on this tab.

**Tab 3 — Me** (person icon)
This is where everything personal lives. Top section: driver photo, name, vehicle, average rating (stars + number from `drivers.avg_rating`).

Below: settings rows with chevrons. Language, Theme, Rates (links to rate profiles management), Documents status (shows compliance expiry dates — chauffeurspas, rijbewijs, VOG, taxidiploma with green/amber/red status indicators), Notifications, Privacy, Log out.

No Profile tab inside Community anymore. Community is pure community content.

---

## PART 10 — COMMUNITY SCREEN CLEANUP

Remove the "Profile" sub-tab from the community screen. The community screen now has exactly three tabs: Announcements, Driver Talk, Ride Swap.

Profile content moves entirely to the "Me" tab in bottom navigation.

The community screen is now purely a social space — no driver personal info, no settings, just the three channels.

---

## PART 11 — SUPABASE TABLES CREATED IN THIS SESSION

These tables and functions are now live in your database:

| Name | Type | Purpose |
|------|------|---------|
| `driver_earnings_targets` | Table | Stores daily/weekly earnings targets per driver |
| `driver_rate_profiles` | Table | Saved rate profiles (Standard, Peak, Airport) |
| `driver_safety_events` | Table | Log of emergency calls, trip shares, recordings |
| `driver_return_trips` | View | Pending rides heading toward driver's home zone |
| `fn_driver_has_overlap()` | Function | Returns true if a scheduled ride conflicts with existing rides (buffer: duration + 40min) |
| `fn_switch_rate_profile()` | Function | Atomically activates a rate profile and copies rates to drivers table |

**New for Driver Power Mode (PART 7B):**

| Name | Type | Purpose |
|------|------|---------|
| `driver_locations` | Table | Real-time driver position for demand/location analysis |
| `driver_goals` | Table | Weekly/daily targets (or reuse `driver_earnings_targets`) |
| Realtime channel `driver_power` | Channel | Live insight updates to Power Mode screen |

**New for Driver Union Mode (PART 7C):**

| Name | Type | Purpose |
|------|------|---------|
| `driver_rates` | Table/view | Aggregated driver rates for market price comparison |
| `zone_demand` | Table | Passengers waiting vs drivers online per zone |
| `driver_density` | Table/view | Driver count per zone for saturation map |
| `market_prices` | Table | Average per-km, per-min, start fare by zone |
| `driver_signals` | Table | Anonymous community signals (police, events, road closures) |
| Realtime channel `market_signals` | Channel | Live market data updates to Union Mode screen |

Previously created in the last session (still valid):

| Name | Type | Purpose |
|------|------|---------|
| `zone_demand_live` | View | Live passenger count per zone for the map circles |
| `get_driver_earnings_summary()` | Function | Today/week/month earnings in one call |
| `scheduled_rides_available` | View | Upcoming scheduled rides with decoded lat/lng |
| `driver_passenger_comments` | View | Rider comments for the driver score section |
| `fn_claim_swap_ride()` | Function | Race-condition-safe swap claim |
| `fn_confirm_swap_ride()` | Function | Finalises swap after passenger responds |

---

## PART 12 — BUILD ORDER

Do these in order. Do not skip steps.

**Step 1:** _DONE in Flutter code._ `ThreeStateToggle` widget created and wired to backend `setStatus` with three states (offline, on_break, available). Next iteration: refine animations and replace any remaining usages of `DriverSwipeToGoOnline` so there is no duplicate control.

**Step 2:** _IN PROGRESS._ Floating earnings card no longer shows the go-online control; it now introduces the "Active rates" section with profile chips. Next iteration: replace placeholders with real `driver_rate_profiles` data and wire taps to `fn_switch_rate_profile`.

**Step 3:** _PARTIALLY DONE._ Calendar map button removed from map floating overlay. Next iteration: add Driver Hub button with badge and connect it to the Driver Hub modal.

**Step 4:** Build the Driver Hub modal with all four sections plus Power Mode and Union Mode navigation rows. Build each section top to bottom. Use `SliverList` inside a `CustomScrollView` for the modal content so it scrolls correctly. Power Mode tap → push Power Mode screen (PART 7B); Union Mode tap → push Union Mode screen (PART 7C).

**Step 5:** Replace the Driver Rating card with the Return Trips card. Wire to `driver_return_trips` view filtered by `heading_home_zone_id`. Tapping opens the Smart Return Ride Marketplace (PART 8B) — build that screen with header, Return Discount slider, match probability, and live passenger request cards with Accept buttons.

**Step 6:** Update the Scheduled Rides count to use `fn_driver_has_overlap` filtering.

**Step 7:** Update the Today's Rides detail screen to show zone names instead of addresses.

**Step 8:** Remove the hamburger menu. Move drawer contents to the Me tab.

**Step 9:** Remove the Profile sub-tab from the community screen.

**Step 10:** Test on a real physical device with a second device acting as a rider. Every status change, every rate profile switch, every safety event, Driver Power Mode, Driver Union Mode.

**Step 11:** Build Driver Power Mode screen (PART 7B). Six card types: High Demand Nearby, Smart Price Suggestion, Return Trip Opportunity, Surge Opportunity, Idle Warning, Goal Tracker. Realtime channel `driver_power`. Route: /driver/power-mode.

**Step 12:** Build Driver Union Mode screen (PART 7C). Five sections: Market Balance, Average Driver Price, Zone Saturation Map, Collective Surge Signal, Community Intelligence. Realtime channel `market_signals`. Route: /driver/union-mode.

---

## PART 13 — DESIGN RULES (REMINDER)

These apply to every new widget in this build:

- Pure white (`#FFFFFF`) backgrounds. No beige. No off-white.
- Gold (`#E6A800`) for one primary action per screen only.
- Inter font at all sizes. No serif. No system default.
- Every color from `ref.watch(colorsProvider)`. No hardcoded hex.
- Every string from `l10n.xxx`. No hardcoded text.
- Max 300 lines per file. Split before hitting that number.
- Backend writes before UI updates. No optimistic status changes.
- Test on a real device before marking any screen done.

---

## PART 14 — FLUTTER PACKAGES FOR NEW FEATURES

```yaml
# Already in project — confirm these are present:
flutter_animate: ^4.5.0
fl_chart: ^0.68.0
audioplayers: ^6.0.0

# Add these new ones:
share_plus: ^7.2.2        # For trip sharing from safety toolkit
record: ^5.0.4            # For audio recording from safety toolkit
url_launcher: ^6.2.6      # For emergency call (tel:112) and help articles
webview_flutter: ^4.7.0   # For "Browse help articles" in-app WebView
```

---

*HeyCaby Driver Driver App Build Guide v3 — March 2026*
*Supabase project: fvrprxguoternoxnyhoj*
*New tables created: driver_earnings_targets, driver_rate_profiles, driver_safety_events*
*New views: driver_return_trips*
*New functions: fn_driver_has_overlap, fn_switch_rate_profile*





All right, let’s break it down step by step.
	1.	Online/Offline Toggle Redesign: Replace the current “Slide to go online” with a swipeable control. The driver can swipe left for “Pause,” to the center for “Break,” and fully right for “Online.” Each stage should visually reveal the status as the user swipes, ensuring clear feedback.
	2.	Scheduled Rides Logic: The “Scheduled Rides” card will show live data. Ensure your backend logic prevents overlapping rides based on duration and buffer time. If a driver has a ride from Rotterdam to Amsterdam at 1 p.m. lasting 1 hour 20 minutes, buffer that to about 2 hours. After 3 p.m., the driver can take a return trip back. Show only feasible rides based on these calculations.
	3.	Replace Driver Rating with Return Trips: The “Driver Rating” card will be replaced with a “Return Trips” card. Tapping it shows available return rides (e.g., back to Rotterdam or nearby cities) within a logical timeframe after their last ride.
	4.	Today’s Rides Card: Keep this card. When tapped, it opens a full screen showing how many rides were completed today. Display zones rather than exact addresses for privacy, giving drivers context (like “from Zone A to Zone B”).
	5.	Community and Profile Integration: The “Driver Talk” card stays, but the community screen must no longer have a separate profile tab. Instead, move “Profile” into the bottom navigation (perhaps as a separate tab, like “Me”). The community page should only show community-related content and discussions, not driver profiles.
	6.	Remove Hamburger Menu: Eliminate the top-left drawer (hamburger icon). All key navigation should be bottom-based, minimizing redundant or hidden navigation elements.

This redesign will simplify the driver’s experience, provide clearer ride scheduling, and ensure smoother navigation!




Absolutely! Here’s how we’ll break it down for your dev:

First, we’ll redesign the main toggle interaction. We’ll remove the simple “Slide to go online” button. Instead, we’ll implement a swipeable control with three states—Pause, Break, and Online. Swiping will reveal each state, and as the driver swipes, the backend updates their status in real time.

Next, we’ll overhaul the pop-up widget. Instead of repeating the online toggle, we’ll display the driver’s current pricing profile—such as rates per kilometer, per minute, and base fare. The driver will be able to quickly switch between predefined rate sets (like Standard or Peak). Any change will update instantly in the backend.

We’ll also enhance the “Scheduled Rides” card. The backend logic will ensure no overlapping rides by factoring in travel time and buffer. It will only show feasible rides in real time. zaq

The “Driver Rating” card will be replaced with a “Return Trips” card, showing rides back toward their starting area or home city.

Finally, we’ll simplify navigation by removing the community’s profile tab and ensuring the profile sits in bottom navigation. The result will be intuitive and let drivers manage their business seamlessly.



Absolutely! Here’s the plan for the dev:

First, we’ll remove the current calendar (floating button) from the map screen since it duplicates the “Scheduled Rides” card. In its place, we’ll introduce the “Driver Hub” button. When tapped, this will open a modal with multiple driver-focused tools. We’ll start simple: one function might be a goal tracker where drivers set and monitor earnings targets. Another option could be charging station or gas station locators. Down the line, we might expand to a demand heatmap or proactive battery alerts. But for V1, we keep it lean: the Driver Hub button, a clean modal, and core features like goal tracking. This replaces that floating icon and ensures every tool directly helps them manage their independent business.


Absolutely! Here’s what your dev should do. In the Driver Hub modal, add a dedicated “Safety Toolkit” section. In it, include buttons for emergency calling, sharing trip details, and audio recording, similar to what you showed. Now, to make it dynamic: connect the Hub to your Supabase backend. When there’s a safety-related notification—like a new trip share or an alert—you’ll store that in Supabase. Then, on the front end, show a small badge on the Hub button (like a red dot with a number) whenever there’s something new. Tapping the Hub will open the updated content. This way, the Hub not only has safety tools but also ensures drivers know right away if there’s something urgent to check.


This is crucial because drivers need fast support. In the Driver Hub, we’ll add a “Help & Support” section. First, allow drivers to see recent trip issues or unresolved reports (like the screenshot shows). Second, provide direct options: a “Send a Message” button that links to a chat or ticket system, a “Browse Help Articles” link (pulling articles from a knowledge base), and a “Messages” section for ongoing conversations. To add this, wire up a backend—like Supabase—to store driver inquiries and responses. Notifications can alert them when new support messages arrive. This ensures drivers feel supported on every trip, right from the Hub.