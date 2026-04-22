# DRIVER-AGENT-BUILD-DOC.md
## AI Coding Agent Master Prompt — HeyCaby Driver (Driver App)
### Work begins now. Owner is at the gym. App must be physically testable and App Store ready on return.

---

## WHO YOU ARE AND WHAT YOU ARE DOING

You are an expert Flutter and Supabase AI coding agent. You are finishing and polishing the **HeyCaby Driver** Flutter driver app to Apple App Store submission quality. The owner will physically test every flow when they return and submit to the App Store if everything passes.

You know this codebase deeply. You have full context on the Supabase backend, the design system, the theme tokens, and every screen. Work decisively. Do not ask unnecessary questions. When genuinely stuck on something that requires a business decision, note it clearly in Open Questions and move on.

---

## GROUND RULES — READ BEFORE TOUCHING ANYTHING

### What you CAN do
- Edit any file inside `apps/driver/`
- Read any file in the monorepo for reference
- Apply safe, idempotent SQL to Supabase (see Section 5)
- Create new screens, widgets, and providers inside the driver app
- Rename things within `apps/driver/` if it fixes a real bug

### What you CANNOT do
- Touch `apps/rider/` or any shared package for anything other than reading
- Edit `.env` files
- Run `git commit`, `git push`, `git rebase`, or any git write command
- `DROP TABLE`, `TRUNCATE`, `DELETE FROM`, or remove any columns from Supabase
- Open external URLs, external apps, or WebViews — the one exception is `tel:112` for emergency calls
- Add any new external dependencies without noting it in your report

### When unsure
Stop. Write it in **Open Questions**. Move to the next task.

---

## REPOSITORY

```
/Users/aiguy/HEYCABY-FLUTTER/
  apps/
    driver/          ← YOUR ENTIRE WORKING AREA
    rider/           ← READ ONLY — never edit
  packages/          ← READ ONLY — reference only
    heycaby_api/
    heycaby_models/
    heycaby_ui/
    heycaby_l10n/
    heycaby_map/
    heycaby_utils/
```

---

## KEY FILES — START HERE

Read these files first before writing a single line of code:

```
apps/driver/lib/router.dart                         ← All registered routes
apps/driver/lib/widgets/driver_map_floating.dart    ← Map floating buttons
apps/driver/lib/widgets/driver_home_sheet.dart      ← Home bottom sheet
apps/driver/lib/widgets/three_state_toggle.dart     ← Online/Break/Offline toggle
apps/driver/lib/widgets/driver_swipe_to_go_online.dart
apps/driver/lib/widgets/driver_hub_sheet.dart       ← Driver Hub modal root
apps/driver/lib/widgets/driver_hub_sections.dart    ← Hub sections content
apps/driver/lib/widgets/driver_earnings_modal.dart  ← Rates + earnings card
apps/driver/lib/screens/driver_profile_screen.dart
apps/driver/lib/screens/driver_support_screen.dart
apps/driver/lib/screens/driver_help_articles_screen.dart
apps/driver/lib/services/driver_data_service.dart
apps/driver/lib/providers/driver_data_providers.dart
```

---

## SUPABASE BACKEND — WHAT ALREADY EXISTS

The backend is already built and live. Do not recreate anything that exists.

### Project: `fvrprxguoternoxnyhoj` (eu-west-1)

