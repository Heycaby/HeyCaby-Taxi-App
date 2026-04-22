# HeyCaby Driver — Driver App Build Guide
## The definitive implementation document for the Flutter developer
### March 2026 — Based on v3 brief, live screenshots, and verified Supabase schema

---

## THE RULES — READ BEFORE WRITING A SINGLE LINE

These are non-negotiable. Every file you touch must follow every one of these.

**Design — think like an Apple engineer:**
- Pure white (`#FFFFFF`) backgrounds everywhere. Screens, sheets, cards, modals.
- Depth comes from shadows and borders, never from background colour tinting.
- Every interactive element has a clear pressed state. Use `InkWell` with `borderRadius` or `GestureDetector` with `AnimatedScale`.
- Spacing is consistent: 16px horizontal padding on screens, 12px between cards, 8px between elements inside a card. Never mix these.
- Typography follows a strict scale. No in-between sizes. Permitted: 32, 24, 20, 17, 15, 13, 11px. Bold for headings, medium (500) for labels, regular (400) for body.
- Animations use `Curves.easeOutBack` for elastic snaps, `Curves.easeOut` for reveals, `Curves.easeInOut` for continuous motion. Duration: 250ms short, 400ms medium, 600ms long.
- Bottom sheets have 20px top corner radius. All other cards: 12px radius.
- Icons: use line-style icons (not filled). `HugeIcons` or `Lucide` preferred. Never mix filled and outline icons on the same screen.
- Follow iOS safe area rules. Use `SafeArea` at the root of every screen.

**Code quality:**
- Maximum 300 lines per file. Split before hitting that number.
- Every color from `ref.watch(colorsProvider)`. Zero hardcoded hex.
- Every string from `AppLocalizations` / `DriverStrings`. Zero hardcoded text.
- No mock data. Every number displayed comes from Supabase.
- Backend writes happen before UI updates. Never optimistic status changes.
- Check for duplicates before any INSERT. Use `ON CONFLICT DO NOTHING` in SQL or check with `.maybeSingle()` in Dart before inserting.
- Every new file: check if the thing you are building already exists. Search the codebase first.
- Test on a physical device. Simulator is not sufficient for location, sound, or background services.

---

## WHAT IS ALREADY DONE — DO NOT REBUILD THESE

Before starting any step, confirm these exist and work:

| Feature | File | Status |
|---------|------|--------|
| Three-state toggle (Offline/Break/Online) | `driver_home_sheet.dart` | Done — backend write on snap, end-shift confirmation |
| Earnings modal (no duplicate toggle) | `driver_earnings_modal.dart` | Done ✅ — wired to Supabase (rate profiles + break banner) |
| Calendar FAB removed | `driver_map_floating.dart` | Done |
| Hamburger removed from map overlay | `driver_map_floating.dart` | Done ✅ — drawer removed from `driver_shell.dart` |
| Three-tab nav (Home / Work / Me) | Navigation shell | Done |
| Driver Hub button + badge | `driver_map_floating.dart` | Done ✅ — badge = tickets + unresolved safety events |
| Driver Hub modal (targets/rates/safety/support) | `driver_hub_sheet.dart` | Done ✅ — DraggableScrollableSheet + routes wired |
| Return trips card + marketplace | `driver_home_sheet.dart`, `driver_return_trips_screen.dart` | Done ✅ — card replaces rating, marketplace + slider |
| Scheduled rides feasible count | `driver_data_service.dart`, `driver_home_sheet.dart` | Done ✅ — 60s cache, subtitle "X rides you can take" |
| Today's rides zone names only | `driver_data_service.dart`, `work_screen.dart` | Done ✅ — driver_trip_history + bubble_zones join, row format Zone A → Zone B · € · time |
| Me tab (drawer content moved) | `me_screen.dart`, `driver_shell.dart` | Done ✅ — drawer removed; Profile: photo 64px, vehicle, rating, Documents/Tarieven/Instellingen/Support/Uitloggen |
| Community (3 channels only) | `me_screen.dart`, `driver_data_service.dart` | Done ✅ — announcements/general/swap; swap shows open only; announcements read-only |
| Driver Power Mode | `driver_power_mode_screen.dart` | Done ✅ — live cards from fn_get_power_suggestions + realtime + dismiss |
| Driver Union Mode | `driver_union_mode_screen.dart` | Done ✅ — union_mode_dashboard cards + signals feed + compose/upvote |

