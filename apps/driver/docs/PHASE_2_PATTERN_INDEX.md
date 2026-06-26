# Phase 2 — Pattern Index

**Purpose:** Map every `lib/ui/` component and motion preset to reference implementations so Phase 3+ screens reuse patterns — no new inventions.

**Gold standard screens:** Trust Screen (`login_screen.dart`) · Money Dashboard (`driver_home_screen.dart`)

---

## Theme (`lib/theme/`)

| Token / module | Use |
|----------------|-----|
| `DriverColors` | All semantic colors |
| `DriverTypography` | All text styles |
| `DriverSpacing` | Padding, gaps, touch targets |
| `DriverRadius` | Corners, sheet top, pills |
| `DriverShadows` | Cards, FABs, sheets |
| `DriverMotion` | Duration + curve constants |
| `driver_motion_presets.dart` | `driverFadeSlideIn`, `driverMapChromeEnter`, `driverSuccessPop`, `driverRideIncomingPulse`, `DriverAnimatedEarnings`, `DriverOnlineStatusBadge` |

Import kit: `import 'package:heycaby_driver/ui/driver_ui.dart';`

---

## Components → where used (Phase 2)

| Component | Trust Screen | Money Dashboard | Map chrome | Phase 3+ reuse |
|-----------|:------------:|:---------------:|:----------:|----------------|
| `DriverButton` | ✅ email + OTP CTA | — | — | Any primary CTA |
| `DriverTextField` | ✅ email | — | — | Forms, search |
| `DriverOtpInput` | ✅ OTP step | — | — | Verification flows |
| `DriverStatusBanner` | ✅ error / success | — | — | Inline form feedback |
| `DriverEarningsChip` | — | ✅ map overlay | ✅ | Earnings anywhere |
| `DriverMapFab` | — | ✅ menu + recenter | ✅ | All map screens |
| `DriverMapControlsColumn` | — | — | ✅ | Map FAB stacks |
| `DriverMapOnlineChip` | — | — | ✅ | Online / break status |
| `DriverMapDemandChip` | — | — | ✅ | Hotspots, home map |
| `DriverMapEtaChip` | — | — | ✅ (kit) | Active ride, nav |
| `DriverAccentRailCard` | — | ✅ sheet quick actions | — | Hub tiles, lists |
| `DriverRideCard` | — | — | — (kit) | ✅ Opportunity + ride flow |
| `DriverRideCountdownRing` | — | — | — | ✅ Opportunity Screen |
| `DriverRideActionChip` | — | — | — | ✅ Active Trip, Pickup Arrival |
| `DriverCard` | — | via rail cards | — | Generic content |
| `DriverChip` / `DriverStatusBadge` | — | — | — (gallery) | Filters, tags |
| `DriverStatisticCard` | — | — | — (gallery) | ✅ Earnings Hub |
| `DriverSkeleton` | — | — | — (gallery) | Loading states |
| `DriverEmptyState` | — | — | — (gallery) | Empty lists |
| `DriverAppBar` | — | — | — (gallery) | Secondary screens |
| `DriverBottomSheet` | — | — | — (gallery) | Modals, pickers |

---

## Widget orchestration (not in `lib/ui/` — reference only)

