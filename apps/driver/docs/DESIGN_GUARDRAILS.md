# HeyCaby Driver — Design Guardrails

**Purpose:** Definition of done for every UI pull request. Not a design spec — a **checklist**.

**Foundation (read once):**

| Phase | Doc |
|-------|-----|
| 0 | Audit — what exists |
| 0.5 | [`DRIVER_VISUAL_IDENTITY.md`](./DRIVER_VISUAL_IDENTITY.md) — how it looks |
| 0.75 | [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md) — how it feels |
| 1.9+ | [`SCREEN_OWNERSHIP.md`](./SCREEN_OWNERSHIP.md) — what each screen is *for* |

If this PR changes UI, **every applicable box must be checked** (or N/A explained in the PR description).

---

## Visual consistency

- [ ] Uses **design tokens only** (`DriverColors`, `DriverTypography`, `DriverSpacing`, etc.)
- [ ] **No hardcoded colors** (`Color(0x…)`, raw `Colors.green`, etc.)
- [ ] **No hardcoded font sizes** outside `DriverTypography` / theme text styles
- [ ] Uses **spacing scale** (`DriverSpacing` / `HeyCabySpacing`)
- [ ] Uses **radius tokens** (`DriverRadius`)
- [ ] Uses **shadow tokens** (`DriverShadows`) where elevation is needed
- [ ] Uses **component library** (`apps/driver/lib/ui/`) — no one-off buttons/cards if a component exists
- [ ] **Light mode** verified on device or simulator
- [ ] **Dark mode** verified when theme supports it (or N/A with ticket link)

---

## Experience

- [ ] **Screen ownership** — purpose name from [`SCREEN_OWNERSHIP.md`](./SCREEN_OWNERSHIP.md) stated in PR; design serves that job
- [ ] **One primary action** per screen or sheet
- [ ] Passes [**Million-Dollar Test**](./DRIVER_EXPERIENCE_BLUEPRINT.md#million-dollar-test) (5/5 or documented exception)
- [ ] **TTU target met** — see [`DESIGN_SCORE.md`](./DESIGN_SCORE.md#time-to-understand-ttu) (Phase 2+: Login &lt; 3 s, Home &lt; 1 s)
- [ ] Matches [**Design DNA**](./DRIVER_EXPERIENCE_BLUEPRINT.md#heycaby-driver-design-dna) — filter applied
- [ ] No [**Commandment**](./DRIVER_EXPERIENCE_BLUEPRINT.md#design-commandments) violations
- [ ] **One-handed use** — primary CTA in thumb zone where applicable
- [ ] **Readable in sunlight** — body text contrast AA+
- [ ] **Glanceable** — hero info understandable in &lt; 1 second
- [ ] **No unnecessary animations** — every motion has purpose ([motion tokens](../lib/theme/driver_motion.dart))
- [ ] North star respected: *The driver should never have to think about the app.*

---

## Engineering

- [ ] **No duplicated widgets** — extract to `lib/ui/` if reused twice
- [ ] **Theme-aware** — `DriverColors.of(ref)`, not static colors
- [ ] **Responsive** — no overflow on small phones (scroll where needed)
- [ ] **Accessible** — 48×48 dp min touch targets (56 dp ride-critical actions)
- [ ] Respects `MediaQuery.disableAnimations` where custom motion is added
- [ ] **Zero business logic changes** — no API, provider, router, or service edits unless explicitly scoped
- [ ] **Zero backend changes** — no Supabase, Go, or migration edits in UI PRs
- [ ] **Visual regression** — `./scripts/driver_visual_regression.sh compare` passes (or baseline updated with review)
- [ ] **Design score ≥ 95%** — see [`DESIGN_SCORE.md`](./DESIGN_SCORE.md)

---

## Assets (when adding visuals)

- [ ] Placed under correct folder: `assets/icons/`, `illustrations/`, `lottie/`, `patterns/`, `backgrounds/`
- [ ] Matches single visual language (see Phase 0.5 illustration brief)
- [ ] Declared in `pubspec.yaml`
- [ ] No stock clipart / mixed illustration styles

---

## PR template snippet

Copy into PR description for UI work:

```markdown
## Design guardrails
- [ ] Screen purpose: ___ (from SCREEN_OWNERSHIP.md)
- [ ] Tokens + component library only
- [ ] Experience blueprint (DNA + Commandments + Million-Dollar Test + TTU)
- [ ] No business logic / backend changes
- [ ] Device tested: ___ 
```

---

## Enforcement

- Reviewer **blocks merge** if guardrails fail without documented exception.
- Phase 2+ screen PRs that skip the component library require **explicit justification**.

---

*This file is frozen. Do not expand into another design doc — update only when guardrails themselves change.*