---

## THE COMPLETE FEATURE LIST — IN BUILD ORDER

---

### STEP 1 — REFINE THE THREE-STATE TOGGLE (Done ✅)

The toggle exists. These refinements make it Apple-quality.

**What to add:**

The three labels (Offline / Break / Online) must always be visible below the track — never hidden under the thumb. All three labels show at all times. The active state label is in your theme's `colors.text` at 13px medium. The other two are `colors.textSoft` at 13px regular.

Haptic feedback on every snap:
- Snap to Online: `HapticFeedback.heavyImpact()` + play `SoundService().playNotification()`
- Snap to Break: `HapticFeedback.mediumImpact()`
- Snap to Offline: `HapticFeedback.lightImpact()`

The status pill on the map (the floating earnings pill at the top) must show a timestamp: "Online · since 14:32" or "On break · since 15:10". The timestamp comes from `drivers.shift_start_at` (for online) or `drivers.last_break_start_at` (for break). Format: `HH:mm` only. No date.

**Supabase columns used:** `drivers.shift_start_at`, `drivers.last_break_start_at`, `drivers.status`

---

### STEP 2 — WIRE THE EARNINGS MODAL TO SUPABASE (Done ✅)

The earnings modal (`driver_earnings_modal.dart`) currently has hardcoded placeholder chips. Wire everything to live data.

**Rate profiles:**

Query `driver_rate_profiles` where `driver_id = currentDriverId` ordered by `sort_order ASC`. Each row becomes a chip. The chip labelled with `profile_name`. The chip with `is_active = true` is gold-filled. The others are white with a gold border.

When a driver taps a chip, call `fn_switch_rate_profile(driver_id, profile_id)`. On success, refresh the `activeRateProfileProvider`. Below the chips show: "€{per_km_rate}/km · €{per_min_rate}/min · €{base_fare} start" in 12px `colors.textSoft`.

If no profiles exist, show a single row: "Set up your rates →" as a gold text link. Tapping creates a first profile from the values already in `drivers.base_fare`, `drivers.per_km_rate`, `drivers.per_min_rate` with name "Standaard".

```dart
// Check for existing profiles before creating
final existing = await supabase
  .from('driver_rate_profiles')
  .select('id')
  .eq('driver_id', driverId)
  .maybeSingle(); // Returns null if none exist

if (existing == null) {
  // Create first profile from drivers table values
  await supabase.from('driver_rate_profiles').insert({
    'driver_id': driverId,
    'profile_name': 'Standaard',
    'base_fare': driver.baseFare ?? 2.50,
    'per_km_rate': driver.perKmRate ?? 2.00,
    'per_min_rate': driver.perMinRate ?? 0.35,
    'minimum_fare': driver.minimumFare ?? 5.00,
    'waiting_rate': driver.waitingTimeRatePerMin ?? 0.25,
    'is_active': true,
    'sort_order': 0,
  });
}
```

**Dutch break compliance banner:**

Calculate `continuousDrivingMinutes` from `drivers.continuous_driving_started_at`. If more than 255 minutes (4h 15m):

```dart
final sinceBreak = DateTime.now().difference(continuousDrivingStartedAt);
if (sinceBreak.inMinutes > 255) {
  // Show amber banner: "Pauze aanbevolen over X minuten"
} else if (sinceBreak.inMinutes >= 270) {
  // Show red banner: "Wettelijke pauze vereist"
}
```

The banner sits at the bottom of the modal above the drag handle. Amber background (`colors.warning` at 15% opacity), dark text, small clock icon. Never a blocking dialog.

**Riverpod providers to add:**
- `driverRateProfilesProvider` — `StreamProvider` from `driver_rate_profiles` table
- `activeRateProfileProvider` — derived provider filtering `is_active = true`

---

### STEP 3 — ADD THE DRIVER HUB BUTTON TO THE MAP (Done ✅)

**Location:** Right side of the map, vertically centred in the visible map area (above the sheet). Same visual style as the recenter button: round white container, 44×44px, 6px shadow at 8% opacity.

**Icon:** Use `Icons.apps_rounded` or `Icons.grid_view_rounded` from Material. No new package dependency needed.

**Badge:** A small red circle in the top-right corner of the button. Shows a number if `badgeCount > 0`.

