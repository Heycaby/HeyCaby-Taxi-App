# HeyCaby Driver — Visual Identity & Experience (Phase 0.5)

> **The driver should never have to think about the app. The app should think for the driver.**

**Status:** Locked — paired with Phase 0.75 before implementation.  
**Scope:** UI/UX only. Business logic, APIs, navigation, ride flow, billing, and Supabase/Go backends are **frozen**.

**Foundation stack:**

| Phase | Document |
|-------|----------|
| 0 | Audit (screen/widget inventory) |
| **0.5** | **This file** — how it looks |
| **0.75** | [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md) — how it feels |
| 1+ | Flutter implementation |

**After Phase 0.75:** No new design documents. Build and validate against 0 + 0.5 + 0.75.

---

## North star

Build the **best-looking taxi driver app in Europe** — unmistakably **HeyCaby**, standing beside Uber Driver, Bolt Driver, Tesla, Apple, Revolut, Linear, Spotify, Airbnb, and Stripe as an **equal**, not an imitation.

**Study those products to understand why they feel effortless.** Do not copy layouts, colors, or iconography. Extract principles: clarity, hierarchy, restraint, speed, trust.

---

## Brand personality

### Always feel like

| Trait | In practice |
|-------|-------------|
| **Premium** | Generous space, refined type, soft depth — never cramped |
| **Calm** | Low visual noise; one focal action per view |
| **Fast** | UI responds instantly; motion is short and purposeful |
| **Intelligent** | Surfaces the right info at the right moment — no hunting |
| **Professional** | Taxi-industry credible; suitable for regulators and partners |
| **Confident** | Bold headlines, clear CTAs, no apology copy in UI chrome |
| **Minimal** | Remove before you add; every element earns its place |
| **Luxurious** | Quality of finish (blur, shadow, typography) over decoration |
| **Modern** | 2026 mobile patterns; no skeuomorphic clutter |
| **Reliable** | Predictable placement; stable components; honest states |

### Never feel like

Busy · Cartoonish · Cheap · Overly colorful · Confusing · Playful · Gamified · Stock-template · “Startup gradient soup”

---

## Design language

### Core philosophy

> **One glance. One action.**

Within **one second** every screen must answer:

1. **Where am I?** — clear title, context, or map state  
2. **What should I do next?** — single primary action, visually dominant  
3. **What information matters most?** — hierarchy, not equality  

Drivers should **not search**. The most important action is **obvious** without reading paragraphs.

### Layout principles

- **F-pattern for lists** — title top-left, action top-right or bottom sticky  
- **Thumb zone** — primary actions in lower 40% of screen (one-handed)  
- **Map is sacred** — chrome floats above map; never fight the map for attention unless ride-critical  
- **Progressive disclosure** — show summary first; details on tap or sheet  
- **Cards over boxes** — grouped content in rounded surfaces with soft elevation, not bordered rectangles  

---

## Emotional design

Design decisions are validated against **how the driver should feel**, not only how the screen looks.

| Moment | Target emotion | Design response |
|--------|----------------|-----------------|
| **App open** | “I’m ready to make money.” | Confident splash → clean home; earnings hint visible; online path clear |
| **Going online** | Control + readiness | Checklist clarity; swipe or single decisive CTA; green “live” state |
| **Incoming ride** | Focused excitement | Full-screen urgency without panic; price/route hero; accept/reject unambiguous |
| **En route / pickup** | Professional flow | Map + next step + one tap; minimal distraction |
| **Trip complete** | Reward | Success micro-moment; earnings delta; warm confirmation |
| **Earnings / finance** | Success | Large numbers; green accents; trend clarity |
| **Going offline** | In control | Clear summary; no guilt; easy return path |
| **Errors / blocked** | Supported, not blamed | Plain language; one recovery action; no dead ends |
| **Community / support** | Safe, professional | Trust copy; readable rules; calm density |

If a screen does not evoke the target emotion, **redesign the hierarchy**, not just the colors.

---

## Visual rules

### Color — one accent: green

Green = money, growth, safety, professionalism, “go”.

**Driver-only theme** (`driver-pro` in `heycaby_ui`) — do not change Rider palettes.

| Token | Role | Starting direction (tune in Phase 1) |
|-------|------|--------------------------------------|
| `accent` | Primary CTA, online, success highlights | `#00C853` → `#00A86B` range |
| `accentDark` | Pressed / dark mode accent | `#00875A` |
| `accentLight` | Tinted surfaces, chips | `#E8F5E9` (light) / `#1B3D2F` (dark) |
| `success` | Completed ride, paid, verified | Align with accent family |
| `warning` | Attention, not error | Amber **only** for warnings — not brand |
| `error` | Failures, destructive | `#FF3B30` iOS-red family |
| `info` | Neutral system messages | Cool grey-blue |
| `bg` / `bgAlt` | App canvas | Warm neutral light; true dark for night shifts |
| `card` | Elevated surfaces | White / `#1C1C1E` with subtle warmth |
| `border` | Rare — prefer shadow/elevation | `#E5E5EA` light; `#38383A` dark |