### Tables the driver app uses
| Table | Purpose | Key columns |
|-------|---------|-------------|
| `drivers` | Driver profile, status, rates, shift tracking | `status` enum (available/on_ride/offline/on_break), `shift_start_at`,  `last_break_start_at`, `continuous_driving_started_at`, `acceptance_rate`, `per_km_rate`, `per_min_rate`, `base_fare`, `minimum_fare` |
| `driver_locations` | GPS position upsert | PK = `user_id`, columns: `latitude`, `longitude` (NOT lat/lng) |
| `driver_rate_profiles` | Saved rate sets | `profile_name`, `base_fare`, `per_km_rate`, `per_min_rate`, `minimum_fare`, `waiting_rate`, `is_active`, `return_discount_pct` |
| `driver_earnings_targets` | Daily/weekly goals | `target_type` (daily/weekly), `target_amount` |
| `driver_safety_events` | Emergency/safety log | `event_type` (emergency_call/trip_share/audio_recording) |
| `driver_power_suggestions` | Power Mode AI cards | `card_type`, `title`, `subtitle`, `value_a/b/c`, `priority` |
| `driver_market_signals` | Anonymous Union Mode signals | NO driver_id — anonymous |
| `driver_trip_history` | Completed rides | `pickup_zone_id`, `destination_zone_id`, `completed_at` |
| `tickets` | Support — messages stored as JSONB array | `user_type` ('driver'), `user_id` (auth.uid() as text), `messages` (JSONB array), `status` (open/closed) |
| `community_posts` | Driver community | `channel` enum includes: general, announcements, swap |
| `ride_requests` | Active rides | `status`, `pickup_address`, `destination_address`, `offered_fare` |
| `bubble_zones` | Zone data | `name_display`, `center_lat`, `center_lng`, `radius_m` |

### Views already live
| View | Use it for |
|------|-----------|
| `zone_demand_live` | Map zone circles — `waiting_passengers`, `demand_level` |
| `scheduled_rides_available` | Scheduled rides list with decoded lat/lng |
| `driver_return_trips` | Return trip marketplace |
| `driver_passenger_comments` | Rider comments for driver score |
| `union_mode_dashboard` | Union Mode — market balance per zone |

### Functions already live (call via `supabase.rpc()`)
| Function | Arguments | Returns |
|----------|-----------|---------|
| `get_driver_earnings_summary` | `p_driver_id UUID` | today/week/month earnings + ride counts |
| `fn_switch_rate_profile` | `p_driver_id UUID, p_profile_id UUID` | `{success, profile_name}` |
| `fn_driver_has_overlap` | `p_driver_id UUID, p_proposed_start TIMESTAMPTZ, p_proposed_duration_min NUMERIC` | boolean |
| `fn_claim_swap_ride` | `p_post_id UUID, p_claiming_driver_id UUID` | `{success, error?}` |
| `fn_get_power_suggestions` | `p_driver_id UUID` | rows from driver_power_suggestions |
| `fn_dismiss_power_card` | `p_card_id UUID, p_driver_id UUID` | boolean |
| `fn_generate_power_cards` | `p_driver_id UUID` | auto-fires on online + ride complete |

### IMPORTANT: Support chat uses existing `tickets` table
The `tickets` table already has `messages JSONB` array. DO NOT create new `support_threads` or `support_messages` tables. Build the in-app chat UI reading from and writing to the existing `tickets` table.

Message format inside `tickets.messages`:
```json
[
  {
    "id": "uuid",
    "sender_type": "driver",
    "body": "message text",
    "created_at": "2026-03-18T10:00:00Z",
    "read_at": null
  }
]
```

---

## DESIGN SYSTEM — NON-NEGOTIABLE

Every widget you write must follow these rules. Zero exceptions.

```dart
// Colors — always from provider
final colors = ref.watch(colorsProvider);
final typo   = ref.watch(typographyProvider);

// NEVER hardcode these
// ❌ Color(0xFFE6A800)   ❌ Colors.white   ❌ Colors.black
// ✅ colors.accent       ✅ colors.card    ✅ colors.text

// Status colors (these are the only correct ones)
Online  → colors.success  (#10B981 green)
Break   → colors.warning  (#F59E0B amber)
Offline → colors.error    (#EF4444 red)

// Typography — always from provider
// ❌ TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
// ✅ typo.headingLarge.copyWith(color: colors.text)
```

### Spacing (memorise these — never deviate)
```
Screen horizontal padding: 16px
Between cards: 12px
Within cards: 14px
Between elements inside a card: 8px
```