Badge count = open tickets + unresolved safety events:

```dart
final badgeCount = await Future.wait([
  supabase.from('tickets')
    .select('id', const FetchOptions(count: CountOption.exact))
    .eq('user_type', 'driver')
    .eq('user_id', driver.userId)
    .neq('status', 'resolved'),
  supabase.from('driver_safety_events')
    .select('id', const FetchOptions(count: CountOption.exact))
    .eq('driver_id', driver.id)
    .eq('resolved', false),
]);
// Sum both counts
```

Show badge only if count > 0. No badge = clean button. Maximum badge number shown: "9+".

```dart
Positioned(
  right: 16,
  top: mapVisibleHeight * 0.42, // 42% down the visible map
  child: _DriverHubButton(
    badgeCount: badgeCount,
    onTap: () => showDriverHub(context),
  ),
)
```

---

### STEP 4 — BUILD THE DRIVER HUB MODAL (Done ✅)

One bottom sheet. 85% height. White background. Drag handle at top. "Driver hub" in 22px bold Inter, left-aligned, 16px from left edge, 20px below drag handle.

Use `DraggableScrollableSheet` so the content scrolls inside the sheet without the sheet dismissing.

**Structure — four sections separated by 1px `colors.border` dividers:**

---

#### Section 1 — Earnings target

A donut chart using `fl_chart`'s `PieChart`. Two segments: earned (gold, `colors.accent`) and remaining (light grey, `colors.border`). Centre text: earned amount in 22px bold, "of €{target}" in 12px `colors.textSoft`.

Two chips below the chart: "Dagelijks" and "Wekelijks". Selected chip has a 2px gold underline. Tapping switches between daily and weekly views.

Small gold text link: "Doel instellen →". Tapping opens a lightweight sheet (not a new screen) with a numeric input field and a "Opslaan" button. This writes to `driver_earnings_targets`:

```dart
// Upsert — don't create duplicates
await supabase.from('driver_earnings_targets').upsert({
  'driver_id': driverId,
  'target_type': selectedPeriod, // 'daily' or 'weekly'
  'target_amount': enteredAmount,
}, onConflict: 'driver_id,target_type');
```

**Data source:**
- Earnings: `SELECT * FROM get_driver_earnings_summary($driverId)`
- Target: `SELECT * FROM driver_earnings_targets WHERE driver_id = $driverId`

---

#### Section 2 — Active rates

Same rate profile chips as in the earnings modal. This is the same widget — extract it into a shared widget called `_RateProfileChips` and use it in both places. Do not duplicate the logic.

A "Tarieven beheren →" text link at the bottom of this section navigates to a rates management screen (a simple list where the driver can edit profile names and amounts — a later iteration).

---

#### Section 3 — Safety toolkit

Three rows. Each row is a list tile with icon, title, subtitle, and an optional right-side indicator.

**Row 1 — Emergency call (always active):**
- Red alert icon (`Icons.emergency_outlined`)
- Title: "Alarmnummer bellen" in `colors.error` at 15px medium
- Subtitle: "112 — politie en ambulance" in 13px `colors.textSoft`
- On tap: `launchUrl(Uri.parse('tel:112'))` + insert to `driver_safety_events`:

```dart
await supabase.from('driver_safety_events').insert({
  'driver_id': driverId,
  'event_type': 'emergency_call',
  'ride_request_id': activeRideId, // null if no active ride
});
```

**Row 2 — Share trip details (active rides only):**
- Grey share icon
- Title: "Rit details delen"
- Subtitle: `isOnRide ? "Deel je huidige rit" : "Beschikbaar tijdens actieve rit"`
- Enabled only when `driverStateProvider.status == DriverStatus.onRide`
- On tap: fetch or create a `ride_shares` row, build URL `https://heycaby.nl/track/{share_token}`, call `Share.share(url)` from `share_plus`
- Greyed out and non-tappable when not on a ride. No error — just visually disabled.

**Row 3 — Audio recording (active rides only):**
- Grey waveform icon (`Icons.graphic_eq_rounded`)
- Title: "Audio opname"
- Subtitle: same pattern as share
- On tap: `AudioRecorder` from `record` package. Store file locally in app documents directory. Insert to `driver_safety_events` with `event_type = 'audio_recording'`.
- While recording, show a small red pulsing dot on the row (use `flutter_animate` repeat with opacity 0.3→1.0).