| Widget | Role | Do not duplicate |
|--------|------|------------------|
| `DriverLoginHero` | Trust hero image + fade | Other entry screens |
| `DriverTrustScreenBody` | Login form sheet | — |
| `DriverMoneyDashboardHeader` | Sheet earnings hero | Earnings hub |
| `DriverHomeSheet` | Bottom sheet layout + stagger | — |
| `DriverMapFloating` | Map overlay stack | Active ride map |
| `DriverSwipeToGoOnline` | Online toggle + success | Go-live flows |
| `DriverShiftTimerWidget` | Online shift card | — |
| `DriverOpportunityScreenBody` | Opportunity Screen layout | Active ride offers |
| `DriverEarningsHubBody` | Earnings Hub — net hero + metrics | — |
| `DriverSubscriptionGateBody` | Subscription Gate — plan + pay | — |
| `DriverPaymentHistoryBody` | Payment History list | — |
| `DriverMoneyFlowScaffold` | Shared money/billing shell | Phase 4 money screens |
| `DriverSettingsFlowScaffold` | Settings & profile shell | Phase 5 settings screens |
| `DriverIdentityBody` | Driver Identity — Account Hub | — |
| `DriverPreferencesBody` | Preferences — toggles + appearance | — |
| `DriverComplianceVaultBody` | Compliance Vault — checklist + forms slot | — |
| `DriverVeriffTrustBody` | Veriff trust entry | — |
| `DriverVehicleProfileBody` | Vehicle Profile — kenteken + RDW | — |
| `DriverHelpHubBody` | Help Hub — support entry | — |
| `DriverQuickAnswersBody` | Quick Answers — FAQ | — |
| `DriverSupportInboxBody` | Support Inbox — ticket list | — |
| `DriverRaiseIssueBody` | Raise Issue — new ticket form | — |
| `DriverSupportFlowScaffold` | Shared support shell | Phase 6 support screens |
| `DriverTodaysLedgerBody` | Today's Ledger — compact ride rows | — |
| `DriverRideHistoryBody` | Ride History — scannable cards | — |
| `DriverTripReceiptBody` | Trip Receipt — fare hero + breakdown | — |
| `DriverLedgerFlowScaffold` | Shared trip ledger shell | Phase 7 ledger screens |
| `DriverPerformanceScorecardBody` | Performance Scorecard | — |
| `DriverRateControlBody` | Rate Control — tariff editor | — |
| `DriverDemandRadarOverlay` | Demand Radar map chrome | — |
| `DriverPerformanceFlowScaffold` | Shared demand/performance shell | Phase 8 screens |
| `DriverFeedbackLoopBody` | Feedback Loop — post-ride rating | — |
| `DriverLegalTrustBody` | Legal Trust — terms & privacy reader | — |
| `DriverAiSupportChatBody` | AI Support Chat — Lee conversation | — |
| `DriverTrustFlowScaffold` | Shared trust/legal/chat shell | Phase 9 screens |
| `DriverCommunityHubBody` | Community Hub — feed selector + slivers | — |
| `DriverCommunityChannelBody` | Community Channel — full feed list | — |
| `DriverSupportConversationBody` | Support Conversation — human ticket chat | — |
| `DriverLiabilityAcknowledgmentBody` | Liability Acknowledgment — doc + consent | — |
| `DriverCommunityFlowScaffold` | Shared community shell | Phase 10 screens |
| `DriverManualRideEntryBody` | Manual Ride Entry — off-app trip form | — |
| `DriverReturnTripsBody` | Return Trips — discount + offers | — |
| `DriverScheduledRidesBody` | Scheduled Rides — tabbed list | — |
| `DriverTripPlanningFlowScaffold` | Shared trip planning shell | Phase 11 screens |
| `DriverRideSwapBody` | Ride Swap — feed shell + refresh | — |
| `DriverGoLiveBody` | Go Live — readiness checklist + swipe | — |
| `DriverReferralShareBody` | Referral Share — link + share actions | — |
| `DriverAppSuggestionBody` | App Suggestion — form + top ideas | — |
| `DriverWorkFlowScaffold` | Shared work/growth shell | Phase 12 screens |
| `DriverOnboardingGateBody` | Onboarding Gate — register form | — |
| `DriverKnowledgeBaseBody` | Knowledge Base — help articles shell | — |
| `DriverReadinessGateBody` | Readiness Gate — checklist + CTAs | — |
| `DriverUpdateGateBody` | Update Gate — iOS minimum version | — |
| `DriverEntryFlowScaffold` | Shared entry/gate shell | Phase 13 screens |
| `DriverBrandMomentBody` | Brand Moment — splash intro | — |
| `DriverShiftCommandBody` | Shift Command — earnings + rides | — |
| `DriverRiderConversationBody` | Rider Conversation — in-ride chat | — |
| `DriverMeCommunityBody` | Community Feed — legacy me tab | — |
| `DriverCommunityNotificationsSheetBody` | Notifications sheet | — |
| `DriverCommunitySearchSheetBody` | Community search sheet | — |
| `DriverCommunityDisclaimerBody` | Welcome disclaimer dialog | — |
| `DriverCommunityCreatePostBody` | Create post / poll composer | — |
| `DriverStagingSurfaceBody` | Staging placeholder screen | — |
| `DriverShiftCommandEarningsPreview` | Shift command golden earnings panel | Phase 14 previews |
| `DriverActiveTripBody` | Active Trip — en route to pickup | — |
| `DriverPickupArrivalBody` | Pickup Arrival — await rider | — |
| `DriverNavigationFocusBody` | Navigation Focus — minimal in-ride UI | — |
| `DriverRewardScreenBody` | Reward Screen — payment + rate | — |
| `DriverRideFlowScaffold` | Shared ride-flow shell + bottom bar | All Phase 3 ride screens |
| `DriverOnlineStatusWidget` | Animated wrapper → `DriverMapOnlineChip` | — |

---

## Motion presets → where applied

| Preset | Applied in |
|--------|------------|
| `driverFadeSlideIn` | Trust form, home sheet rows, ride request + ride flow bodies |
| `driverMapChromeEnter` | Earnings chip, online chip, demand chip, FAB column |
| `driverSuccessPop` | Swipe-to-online success, OTP success banner |
| `driverRideIncomingPulse` | `DriverRideCard(incomingPulse: true)` |
| `DriverAnimatedEarnings` | Map chip, dashboard header |
| `DriverOnlineStatusBadge` | Dashboard header online pill |