### Components
```
Card:    white bg, 0.5px border (colors.border), 12px radius, shadow 6% black blur 8
Button:  52px height, 12px radius, full width, colors.accent background, white text
Sheet:   20px top radius, colors.surface background
```

### File size rule
**Maximum 300 lines per file.** If you approach 300, extract widgets immediately.

### Strings
Every user-facing string goes through `DriverStrings` or `AppLocalizations`. Zero hardcoded text.

---

## WORK TO DO — IN EXACT PRIORITY ORDER

Work through these in order. Do not jump ahead. Complete each section before starting the next.

---

### PRIORITY 0 — Navigation audit and repair (DO THIS FIRST)

This is the most important task. A dead tap on any screen = app store rejection.

**Step 1: Audit**
Read `router.dart`. List every registered route.
Then scan every file in `apps/driver/lib/` for:
- `context.go(`
- `context.push(`
- `onTap:`
- `GestureDetector(`
- `InkWell(`
- `ListTile(` with `onTap`
- `TextButton(`, `FilledButton(`, `OutlinedButton(`
- Any text styled to look like a link

For each one, verify the target route exists in `router.dart`.

**Step 2: Fix every broken tap**
If a route is missing, create a minimal premium screen for it.
If an `onTap` is `null` or `() {}`, implement it properly.
Never leave a tappable element that does nothing.

**The only allowed no-op taps:**
- A button that is intentionally disabled (must show `opacity: 0.45` and a tooltip explaining why)

**Result:** Output a navigation audit table in your final report.

---

### PRIORITY 1 — Three-state toggle refinements

The toggle exists. Make it Apple-quality.

**Labels:** All three labels (Offline / Break / Online) must be visible below the track at all times. The active label is 13px medium `colors.text`. The other two are 13px regular `colors.textSoft`. Labels never get covered by the thumb.

**Haptics:**
```dart
Online snap:  HapticFeedback.heavyImpact() + SoundService().playNotification()
Break snap:   HapticFeedback.mediumImpact()
Offline snap: HapticFeedback.lightImpact()
```

**Timestamp on status pill:** The floating earnings pill at the top of the map shows:
- "€24.50 · Online · since 14:32" when online
- "On break · since 15:10" when on break
- "€0.00 · Offline" when offline

Timestamp source: `drivers.shift_start_at` (online), `drivers.last_break_start_at` (break). Format: HH:mm only.

**End shift confirmation:** When the driver drags to Offline AND has been online for more than 30 minutes, show a confirmation dialog before proceeding:

```
Title:   "Dienst beëindigen?"
Body:    "Je hebt X uur Y minuten gereden en Z ritten voltooid vandaag."
Buttons: "Annuleren" (ghost) | "Dienst beëindigen" (black, NOT gold)
```

If online less than 30 minutes, go offline immediately with no dialog.

**Status color enforcement:**
```
Online → green background on status indicators (colors.success)
Break  → amber background (colors.warning)
Offline → red dot (colors.error)
```

---

### PRIORITY 1 — Earnings modal — wire to real data

The earnings modal (`driver_earnings_modal.dart`) has placeholder rate chips. Wire everything to Supabase.

**Rate profiles:**
```dart
// Query driver_rate_profiles for current driver
final profiles = await supabase
  .from('driver_rate_profiles')
  .select()
  .eq('driver_id', driverId)
  .order('sort_order');

// Each profile becomes a chip
// Active chip (is_active = true): gold filled
// Others: white with gold border
```