---

#### Section 4 — Help & support

**Recent trips with issues:**

Query `tickets` table: `user_type = 'driver'`, `user_id = driver.userId`, ordered by `created_at DESC`, limit 3.

Each row: date in 12px `colors.textSoft`, zone name (from `ride_request_id` join to `ride_requests.zone_id` join to `bubble_zones.name_display`) in 15px `colors.text`, status label below:
- `status = 'open'` and `messages` array is empty from driver side: "U heeft niet gereageerd" in `colors.error`
- `status = 'open'` with messages: "In behandeling" in `colors.warning`
- `status = 'resolved'`: "Opgelost" in `colors.success`

A "Alles zien →" chevron link top-right navigates to a full tickets list screen.

**Contact support rows:**

Three simple list tiles with icons and chevrons:
1. "Stuur een bericht" (`Icons.edit_outlined`) — opens new ticket compose sheet. Insert to `tickets`:

```dart
await supabase.from('tickets').insert({
  'user_type': 'driver',
  'user_id': driver.userId,
  'category': 'driver_support',
  'priority': 'normal',
  'status': 'open',
  'messages': [],
});
```

2. "Berichten" (`Icons.chat_bubble_outline_rounded`) — opens conversation view for most recent open ticket.

3. "Help artikelen" (`Icons.search_rounded`) — opens `WebView` loading URL from `app_config` where `key = 'driver_help_url'` (currently set to `https://heycaby.nl/help/drivers`).

---

#### Bottom of Driver Hub — two special rows

Below the four sections, above the bottom safe area, two prominent rows that lead to the two premium features:

**Driver Power Mode:**
Left icon: `Icons.bolt_rounded` in gold. Title: "Driver Power Mode" in 17px medium. Subtitle: "AI-suggesties om meer te verdienen" in 13px `colors.textSoft`. Chevron right. Tapping pushes the Power Mode screen.

**Driver Union Mode:**
Left icon: `Icons.groups_rounded` in `colors.textMid`. Title: "Driver Union Mode" in 17px medium. Subtitle: "Live marktintelligentie" in 13px `colors.textSoft`. Chevron right. Tapping pushes the Union Mode screen.

---

### STEP 5 — RETURN TRIPS CARD + SMART RETURN MARKETPLACE (Done ✅)

**The card (left card in the 2-column grid):**

Replace the "Driver rating" card entirely. The new card:
- Label: "Retourritten" in 12px `colors.textSoft`
- Count: number of available return trips in 28px bold
- A small back-arrow icon in `colors.accent`
- Data from `driver_return_trips` view, filtered in Dart:

```dart
// Filter return trips — only rides heading toward driver's home zone or city
final returnTrips = allReturnTrips.where((ride) =>
  ride.destinationZoneId == driver.headingHomeZoneId ||
  ride.destinationCity?.toLowerCase() == driver.homeCity?.toLowerCase()
).toList();
```

`drivers.heading_home_zone_id` already exists in your schema. If it is null for a driver, show all return trips without filtering.

**Smart Return Ride Marketplace screen:**

Full screen. Title: "Retourritten" with your zone as subtitle (e.g. "Rotterdam → Amsterdam route, 74 km").

A prominent return discount slider at the top:
- Label: "Jouw retourkorting"
- Slider: 0% to 40%, steps of 5%
- Below slider: "Reiskosten gedeeld met passagier: €{calculatedFare}" and "Match kans: {high/medium/low}" as a coloured badge
- The discount percentage is stored in `driver_rate_profiles.return_discount_pct` (column added in last migration)

On slider change, call `fn_switch_rate_profile` with the updated discount. Debounce the call by 800ms to avoid rapid database writes.

**Live ride cards below the slider:**

Each card shows:
- Gold pickup dot → dark destination dot with connecting line
- Pickup zone and destination zone (not full addresses — zone names only)
- Passenger's offered fare, discounted fare side by side
- Distance and estimated duration
- "Accepteren" button — wide, gold, 52px height, 12px corner radius

Cards come from `driver_return_trips` view via Realtime. Subscribe to changes on the channel `return_market`:

