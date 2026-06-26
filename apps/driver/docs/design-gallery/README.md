# HeyCaby Driver — Design Gallery

Visual portfolio of the redesign. Updated at the **end of each phase**.

## Structure

```
design-gallery/
  phase-1-baseline/     # Pre-redesign goldens (Phase 1.9)
  phase-2-premium/      # Login + Home + map chrome (Phase 2 frozen)
  phase-3-ride/         # Core Ride Flow (Phase 3 frozen)
  phase-4-money/        # Money & Earnings (Phase 4 frozen)
  phase-5-profile/      # Settings & Profile (Phase 5 frozen)
  phase-6-support/      # Support & Help (Phase 6 frozen)
  phase-7-ledger/       # Trip Ledger (Phase 7 frozen)
  phase-8-performance/  # Demand & Performance (Phase 8 frozen)
  phase-9-trust/        # Trust & Feedback (Phase 9 frozen)
  phase-10-community/   # Community & Support (Phase 10 frozen)
  phase-11-planning/    # Trip Planning (Phase 11 frozen)
  phase-12-work-growth/ # Work & Growth (Phase 12 frozen)
  phase-13-entry-gates/ # Entry & Gates (Phase 13 frozen)
  phase-14-active-hub/  # Active Hub (Phase 14 frozen)
  phase-15-overlays/    # Community Overlays (Phase 15 frozen)
  ...
```

## Generate from goldens

```bash
PHASE=phase-2-premium ./scripts/driver_visual_regression.sh gallery
```

## Phase 15 captures (Community Overlays — frozen)

| File | Purpose | Surface |
|------|---------|---------|
| `community_notifications_light.png` | Notifications | Community hub sheet |
| `community_search_light.png` | Search | Community hub sheet |
| `community_disclaimer_light.png` | Disclaimer | Community welcome dialog |
| `community_create_post_light.png` | Create Post | New post sheet |
| `staging_surface_light.png` | Staging Surface | `placeholder_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-15-overlays ./scripts/driver_visual_regression.sh gallery
```

## Phase 14 captures (Active Hub — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `brand_moment_light.png` | Brand Moment | `splash_screen.dart` |
| `shift_command_light.png` | Shift Command | `work_screen.dart` |
| `rider_conversation_light.png` | Rider Conversation | `driver_chat_screen.dart` |
| `me_community_light.png` | Community Feed | `me_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-14-active-hub ./scripts/driver_visual_regression.sh gallery
```

## Phase 13 captures (Entry & Gates — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `onboarding_gate_light.png` | Onboarding Gate | `register_screen.dart` |
| `knowledge_base_light.png` | Knowledge Base | `driver_help_articles_screen.dart` |
| `readiness_gate_light.png` | Readiness Gate | `driver_runtime_gate_screen.dart` |
| `update_gate_light.png` | Update Gate | `driver_ios_update_required_app.dart` |

Copy to gallery:

```bash
PHASE=phase-13-entry-gates ./scripts/driver_visual_regression.sh gallery
```

## Phase 12 captures (Work & Growth — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `ride_swap_light.png` | Ride Swap | `ride_swap_screen.dart` |
| `go_live_light.png` | Go Live | `go_online_screen.dart` |
| `referral_share_light.png` | Referral Share | `driver_tell_friend_screen.dart` |
| `app_suggestion_light.png` | App Suggestion | `driver_app_suggestion_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-12-work-growth ./scripts/driver_visual_regression.sh gallery
```

## Phase 11 captures (Trip Planning — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `manual_ride_entry_light.png` | Manual Ride Entry | `driver_add_manual_ride_screen.dart` |
| `return_trips_light.png` | Return Trips | `driver_return_trips_screen.dart` |
| `scheduled_rides_light.png` | Scheduled Rides | `scheduled_rides_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-11-planning ./scripts/driver_visual_regression.sh gallery
```

## Phase 10 captures (Community & Support — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `community_hub_light.png` | Community Hub | `driver_community_hub_screen.dart` |
| `community_channel_light.png` | Community Channel | `driver_community_channel_feed_screen.dart` |
| `support_conversation_light.png` | Support Conversation | `support_chat_screen.dart` |
| `liability_ack_light.png` | Liability Acknowledgment | `driver_indemnification_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-10-community ./scripts/driver_visual_regression.sh gallery
```