**If no profiles exist**, auto-create one from the driver's existing rates:
```dart
// Check first — never create duplicates
final existing = await supabase
  .from('driver_rate_profiles')
  .select('id')
  .eq('driver_id', driverId)
  .maybeSingle();

if (existing == null) {
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

**On chip tap:** Call `fn_switch_rate_profile(driverId, profileId)`. Then refresh.

**Active rates line:** Below chips show: "€2.00/km · €0.35/min · €2.50 start" from active profile.

**Dutch break law banner:** If `continuous_driving_started_at` is more than 255 minutes ago:
- 255–269 min: amber banner "Pauze aanbevolen over X minuten"
- 270+ min: red banner "Wettelijke pauze vereist nu"

**Earnings data:** Call `get_driver_earnings_summary(driverId)`. Display today's earnings, ride count, shift minutes.

---

### PRIORITY 1 — Driver Hub modal — all four sections complete

The hub (`driver_hub_sheet.dart`) must have four working sections. Each section is separated by a 1px `colors.border` divider.

**Section 1 — Earnings target:**
- Donut chart (`fl_chart` PieChart): gold segment = earned, grey = remaining to target
- Centre text: "€X.XX" 22px bold + "van €Y doel" 12px `colors.textSoft`
- Two chips: "Dagelijks" / "Wekelijks" — selected has 2px gold underline
- "Doel instellen →" gold text link → opens small input sheet → upsert to `driver_earnings_targets`:
```dart
await supabase.from('driver_earnings_targets').upsert({
  'driver_id': driverId,
  'target_type': selectedPeriod, // 'daily' or 'weekly'
  'target_amount': amount,
}, onConflict: 'driver_id,target_type');
```

**Section 2 — Rate profile switcher:**
Same chips as earnings modal. Extract into a shared `_RateProfileChips` widget used in both places. Do not duplicate logic.

**Section 3 — Safety toolkit:**

Row 1 — Emergency call (ALWAYS tappable, red):
```dart
// Red alert icon, red text, always active
onTap: () async {
  await launchUrl(Uri.parse('tel:112'));  // Only allowed external call
  await supabase.from('driver_safety_events').insert({
    'driver_id': driverId,
    'event_type': 'emergency_call',
    'ride_request_id': activeRideId, // null if no active ride
  });
}
```

Row 2 — Share trip details (active during rides only):
- If no active ride: subtitle "Beschikbaar tijdens actieve ritten", row opacity 0.45, onTap = null
- If active ride: generate `ride_shares` link, call `Share.share(url)` from `share_plus`

Row 3 — Audio recording (active during rides only):
- Same conditional pattern as Row 2
- Start/stop `AudioRecorder` from `record` package
- Store locally in app documents directory
- Show red pulsing dot while recording
- On stop: insert to `driver_safety_events` with `event_type = 'audio_recording'`

**Section 4 — Help & support:**

Show last 3 tickets from `tickets` where `user_type = 'driver'` and `user_id = auth.uid()`:
```dart
final tickets = await supabase
  .from('tickets')
  .select('id, status, messages, created_at, ride_request_id')
  .eq('user_type', 'driver')
  .eq('user_id', supabase.auth.currentUser!.id)
  .order('created_at', ascending: false)
  .limit(3);