```dart
supabase.channel('return_market')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'ride_requests',
    filter: PostgresChangeFilter(
      type: FilterType.eq,
      column: 'status',
      value: 'pending',
    ),
    callback: (_) => ref.invalidate(returnTripsProvider),
  )
  .subscribe();
```

---

### STEP 6 — SCHEDULED RIDES FEASIBLE COUNT (Done ✅)

The "Scheduled rides" card subtitle currently shows "0 rides available in your area" from a simple count. This needs to show only rides the driver can actually take without overlap.

```dart
// In DriverDataService
Future<int> getFeasibleScheduledCount(String driverId) async {
  // 1. Get all scheduled rides
  final all = await supabase
    .from('scheduled_rides_available')
    .select('id, scheduled_pickup_at, estimated_duration_min');

  // 2. Filter out overlapping ones using backend function
  var feasible = 0;
  for (final ride in all as List) {
    final hasOverlap = await supabase.rpc('fn_driver_has_overlap', params: {
      'p_driver_id': driverId,
      'p_proposed_start': ride['scheduled_pickup_at'],
      'p_proposed_duration_min': ride['estimated_duration_min'] ?? 60.0,
    });
    if (hasOverlap == false) feasible++;
  }
  return feasible;
}
```

**Important:** This runs multiple RPC calls. Cache the result for 60 seconds. Do not re-run on every rebuild. Use a `FutureProvider` with a cache duration, not a `StreamProvider`.

---

### STEP 7 — TODAY'S RIDES — ZONE NAMES ONLY (Done ✅)

When the driver taps "Today's rides", the detail screen shows their ride list from `driver_trip_history`.

Each row must show zone names, not addresses. The query:

```dart
final todayRides = await supabase
  .from('driver_trip_history')
  .select('''
    id, completed_at, distance_km,
    pickup_zone:bubble_zones!pickup_zone_id(name_display),
    destination_zone:bubble_zones!destination_zone_id(name_display),
    ride_request:ride_requests!ride_request_id(final_fare, payment_method)
  ''')
  .eq('driver_id', driverId)
  .gte('completed_at', DateTime.now().toIso8601String().substring(0, 10))
  .order('completed_at', ascending: false);
```

Each row displays: "Zone A → Zone B · €18.50 · 14:23". If `name_display` is null (zone not found), fall back to city name. Never show full addresses on this screen.

---

### STEP 8 — REMOVE DRAWER, COMPLETE THE ME TAB (Done ✅)

**Remove:** Delete the drawer from `driver_shell.dart`. Delete the `Drawer` widget and the `GlobalKey<DrawerState>` that opens it. Do not remove the content — move it.

**Me tab (`me_screen.dart`):** The Profile sub-tab must contain all the items that were in the drawer:

At the top: driver photo (circular, 64px, from `drivers.profile_photo_url`), full name, vehicle make + model + plate, star rating from `drivers.avg_rating`.

Below, settings rows with chevrons:
- Documents (`Icons.description_outlined`) — navigates to compliance status screen showing chauffeurspas, rijbewijs, VOG, taxidiploma with green/amber/red expiry status
- Tarieven (`Icons.price_change_outlined`) — navigates to rate profiles management
- Instellingen (`Icons.tune_outlined`) — navigates to preferences (language, theme, notifications, max pickup distance)
- Support (`Icons.headset_mic_outlined`) — navigates to the tickets list screen
- Uitloggen (`Icons.logout_rounded`) — confirmation dialog then `supabase.auth.signOut()`

Documents row: show a small amber dot if any compliance document expires within 30 days. Show red dot if any is already expired. This reads from `drivers.chauffeurspas_expiry`, `drivers.rijbewijs_expiry`, `drivers.vog_expires_at`, `drivers.taxi_insurance_expiry`.

---

### STEP 9 — COMMUNITY SCREEN — THREE CHANNELS ONLY (Done ✅)

Confirm: the community screen has exactly three channel tabs: Aankondigingen (announcements), Rijden (driver talk — maps to `channel = 'general'`), Ritruil (ride swap — maps to `channel = 'swap'`).

If there is a fourth "Profile" or "Me" tab inside the community screen, remove it. Profile content belongs in the Me tab (Step 8).

The "Aankondigingen" tab shows posts where `channel = 'announcements'`. No compose button on this tab. Read-only.

The "Rijden" tab shows posts where `channel = 'general'`. Gold compose button (round, bottom-right of list). Tapping opens the compose sheet.

