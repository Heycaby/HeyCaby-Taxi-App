# HeyCaby Driver — Driver App Design & Build Guide
## Version 2 — Updated with Bolt reference screenshots
### Plain English for the Flutter developer

---

## IMPLEMENTATION STATUS (as of March 2026)

- **[DONE]** = Implemented and wired to backend
- **[PARTIAL]** = Implemented with placeholder or limited scope
- **[TODO]** = Not yet implemented

---

## WHAT YOU STUDIED IN BOLT — KEY OBSERVATIONS

Before building anything, here is what Bolt does well that we are going to match and beat:

**Bolt home screen (offline state):**
- Map takes 55% of the screen. Full width. No padding.
- A floating earnings pill at the top centre of the map shows "€0.00 / Today" — always visible, always on the map, not in the sheet.
- Top left: a hamburger menu button — round white button, subtle shadow.
- Top right: a shield/safety button — round white button, subtle shadow.
- The "Go online" button is a wide full-width pill sitting just above the sheet, on top of the map. Green. White text. Not inside the sheet — it floats between map and sheet.
- The sheet below is pure white. Clean. No grey.

**Bolt bottom sheet cards:**
- "Offers" — white card, green circular icon on the left, title + subtitle, full width, chevron on the right.
- "Scheduled Rides available" — same layout, grey circular icon.
- "Driver score" and "Bolt Rewards" — two cards side by side in a 2-column grid. Clean white background, small label at top, big number below, chevron.
- "Acceptance rate" — same grid card.

**Bolt earnings modal (tapping the earnings pill):**
- Floats as a white card over the map — not a full sheet. White card, round corners, shadow.
- Big earnings number centred: "€0.00" with "Today" underneath in grey.
- Two sub-cards below in a grid: "Weekly" and "Balance" — each with a label, an icon, and "€0.00".
- Eye icon top left to show/hide the number.
- This is a floating card, NOT a bottom sheet. It sits in the upper portion of the screen over the map.

**Bolt map view settings:**
- Bottom sheet from below. Title "Map view". Close X button.
- Two image cards side by side: "Surge" heatmap and "Clear map". The selected one has a green border.

**Bolt scheduled rides:**
- Full white screen. Back arrow top left, centred title.
- Toggle between "Requests" and "Confirmed" at the top — pill toggle, white selected, grey unselected.
- Each ride card: fare + pickup time as the headline (bold), vehicle category + distance in grey below, then a mini map image showing the route, then two address rows with coloured dots.

**Bolt driver score:**
- Full white screen. Large percentage number centred (85%). Progress bar below.
- Grey section header "What reduced my score?" then content rows.
- Rider comments shown as quotes at the bottom.

---

## HOW HEYCABY DOES IT BETTER

We take everything Bolt does well and add what Bolt is missing:

- Bolt's earnings pill shows today's total. **HeyCaby's shows today's total AND current zone** — two pieces of info in one pill. More useful.
- Bolt's heatmap is vague colours. **HeyCaby's zone circles show the exact passenger count** — real actionable data.
- Bolt has no Dutch break law compliance. **HeyCaby tracks driving hours and warns at 4h15m**. Unique to the Dutch market.
- Bolt has no community or ride swap. **HeyCaby has Driver Talk and Ride Swap** — network effects that Bolt cannot replicate.
- Bolt has 4 bottom nav tabs. **HeyCaby has 3** — cleaner, faster to navigate.

---

## THE DESIGN RULES — READ BEFORE TOUCHING ANY CODE

1. Pure white (`#FFFFFF`) for all screens, sheets, cards, modals. Not off-white. Not grey. White.
2. Gold (`#E6A800`) for one primary action per screen and the active nav icon. Nothing else.
3. Inter font everywhere. No serif fonts. No system default.
4. Text hierarchy: 32px bold for hero numbers, 22px bold for screen titles, 16px medium for labels, 14px regular for body, 12px light grey for hints.
5. Every color from `ref.watch(colorsProvider)`. No hardcoded hex.
6. Every string from `l10n.xxx`. No hardcoded text.
7. Max 300 lines per file. Split when approaching that number.
8. No mock data. Every number comes from the live Supabase database.

---

## PART 1 — HOME SCREEN LAYOUT [DONE]

### The map [DONE]

Full screen. Always. The map covers 100% of the screen from edge to edge, top to bottom. The sheet, the floating elements, and the buttons all sit on top of the map inside a `Stack`. The map never shrinks.

Use `MapboxStyles.NAVIGATION_DAY`. Zoom 15 at street level.

### The floating elements on top of the map

There are four elements floating on the map. All sit inside a `Stack` above the `MapWidget`.

**Element 1 — Hamburger menu button (top left) [DONE]**
A round white button, 44x44px, with a subtle shadow. Three horizontal lines icon. Tapping opens a side drawer with: driver profile, documents, support, settings, logout. This is the same pattern as Bolt.

```dart
Positioned(
  top: MediaQuery.of(context).padding.top + 12,
  left: 16,
  child: _MapFloatingButton(icon: Icons.menu, onTap: _openDrawer),
)
```

**Element 2 — Earnings pill (top centre) [DONE]**
A white pill button floating above the map. Shows today's earnings on the left and the driver's current zone name on the right, separated by a thin divider. Tapping it opens the earnings modal (see below).

When the driver is offline, it shows "€0.00 · Offline". When online, it shows "€14.50 · Rotterdam Centrum". The zone name comes from `driver_locations.current_zone_id` joined to `bubble_zones.name_display`.

```dart
Positioned(
  top: MediaQuery.of(context).padding.top + 12,
  left: 70,
  right: 70,
  child: _EarningsPill(
    todayEarnings: earnings,
    zoneName: currentZoneName,
    onTap: _showEarningsModal,
  ),
)
```