```

Each row: date + zone name (from ride_request_id if available) + status label.
Status label: open + no driver reply → "U heeft niet gereageerd" in `colors.error`.
Status label: open + driver replied → "In behandeling" in `colors.warning`.
Status label: resolved → "Opgelost" in `colors.success`.

Three contact rows:
1. "Nieuw bericht sturen" → navigate to `/driver/support/new`
2. "Berichten" → navigate to `/driver/support`
3. "Help artikelen" → navigate to `/driver/faq`

**Bottom of hub — two navigation rows:**

Driver Power Mode:
- Gold bolt icon, "Driver Power Mode", "AI-suggesties om meer te verdienen"
- Navigate to `/driver/power-mode`

Driver Union Mode:
- Group icon, "Driver Union Mode", "Live marktintelligentie"
- Navigate to `/driver/union-mode`

---

### PRIORITY 2 — Support chat (in-app, chat-only, uses existing `tickets` table)

**Important:** Do NOT create new tables. Use the existing `tickets` table. Messages live in `tickets.messages` as a JSONB array.

**Screens to build:**

**Screen 1: `/driver/support`** — Support home
- Title: "Ondersteuning"
- Section "Recente ritten met problemen": last 3 tickets with status labels (same as Hub Section 4)
- "Alles zien →" tappable — shows full ticket list
- Section "Contact": three rows:
  1. "Nieuw bericht" → push to `/driver/support/new`
  2. "Berichten" → push to `/driver/support/threads`
  3. "Help artikelen" → push to `/driver/faq`

**Screen 2: `/driver/support/threads`** — Ticket list
- Lists all driver's tickets ordered by `updated_at DESC`
- Each row: category, last message preview (from `messages` array last item), timestamp, status badge
- Tap a row → push to `/driver/support/chat/:ticketId`

**Screen 3: `/driver/support/new`** — New ticket
- Category selector (chips): "Rit probleem", "Betaling", "Account", "Overige"
- Optional ride selector: dropdown from recent completed rides
- Message input field (multiline, max 500 chars)
- "Versturen" gold button → insert to `tickets`:
```dart
await supabase.from('tickets').insert({
  'user_type': 'driver',
  'user_id': supabase.auth.currentUser!.id,
  'category': selectedCategory,
  'ride_request_id': selectedRideId, // optional
  'messages': [{
    'id': uuid.v4(),
    'sender_type': 'driver',
    'body': messageText,
    'created_at': DateTime.now().toIso8601String(),
    'read_at': null,
  }],
});
```
After insert → navigate to `/driver/support/chat/:newTicketId`

**Screen 4: `/driver/support/chat/:ticketId`** — Chat thread
- Back arrow + ticket category as title
- Status badge (open/resolved) in top right
- Message list: driver messages right-aligned (gold bubble), support messages left-aligned (grey bubble)
- Each message: body text + timestamp (HH:mm format)
- If ticket is open: text input + send button at bottom
- On send: append to `tickets.messages` JSONB array:
```dart
// Read current messages, append new one, update
final ticket = await supabase
  .from('tickets')
  .select('messages')
  .eq('id', ticketId)
  .single();

final messages = List<Map>.from(ticket['messages'] ?? []);
messages.add({
  'id': uuid.v4(),
  'sender_type': 'driver',
  'body': newMessage,
  'created_at': DateTime.now().toIso8601String(),
  'read_at': null,
});

