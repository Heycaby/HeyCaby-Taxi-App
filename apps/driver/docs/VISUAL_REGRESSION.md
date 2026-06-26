# Phase 1.9 — Visual Regression Protection

**Purpose:** UI smoke tests — catch accidental layout regressions during redesign.  
**Not** a blocker on intentional visual change; **is** a blocker on unintentional breakage.

## Workflow

```
Current screen  →  Golden PNG (baseline)
       ↓
Redesigned screen  →  flutter test  →  Pixel diff
       ↓
Human review  →  Accept (update baseline) or Fix
```

## Commands

From repo root:

```bash
# Freeze baseline (after review)
./scripts/driver_visual_regression.sh baseline

# CI / pre-merge compare
./scripts/driver_visual_regression.sh compare

# Publish to portfolio gallery
PHASE=phase-2-premium ./scripts/driver_visual_regression.sh gallery
```

## What we test today

| Golden | Surface | Status |
|--------|---------|--------|
| `login_email_light.png` | Login (email step) | Baseline |
| `components_light.png` | Design system gallery | Baseline |
| `home_light.png` | Money Dashboard (map chrome + sheet) | Baseline |
| `home_map_online_light.png` | Map experience — online chrome + demand + shift shell | Baseline |
| `ride_request_light.png` | Opportunity Screen (Phase 3) | Baseline |
| `active_trip_light.png` | Active Trip — navigate to pickup (Phase 3) | Baseline |
| `pickup_arrival_light.png` | Pickup Arrival — await rider (Phase 3) | Baseline |
| `navigation_focus_light.png` | Navigation Focus — ride in progress (Phase 3) | Baseline |
| `reward_screen_light.png` | Reward Screen — payment + rate (Phase 3) | Baseline |
| `earnings_hub_light.png` | Earnings Hub (Phase 4) | Baseline |
| `subscription_gate_light.png` | Subscription Gate (Phase 4) | Baseline |
| `payment_history_light.png` | Payment History (Phase 4) | Baseline |
| `driver_identity_light.png` | Driver Identity (Phase 5) | Baseline |
| `preferences_light.png` | Preferences (Phase 5) | Baseline |
| `vehicle_profile_light.png` | Vehicle Profile (Phase 5) | Baseline |
| `veriff_trust_light.png` | Identity Verification (Phase 5) | Baseline |
| `compliance_vault_light.png` | Compliance Vault (Phase 5) | Baseline |
| `help_hub_light.png` | Help Hub (Phase 6) | Baseline |
| `quick_answers_light.png` | Quick Answers (Phase 6) | Baseline |
| `support_inbox_light.png` | Support Inbox (Phase 6) | Baseline |
| `raise_issue_light.png` | Raise Issue (Phase 6) | Baseline |
| `todays_ledger_light.png` | Today's Ledger (Phase 7) | Baseline |
| `ride_history_light.png` | Ride History (Phase 7) | Baseline |
| `trip_receipt_light.png` | Trip Receipt (Phase 7) | Baseline |
| `performance_scorecard_light.png` | Performance Scorecard (Phase 8) | Baseline |
| `rate_control_light.png` | Rate Control (Phase 8) | Baseline |
| `demand_radar_light.png` | Demand Radar (Phase 8) | Baseline |
| `feedback_loop_light.png` | Feedback Loop (Phase 9) | Baseline |
| `legal_trust_light.png` | Terms Trust (Phase 9) | Baseline |
| `privacy_trust_light.png` | Privacy Trust (Phase 9) | Baseline |
| `ai_support_chat_light.png` | AI Support Chat (Phase 9) | Baseline |
| `community_hub_light.png` | Community Hub (Phase 10) | Baseline |
| `community_channel_light.png` | Community Channel (Phase 10) | Baseline |
| `support_conversation_light.png` | Support Conversation (Phase 10) | Baseline |
| `liability_ack_light.png` | Liability Acknowledgment (Phase 10) | Baseline |
| `manual_ride_entry_light.png` | Manual Ride Entry (Phase 11) | Baseline |
| `return_trips_light.png` | Return Trips (Phase 11) | Baseline |
| `scheduled_rides_light.png` | Scheduled Rides (Phase 11) | Baseline |
| `ride_swap_light.png` | Ride Swap (Phase 12) | Baseline |
| `go_live_light.png` | Go Live (Phase 12) | Baseline |
| `referral_share_light.png` | Referral Share (Phase 12) | Baseline |
| `app_suggestion_light.png` | App Suggestion (Phase 12) | Baseline |
| `onboarding_gate_light.png` | Onboarding Gate (Phase 13) | Baseline |
| `knowledge_base_light.png` | Knowledge Base (Phase 13) | Baseline |
| `readiness_gate_light.png` | Readiness Gate (Phase 13) | Baseline |
| `update_gate_light.png` | Update Gate (Phase 13) | Baseline |
| `brand_moment_light.png` | Brand Moment (Phase 14) | Baseline |
| `shift_command_light.png` | Shift Command (Phase 14) | Baseline |
| `rider_conversation_light.png` | Rider Conversation (Phase 14) | Baseline |
| `me_community_light.png` | Community Feed (Phase 14) | Baseline |
| `community_notifications_light.png` | Notifications sheet (Phase 15) | Baseline |
| `community_search_light.png` | Search sheet (Phase 15) | Baseline |
| `community_disclaimer_light.png` | Disclaimer dialog (Phase 15) | Baseline |
| `community_create_post_light.png` | Create post sheet (Phase 15) | Baseline |
| `staging_surface_light.png` | Staging Surface (Phase 15) | Baseline |