**Rules**

- One accent color (green) for brand actions.  
- Minimal borders — use elevation and spacing instead.  
- Rich gradients **sparingly** (hero, splash, success) — not on every card.  
- Glass / blur **only** where it adds value (map overlays, floating panels).  
- Logo wordmark stays **yellow on dark** for brand recognition; UI chrome uses **green**, not yellow, for actions.

### Typography

**One unified stack** for the entire driver app (retire DM Sans login-only split).

Recommended: **Inter** or **Plus Jakarta Sans** (already partial) — Uber/Stripe-grade readability at 12–14px in sunlight.

| Scale | Use | Weight | Size (sp) |
|-------|-----|--------|-----------|
| Display | Splash, ride offer price | 700–800 | 32–40 |
| Headline | Screen titles | 700 | 22–28 |
| Title | Section headers | 600–700 | 17–20 |
| Subtitle | Supporting headers | 600 | 15–16 |
| Body | Copy, lists | 400–500 | 15–16 |
| Caption | Meta, timestamps | 400 | 12–13 |
| Micro | Badges, legal micro | 500 | 10–11 |
| Button | CTAs | 600–700 | 15–17 |
| **Numbers** | Earnings, fares, stats | **700–800**, tabular figures | Contextual |

**Rules:** Big typography for money and status. Generous line height (1.4–1.5 body). Max 2 weights per screen section.

### Space & shape

- **8pt grid** — all spacing multiples of 4/8  
- **Corner radius:** 12 (inputs), 16 (cards), 20–24 (sheets), 999 (pills)  
- **Whitespace:** prefer empty space over dividers  
- **Shadows:** very soft — `y: 4–8`, low opacity; no harsh Material 2 drops  

### Depth

- Cards float above background  
- Map controls: frosted pill, not solid blocks  
- Sheets: rounded top + drag handle + optional subtle scrim  

---

## Motion principles

Every animation must feel **quick**, **smooth**, and **intentional**.

| Property | Guideline |
|----------|-----------|
| Duration | 180–320ms UI; 400ms max for page transitions |
| Easing | `Curves.easeOutCubic` default; `easeInOut` for sheets |
| Never | Bouncy springs on functional UI; slow fades; parallax for show |

### Standard motions

| Event | Motion |
|-------|--------|
| Tab change | Instant content (existing); subtle icon scale optional |
| Sheet open | Slide up 280ms + scrim fade |
| Primary button press | Scale 0.98 + haptic light |
| Ride accepted | Short green pulse + check morph (400ms total) |
| Online toggle | Smooth track fill + status label crossfade |
| Success (trip complete) | Check draw + optional confetti **restrained** |
| Loading | Skeleton shimmer, not spinners alone |
| Error | Shake horizontal 8px once — then static message |

Reference: `packages/heycaby_ui/lib/src/theme/motion.dart` — extend with driver tokens.

---

## Icon system

**One family only** — no mixing Material filled, Lucide, and custom in the same row.

| Property | Rule |
|----------|------|
| Library base | Lucide (already in `app_icons.dart`) **or** custom SVG set — pick one for v1 |
| Stroke | 1.5–2px consistent |
| Optical size | 20 / 24 / 28dp tiers |
| Corner language | Rounded caps; match app radius language |
| Color | `textMid` default; `accent` active; never rainbow |

All navigation, hub, and settings icons flow through **`AppIcons`** — no raw `Icons.*` in new code.

**Phase 1 deliverable:** icon size + color wrapper widget (`DriverIcon`).

---

## Illustration system

All artwork must look like **one illustrator** — custom, not stock.

### Generate / commission (AI-assisted)

| Asset | Use |
|-------|-----|
| Onboarding (3–6) | Feature tour, first-run |
| Empty states | No rides, no earnings yet, no messages |
| Success | Trip complete, payout, verification approved |
| Safety | Emergency, break reminder |
| Earnings | Wallet, weekly summary hero |
| Vehicle | Silhouettes by type (sedan, van, EV) |
| Achievements | Score milestones, founding driver |
| Background patterns | Subtle map-adjacent textures (low contrast) |

**Style brief:** Flat + soft gradient; green brand; dark ink lines optional; no cartoon faces; European urban context; premium mobility, not gaming.