await supabase.from('tickets').update({
  'messages': messages,
  'updated_at': DateTime.now().toIso8601String(),
}).eq('id', ticketId);
```
- Use `flutter_animate` for message bubble entrance animation
- Auto-scroll to bottom on new message
- Realtime subscription on this ticket for support replies

---

### PRIORITY 2 — Driver profile screen

The profile screen (`driver_profile_screen.dart`) must show and allow editing of real driver data from the `drivers` table.

**Profile header:**
- Circular photo (64px) from `drivers.profile_photo_url` — tap to replace (image_picker from gallery, upload to Supabase storage)
- Full name from `drivers.full_name`
- Vehicle: `drivers.vehicle_make` + `drivers.vehicle_model` + `drivers.vehicle_year`
- Star rating: `drivers.avg_rating` displayed as stars + number

**Settings rows (all with chevrons, all navigating somewhere):**

| Row | Icon | Action |
|-----|------|--------|
| Mijn voertuig | car | Navigate to vehicle edit screen `/driver/profile/vehicle` |
| Documenten | description | Navigate to `/driver/profile/documents` |
| Tarieven | price_change | Navigate to rate profiles screen `/driver/profile/rates` |
| Werkgebied | map | Navigate to `/driver/profile/service-area` |
| Taal | language | Language picker dialog |
| Thema | palette | Theme picker (from existing theme system) |
| Meldingen | notifications | Notifications settings |
| Privacy beleid | lock | Navigate to `/driver/privacy` |
| Gebruiksvoorwaarden | gavel | Navigate to `/driver/terms` |
| Veelgestelde vragen | help | Navigate to `/driver/faq` |
| Ondersteuning | headset_mic | Navigate to `/driver/support` |
| Uitloggen | logout | Confirmation dialog → `supabase.auth.signOut()` → navigate to login |

**Documents row:** Show a small amber dot if any compliance document expires within 30 days. Red dot if already expired. Read from: `drivers.chauffeurspas_expiry`, `drivers.rijbewijs_expiry`, `drivers.vog_expires_at`, `drivers.taxi_insurance_expiry`.

---

### PRIORITY 3 — FAQ screen

**Route:** `/driver/faq`
**Access from:** Profile screen, Support screen, Help articles screen

Build a native accordion-style FAQ. No WebView. No external links. Pure Flutter.

Use `ExpansionTile` for each question. Group into sections.

**Questions to include:**

Section: Aan de slag
- Hoe ga ik online? — Explanation of the three-state toggle
- Hoe stel ik mijn tarieven in? — Explains rate profiles
- Hoe ontvang ik ritaanvragen? — Explains ride requests and notifications

Section: Ritten en verdiensten
- Hoe berekent HeyCaby mijn verdiensten? — Base fare + per km + per min
- Wanneer krijg ik betaald? — Direct payment from passengers (cash/pin/tikkie)
- Wat zijn retourritten? — Explains the return trip marketplace
- Hoe werkt de Marktplaats? — Explains marketplace bidding

Section: Pauzes en diensten
- Hoe lang mag ik rijden zonder pauze? — Dutch law: 4.5 hours max, 30 min break required
- Hoe neem ik pauze? — Swipe toggle to Break
- Hoe beëindig ik mijn dienst? — Swipe to Offline, confirmation dialog

Section: Veiligheid
- Wat is de veiligheidskit? — Emergency call, trip sharing, audio recording
- Hoe gebruik ik audio-opname? — Only during active rides, stored locally

Section: Documenten en compliance
- Welke documenten heb ik nodig? — Chauffeurspas, rijbewijs, VOG, taxidiploma, verzekering
- Hoe verlenging ik mijn documenten? — Contact RDW / municipality
- Wat als mijn chauffeurspas verloopt? — Account suspended, contact support

Section: Ondersteuning
- Hoe neem ik contact op met support? — In-app chat via Ondersteuning tab
- Kan ik bellen met support? — Nee, alleen chat
- Hoe lang duurt het voor ik antwoord krijg? — Typically within 24 hours

---

### PRIORITY 3 — Terms of Service and Privacy Policy screens

**Routes:** `/driver/terms` and `/driver/privacy`

Both are native Flutter screens — no WebView, no external URL.

Structure: `Scaffold` + `SingleChildScrollView` + `Padding` + `Text` blocks.

**Terms of Service** (`/driver/terms`):
Include standard taxi driver platform terms covering:
- Service agreement between driver and HeyCaby platform
- Driver responsibilities (valid documents, vehicle condition, passenger safety)
- Payment terms (0% commission, direct passenger payment)
- Account suspension conditions
- Dispute resolution
- Governing law (Netherlands)
- Contact: via in-app support

**Privacy Policy** (`/driver/privacy`):
Include GDPR-compliant privacy policy covering:
- Data collected (location, trip history, documents)
- How location data is used (only when online)
- Data retention periods
- Driver rights (access, deletion, correction)
- No sale of personal data to third parties
- Contact for privacy requests: via in-app support

Both screens must link to nothing external. Support contact navigates to `/driver/support`.

---

### PRIORITY 3 — Today's rides detail screen

**Route:** `/driver/rides/today`
**Access from:** "Today's rides" card tap on home screen

Show today's completed rides from `driver_trip_history`.

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
  .gte('completed_at', DateTime.now().toLocal().toString().substring(0,10))
  .order('completed_at', ascending: false);
```

Each row displays: "Zone A → Zone B · €18.50 · 14:23"

**NEVER show full addresses** — zone names only. This is both a privacy rule and cleaner UX.

---

### PRIORITY 3 — Return trips screen

**Route:** `/driver/return-marketplace`
**Access from:** "Retourritten" card tap on home screen

Query `driver_return_trips` view. Filter in Dart to rides heading toward `drivers.heading_home_zone_id` or matching driver's home city.

