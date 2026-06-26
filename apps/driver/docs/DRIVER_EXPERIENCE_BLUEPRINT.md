# HeyCaby Driver — Experience Blueprint (Phase 0.75)

> **The driver should never have to think about the app. The app should think for the driver.**

This sentence sits above every design decision — layout, button, notification, sound, haptic, and animation.

**Status:** Locked. No Flutter widgets until Phase 1 passes this gate.  
**Foundation stack:** Phase 0 (Audit) → Phase 0.5 (Visual Identity) → **Phase 0.75 (this doc)** → Phase 1 (Design System).

**Rule for implementers:** When in doubt, ask *"Does this follow the HeyCaby DNA?"* and run the *Million-Dollar Test*. If either fails, redesign — do not ship.

---

## What Phase 0.75 answers

> **What should the driver experience during every second of using HeyCaby?**

We design **experiences**, not screens. Screens are containers; the journey is the product.

---

## Driver emotional journey

Every moment has a target feeling. Animation, sound, vibration, color, and layout **reinforce** that feeling — never fight it.

```
Open app
    → Feel welcomed
        Splash: calm confidence. Home: map + earnings hint + clear online path.

Go online
    → Feel ready to earn
        Checklist honest; one decisive action; green “live” state.

Waiting (online, no ride)
    → Feel informed, never bored
        Earnings pulse, hotspots hint, shift timer — no empty dead air.

Ride request
    → Feel excitement (focused, not panic)
        Full attention: price, route, time — accept/decline obvious in <1s.

Accepted
    → Feel confident
        Immediate next step; haptic + short success motion; no ambiguity.

Navigation / en route
    → Feel focused
        Map primary; one line of context; minimal chrome.

Pickup / arrived
    → Feel in control
        Rider info, actions (call, chat, arrived) at thumb; no hunting.

Passenger onboard
    → Feel relaxed
        Trip progress clear; distractions hidden; break reminders gentle.

Trip complete
    → Feel rewarded
        Success moment; fare visible; forward path to next ride or rest.

View earnings
    → Feel successful
        Big numbers; green growth; trends without spreadsheet noise.

Go offline
    → Feel accomplished
        Session summary optional; no guilt; easy return when ready.
```

### Journey → screen mapping (logic unchanged; experience layer only)

| Journey step | Primary surfaces | Emotional job |
|--------------|------------------|---------------|
| Open app | Splash, Home | Welcome + orient |
| Go online | Home sheet, Go-online, Runtime gate | Ready to earn |
| Waiting | Home map, Hotspots, Shift timer | Informed patience |
| Ride request | New ride request | Focused excitement |
| Accepted | Active ride | Confident momentum |
| Navigation | Active ride, In progress | Focus |
| Pickup | At pickup | Control |
| Onboard | In progress | Relaxed professionalism |
| Complete | Ride complete, Rate rider | Reward |
| Earnings | Finance, Earnings modal, Home chip | Success |
| Offline | Home toggle, shift end | Accomplished control |

**Sensory reinforcement (UI-only; no backend change):**

| Moment | Visual | Motion | Haptic | Sound |
|--------|--------|--------|--------|-------|
| Welcome | Dark splash → map reveal | Logo fade 280ms | — | — |
| Go online | Green state bloom | Track fill 220ms | Medium | Optional subtle |
| Ride offer | Full-screen card | Slide up 240ms | Heavy | Incoming request (existing) |
| Accepted | Green check | Pulse 400ms | Light | Driver found tone |
| Complete | Success illustration | Check draw | Light | Trip complete (existing) |
| Earnings | Number count-up optional | Fade in | — | — |

---

## HeyCaby Driver Design DNA

When the AI (or human) must choose between two valid options, DNA breaks the tie.

| Principle | Meaning |
|-----------|---------|
| **Calm before busy** | Default to quiet UI; urgency only when ride-critical |
| **Information before decoration** | Data and actions first; illustration supports, never blocks |
| **Confidence before excitement** | Professional clarity beats hype |
| **Money is always visible** | Earnings accessible from home — never buried |
| **Maps are always primary** | Map owns the canvas unless full-screen ride offer |
| **One-hand first** | Primary actions in thumb zone; 48dp+ targets |
| **Dark-friendly** | Night-shift readable; OLED-conscious dark mode |
| **Driving-first** | Glanceable; no reading novels at 50 km/h |
| **Zero unnecessary taps** | Remove steps; smart defaults; remember state |
| **Every interaction saves time** | If it doesn’t save seconds, cut it |

**Decision filter:** *Does this follow the HeyCaby DNA?* → Yes / No / Redesign.

---

## Design Commandments