The "Ritruil" tab shows posts where `channel = 'swap'` and `swap_status = 'open'`. Each card has a gold "Rit overnemen" button if the swap is still open.

---

### STEP 10 — DEVICE TEST PASS

Test on two physical devices simultaneously. One as driver, one as rider.

| Test | Expected | Pass? |
|------|---------|-------|
| Toggle Offline → Break → Online | Status pill updates, timestamp appears, haptic fires, sound plays on Online | |
| Toggle Online → Offline after 30min | Confirmation dialog appears | |
| Toggle Online → Offline under 30min | No dialog, immediate offline | |
| Tap earnings pill | Floating card appears with rate chips | |
| Tap rate chip | Active chip turns gold, rate line updates, Supabase updated | |
| Tap Driver Hub button | Modal opens at 85% | |
| Tap Emergency call | Phone dials 112, event logged in driver_safety_events | |
| Share trip (during ride) | Share sheet opens with heycaby.nl/track link | |
| Share trip (no ride) | Row is greyed out, not tappable | |
| Earnings target — set daily | Modal saves to driver_earnings_targets, donut chart updates | |
| Return trips card | Count shows filtered rides toward home zone | |
| Scheduled rides count | Only shows non-overlapping rides | |
| Today's rides — tap | Shows zone names, not addresses | |
| Me tab | Shows all drawer content correctly | |
| Community | Three tabs, no Profile tab | |

---

### STEP 11 — DRIVER POWER MODE SCREEN (Done ✅)

Route: `/driver/power-mode`

Full screen. White. Back arrow top-left. Title "Power Mode" in 22px bold. Subtitle "Suggesties om meer te verdienen" in 15px `colors.textSoft`.

**Data source:** `SELECT * FROM fn_get_power_suggestions($driverId)` — returns up to 10 cards ordered by priority.

**Realtime subscription:** Subscribe to `driver_power_suggestions` table for this driver's rows. Refresh the list on any change.

```dart
supabase.channel('driver_power')
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'driver_power_suggestions',
    filter: PostgresChangeFilter(
      type: FilterType.eq,
      column: 'driver_id',
      value: driverId,
    ),
    callback: (_) => ref.invalidate(powerSuggestionsProvider),
  )
  .subscribe();
```

**The six card types — each is a distinct card widget:**

**1. `high_demand` — High demand zone:**
Gold header bar. Zone name in 17px bold. `value_a` = passengers waiting (e.g. "18 wachtend"). `value_b` = approximate distance. "Navigeer" button launches external maps. X dismiss button top-right — calls `fn_dismiss_power_card`.

**2. `price_suggestion` — Smart price suggestion:**
White card. "Tariefsuggestie" label. Current rate vs recommended rate side by side. "Toepassen" gold button — calls `fn_switch_rate_profile` with the profile containing the suggested rate. "Negeren" ghost button — dismisses.

**3. `return_trip` — Return trip opportunity:**
White card. Links to the Smart Return Ride Marketplace. "Retourrit beschikbaar" label. Destination zone. Fare. "Rit bekijken" button pushes to the marketplace screen pre-filtered.

**4. `surge_opportunity` — Surge event nearby:**
Amber header. Event name from `subtitle`. `value_a` = surge percentage. "Ga erheen" button launches navigation.

**5. `idle_warning` — Idle too long:**
Light grey card. `value_a` = idle minutes. "Je staat al X minuten stil". Zone map thumbnail. "Drukke zones bekijken" button navigates to the zone demand map.

**6. `goal_tracker` — Earnings goal progress:**
White card. Mini donut chart (same widget as Driver Hub, just smaller at 64px). `value_a` = earned today, `value_b` = target, `value_c` = remaining. "X ritten nog nodig" estimate at bottom. No action button — informational only.

**Empty state:** If no cards, show a single message: "Alles ziet er goed uit 👍 We laten je weten als er kansen zijn." Centre-aligned, 17px, `colors.textSoft`.

---

### STEP 12 — DRIVER UNION MODE SCREEN (Done ✅)

Route: `/driver/union-mode`

Full screen. White. Back arrow top-left. Title "Union Mode" in 22px bold. Subtitle "Live marktintelligentie" in 15px `colors.textSoft`.

**Data source:** `SELECT * FROM union_mode_dashboard` — one row per active zone with market balance data.