**Element 3 — Location recenter button (right side) [DONE]**
A round white button with a location pin icon. Taps recenters the map on the driver's current GPS position.

**Element 4 — Map filter button (bottom right, just above the Go Online button) [DONE]**
A round white button with a sliders icon — same as Bolt's sliders button. Tapping opens the zone view settings modal (see Part 3).

### The Go Online button [DONE]

This is the most important element on the home screen when the driver is offline. It is a wide pill button, gold (not green like Bolt — this is HeyCaby), white text "Go online". It floats at the bottom of the map portion, just above the sheet.

Critically: it is NOT inside the sheet. It is positioned as a `Positioned` element at the bottom of the map area, so it sits between the map and the sheet edge. This makes it feel attached to the map rather than being a sheet button.

```dart
Positioned(
  bottom: sheetHeight + 16,
  left: 16,
  right: 70, // leaves room for the filter button on the right
  child: _GoOnlineButton(onTap: _goOnline),
)
```

When the driver goes online, the Go Online button disappears with a fade animation and the floating status widget appears at the top (see Part 2).

### The bottom sheet — offline state [DONE]

The sheet sits at 42% height by default. Pure white. 20px top corner radius. Subtle shadow (8px blur, 5% black).

Inside the sheet, from top to bottom:

**Drag handle [DONE]** — a 40x4px grey pill centred at the very top.

**Scheduled rides card [DONE]** — full width, white background, 1px `#E8E8E6` border, 12px corner radius, subtle shadow. Left side: a gold circular icon background with a calendar icon. Right side: title "Scheduled rides" in 15px medium, subtitle "X rides available in your area" in 13px grey. Chevron on the far right. Tapping navigates to the scheduled rides screen.

This count comes from `ride_requests` where `booking_mode = 'scheduled'` and `status = 'pending'` and the zone matches the driver's current zone.

**2-column stats grid [DONE]** — two cards side by side.