Each card:
- Pickup zone → destination zone (gold dot → dark dot with connector line)
- Offered fare in bold gold on the right
- Distance + estimated duration
- "Accepteer" gold button (52px, full card width)

Subscribe to Realtime on the channel `return_market` for live updates.

---

### PRIORITY 3 — Scheduled rides screen

**Route:** `/driver/scheduled`
**Access from:** "Gepland" tab on Work screen, "Geplande ritten" card tap

Use `scheduled_rides_available` view. Filter with `fn_driver_has_overlap` before showing count and cards.

Each card:
- Fare + pickup time as headline: "€42.00 · Vandaag om 09:45"
- Distance: "17.3 km"
- Pickup zone → destination zone
- Mini map thumbnail using Mapbox Static Images URL:
```
https://api.mapbox.com/styles/v1/mapbox/navigation-day-v1/static/{lng},{lat},13,0/320x120@2x?access_token={token}
```
Use `cached_network_image` for this.
- "Accepteer" button

Two tabs: "Aanvragen" (pending) and "Bevestigd" (accepted by this driver)

---

### PRIORITY 4 — Power Mode screen

**Route:** `/driver/power-mode`
**Access from:** Driver Hub bottom row

Query: `supabase.rpc('fn_get_power_suggestions', params: {'p_driver_id': driverId})`

Realtime channel: subscribe to `driver_power_suggestions` for this driver.

**Six card types — build as separate widget classes:**

`HighDemandCard` — gold header bar, zone name, passenger count badge, "Navigeer" button
`PriceSuggestionCard` — current vs recommended rate, "Toepassen" + "Negeren" buttons
`ReturnTripCard` — links to `/driver/return-marketplace`
`SurgeOpportunityCard` — amber header, event/venue, surge %, "Ga erheen"
`IdleWarningCard` — grey, idle minutes, "Drukke zones bekijken" button → opens zone map
`GoalTrackerCard` — mini donut chart (same component as Hub), earned vs target

**Dismiss button (X):** top-right of every card. Calls:
```dart
await supabase.rpc('fn_dismiss_power_card', params: {
  'p_card_id': cardId,
  'p_driver_id': driverId,
});
```

**Empty state:** centred icon + "Alles ziet er goed uit 👍 We laten je weten als er kansen zijn."

---

### PRIORITY 4 — Union Mode screen

**Route:** `/driver/union-mode`
**Access from:** Driver Hub bottom row

Query: `SELECT * FROM union_mode_dashboard` — one row per active zone.

Realtime: subscribe to `driver_market_signals` for live signal feed.

**Five sections as cards:**

1. **Marktbalans** — Three pills: Passagiers / Chauffeurs / Balans (green=high_demand, grey=balanced, red=saturated)

2. **Gemiddelde ritprijs** — Top 5 zones by `avg_offered_fare`. Table: zone name | avg fare. Your active rate highlighted if it matches.

3. **Zone bezetting** — Horizontal scrollable zone chips. Color per `market_balance`. Tap chip → jump to that zone on map.

4. **Collectief surge signaal** — If a zone has `market_balance = 'high_demand'` AND fare below market average by >15%, show: "Zone X heeft hoge vraag — overweeg €{rate}/km"

5. **Chauffeurssignalen** — List of `driver_market_signals` by `upvotes DESC`. Each row: signal type icon, zone name, description, upvote button.

**Post signal FAB (bottom right):** Opens a sheet with zone selector, signal type chips, optional description (max 80 chars). Duplicate check before inserting:
```dart
final recent = await supabase.from('driver_market_signals')
  .select('id, upvotes')
  .eq('zone_id', zoneId)
  .eq('signal_type', signalType)
  .gte('created_at',
    DateTime.now().subtract(const Duration(hours: 1)).toIso8601String())
  .maybeSingle();

if (recent != null) {
  // Upvote existing instead of creating duplicate
  await supabase.from('driver_market_signals')
    .update({'upvotes': (recent['upvotes'] as int) + 1})
    .eq('id', recent['id']);
} else {
  await supabase.from('driver_market_signals').insert({
    'zone_id': zoneId,
    'signal_type': signalType,
    'description': description.isEmpty ? null : description,
    // NO driver_id — anonymous by design
  });
}
```

