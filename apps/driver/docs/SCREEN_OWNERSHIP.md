# Screen Ownership — HeyCaby Driver

**Status:** Frozen — final design-system rule before Phase 2.

Every screen has a **purpose**, not just a filename. Name the job the screen does for the driver. Design decisions follow from purpose.

## How to use

Before redesigning any file in `lib/screens/`:

1. Find its **Purpose name** in the table below.
2. Ask: *Does every pixel serve that purpose?*
3. Record the purpose in the PR: `Screen: Trust Screen (login_screen.dart)`.

```dart
/// **Trust Screen** — make drivers trust HeyCaby within 5 seconds.
class LoginScreen extends ...
```

---

## Phase 2 gold standard

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `login_screen.dart` | **Trust Screen** | Make drivers trust HeyCaby within 5 seconds |
| `driver_home_screen.dart` | **Money Dashboard** | One glance: map, online state, today's earnings, next action |

If Login + Home nail their purpose, the design system is proven.

---

## Full registry

### Entry & trust

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `splash_screen.dart` | **Brand Moment** | Confirm this is HeyCaby; zero friction to next step |
| `login_screen.dart` | **Trust Screen** | Trust HeyCaby within 5 seconds; start earning |
| `register_screen.dart` | **Onboarding Gate** | Join as a driver with confidence |
| `driver_runtime_gate_screen.dart` | **Readiness Gate** | Show what's blocking go-live; one path forward |
| `driver_ios_update_required_app.dart` | **Update Gate** | Explain why iOS must update; no dead end |

### Money dashboard & map (Phase 2 focus)

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `driver_home_screen.dart` | **Money Dashboard** | Map hero + online + earnings + progress at a glance |
| `go_online_screen.dart` | **Go-Live Moment** | Clear checklist before first trip |
| `work_screen.dart` | **Shift Command** | Control active shift without leaving the map mental model |

### Ride flow

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `new_ride_request_screen.dart` | **Opportunity Screen** | Accept or decline in &lt; 1 second |
| `active_ride_screen.dart` | **Active Trip** | Navigate to pickup; rider + ETA obvious |
| `at_pickup_screen.dart` | **Pickup Arrival** | Confirm arrival; start trip friction-free |
| `ride_in_progress_screen.dart` | **Navigation Focus** | Driving-first; minimal distraction |
| `ride_complete_screen.dart` | **Reward Screen** | Celebrate earnings; clear next step |
| `rate_rider_screen.dart` | **Feedback Loop** | Quick rating; back to earning |
| `ride_swap_screen.dart` | **Transfer Hub** | Hand off or pick up a swap safely |
| `scheduled_rides_screen.dart` | **Future Rides** | Upcoming commitments at a glance |
| `today_rides_screen.dart` | **Today's Ledger** | Today's trips and totals |
| `driver_my_rides_screen.dart` | **Ride History** | Past trips searchable and scannable |
| `driver_ride_detail_screen.dart` | **Trip Receipt** | One ride, full detail |
| `driver_add_manual_ride_screen.dart` | **Manual Entry** | Log off-app trip without confusion |
| `driver_return_trips_screen.dart` | **Return Trips** | Find rides heading your way |

### Earnings & billing

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `driver_finance_screen.dart` | **Earnings Hub** | Understand money in &lt; 2 seconds |
| `driver_billing_screen.dart` | **Subscription Gate** | Platform fee clear; pay and continue |
| `driver_billing_history_screen.dart` | **Payment History** | Past charges transparent |

### Demand & performance

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `driver_hotspots_screen.dart` | **Demand Radar** | Where to drive for more rides |
| `driver_score_screen.dart` | **Performance Scorecard** | Score motivates improvement, not anxiety |
| `driver_tariff_editor_screen.dart` | **Rate Control** | Set fares confidently |

### Profile & compliance

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `driver_profile_screen.dart` | **Driver Identity** | Public-facing driver brand |
| `me_screen.dart` | **Account Hub** | Settings entry; who am I |
| `driver_preferences_screen.dart` | **Preferences** | App behavior, not business rules |
| `driver_documents_screen.dart` | **Compliance Vault** | Documents status always clear |
| `driver_veriff_screen.dart` | **Identity Verification** | Verify once; trust forever |
| `vehicle_edit_screen.dart` | **Vehicle Profile** | Car details accurate for riders |

### Legal & trust (documents)

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `driver_terms_screen.dart` | **Terms Trust** | Legal clarity without intimidation |
| `driver_privacy_screen.dart` | **Privacy Trust** | Data use explained plainly |
| `driver_indemnification_screen.dart` | **Liability Acknowledgment** | Serious content, calm presentation |

### Support & community

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `driver_support_screen.dart` | **Help Hub** | Find help in one tap |
| `driver_faq_screen.dart` | **Quick Answers** | FAQ scannable while parked |
| `driver_help_articles_screen.dart` | **Knowledge Base** | Deep help when needed |
| `support_threads_screen.dart` | **Support Inbox** | Open tickets visible |
| `support_new_ticket_screen.dart` | **Raise Issue** | Report problem fast |
| `support_chat_screen.dart` | **Support Conversation** | Human help, driving-safe layout |
| `support_lee_screen.dart` | **AI Support** | Instant answers; escalate when stuck |
| `driver_chat_screen.dart` | **Rider Conversation** | Message rider without distraction |
| `driver_community_hub_screen.dart` | **Driver Community** | Peers, news, belonging |
| `driver_community_channel_feed_screen.dart` | **Community Channel** | One topic, focused feed |
| `driver_tell_friend_screen.dart` | **Referral Growth** | Invite drivers; reward clear |
| `driver_app_suggestion_screen.dart` | **Product Feedback** | Voice heard; low effort |

### Internal / staging

| File | Purpose name | Job of the screen |
|------|--------------|-------------------|
| `placeholder_screen.dart` | **Staging Surface** | Dev-only; not shipped |

---

## Purpose → design questions

| Purpose type | Ask before shipping |
|--------------|---------------------|
| **Trust** | Would a new driver feel safe entering payment/identity data? |
| **Money Dashboard** | Can they see map + online + earnings without reading? |
| **Opportunity** | Can they accept/decline one-handed in &lt; 1 s? |
| **Reward** | Do they feel the trip was worth it? |
| **Earnings Hub** | Is today's number the hero? |

---

## Related

- Phase 2 milestones: [`PREMIUM_EXPERIENCE_PROOF.md`](./PREMIUM_EXPERIENCE_PROOF.md)
- Current home status-control redesign: [`STATUS_CONTROL_REDESIGN_HANDOFF.md`](./STATUS_CONTROL_REDESIGN_HANDOFF.md)
- TTU targets: [`DESIGN_SCORE.md`](./DESIGN_SCORE.md#time-to-understand-ttu)
- PR checklist: [`DESIGN_GUARDRAILS.md`](./DESIGN_GUARDRAILS.md)

*Frozen. Do not add methodology docs after Phase 2 begins — iterate UI, not process.*