Left card — "Driver rating" [DONE]: label in 12px grey at top, the rating number from `drivers.rating` in 28px bold below, a row of 5 small star icons, chevron top right. Tapping goes to the driver score detail screen (like Bolt's driver score).

Right card — "Today's rides" [DONE]: label in 12px grey at top, count of today's completed rides from `driver_trip_history` where `completed_at >= today` in 28px bold below. No chevron needed.

**Community preview card [DONE]** — full width card. Shows the most recent post from the community (`community_posts` where `channel = 'general'`, ordered by `created_at DESC`, limit 1). Left side: a small avatar circle with the posting driver's initials. Right side: the post content truncated to one line. A "Driver Talk" label badge in gold at the top. Tapping goes to the community tab. This gives the community a presence on the home screen and encourages drivers to check it.

---

## PART 2 — THE ONLINE STATUS WIDGET [DONE]

### What it is [DONE]

When the driver goes online, the Go Online button fades out and a compact floating widget appears at the top of the map. This widget is always visible while the driver is online.

The widget is a pill-shaped white card with a shadow. It contains:
- A green pulsing dot on the left (online indicator)
- "Online" text in 13px medium
- A thin vertical divider
- The current zone name in 13px grey
- A tiny chevron on the right

Width is about 180px, height 36px. It sits at the top of the screen, centred.

```dart
// The widget uses flutter_animate for the entry animation
_OnlineStatusWidget()
  .animate()
  .slideY(begin: -2.0, end: 0.0, duration: 400.ms, curve: Curves.easeOutBack)
  .fadeIn(duration: 300.ms)
```

### What happens when you tap the widget [DONE]

A panel slides DOWN from the top of the screen — not up from the bottom like a normal sheet. This is the design moment that makes HeyCaby feel different from every other taxi app. Use `SlideTransition` with `Tween<Offset>(begin: Offset(0, -1), end: Offset.zero)`.

The panel is a white card that occupies the top 60% of the screen. It has a close handle at the bottom. Inside it shows:

**Top section — shift summary [DONE]**
Three metric cards in a row: "Online" (hours and minutes since shift start), "Rides" (count from `driver_trip_history` today), "Earned" (sum from today's rides). These are the three numbers a driver cares about most during a shift.

**Middle section — break management [DONE]**
A large "Take a break" button in a light grey pill. When tapped, the driver goes `on_break` status. The widget dot turns amber.

Below it, the Dutch taxi break compliance notice: "You have been driving for X hours. Dutch regulations require a 30-minute break after 4.5 hours of driving." This text is only shown when the driver has been online for more than 3 hours. When they approach 4.5 hours it turns amber. When they exceed it, it turns red.

**Bottom section — end shift [DONE]**
A text button "End shift" in dark grey (not gold — this is a destructive secondary action). Tapping shows a confirmation dialog: "End your shift? You have driven X hours and completed Y rides today." Two buttons: "Cancel" and "End shift" (the confirmation button is black, not gold, to signal this is a finality).

### The on_break state [DONE]

When on break, the floating widget changes: the green dot becomes amber, text changes to "On break · Resume". Tapping the widget when on break shows a simple dialog: "Ready to go back online?" with a gold "Go online" button.

The status is written to the backend FIRST, then the UI updates. Never optimistic.

```dart
Future<void> _takeBreak() async {
  // 1. Write to backend first
  final success = await ref.read(driverApiProvider).setStatus('on_break');
  // 2. Only update UI if backend confirmed
  if (success) {
    ref.read(driverStateProvider.notifier).setStatus(DriverStatus.onBreak);
  }
}
```

---

## PART 3 — THE ZONE MAP IN DETAIL [DONE]

### How it looks [DONE]

The zone circles described in the previous version of this guide are correct. Here is additional detail on exactly how to implement it to feel premium.

Each zone with waiting passengers gets a circle drawn on the map. The circle is centered on `bubble_zones.center_lat` and `bubble_zones.center_lng`. The radius uses `bubble_zones.radius_m`.

Color system for zones [DONE]:
- 1–3 passengers: very faint gold at 12% opacity, no label
- 4–9 passengers: gold at 30% opacity, zone name label
- 10–19 passengers: gold at 55% opacity, zone name + count badge
- 20+ passengers: gold at 70% opacity, pulsing animation, zone name + count badge

The count badge [DONE] is a small white pill (implemented via SymbolLayer text, not PointAnnotation) floating in the centre of the zone circle. It shows "14 waiting" in 11px bold dark text. This is drawn using a `PointAnnotation` with a custom generated image.

### The zone filter modal [DONE]

Tapping the sliders button on the map opens this modal from below. It looks similar to Bolt's "Map view" modal but with HeyCaby content.

Title: "Zone view". Close X button top right.

Two options shown as image cards side by side:
- "Demand zones" — shows the gold circles with passenger counts. Default selected state.
- "Clear map" — hides all zone overlays for a clean driving view.

The selected card has a gold border (not green like Bolt). A description line below explains what the selected view does.

```dart
// Store selection in Riverpod
final mapViewProvider = StateProvider<MapView>((ref) => MapView.demandZones);
```

### Driver's current zone indicator [DONE]

Inside the floating status widget, the zone name comes from joining `driver_locations.current_zone_id` to `bubble_zones.name_display`. This updates whenever the driver's location crosses into a different zone.

The driver also sees their zone highlighted differently on the map — their current zone has a slightly brighter gold border (not fill, just border) so they can see which zone they are currently in even at a glance.

---

## PART 4 — THE EARNINGS MODAL (FLOATING CARD OVER MAP) [DONE]

This is modelled exactly on how Bolt does it — a floating card that appears over the map, not a full-screen navigation. The driver taps the earnings pill and a white card slides down from just below the pill.

The card is 90% screen width, centered. White background. 16px corner radius. Shadow: 0px 8px 24px at 12% black opacity.

**Inside the card:**

Top row [DONE]: eye icon (toggle to show/hide the number), large earnings number centred "€24.50", "Today" in grey below.

Two cards in a grid below [DONE]:
- "This week": a small calendar icon in a grey circle, "€24.50" in 18px bold. Tapping navigates to the full earnings screen.
- "Acceptance rate": a percentage in 18px bold from the driver's stats. Tapping goes to the driver score screen.

These numbers come from:
- Today: sum of `rides.final_fare` where `completed_at >= today` and `driver_id = current_driver`
- This week: same but `completed_at >= start of this week`
- Acceptance rate: you will need to add this column to the `drivers` table or calculate it from `driver_trip_history`. See Part 8.

The card closes when the driver taps anywhere outside it, or taps the pill again.

---

## PART 5 — SCHEDULED RIDES SCREEN [DONE]

This is modelled on Bolt's scheduled rides screen. Here is how to build it for HeyCaby.

Full white screen. Back arrow top left. "Scheduled rides" title centred.

**Toggle at the top [DONE]:** Two options — "Requests" and "Confirmed". The selected one has a white background with a border. The unselected one is light grey. This is a `SegmentedButton` in Flutter or a custom toggle. Not a tab bar with icons — just two text pills.

**Requests tab** shows `ride_requests` where `booking_mode = 'scheduled'` and `status = 'pending'` and the pickup zone is within the driver's service area, ordered by `scheduled_pickup_at` ascending.

**Confirmed tab** shows rides the driver has already accepted.

**Each ride card [DONE] looks exactly like Bolt's scheduled ride card:**

Top line: fare in bold + bullet + pickup time. Example: "€42.00 · Pick-up today 09:45"
Second line: vehicle category icon + distance. Example: car icon + "17.3km"

Below that [DONE], a small static map preview. In Flutter, use a Mapbox Static Images API URL to generate a map thumbnail:
```
https://api.mapbox.com/styles/v1/mapbox/navigation-day-v1/static/[lng],[lat],12,0/320x120@2x?access_token=TOKEN
```
This generates a 320x120 map image without needing to render a full MapWidget. Display it in a `CachedNetworkImage` widget with a rounded corner container.

Below the map [DONE]: two address rows with coloured dots. Pickup dot is gold. Destination dot is a dark filled circle. Full addresses with postcode.

Tapping a card opens the ride detail with accept/decline buttons [DONE].

---

## PART 6 — DRIVER SCORE SCREEN [DONE]

HeyCaby should have this screen. It makes drivers care about their quality. Bolt does it well — copy the structure and make it gold instead of green.

Full white screen. Back arrow. "Driver score" centred title.

Big percentage number at the top centred — this is `drivers.rating` multiplied by 20 (since Supabase stores it as a 1-5 star rating, multiply by 20 to get a percentage). Display "4.8 ★" or "96%" — pick one format and stick to it.

Below the number: a horizontal progress bar. Gold fill on the left, light grey on the right. Width proportional to the score.

Section: "Recent passenger comments" [DONE] — these come from `ride_ratings.rider_comment` (via driver_passenger_comments) where `driver_id = current_driver` and `rider_comment IS NOT NULL` ordered by `created_at DESC` limit 10. Show each comment as a simple quote row with a three-dot menu (report/dismiss). [DONE] Report → inserts into `driver_comment_reports`; Dismiss → inserts into `driver_hidden_comments` and filters from view.

Section: "Acceptance rate" [DONE] — from drivers table.
Section: "What reduced my score?" [DONE] — explanatory text. See Part 8 for the database note.

---

## PART 7 — DRIVER PREFERENCES SCREEN [DONE]

This is simple and should closely follow Bolt's preferences screen. Clean white. Settings rows separated by thin dividers. No section backgrounds — just dividers.

Each row: label in 16px dark, subtitle or current value in 14px grey below, chevron on the right for rows that navigate somewhere, toggle on the right for boolean settings.

Rows to include [all DONE]:
- **Vehicle** — shows `drivers.vehicle_plate` + `drivers.vehicle_make` + `drivers.vehicle_model` + `drivers.vehicle_year`. Tapping opens the vehicle edit screen.
- **Pickup distance** — how far the driver is willing to go for a pickup. A badge chip shows the current value (e.g. "15 KM"). Tapping shows a slider modal. Default 20km as Bolt shows. Persisted via `updateDriverPrefs`.
- **Accepts cash** — toggle, from `drivers.payment_method` array.
- **Accepts Tikkie** — toggle, same array.
- **Pet friendly** — toggle, from `drivers.is_pet_friendly`.
- **Wheelchair accessible** — toggle, from `drivers.is_wheelchair_accessible`.
- **Language** — current app language, chevron. Picker modal (en, nl, ar). Persisted via `localeProvider`.
- **Theme** — current theme name, chevron. Picker modal with all `kThemes`. Persisted via `ThemeNotifier`.

---

## PART 8 — DATABASE NOTES FOR THE DEVELOPER [REFERENCE]

These are columns you will need that may not exist yet or need clarification.

**Earnings calculation:**
Your `driver_trip_history` table does NOT have a `fare` or `earnings` column. It only has `distance_km` and timestamps. To calculate earnings, join it to `ride_requests`:
```sql
SELECT SUM(r.final_fare)
FROM driver_trip_history dth
JOIN rides r ON r.ride_request_id = dth.ride_request_id
WHERE dth.driver_id = $driver_id
AND dth.completed_at >= CURRENT_DATE;
```

**Acceptance rate:**
The `drivers` table does not have an `acceptance_rate` column. For now, calculate it in the app:
- Total ride requests received by the driver (you need a query or counter)
- Divided by rides accepted
This may need a new column or a backend function. Discuss with the team whether to store this or calculate on the fly.

**Rider comments:**
The `ride_ratings` table has `rider_comment TEXT`. This is the source for the compliments/comments section on the driver score screen. Query:
```dart
final comments = await supabase
  .from('ride_ratings')
  .select('rider_comment, rider_rating_of_driver, created_at')
  .eq('driver_id', driverId)
  .not('rider_comment', 'is', null)
  .order('created_at', ascending: false)
  .limit(20);
```

**Swap channel migration [DONE — applied via Supabase MCP]:**
Initial migration (swap enum value, ride_request_id, swap_status) applied. Backend already had fn_claim_swap_ride(p_post_id, p_claiming_driver_id), fn_confirm_swap_ride(p_post_id, p_passenger_response). community_posts uses driver_id, content (not author_driver_id, body). Original migration for reference:
```sql
ALTER TYPE community_channel ADD VALUE IF NOT EXISTS 'swap';
ALTER TABLE community_posts 
  ADD COLUMN IF NOT EXISTS ride_request_id UUID REFERENCES ride_requests(id),
  ADD COLUMN IF NOT EXISTS swap_status TEXT DEFAULT 'open' 
    CHECK (swap_status IN ('open', 'claimed', 'confirmed', 'cancelled'));
```

---

## PART 9 — BOTTOM NAVIGATION — THREE TABS [DONE]

Three tabs. No more.

**Tab 1 — Home** (map icon, line style)
The zone map, online widget, incoming rides, everything operational.

**Tab 2 — Work [DONE]** (briefcase or list icon, line style)
Two sub-tabs at the top: "Earnings" and "Available rides".
- Earnings: today's number big at top, weekly chart using `fl_chart`, today's ride list from `driver_trip_history` JOIN `ride_requests`.
- Available rides: three filter chips (Now, Scheduled, Marketplace), then the scrollable ride cards.

**Tab 3 — Me [DONE]** (person icon, line style)
Two sub-tabs: "Community" and "Profile".
- Community: the three channel tabs (Announcements, Driver Talk, Ride Swap), post feed. Pull-to-refresh via `easy_refresh`.
- Profile: driver name (from auth), photo (placeholder), vehicle, rating. Settings rows below.

**Drawer [DONE]:** Profile, Documents, Support, Settings (→ Preferences), Logout. Each opens a dedicated screen.

Active tab icon: gold `#E6A800`. Inactive: `#A0A0A0`. No labels needed if icons are clear. If labels are added: 11px, same color rules.

---

## PART 10 — FLUTTER PACKAGES [DONE]

All design doc packages are in pubspec.yaml. Note: hugeicons is optional and not included.

```yaml
dependencies:
  # Charts for earnings screen - clean, customisable
  fl_chart: ^0.68.0
  
  # Premium line icons
  hugeicons: ^0.0.7
  
  # Smooth animations - use this instead of AnimationController by hand
  flutter_animate: ^4.5.0
  
  # Cached network images for map thumbnails on scheduled rides screen
  cached_network_image: ^3.3.1
  
  # In-app sounds
  audioplayers: ^6.0.0
  
  # Pull to refresh on community feed
  easy_refresh: ^3.4.0
  
  # Already in project:
  # mapbox_maps_flutter: 2.19.1
  # flutter_riverpod: ^2.5.0
  # go_router
  # supabase_flutter
  # flutter_background_service: ^5.0.0
  # geolocator: ^11.0.0
```

### The flutter_animate pattern — use this everywhere for premium feel

Instead of writing `AnimationController` by hand, chain animations directly on widgets:

```dart
// Go Online button disappearing when driver goes online
_GoOnlineButton()
  .animate(target: isOnline ? 1.0 : 0.0)
  .fadeOut(duration: 250.ms)
  .slideY(end: 0.3, duration: 250.ms)

// Status widget appearing
_OnlineStatusWidget()
  .animate()
  .slideY(begin: -1.5, end: 0.0, duration: 400.ms, curve: Curves.easeOutBack)
  .fadeIn(duration: 300.ms)

// Earnings modal card dropping down
_EarningsCard()
  .animate()
  .slideY(begin: -0.5, end: 0.0, duration: 350.ms, curve: Curves.easeOut)
  .fadeIn(duration: 250.ms)

// Zone circles pulsing
CircleWidget()
  .animate(onPlay: (c) => c.repeat(reverse: true))
  .scaleXY(begin: 0.95, end: 1.05, duration: 800.ms, curve: Curves.easeInOut)
```

---

## PART 11 — WHAT MAKES HEYCABY BETTER THAN BOLT — SUMMARY FOR THE DEVELOPER

When you are building this app and you are tired and tempted to just copy Bolt, remember these specific reasons why HeyCaby is better:

Bolt shows vague heatmap colours. HeyCaby shows "18 passengers waiting in Rotterdam Centrum right now." That is real data that helps a driver make a real decision.

Bolt shows a simple earnings pill. HeyCaby's pill shows earnings AND zone name together — two pieces of data in the same space.

Bolt has no break tracking. HeyCaby tracks Dutch regulatory driving hours and warns the driver before they break the law. This is a feature that protects real Dutch taxi drivers from losing their license.

Bolt has no community. HeyCaby has Driver Talk where drivers share traffic tips, and Ride Swap where a sick driver can hand a job to a colleague instead of leaving a passenger stranded.

Bolt's bottom sheet is informational. HeyCaby's bottom sheet has a community preview showing the latest driver post — the community is always one tap away, not buried in a tab.

These features exist because HeyCaby was built specifically for Dutch professional taxi drivers. Bolt was built for everyone everywhere. That difference is the entire product.

---

---

## IMPLEMENTATION SUMMARY

| Part | Status | Notes |
|------|--------|-------|
| 1 Home screen | DONE | Map, floating elements, Go Online, bottom sheet, scheduled rides card, 2-col stats, community preview |
| 2 Online status | DONE | Widget, top-slide panel, break management, Dutch notice, end shift |
| 3 Zone map | DONE | Circles, labels, count badges, pulsing 20+, filter modal, current zone gold border |
| 4 Earnings modal | DONE | Floating card, eye toggle, Today/Week/Rate, taps to Work/Score |
| 5 Scheduled rides | DONE | Toggle, cards, map thumbnails, addresses, accept/decline |
| 6 Driver score | DONE | Rating, progress bar, acceptance rate, "What reduced my score?", comments with 3-dot Report/Dismiss (backend: driver_hidden_comments, driver_comment_reports) |
| 7 Preferences | DONE | Vehicle edit, pickup slider, toggles, language picker, theme picker |
| 8 Database | REF | Notes for backend; earnings/acceptance/comments wired to views |
| 9 Bottom nav | DONE | 3 tabs, Work sub-tabs, Me sub-tabs, drawer screens |
| 10 Packages | DONE | fl_chart, flutter_animate, cached_network_image, easy_refresh |
| Ride Swap | DONE | Claim button on swap posts, claimSwapRide/confirmSwapRide in service |
| Driver name | DONE | From auth user_metadata.full_name or email |

**Ride Swap [DONE]:** Claim button on swap posts (swap_status=open). Calls `fn_claim_swap_ride`. Confirm flow uses `fn_confirm_swap_ride` when backend supports it.

**Driver display name [DONE]:** From `auth.user_metadata.full_name` or email.

**Driver photo [DONE]:** Uses `drivers.profile_photo_url` when available; CachedNetworkImage with fallback placeholder.

**Ride Swap post creation [DONE]:** FAB on Ride Swap tab opens modal; driver selects from assigned rides, adds optional message, posts via `createSwapPost()`.

**Available rides Now [DONE]:** Queries `ride_requests` (status='pending') via `getAvailableRidesNow()`; zone-filtered when driver has current zone.

**Marketplace [DONE]:** Queries `ride_requests` (status='pending', is_market=true) via `getAvailableMarketplaceRides()`; zone-filtered.

**Driver Talk post creation [DONE]:** FAB on Driver Talk tab opens modal; driver enters message, posts via `createCommunityPost(id, 'general', content)`.

**Support screen [DONE]:** Help Center → heycaby.nl/help; Contact support → mailto:support@heycaby.nl; Call support → tel:+31201234567 via url_launcher.

---

*HeyCaby Driver Driver App Guide v2 — March 2026*
*Updated after studying 6 Bolt driver app screenshots*
*Supabase project: fvrprxguoternoxnyhoj*
*Key tables: drivers, driver_trip_history, ride_ratings, driver_locations, bubble_zones, community_posts, community_replies, ride_requests*








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

### PART 1 — Refinements: swipe-to-reveal, feedback, labels, timestamps

**Swipe-to-reveal behaviour:** The control should feel like a swipe-to-reveal: as the driver swipes, the state (and its colour) is revealed. Use a single draggable track with three contiguous segments (Offline = red, Break = amber, Online = gold). The thumb position drives which segment is active; the filled portion of the track reveals the current segment (e.g. `Stack` + `ClipRect` or fractional width). Swiping right reveals Break then Online; swiping left reveals Break then Offline.

**Labels — always visible:** Place all three labels **below** the sliding track in one row: "Offline" | "Break" | "Online". The active label is bold/accent; inactive labels are grey. No label is ever covered by the thumb. Use l10n: `DriverStrings.offline`, `DriverStrings.onBreak`, `DriverStrings.online`.

**Tactile feedback:**
- **Snap to Break:** `HapticFeedback.mediumImpact()` or `heavyImpact()` so it feels like a lock/notch.
- **Snap to Online:** Play sound via `SoundService().playNotification()` or `SoundService().playTripComplete()`.
- **Snap to Offline:** Optional `HapticFeedback.lightImpact()`.
- Use a decisive snap animation (e.g. `Curves.easeOutBack`) so the thumb clearly locks into position.

**Timestamps for proof:** Every status change must have a timestamp drivers can use as proof (compliance/disputes). Store `status_changed_at` in the backend when `setStatus` is called. In the app, show it in the status pill or online widget, e.g. "Online · since 14:32", "Break · since 15:00", "Offline · since 16:45". Optionally "Last changed: [date], HH:mm" in the earnings card or Driver Hub.

---

## PART 2 — THE ONLINE WIDGET (WHEN DRIVER IS ACTIVE)

### Current problem

Screenshot 2 shows the floating earnings card duplicates the slide-to-go-online control. This is confusing and wastes the most valuable screen real estate in the app. The current widget has **no visual hierarchy** — everything looks the same weight, and important controls are buried. For a **premium Apple-level driver tool**, the widget should feel like a **control center for the driver's business**, not just a modal.

---

## PART 2B — DRIVER EARNINGS WIDGET — APPLE-LEVEL REDESIGN (Driver Control Panel)

Goals: Clear visual hierarchy, large tappable cards, real-time data from Supabase, driver business tools in one place, clean Apple-style layout (large typography, breathing space).

### Structure — 4 visual sections (each a separate card)

```
1. Earnings Summary
2. Driver Status
3. Active Rate Profile
4. Return Trip Discount Control
```

Layout: `[ Earnings ]` `[ Status ]` `[ Rates ]` `[ Return Discount ]` — each card visually separated with spacing.

### Card 1 — Earnings Summary

Top section. Large typography like Apple Wallet.

Layout:
```
TODAY
€124.80
5 rides completed
```

Design: € amount = **48px** (very large); secondary label = smaller; colour changes if online. Data: `driver_daily_earnings` or `get_driver_earnings_summary`. Live Supabase subscription. Optional later: progress bar toward daily goal.

### Card 2 — Driver Status

Replace tiny "offline" text with a **status pill**.

Example: `● Offline` | `● Online` | `● Break`

Colour logic: Offline → red, Online → green, Break → orange. Live state from `driver_status` / `drivers.status`.

### Card 3 — Active Rate Profile

Large rate card (not tiny chips buried in text).

Layout:
```
ACTIVE RATE
Standard
€2.00/km · €0.35/min · €2.50 start
[ Manage Rates ]
```

Or preset chips: `[ Standard ] [ Peak ] [ Airport ]` — selected chip gold-filled. Tapping updates `driver_rate_profiles` via `fn_switch_rate_profile`. Live update.

### Card 4 — Return Trip Discount (NEW)

Drivers returning from a trip can offer **discounted rides** to fill empty seats (e.g. drop in Amsterdam, going back to Rotterdam — offer discount for faster match).

**UI:** Large slider card.
```
RETURN TRIP DISCOUNT
0% ----|----|----|----|---- 40%
      10   20   30   40
```

Allowed values: 0%, 10%, 20%, 30%, 40% (max 40%).

**Passenger match probability** (below slider, from backend):
```
10% discount → 22% faster match
20% discount → 38% faster match
30% discount → 55% faster match
40% discount → 72% faster match
```

Backend: `return_trip_probability` query; `match_probability = demand_index * discount_factor * time_of_day * driver_location`. UI shows e.g. "⚡ Higher chance of quick return ride".

### Live data — Supabase Realtime

Use `supabase.realtime` subscriptions:
- `driver_status`
- `driver_earnings` / `driver_daily_earnings`
- `driver_rate_profile`
- `return_discount_setting`
- `return_trip_probability`

When driver moves slider: update `return_discount_setting`; backend recalculates `match_probability`; return to UI instantly.

### Visual hierarchy rules

**Typography:** Money = 48px; section titles = 14px uppercase; body = 16px.

**Card design:** 16px padding, 16px margin, 20px border radius. Apple-style shadow: `0 8px 30px rgba(0,0,0,0.08)`.

**Spacing:** 24px between cards.

### Remove UI clutter

Remove: small grey lines, tiny icons with no meaning, duplicate controls. Keep: big cards, clear data, large tap areas.

### Final layout (Driver Control Panel)

```
--------------------------------
Driver Control Panel
--------------------------------
[ Earnings Card ]
Today | €0.00 | 5 rides
--------------------------------
[ Status Card ]
● Offline
--------------------------------
[ Active Rates ]
Standard | €2.00/km · €0.35/min · €2.50 start
[ Manage Rates ]
--------------------------------
[ Return Trip Discount ]
0% ----|----|----|----|---- 40%
Selected: 20%
⚡ 38% faster chance of passenger
--------------------------------
[ View Details ]
```

### Backend tables (for Return Trip Discount)

- `return_discount_setting` — driver_id, discount_percent (0–40), updated_at
- `return_trip_probability` — RPC or view returning `{ discount, match_probability }` based on demand algorithm

### Future (V2)

Daily goal progress, fuel expense tracker, heatmap demand, smart pricing suggestions.

---

### Dutch break compliance banner (retained)

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

The modal has four sections plus two navigation rows. Each section is separated by a thin divider. No section headers needed — the content is self-explanatory. At the bottom: **Driver Power Mode** — list tile with lightning icon, chevron; **Driver Union Mode** — list tile with group/union icon, chevron; tapping pushes the respective screen (PART 7B, PART 7C).

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

A smart assistant for the driver that analyzes demand, location, time, driver price, return routes, and ride patterns — then gives real-time suggestions to help the driver earn more. This is the feature that makes drivers prefer your platform over Uber/Bolt. Philosophy: *Drivers are independent. The platform is just a smart tool.*

**Where it lives:** Driver Hub — a list tile at the bottom: "Driver Power Mode" with lightning icon, chevron. Tapping opens the Power Mode screen.

### Power Mode screen layout

**Top section:**
```
POWER MODE
AI suggestions to increase earnings
```

Clean Apple-style stacked cards. Large cards, simple text, action buttons. Each card is an actionable insight.

### Card 1 — High Demand Nearby

```
HIGH DEMAND ZONE

Schiphol Airport
+42% ride demand

Distance: 9 km
Estimated earnings next hour: €75–€110

[Navigate]
```

Backend: `zone_demand_score`, `ride_requests_last_10_min`, `driver_density` → `profit_probability`. Drivers immediately know where to go.

### Card 2 — Smart Price Suggestion

```
SMART PRICE ADJUSTMENT

Your current rate: €2.00/km
Recommended: €2.30/km

Reason: High demand in Rotterdam center

[Apply] [Ignore]
```

Driver still controls pricing. Platform only advises.

### Card 3 — Return Trip Opportunity

```
RETURN TRIP OPPORTUNITY

Passenger waiting
Amsterdam → Rotterdam

Fare: €64
Discount applied: 20%

[Accept ride]
```

Connects to the Return Discount system and Smart Return Ride Marketplace.

### Card 4 — Surge Opportunity

```
SURGE WINDOW

Event ending in 20 minutes
Ahoy Arena Rotterdam

Estimated ride surge: +60%

Recommended positioning: Park near exit B
```

Event-based demand insight. Drivers love this.

### Card 5 — Idle Warning

```
IDLE ALERT

You have been idle for 18 minutes.

Move to: Rotterdam Centrum
Estimated wait time: 4 minutes
```

Prevents drivers wasting time in low-demand areas.

### Card 6 — Goal Tracker

```
WEEKLY GOAL

Target: €1000
Current: €412

You need: €588
Estimated rides: 7–9 rides
```

Motivation and planning. Uses `driver_earnings_targets` and `get_driver_earnings_summary`.

### Backend (Supabase)

**Tables:** `driver_locations`, `ride_requests`, `demand_zones`, `driver_rate_profiles`, `return_discount_setting`, `driver_earnings_targets` (or `driver_goals`)

**Realtime:** `supabase.channel("driver_power")` — driver sees insights update live.

### Why drivers will love this

They feel like they have a co-pilot helping them earn more. Uber treats drivers like robots. Your platform treats drivers like business owners with tools. Result: drivers earn 20–30% more through smarter decisions.

### The bigger vision

The platform becomes **The Operating System for Taxi Drivers** — managing pricing, routes, discounts, demand, earnings, support, and safety in one place.

---

## PART 7C — DRIVER UNION MODE

Data-driven coordination for drivers — collective intelligence through anonymous market signals. Not a political union; a **market dashboard** so drivers can make better decisions together. Philosophy: drivers are independent business owners; the platform is SaaS for drivers. Uber/Bolt avoid this because transparency reduces platform control; your platform embraces it because you sell tools, not rides.

**Where it lives:** Driver Hub — list tile "Driver Union Mode" with group/union icon, chevron. Tapping opens the Union Mode market dashboard.

### Screen 1 — Market Balance

```
ROTTERDAM CENTRUM

Passengers waiting: 34
Drivers online: 21

Demand level: HIGH
```

Color indicator: green = Balanced, amber = Busy, red = High demand. Helps drivers know where demand is strongest.

### Screen 2 — Average Driver Price

Drivers see market pricing trends:

```
AVERAGE DRIVER PRICE

Rotterdam: €2.10/km · €0.38/min · €3.10 start

Your price: €1.90/km

You are 10% cheaper than average
```

Or: "You are 18% higher than average". Drivers stay competitive. No personal data — only aggregated market data.

### Screen 3 — Zone Saturation Map

Map overlay showing driver density:

```
Drivers nearby: 42
Passengers requesting: 12

Too many drivers
```

Another area:

```
Drivers: 8
Passengers: 24

High opportunity
```

Drivers move to better zones.

### Screen 4 — Collective Surge Signal

When many drivers decline low fares, the system detects it:

```
Drivers rejecting rides below €10
Demand increasing

Suggested minimum fare: €12
```

Drivers decide if they want to follow. Prevents race-to-the-bottom pricing.

### Screen 5 — Community Intelligence

Drivers share quick anonymous signals:

```
⚠ Police control on A13
⚡ Event ending at 22:00 Ahoy
🚧 Road closed near Blaak
```

Like Waze but for taxi drivers. Anonymous, very fast.

### Backend (Supabase)

**Tables:** `driver_locations`, `driver_rates`, `zone_demand`, `driver_density`, `market_prices`, `driver_signals`

**Realtime:** `supabase.channel("market_signals")` — drivers see live market data.

### Why this will go viral with drivers

Drivers finally feel empowered. They understand the market. Instead of being controlled by an algorithm, they **see the algorithm**. The app becomes **The Bloomberg Terminal for Taxi Drivers** — real-time market intelligence.

### Combined platform summary

**Driver Hub:** earnings tools, safety toolkit, support, Power Mode, Union Mode

**Power Mode:** smart demand suggestions, surge alerts, pricing insights

**Return Marketplace:** fill empty trips

**Union Mode:** market intelligence

**Result:** Drivers make 20–40% more income through smarter decisions.

---

## PART 8 — HOME SCREEN SHEET CARD CHANGES

### Bottom sheet layout (order)

Keep this order from top to bottom: (1) Status toggle (swipe-to-reveal), (2) Scheduled rides card, (3) Two-column grid, (4) Driver Talk card. Only the grid content changes: left = Return trips, right = Today's rides.

### Remove: "Driver rating" card
Delete the left card in the 2-column grid that shows "Driver rating / —". This is replaced by the Return Trips card.

### Add: "Return trips" card (left card)
Label: "Return trips" in 12px grey at top. A count number below: "3 available" in 22px bold. A small arrow icon pointing back-left (suggesting return direction).

**Tapping opens the Smart Return Ride Marketplace** (see PART 8B below) — a full screen that helps drivers fill empty return rides with passengers going the same direction. This is connected to the Return Discount slider in the Driver Control Panel.

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

This is the screen that opens when the driver taps the **Return trips** card. It helps drivers fill empty return rides with passengers going the same direction — something Uber and Bolt do not do well. It connects to the Return Discount slider in the Driver Control Panel.

### When it appears

After a driver finishes a trip and is heading back toward their home zone. Example: driver drops passenger in Amsterdam, home zone = Rotterdam. The system detects `driver_direction`, `driver_destination`, and distance (e.g. 74 km), then the Return Marketplace card/screen appears automatically. Tapping the Return trips card on the home sheet also opens this screen.

### Screen layout

**Top section — header**

Large clear header:

```
RETURN RIDE OPPORTUNITIES
Amsterdam → Rotterdam
74 km
```

Below: "You may find a passenger for your return trip"

**Return Discount control (connected to Driver Control Panel)**

Same slider as in the Driver Control Panel (0% — 10% — 20% — 30% — 40%). When driver selects e.g. 20%, the UI shows:

```
Estimated passenger match: 38%
Estimated wait time: 9 min
```

Values come from Supabase demand data (RPC or view).

**Live passenger requests**

Real ride requests going the same direction. Example cards:

```
Passenger
Amsterdam → Rotterdam
Departure: 14:20
Distance: 71 km

Passenger price: €72
Your price after discount: €57

[Accept]
```

Another example:

```
Passenger
Amsterdam → Den Haag
Departure: 14:35

Passenger price: €60
Your price after discount: €48

[Accept]
```

Driver chooses which to accept.

### Visual spec (Apple-level UX)

- Cards: `radius: 18px`, `padding: 16px`, soft shadow
- Accept button: `height: 52px`, large, green

### Backend logic (Supabase)

**Tables needed:** `drivers`, `driver_routes`, `return_discount_setting`, `ride_requests`, `demand_zones`

When driver finishes ride, backend calculates:
- `driver_direction`
- `driver_destination`
- `nearby_requests`

Query example:

```sql
SELECT * FROM ride_requests
WHERE destination_direction = driver_direction
  AND distance < 20 km
```

**Realtime subscription:** `supabase.channel("return_market")` — driver sees live passengers appear as requests come in.

### Probability engine

Match chance shown to driver:

```
match_probability = demand_score × discount_factor × driver_density × time_of_day
```

Example: 20% discount → +35% visibility boost (passengers see cheaper ride, accept faster).

### Why this beats Uber/Bolt

- Uber/Bolt: drivers have no control over return trips, pricing is hidden, empty rides happen constantly
- Our platform: driver controls price, driver controls discount, driver sees probability, driver fills empty rides

### Future: Return Ride Pooling

Later we can add: one return ride, multiple passengers (e.g. Amsterdam → Rotterdam: Passenger 1 €35, Passenger 2 €32, Passenger 3 €29, Total €96).

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

**New for Smart Return Marketplace (PART 8B):**

| Name | Type | Purpose |
|------|------|---------|
| `driver_routes` | Table | Driver direction/destination when heading home after a trip |
| `return_discount_setting` | Table | Per-driver return discount % (0–40) |
| `demand_zones` | Table | Demand score per zone for match probability |

**New for Driver Power Mode (PART 7B):**

| Name | Type | Purpose |
|------|------|---------|
| `driver_locations` | Table | Real-time driver position for demand/location analysis |
| `driver_goals` | Table | Weekly/daily earnings targets (or reuse `driver_earnings_targets`) |
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

**Step 1:** Build the `ThreeStateToggle` widget in isolation. Test all three states, all transitions, the spring snap animation, and the backend write. Get this perfect before touching anything else — it is the most used interaction in the entire app.

**Step 2:** Update the floating earnings card to remove the duplicate toggle. Add the rate profile chips. Wire to `driver_rate_profiles` table and `fn_switch_rate_profile` function.

**Step 3:** Remove the calendar map button. Add the Driver Hub button with badge logic.

**Step 4:** Build the Driver Hub modal with all four sections plus Power Mode and Union Mode navigation rows. Build each section top to bottom. Use `SliverList` inside a `CustomScrollView` for the modal content so it scrolls correctly. On Power Mode tap, push Power Mode screen (PART 7B); on Union Mode tap, push Union Mode screen (PART 7C).

**Step 5:** Replace the Driver Rating card with the Return Trips card. Wire to `driver_return_trips` view filtered by `heading_home_zone_id`. Tapping opens the Smart Return Ride Marketplace (PART 8B) — build that screen with header, Return Discount slider, match probability, and live passenger request cards with Accept buttons. Backend: query `ride_requests` by `destination_direction`, Realtime channel `return_market`.

**Step 6:** Update the Scheduled Rides count to use `fn_driver_has_overlap` filtering.

**Step 7:** Update the Today's Rides detail screen to show zone names instead of addresses.

**Step 8:** Remove the hamburger menu. Move drawer contents to the Me tab.

**Step 9:** Remove the Profile sub-tab from the community screen.

**Step 10:** Test on a real physical device with a second device acting as a rider. Every status change, every rate profile switch, every safety event, Driver Power Mode, Driver Union Mode.

**Step 11:** Build Driver Power Mode screen (PART 7B). Six card types: High Demand Nearby, Smart Price Suggestion, Return Trip Opportunity, Surge Opportunity, Idle Warning, Goal Tracker. Realtime channel `driver_power`. Route: /driver/power-mode.

**Step 12:** Build Driver Union Mode screen (PART 7C). Five sections: Market Balance (passengers vs drivers, demand level), Average Driver Price (market vs your price), Zone Saturation Map (driver density heat layer), Collective Surge Signal (rejection-based minimum fare suggestion), Community Intelligence (anonymous driver signals). Realtime channel `market_signals`. Route: /driver/union-mode.

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