**Realtime:** Subscribe to `driver_market_signals` for new community signals. Refresh every 30 seconds for the dashboard data.

**The five sections — displayed as vertically stacked cards:**

**Section 1 — Marktbalans (Market Balance):**
Three metric pills side by side: "Passagiers" (sum of `passengers_waiting` across all zones), "Chauffeurs" (sum of `drivers_online`), "Balans" (colour-coded: green for high_demand, amber for balanced, red for saturated). Below: a horizontal bar comparing the two numbers visually.

**Section 2 — Gemiddelde ritprijs (Average fare):**
A simple table-style card. Top 5 zones by `avg_offered_fare`. Zone name left, fare right in bold. Your active rate shows as a highlighted row if it matches a zone rate.

**Section 3 — Zone bezetting (Zone saturation):**
A scrollable horizontal list of zone chips. Each chip: zone name, a colour dot (green = high_demand, grey = quiet, red = saturated based on `market_balance`). Tap a chip to jump to that zone on the main map (pass zone coordinates back to the home screen via a state update).

**Section 4 — Collectief surge signaal (Collective surge):**
If any zone has `market_balance = 'high_demand'` AND `avg_offered_fare` is below the market average by more than 15%, show a suggestion: "Zone X heeft hoge vraag — overweeg €{suggestedRate}/km". This is computed entirely in Flutter from the dashboard data — no extra query needed.

**Section 5 — Chauffeurssignalen (Community signals):**
List of recent `driver_market_signals` ordered by `upvotes DESC`. Each row: signal icon (🚔 police, 🚧 road closure, 🎉 event, ⬆️ high demand, ⬇️ low demand), zone name, `description` if present, upvote count with a thumbs-up button. Tapping thumbs-up:

```dart
await supabase.from('driver_market_signals')
  .update({'upvotes': signal.upvotes + 1})
  .eq('id', signal.id);
```

A "+" compose button bottom-right. Tapping opens a compact sheet where the driver selects: zone (from a list of nearby zones), signal type (chips), optional short description (max 80 chars). Insert is anonymous — no `driver_id` field:

```dart
// Duplicate check: don't create the same signal twice in the same zone recently
final recent = await supabase.from('driver_market_signals')
  .select('id')
  .eq('zone_id', selectedZoneId)
  .eq('signal_type', selectedType)
  .gte('created_at', DateTime.now().subtract(const Duration(hours: 1)).toIso8601String())
  .maybeSingle();

if (recent != null) {
  // Already reported — just upvote instead
  await supabase.from('driver_market_signals')
    .update({'upvotes': recent['upvotes'] + 1})
    .eq('id', recent['id']);
} else {
  await supabase.from('driver_market_signals').insert({
    'zone_id': selectedZoneId,
    'signal_type': selectedType,
    'description': description.isEmpty ? null : description,
  });
}
```

---

## SUPABASE BACKEND — COMPLETE REFERENCE

Everything that exists in the database for this feature set. Do not create duplicates.

### Tables (all with RLS enabled)

| Table | Purpose | Key columns |
|-------|---------|------------|
| `driver_earnings_targets` | Daily/weekly earnings goals | `driver_id`, `target_type`, `target_amount` |
| `driver_rate_profiles` | Saved rate sets | `driver_id`, `profile_name`, `is_active`, `return_discount_pct` |
| `driver_safety_events` | Emergency calls, recordings | `driver_id`, `event_type`, `ride_request_id` |
| `driver_power_suggestions` | AI suggestion cards | `driver_id`, `card_type`, `priority`, `expires_at`, `dismissed_at` |
| `driver_market_signals` | Anonymous community signals | `zone_id`, `signal_type`, `upvotes`, `expires_at` (NO driver_id) |
| `tickets` | Support tickets | `user_type`, `user_id`, `category`, `status`, `messages` (JSONB) |
| `driver_trip_history` | Completed rides log | `driver_id`, `pickup_zone_id`, `destination_zone_id`, `completed_at` |

### Views

| View | Purpose | When to query |
|------|---------|--------------|
| `zone_demand_live` | Live passenger count per zone | Map refresh, every 30s |
| `scheduled_rides_available` | Future scheduled rides with decoded coords | Scheduled rides count |
| `driver_return_trips` | Pending rides heading toward home zone | Return Trips card |
| `driver_passenger_comments` | Rider comments (anonymised) | Driver score section |
| `union_mode_dashboard` | All Union Mode data in one query | Union Mode screen, every 30s |