Goldens live in `apps/driver/test/visual/goldens/` — **commit to git**.

## Test bootstrap (required)

Every visual test file must import the bootstrap **first** and reference
`kDriverGoldenTypographyBootstrapped` so Dart does not tree-shake it:

```dart
import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;
// …then other imports (heycaby_ui, screens, etc.)
```

This sets `kHeyCabyUseRobotoTypographyForTests` before `kThemes` initializes,
so goldens use bundled **Roboto** (no Google Fonts network in CI).

Motion is disabled via `kDriverMotionEnabled = false` in the same bootstrap
so entrance animations do not flake pixel diffs.

## Phase 2 freeze

All **fifty-six** visual tests pass on compare. Gallery copy:

```bash
PHASE=phase-2-premium ./scripts/driver_visual_regression.sh gallery
```

Proof review: [`PHASE_2_PROOF_REVIEW.md`](./PHASE_2_PROOF_REVIEW.md)

## Viewport

- Size: **393×852** (iPhone 15 Pro logical)
- Safe area: top 59 / bottom 34
- Theme: `driver-pro` light (dark goldens: Phase 7)

## When to update baselines

- **Intentional** Phase 2+ redesign → run `baseline` after design review
- **Never** update baselines to silence a failure without human review

## Catches

- Text disappearing · buttons off-screen · overflow stripes  
- Spacing regressions · safe-area clipping · component drift  

## CI (recommended)

Add to GitLab CI after `flutter test`:

```yaml
- cd apps/driver && flutter test test/visual/ --no-pub
```

## Related

- PR checklist: [`DESIGN_GUARDRAILS.md`](./DESIGN_GUARDRAILS.md)
- Design score: [`DESIGN_SCORE.md`](./DESIGN_SCORE.md)
- Phase 2 brief: [`PREMIUM_EXPERIENCE_PROOF.md`](./PREMIUM_EXPERIENCE_PROOF.md)
- Phase 2 proof: [`PHASE_2_PROOF_REVIEW.md`](./PHASE_2_PROOF_REVIEW.md)
- Pattern index: [`PHASE_2_PATTERN_INDEX.md`](./PHASE_2_PATTERN_INDEX.md)