Non-negotiable. Violating one blocks merge.

1. **Never hide earnings.** Session, day, or path to finance always one tap or visible on home.
2. **Never make drivers guess.** Labels, states, and next steps are explicit.
3. **One primary action per screen.** Secondary actions are visually subordinate.
4. **Never use more than one accent color.** Green = brand action; amber/red only semantic.
5. **Never interrupt a driver unnecessarily.** Notifications and modals earn their interruption.
6. **Every screen must have clear visual hierarchy.** One hero element; F-pattern or map-first.
7. **Every animation must have a purpose.** Inform, confirm, or orient — never decorate idle.
8. **Every pixel should help drivers earn money.** If it doesn’t, remove it.
9. **Every interaction should reduce stress.** Errors offer one recovery; no blame language.
10. **Remove anything that doesn’t create value.** Subtraction is a feature.

---

## Million-Dollar Test

Before any screen, component, or flow is accepted:

| Question | Pass criteria |
|----------|---------------|
| Would **Apple** ship this? | HIG: clarity, touch targets, motion restraint |
| Would **Uber’s design team** approve this? | Ride offer + map hierarchy credible |
| Would a **Bolt driver switch** because this feels better? | Faster to understand, more premium |
| Can a driver understand this in **under one second**? | Glance test on device in sunlight |
| Would this still look **modern in five years**? | Minimal, typographic, not trend-chasing |

**Any “No” → redesign.** No exceptions for “we’ll fix later.”

---

## Driver-centric standard

The driver is **not** sitting at home designing apps.

They are:

- Driving  
- At traffic lights  
- In **sunlight** and **rain**  
- Wearing **gloves**  
- Looking for passengers  
- Under **stress**  
- Trying to **make money**

### Design optimizations for that reality

| Condition | Requirement |
|-----------|-------------|
| Sunlight | High contrast body text; no light-grey-on-white |
| Rain / gloves | Large targets (56dp ride actions); spacing between taps |
| Glance (1–2 s) | Hero info size 17sp+; max 3 info chunks above fold |
| Stress | Calm palette; no flashing except ride offer |
| Money focus | Fare and earnings use **Number** typography scale |
| Interruption | Ride offer > everything; other modals never block accept |
| One hand | Sticky bottom CTAs; no top-only confirm |
| Night | Dark mode Phase 8; no pure white blast |

---

## Experience vs. screen checklist

For each surface in Phase 0 audit, Phase 1+ must document:

- [ ] Target emotion (from journey above)  
- [ ] Primary action (one)  
- [ ] DNA compliance (all 10)  
- [ ] Commandments (no violations)  
- [ ] Million-Dollar Test (5/5)  
- [ ] Driver-centric (sunlight + thumb + glance)  

Store pass/fail in PR description — not another permanent doc.

---

## Locked roadmap (no more design phases)

```
Phase 0      Audit                    ✅
Phase 0.5    Visual Identity          ✅  → DRIVER_VISUAL_IDENTITY.md
Phase 0.75   Experience Blueprint     ✅  → this document
Phase 1      Design Foundation        ✅  → lib/theme/ + lib/ui/
Phase 1.9    Visual Regression        ✅  → VISUAL_REGRESSION.md + goldens
Phase 2      Premium Experience Proof ✅  → PREMIUM_EXPERIENCE_PROOF.md + PHASE_2_PROOF_REVIEW.md
Phase 3      Core Ride Flow
Phase 4      Money & Earnings
Phase 5      Settings & Profile
Phase 6      Polish & Motion
Phase 7      Accessibility & QA
Phase 8      Design Freeze
```

**After Phase 0.75:** No new design documents. Build and validate against Phase 0, 0.5, 0.75, and **DESIGN_GUARDRAILS.md**.

---

## Phase 1 entry (final gate)

Phase 1 may start only when:

- [x] Phase 0 inventory complete  
- [x] Phase 0.5 visual identity locked  
- [x] Phase 0.75 experience blueprint locked  
- [ ] `driver-pro` green tokens scoped in `heycaby_ui` (driver-only)  
- [ ] 8 core components listed in Phase 0.5 checklist  
- [ ] Login + Home chosen as proof surfaces  

**Next command:** *Start Phase 1.*

---

## Document hierarchy (forever)

1. **This doc** — *Why* and *when* the driver should feel what  
2. **DRIVER_VISUAL_IDENTITY.md** — *How* it looks (color, type, motion, icons)  
3. **Phase 0 audit** — *What* exists (inventory)  

All three must agree. Visual identity without experience is decoration. Experience without visual identity is vague. Implementation without both is rework.

---

*HeyCaby Driver — Experience Blueprint v1.0 — Locked.*