### Functions

| Function | Call | Returns |
|----------|------|---------|
| `get_driver_earnings_summary(driver_id)` | `supabase.rpc('get_driver_earnings_summary', params: {'p_driver_id': id})` | today/week/month earnings + ride counts |
| `fn_switch_rate_profile(driver_id, profile_id)` | `supabase.rpc('fn_switch_rate_profile', ...)` | `{success, profile_name, rates}` |
| `fn_driver_has_overlap(driver_id, start, duration_min)` | `supabase.rpc('fn_driver_has_overlap', ...)` | `boolean` |
| `fn_claim_swap_ride(post_id, driver_id)` | `supabase.rpc('fn_claim_swap_ride', ...)` | `{success, error?}` |
| `fn_confirm_swap_ride(post_id, response)` | `supabase.rpc('fn_confirm_swap_ride', ...)` | `{success, action}` |
| `fn_get_power_suggestions(driver_id)` | `supabase.rpc('fn_get_power_suggestions', ...)` | Rows from `driver_power_suggestions` |
| `fn_dismiss_power_card(card_id, driver_id)` | `supabase.rpc('fn_dismiss_power_card', ...)` | `boolean` |
| `fn_act_on_power_card(card_id, driver_id)` | `supabase.rpc('fn_act_on_power_card', ...)` | `boolean` |
| `fn_generate_power_cards(driver_id)` | Called by triggers automatically | `integer` (cards inserted) |

### Realtime channels

| Channel | Table | Use |
|---------|-------|-----|
| `driver_power` | `driver_power_suggestions` | Power Mode live card updates |
| `market_signals` | `driver_market_signals` | Union Mode signal feed |
| `return_market` | `ride_requests` | Return Ride Marketplace live cards |

---

## FLUTTER PACKAGES — FINAL LIST

```yaml
dependencies:
  # Core (already in project)
  flutter_riverpod: ^2.5.0
  go_router: any
  supabase_flutter: any
  mapbox_maps_flutter: 2.19.1
  flutter_animate: ^4.5.0
  fl_chart: ^0.68.0
  google_fonts: ^6.2.1
  audioplayers: ^6.0.0

  # Add these — check pubspec.yaml first before adding
  share_plus: ^7.2.2
  record: ^5.0.4
  url_launcher: ^6.2.6
  webview_flutter: ^4.7.0
  cached_network_image: ^3.3.1
```

Before adding any package, search `pubspec.yaml` for it. If it already exists, do not add it again.

---

## STRINGS TO ADD TO `driver_strings.dart`

Check each one exists before adding. Do not create duplicates.

```dart
// Driver Hub
static const String driverHub = 'Driver hub';
static const String earningsTarget = 'Dagdoel';
static const String setTarget = 'Doel instellen →';
static const String activeRates = 'Actieve tarieven';
static const String manageRates = 'Tarieven beheren →';
static const String safetyToolkit = 'Veiligheidskit';
static const String emergencyCall = 'Alarmnummer bellen';
static const String shareTripDetails = 'Rit details delen';
static const String audioRecording = 'Audio opname';
static const String availableDuringRide = 'Beschikbaar tijdens actieve rit';
static const String sendMessage = 'Stuur een bericht';
static const String messages = 'Berichten';
static const String helpArticles = 'Help artikelen';

// Power Mode
static const String driverPowerMode = 'Driver Power Mode';
static const String powerModeSubtitle = 'AI-suggesties om meer te verdienen';

// Union Mode
static const String driverUnionMode = 'Driver Union Mode';
static const String unionModeSubtitle = 'Live marktintelligentie';

// Return trips
static const String returnTrips = 'Retourritten';
static const String returnDiscount = 'Jouw retourkorting';

// Status timestamps
static const String onlineSince = 'Online · sinds';
static const String onBreakSince = 'Pauze · sinds';
```

---

*HeyCaby Driver Build Guide — March 2026*
*Supabase: fvrprxguoternoxnyhoj*
*Backend complete: all tables, views, functions, triggers in place.*
*Developer starts at Step 1 toggle refinements. Steps 1–9 are pre-launch. Steps 11–12 are Power/Union Mode.*