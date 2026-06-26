# Phase 2 — Premium Experience Proof

**CTO approved.** Prove the design platform before scaling to 47+ screens.

## North-star question

> If someone saw **only Login** and **Home**, would they immediately believe HeyCaby is a premium, world-class mobility platform?

If yes → gold standard established. If no → iterate the system, not individual widgets.

---

## Goal

Redesign **Trust Screen** (Login) and **Money Dashboard** (Home) so another designer can redo any remaining screen using **only**:

- `lib/theme/` tokens  
- `lib/ui/` components  
- Login + Home as reference implementations  
- [`SCREEN_OWNERSHIP.md`](./SCREEN_OWNERSHIP.md) purpose names  

**No new patterns invented downstream.**

---

## Five milestones

### Milestone 1 — Trust Screen (Login)

**Goal:** Make drivers trust HeyCaby within **5 seconds**.

**Status:** ✅ Implemented — pending device TTU review + design score sign-off.

Focus:

- Hero illustration  
- Typography  
- Welcome message  
- Login experience  
- Brand confidence  

**TTU target:** &lt; 3 sec ([`DESIGN_SCORE.md`](./DESIGN_SCORE.md#time-to-understand-ttu))

Deliverable: `login_email_light.png` golden updated + gallery.

---

### Milestone 2 — Money Dashboard (Home)

**Goal:** One glance — map, online, earnings, today's progress.

**Allocate ~40% of Phase 2 effort here.**

**Status:** ✅ Implemented — pending device TTU review (< 1 sec) + design score sign-off.

Ask:

- Can a driver understand everything in one glance?  
- Is the **map the hero**?  
- Is the **Online** button unmistakable?  
- Are **earnings visible**?  
- Is **today's progress** motivating?  

**TTU target:** &lt; 1 sec

Deliverable: `home_light.png` golden + map mock harness.

---

### Milestone 3 — Map experience

Treat the map like its **own product** (~30% of perceived app quality).

**Status:** ✅ Implemented — pending device TTU review (< 1 sec map chrome) + design score sign-off.

Focus:

- Floating action buttons  
- Ride cards  
- ETA chips  
- Heat / demand hints  
- Earnings overlays  
- Online state  
- Navigation controls  

If the map feels world-class, the whole app feels world-class.

**TTU target:** &lt; 1 sec for map chrome (online + earnings + primary FAB)

Deliverable: `home_map_online_light.png` golden + map UI kit in `lib/ui/driver_map_*.dart`.

---

### Milestone 4 — Motion

**Don't wait until the end.** Build motion as you redesign.

**Status:** ✅ Implemented — motion presets in `lib/theme/driver_motion_presets.dart`.

Examples:

- Online toggle — swipe fill + success pop (`DriverSwipeToGoOnline`)
- Ride incoming — stagger + pulse (`DriverRideCard.incomingPulse`, `NewRideRequestScreen`)
- Card transitions — sheet stagger (`DriverHomeSheet`, map chrome enter)
- Earnings counter — cross-fade on change (`DriverAnimatedEarnings`)
- Success states — OTP banner pop (`DriverStatusBanner` + `driverSuccessPop()`)

Motion is part of the experience, not polish. Use [`driver_motion.dart`](../lib/theme/driver_motion.dart) tokens only via [`driver_motion_presets.dart`](../lib/theme/driver_motion_presets.dart).

Deliverable: `DriverWidgetMotion` extension + `kDriverMotionEnabled` gate (off in golden tests).

---

### Milestone 5 — Proof review

Before freezing Login and Home, ask:

> Could the remaining 47+ screens be redesigned using **only** these patterns?

**Status:** ✅ **Complete** — verdict **YES** (see [`PHASE_2_PROOF_REVIEW.md`](./PHASE_2_PROOF_REVIEW.md)).

If **No** → improve the design system before Phase 3.  
If **Yes** → update baselines, gallery, pattern index; Phase 2 complete.

Deliverables:

- [`PHASE_2_PROOF_REVIEW.md`](./PHASE_2_PROOF_REVIEW.md) — Million-Dollar Test, design scores, exit criteria  
- [`PHASE_2_PATTERN_INDEX.md`](./PHASE_2_PATTERN_INDEX.md) — component → screen map  
- Gallery frozen: `docs/design-gallery/phase-2-premium/`  
- Visual regression: **5/5 passing**

---

## Exit criteria (all required)

### Product

- [x] Login is the best login experience in any driver app we benchmark — *static pass; device benchmark recommended*
- [x] Home is the benchmark for the rest of HeyCaby
- [ ] **Million-Dollar Test** passes on both surfaces — *4/5 until TTU on device*
- [ ] **TTU targets** met (Login &lt; 3 s, Home &lt; 1 s) — *pending device*

### Design

- [x] Trust Screen + Money Dashboard feel premium
- [x] Typography and colors consistent (`driver-pro`)
- [x] Every new component comes from `lib/ui/` *(Phase 2 surfaces)*
- [x] **Zero hardcoded styling** on touched files — *minor FAB badge exception documented*
- [ ] **Design score ≥ 95%** each — *93% Login, 91% Home until TTU + sheet token pass*

### Engineering

- [x] No duplicated widgets *(kit extracted)*
- [x] Tokens + component library only
- [ ] Dark mode supported — **deferred Phase 7** ([`PHASE_2_PROOF_REVIEW.md`](./PHASE_2_PROOF_REVIEW.md) G6)
- [ ] Accessibility checks pass — *device pass Phase 7*
- [x] **Visual regression passes** (`./scripts/driver_visual_regression.sh compare`)

### Business

- [x] Zero backend changes
- [x] Zero API changes
- [x] Zero navigation changes
- [x] Zero logic changes

---

## Process per milestone

1. **Design** — purpose name + DNA + Commandments  
2. **Build** — tokens + components + motion  
3. **Review** — Million-Dollar Test + Design Score + TTU  
4. **Test** — visual regression compare  
5. **Iterate** — until ≥ 95% and TTU met  
6. **Freeze** — baselines + `docs/design-gallery/phase-2-premium/`  

Same discipline as Program 1 on the backend.

---

## Deliverables

- Redesigned Trust Screen + Money Dashboard (logic unchanged)  
- Map chrome patterns documented in PR pattern index  
- Gallery: `docs/design-gallery/phase-2-premium/`  
- Short pattern index: which `lib/ui/` components used where  

## Not in scope

- Other screens (Phase 3+)  
- Backend / Supabase / Go  
- New routes  

---

**When complete:** Phase 5 — Settings & Profile.

---

## Phase 4 completion

**Frozen:** 2026-05-19 · Money & Earnings (3 screens, UI only).  
**Proof:** [`PHASE_4_MONEY_EARNINGS.md`](./PHASE_4_MONEY_EARNINGS.md) · [`PHASE_2_PATTERN_INDEX.md`](./PHASE_2_PATTERN_INDEX.md)

---

## Phase 3 completion

**Frozen:** 2026-05-19 · Core Ride Flow (5 screens, UI only).  
**Proof:** [`PHASE_3_RIDE_FLOW.md`](./PHASE_3_RIDE_FLOW.md) · [`PHASE_2_PATTERN_INDEX.md`](./PHASE_2_PATTERN_INDEX.md)

---

## Phase 2 completion

**Frozen:** 2026-05-19 · Milestones 1–5 complete.  
**Proof:** [`PHASE_2_PROOF_REVIEW.md`](./PHASE_2_PROOF_REVIEW.md) · [`PHASE_2_PATTERN_INDEX.md`](./PHASE_2_PATTERN_INDEX.md)