**Format:** SVG where possible; PNG @2x/@3x for complex scenes; store under `apps/driver/assets/illustrations/`.

---

## Component rules

Before building any UI:

1. **Can this be reused?** → If yes, put it in `apps/driver/lib/ui/` (Phase 1 kit).  
2. **Does it use tokens?** → Colors, type, spacing from `heycaby_ui` + driver extensions only.  
3. **One primary CTA?** → If two compete, redesign hierarchy.  
4. **Touch targets?** → See accessibility.  
5. **States?** → Default, pressed, disabled, loading, error, empty — all designed.  

**No duplicated dialog/sheet patterns** — use `DriverDialog`, `DriverSheet`, `DriverBottomBar`.

---

## Accessibility & driver ergonomics

Non-negotiable for 8–12 hour shifts.

| Rule | Spec |
|------|------|
| Minimum touch target | **48×48 dp** (56 for primary ride actions) |
| Contrast | WCAG AA minimum; AAA for earnings numbers where possible |
| Sunlight | Test light theme outdoors; no light-grey-on-white body text |
| Glanceability | Critical ride info readable in **< 2 seconds** at arm’s length |
| One-handed | Primary actions in thumb reach; no top-corner-only CTAs |
| Motion reduce | Respect `MediaQuery.disableAnimations` |
| Dynamic type | Support system text scaling without layout breaks (scroll where needed) |
| Color alone | Never rely on green/red only — pair with icon + label |
| Driving | No required reading while moving; voice/haptic for ride offer |

---

## AI asset generation policy

The redesign **may** use AI generation for:

- Brand illustrations & empty states  
- Vehicle silhouettes & map markers  
- Safety & achievement icons  
- Promotional / tell-a-friend artwork  
- Loading / Lottie **concepts** (implement as Flutter or Rive where feasible)  
- Background patterns  

**Not** for: misleading UI chrome, fake data, or off-brand mascots.

Every asset passes: **premium · minimal · green-aligned · same illustrator family**.

---

## Competitive mindset (updated)

> Study **Uber Driver, Bolt Driver, Lyft Driver, Tesla, Apple Human Interface Guidelines, Revolut, Linear, Spotify, Airbnb, and Stripe** — not to copy them, but to understand why they feel effortless. Build something unmistakably **HeyCaby** that can stand beside those products as an **equal**.

Extract from each:

| Product | Learn |
|---------|--------|
| Uber Driver | Ride offer clarity, map + sheet balance |
| Bolt Driver | European simplicity, earnings clarity |
| Apple HIG | Touch targets, typography, motion restraint |
| Tesla | Confident minimal chrome |
| Revolut | Financial numbers hierarchy |
| Linear | Density without clutter |
| Stripe | Form precision, trust |
| Spotify | Dark mode polish |
| Airbnb | Emotional photography & empty states |

---

## Implementation roadmap (revised)

| Phase | Name | Output |
|-------|------|--------|
| **0** | Audit | Screen/widget inventory ✅ |
| **0.5** | Visual identity | This document ✅ |
| **0.75** | **Experience blueprint** | [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md) ✅ |
| **1** | Design system | Green `driver-pro` tokens, type scale, 8 core components |
| **2** | Shell & home | Nav, map, online, home sheet |
| **3** | Auth & onboarding | Splash, login, tour |
| **4** | Ride flow | Offer → complete → rate |
| **5** | Money | Finance, billing, earnings |
| **6** | Profile & compliance | Documents, Veriff, vehicle |
| **7** | Community & support | Hub, tickets, hotspots |
| **8** | Polish | Dark mode, motion, a11y audit, illustrations |

**No further design phases.** Phase 1+ is code.

---

## Phase 1 entry checklist

Before merging the first visual PR:

- [ ] `kHeyCabyDriverPro` tokens in `heycaby_ui` (driver default switched in `DriverThemeNotifier`)  
- [ ] Typography unified — login uses same scale as home  
- [ ] `DriverButton`, `DriverCard`, `DriverSheet`, `DriverDialog`, `DriverInput`, `DriverChip`, `DriverEmptyState`, `DriverSkeleton`  
- [ ] `DriverIcon` wrapper  
- [ ] Motion constants in `motion.dart`  
- [ ] Proof screens: **Login + Home** redesigned with zero logic changes  
- [ ] Sunlight + one-handed review on physical device  

---

## Sign-off

Phase 0.5 defines **how the app looks**. Phase 0.75 defines **how the app feels moment-by-moment**. Together they turn a screen inventory into a **cohesive product brand**.

**Next action:** Phase 1 — green design system + component library + Login/Home proof. See [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md) for DNA, Commandments, and Million-Dollar Test.