## Phase 9 captures (Trust & Feedback — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `feedback_loop_light.png` | Feedback Loop | `rate_rider_screen.dart` |
| `legal_trust_light.png` | Terms Trust | `driver_terms_screen.dart` |
| `privacy_trust_light.png` | Privacy Trust | `driver_privacy_screen.dart` |
| `ai_support_chat_light.png` | AI Support Chat | `support_lee_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-9-trust ./scripts/driver_visual_regression.sh gallery
```

## Phase 8 captures (Demand & Performance — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `performance_scorecard_light.png` | Performance Scorecard | `driver_score_screen.dart` |
| `rate_control_light.png` | Rate Control | `driver_tariff_editor_screen.dart` |
| `demand_radar_light.png` | Demand Radar | `driver_hotspots_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-8-performance ./scripts/driver_visual_regression.sh gallery
```

## Phase 7 captures (Trip Ledger — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `todays_ledger_light.png` | Today's Ledger | `today_rides_screen.dart` |
| `ride_history_light.png` | Ride History | `driver_my_rides_screen.dart` |
| `trip_receipt_light.png` | Trip Receipt | `driver_ride_detail_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-7-ledger ./scripts/driver_visual_regression.sh gallery
```

## Phase 6 captures (Support & Help — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `help_hub_light.png` | Help Hub | `driver_support_screen.dart` |
| `quick_answers_light.png` | Quick Answers | `driver_faq_screen.dart` |
| `support_inbox_light.png` | Support Inbox | `support_threads_screen.dart` |
| `raise_issue_light.png` | Raise Issue | `support_new_ticket_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-6-support ./scripts/driver_visual_regression.sh gallery
```

## Phase 5 captures (Settings & Profile — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `driver_identity_light.png` | Driver Identity | `driver_profile_screen.dart` |
| `preferences_light.png` | Preferences | `driver_preferences_screen.dart` |
| `vehicle_profile_light.png` | Vehicle Profile | `vehicle_edit_screen.dart` |
| `veriff_trust_light.png` | Identity Verification | `driver_veriff_screen.dart` |
| `compliance_vault_light.png` | Compliance Vault | `driver_documents_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-5-profile ./scripts/driver_visual_regression.sh gallery
```

## Phase 4 captures (Money & Earnings — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `earnings_hub_light.png` | Earnings Hub | `driver_finance_screen.dart` |
| `subscription_gate_light.png` | Subscription Gate | `driver_billing_screen.dart` |
| `payment_history_light.png` | Payment History | `driver_billing_history_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-4-money ./scripts/driver_visual_regression.sh gallery
```

## Phase 3 captures (Core Ride Flow — frozen)

| File | Purpose | Screen |
|------|---------|--------|
| `ride_request_light.png` | Opportunity Screen | `new_ride_request_screen.dart` |
| `active_trip_light.png` | Active Trip | `active_ride_screen.dart` |
| `pickup_arrival_light.png` | Pickup Arrival | `at_pickup_screen.dart` |
| `navigation_focus_light.png` | Navigation Focus | `ride_in_progress_screen.dart` |
| `reward_screen_light.png` | Reward Screen | `ride_complete_screen.dart` |

Copy to gallery:

```bash
PHASE=phase-3-ride ./scripts/driver_visual_regression.sh gallery
```

## Phase 2 captures (frozen)

| File | Purpose | Milestone |
|------|---------|-----------|
| `login_email_light.png` | Trust Screen | M1 |
| `home_light.png` | Money Dashboard (offline sheet) | M2 |
| `home_map_online_light.png` | Map chrome (online) | M3 |
| `ride_request_light.png` | Opportunity Screen | M3 / Phase 3 |
| `components_light.png` | Design system gallery | 1.9 |

See [`PHASE_2_PATTERN_INDEX.md`](../PHASE_2_PATTERN_INDEX.md) for component mapping.

## Planned captures (future phases)

| File | Purpose | Phase |
|------|---------|-------|
| Support hub | Help & tickets | 6+ |

Manual device screenshots may supplement goldens for map-heavy surfaces.