**Golden tests:** `kDriverMotionEnabled = false` in `golden_bootstrap.dart`.

---

## Screen coverage (51 registered)

Phase 2 **fully** applies the kit to **2** screens (+ map chrome layer on Home):

- Trust Screen
- Money Dashboard (+ floating map chrome)

**Partial** (motion or single component only):

- *(none — Opportunity Screen completed Phase 3)*

**Phase 3 complete (Core Ride Flow — UI only):**

- `new_ride_request_screen.dart` — **Opportunity Screen**
- `active_ride_screen.dart` — **Active Trip**
- `at_pickup_screen.dart` — **Pickup Arrival**
- `ride_in_progress_screen.dart` — **Navigation Focus**
- `ride_complete_screen.dart` — **Reward Screen**

**Phase 4 complete (Money & Earnings — UI only):**

- `driver_finance_screen.dart` — **Earnings Hub**
- `driver_billing_screen.dart` — **Subscription Gate**
- `driver_billing_history_screen.dart` — **Payment History**

**Phase 5 complete (Settings & Profile — UI only):**

- `driver_profile_screen.dart` — **Driver Identity**
- `driver_preferences_screen.dart` — **Preferences**
- `driver_documents_screen.dart` — **Compliance Vault**
- `driver_veriff_screen.dart` — **Identity Verification**
- `vehicle_edit_screen.dart` — **Vehicle Profile**

**Phase 6 complete (Support & Help — UI only):**

- `driver_support_screen.dart` — **Help Hub**
- `driver_faq_screen.dart` — **Quick Answers**
- `support_threads_screen.dart` — **Support Inbox**
- `support_new_ticket_screen.dart` — **Raise Issue**

**Phase 7 complete (Trip Ledger — UI only):**

- `today_rides_screen.dart` — **Today's Ledger**
- `driver_my_rides_screen.dart` — **Ride History**
- `driver_ride_detail_screen.dart` — **Trip Receipt**

**Phase 8 complete (Demand & Performance — UI only):**

- `driver_score_screen.dart` — **Performance Scorecard**
- `driver_tariff_editor_screen.dart` — **Rate Control**
- `driver_hotspots_screen.dart` — **Demand Radar** (overlay chrome)

**Phase 9 complete (Trust & Feedback — UI only):**

- `rate_rider_screen.dart` — **Feedback Loop**
- `driver_terms_screen.dart` — **Terms Trust**
- `driver_privacy_screen.dart` — **Privacy Trust**
- `support_lee_screen.dart` — **AI Support Chat**

**Phase 10 complete (Community & Support Conversation — UI only):**

- `driver_community_hub_screen.dart` — **Community Hub**
- `driver_community_channel_feed_screen.dart` — **Community Channel**
- `support_chat_screen.dart` — **Support Conversation**
- `driver_indemnification_screen.dart` — **Liability Acknowledgment**

**Phase 11 complete (Trip Planning — UI only):**

- `driver_add_manual_ride_screen.dart` — **Manual Ride Entry**
- `driver_return_trips_screen.dart` — **Return Trips**
- `scheduled_rides_screen.dart` — **Scheduled Rides**

**Phase 12 complete (Work & Growth — UI only):**

- `ride_swap_screen.dart` — **Ride Swap**
- `go_online_screen.dart` — **Go Live**
- `driver_tell_friend_screen.dart` — **Referral Share**
- `driver_app_suggestion_screen.dart` — **App Suggestion**

**Phase 13 complete (Entry & Gates — UI only):**

- `register_screen.dart` — **Onboarding Gate**
- `driver_help_articles_screen.dart` — **Knowledge Base**
- `driver_runtime_gate_screen.dart` — **Readiness Gate**
- `driver_ios_update_required_app.dart` — **Update Gate**

**Phase 14 complete (Active Hub — UI only):**

- `splash_screen.dart` — **Brand Moment**
- `work_screen.dart` — **Shift Command**
- `driver_chat_screen.dart` — **Rider Conversation**
- `me_screen.dart` — **Community Feed**

**Phase 15 complete (Community Overlays & Staging — UI only):**

- Community hub modals — **Notifications**, **Search**, **Disclaimer**, **Create Post**
- `placeholder_screen.dart` — **Staging Surface**

**Redesign program:** All registered screens + community overlays on Phase 2 kit. ✅

---

## Adding a new screen (Phase 3 checklist)

1. Purpose name from [`SCREEN_OWNERSHIP.md`](./SCREEN_OWNERSHIP.md)
2. Compose from `lib/ui/` — add new component only if used **twice**
3. Tokens only — no `Color(0x…)` / magic numbers
4. Motion via `driver_motion_presets.dart`
5. Golden if static layout; device TTU per [`DESIGN_SCORE.md`](./DESIGN_SCORE.md)
6. `./scripts/driver_visual_regression.sh compare`