---

## SUPABASE CHANGES — SAFE SQL ONLY

Before running any SQL, check if it already exists. Use these patterns:

```sql
-- Safe column add
ALTER TABLE public.table_name
  ADD COLUMN IF NOT EXISTS col_name TEXT;

-- Safe table create
CREATE TABLE IF NOT EXISTS public.table_name (...);

-- Safe index
CREATE INDEX IF NOT EXISTS idx_name ON public.table(col);

-- Safe enum value
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'value'
    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'enum_name')
  ) THEN ALTER TYPE enum_name ADD VALUE 'value'; END IF;
END$$;
```

**NEVER:** DROP TABLE, TRUNCATE, DELETE FROM, DROP COLUMN, ALTER COLUMN TYPE.

---

## DEFINITION OF DONE — ALL MUST PASS

Before writing your final report, verify every item:

**Code quality:**
- [ ] `flutter analyze` reports zero errors and zero new warnings
- [ ] No file exceeds 300 lines
- [ ] No hardcoded colors, no hardcoded strings, no hardcoded fonts
- [ ] Zero `// TODO` comments left uncommitted

**Navigation:**
- [ ] Every `context.go()` and `context.push()` target exists in `router.dart`
- [ ] Every `onTap:` either navigates somewhere real or performs a real action
- [ ] Zero `onTap: () {}` (empty callbacks)
- [ ] Zero `onTap: null` on visually-active elements

**External links:**
- [ ] Zero `launchUrl` calls except `tel:112`
- [ ] Zero WebViews
- [ ] Zero `mailto:` links
- [ ] Zero `https://` opened externally

**Status colors:**
- [ ] Online indicators: `colors.success` (green) everywhere
- [ ] Break indicators: `colors.warning` (amber) everywhere
- [ ] Offline indicators: `colors.error` (red) everywhere

**Supabase:**
- [ ] All new SQL is idempotent (safe to run twice)
- [ ] All new tables have RLS enabled
- [ ] All new RLS policies use the correct driver auth pattern

**Core flows testable:**
- [ ] Login → home screen loads
- [ ] Toggle offline → break → online and back (with haptics, correct colors)
- [ ] Earnings pill tap → modal opens with real rate chips
- [ ] Driver Hub tap → all four sections render with real data
- [ ] Support → new ticket → chat thread works end-to-end
- [ ] Profile screen → all rows navigate somewhere
- [ ] FAQ → all questions expand/collapse
- [ ] Power Mode → cards render, dismiss works
- [ ] Union Mode → market data renders, signal post works

---

## FINAL REPORT FORMAT

Output a markdown report with exactly these sections when done:

### Summary
3–8 bullets: what changed and why

### Done Checklist
All items from Definition of Done: ✅ or ❌ with one-line note

### Navigation Audit Table
| Entry point | Tap target | Route/action | Was broken? | Status |

### External Link Audit
| Was | Replaced with |

### Supabase SQL Bundle
All SQL applied, each block with: what it does, why, compatibility note

### Support Chat Implementation
Screens added, data model used, what remains

### Profile Screen
Fields displayed, fields editable, missing data if any

### FAQ
Route, sections, question count

### Terms + Privacy
Routes, content coverage

### Test Plan (Manual)
Step-by-step test of every core flow for the owner to run on return

### Open Questions / Blockers
Anything that needed a decision you could not make, or that is partially done

---

## PROGRESS UPDATES

Post a progress update every 15–20 minutes in this format:
```
⏱ [TIME] Progress update
✅ Completed: [what]
🔄 Working on: [what]
⚠️ Blocker: [if any]
📍 Next: [what]
```

---

## GO. THE OWNER IS AT THE GYM.