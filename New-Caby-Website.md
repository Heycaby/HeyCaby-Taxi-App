# HeyCaby — New Marketing Website Brief

**File:** `New-Caby-Website.md`  
**Domain:** [heycaby.nl](https://heycaby.nl) / [www.heycaby.nl](https://www.heycaby.nl)  
**Purpose:** Informational landing site that converts scroll → App Store / Play Store tap.  
**Not in scope:** In-browser booking, fare calculators, auth, account creation, live maps, or anything that competes with the native apps.

**North star:** A first-time visitor should feel they are already inside the HeyCaby product — same typography, same calm Apple-tier surfaces, same amber signature — not on a generic startup landing page bolted onto the brand.

---

## 0. What changed from the old brief

The previous draft had the right narrative bones but wrong or incomplete design guidance. This version is grounded in the **actual HeyCaby platform**:

| Old brief assumption | Correct platform truth |
|---|---|
| “Syne headings + Plus Jakarta body” (vague) | **Syne** = marketing display + logo wordmark **“caby”** only. **Plus Jakarta Sans** = all body, UI labels, buttons, captions, fares, ETAs. Weights: 300, 400, 500, 600, 700, 800 only. |
| Amber everywhere | Amber `#F4A800` is the **brand punctuator**, not wallpaper. Surfaces stay neutral; chroma lives in accent + status. |
| “Import design tokens somehow” | Source of truth: `packages/heycaby_ui/lib/src/theme/` — `color_tokens.dart`, `typography.dart`, `spacing.dart`. Website must mirror these as CSS variables; **no eyeball hex**. |
| Five themes on the marketing site | Rider app exposes multiple themes; **marketing site ships one theme**: **Daylight** (signature light). Optional `prefers-color-scheme: dark` polish later — not v1. |
| Stock “happy driver” photos | **Real app screenshots** in clean device frames. Stock photography is banned. |

---

## 1. Core narrative (two audiences, one idea)

**One idea:** HeyCaby gives power to the people who do the work, and safety to the people who trust them.

### Drivers — *You already have the power. We hand you the tools.*

Do not pitch “flexible gig work.” Pitch **structural fairness**:

- Drivers keep **100% of every fare**. HeyCaby charges a **flat weekly platform fee** (€50/week in current copy) — not a commission slice.
- HeyCaby works **for** drivers, not the other way around.
- Language to use: **“Your car. Your hours. Your money.”** / **“Take the tools. Keep the power.”**
- Language to avoid: ecosystem, empowerment, seamless, join our platform.

**Proof points to show (real product, not marketing fluff):**
- Earnings / payout screen (hero driver screenshot)
- Go Online cockpit (status, tariff, blockers)
- Return-ride matching (**Taxi Terug**)
- Platform balance transparency (weekly flat fee model)
- Schedule / service-area control
- Street pickup logging (100% fare retention)

### Riders — *Built by drivers. Safe from A to Z.*

Trust is **structural**, not generic:

- People who built and shaped this product have **sat in the driver’s seat**.
- Safety is a **visible sequence** — booking → verified driver → live tracking → in-trip tools → drop-off — not a bullet list of adjectives.
- Favorite-driver dispatch is a differentiator: book a **specific driver**, **favorites first**, or **favorites only** (real backend modes — do not oversimplify on the site).

**Proof points to show:**
- A→Z safety timeline with real screenshots at each step
- Driver identity before pickup (photo, plate, vehicle, rating)
- Live trip map + ETA
- Safety sheet (share trip, report, 112 emergency)
- Trip completion / receipt

---

## 2. Site architecture

**Format:** Single long scroll with early audience fork. No multi-page nav for v1.

```
┌─────────────────────────────────────────────────────────────┐
│ Sticky header (glass / hairline border)                     │
│ Logo · Voor chauffeurs · Voor ritten · App Store badges     │
├─────────────────────────────────────────────────────────────┤
│ 1. Hero — dual-line promise + one real screenshot           │
│ 2. Audience fork — two equal cards: Ik rijd / Ik boek       │
│ 3. Driver Freedom — flat-fee proof + tool cards             │
│ 4. Rider Safety — A→Z horizontal/step timeline              │
│ 5. Built by Drivers — origin story (specific names if poss) │
│ 6. Product showcase — alternating rider/driver screens      │
│ 7. Social proof — numbers only if strong; real quotes       │
│ 8. Coverage — NL cities / regions (honest, not aspirational)│
│ 9. Final CTA — repeat fork + store badges                   │
│ Footer — legal links (terms, privacy, support), KvK if set  │
└─────────────────────────────────────────────────────────────┘
```

**Header behavior:**
- Sticky, `backdrop-filter` blur on scroll, hairline `border` token.
- Anchor links: `#chauffeurs`, `#ritten`.
- Store badges visible from first paint (desktop: header right; mobile: hero + final CTA).
- Language: **Dutch primary**, English toggle in footer for v1 (matches NL market; AR later if needed).

**Interactions allowed:**
- Scroll, anchor navigation, audience fork cards, app store links, footer legal links, optional “EN / NL” toggle.
- **Nothing else.** No forms, no newsletter gate, no cookie wall that blocks reading.

---

## 3. Section specifications

### 3.1 Hero

**Layout:** 12-column grid, max content width `1120px`, `screenEdge` horizontal padding.

| Element | Spec |
|---|---|
| Display headline | Syne 800, `displayLarge` scale (32px mobile → 48px desktop), `text` color |
| Subhead | Plus Jakarta Sans 400, `bodyLarge` (16px), `textMid`, max-width `42ch` |
| Visual | One real screenshot — **driver earnings** or **rider active trip** — in iPhone 15 Pro frame, subtle shadow, no 3D mockup scenes |
| CTA | Official Apple + Google badge assets only |
| Background | `bg` (#F5F5F7) with optional soft `accentL` radial glow behind phone (≤ 15% opacity) |

**Headline direction (NL, refine with copywriter):**  
*“De taxi-app gebouwd door chauffeurs — voor iedereen die met vertrouwen rijdt.”*

**Subhead direction:**  
*Chauffeurs houden 100% van het tarief. Rijders zien precies wat er gebeurt, van boeking tot afzet.*

---

### 3.2 Audience fork

Two **equal-weight** cards immediately below hero fold.

| Card | Label | Accent hint | On tap |
|---|---|---|---|
| Driver | **Ik rijd** | Left border or icon tint: `driver-pro` green `#00A651` | Smooth scroll to `#chauffeurs` |
| Rider | **Ik boek** | Left border or icon tint: brand amber `#F4A800` | Smooth scroll to `#ritten` |

**Card anatomy (matches app cards):**
- `card` background, `border` 1px hairline, `12px` radius, `component` (16px) padding.
- Title: Plus Jakarta Sans 600, 17px (`titleLarge`).
- One-line teaser: `bodyMedium`, `textMid`.
- Chevron or subtle arrow — not a loud button.

---

### 3.3 Driver Freedom (`#chauffeurs`)

**Structure — three beats, not three paragraphs:**

1. **The claim (one line)**  
   *Jij houdt 100% van elk tarief. HeyCaby rekent een vast weekbedrag — geen commissie per rit.*

2. **The tools (feature card grid)**  
   2×2 or 1×4 responsive grid. Each card = **one screenshot + one line**. No marketing essays.

   | Card | Screenshot | One-liner |
   |---|---|---|
   | Verdiensten | Earnings / payout | *Elke euro die jij verdient, blijft van jou.* |
   | Taxi Terug | Return-ride matching | *Vul lege ritten met passagiers op jouw route.* |
   | Jouw regels | Schedule / zone / tariff | *Jij kiest wanneer, waar en tegen welk tarief.* |
   | Platformbalans | Platform balance screen | *Eén vast bedrag per week. Hoe meer je rijdt, hoe meer je wint.* |

3. **The stance (editorial block)**  
   Short founder-voice paragraph — the **only** place allowed to run longer. Left-aligned text, max `60ch`, optional small portrait. Tone: annoyed on behalf of drivers at commission platforms, not corporate.

**Section accent:** Use `driver-pro` green sparingly for icons, step numbers, and the primary driver CTA. Do **not** turn the whole section green — neutrals dominate.

---

### 3.4 Rider Safety — A→Z timeline (`#ritten`)

**This is the highest-design-investment section.** Build as a **literal sequence**, not prose.

| Step | Label | In-app moment | Safety measure shown |
|---|---|---|---|
| A | Boeken | Home / searching radar | Location + clear pickup |
| B | Chauffeur | Driver profile before pickup | Photo, plate, vehicle, rating |
| C | Onderweg | Live map tracking | Real-time position + ETA |
| D | In de rit | Safety sheet | Deel rit · Meld probleem · 112 |
| E | Afzet | Trip complete / receipt | Confirmation + fare transparency |

**Layout:**
- Desktop: horizontal stepper with connecting line (`border` color), screenshot above each step.
- Mobile: vertical timeline, sticky step label on scroll (optional).
- Active step: `accent` amber dot; completed steps: `success` green check.

**Copy rule:** Describe **what happens**, never “your safety is our priority.”

---

### 3.5 Built by Drivers

- Specific story beats: who drove, which features drivers shaped (tariff control, Terug, flat fee).
- Names + photos if available; otherwise quote from real driver beta testers.
- Avoid empty “we care about drivers” — specificity = credibility.

---

### 3.6 Product showcase

Alternating **rider / driver** screenshot rows (zig-zag on desktop, stack on mobile).

- Use `section` (24px) vertical rhythm between rows.
- Caption each shot with Plus Jakarta Sans 600, 15px — one factual line tied to the image.
- Lazy-load below fold; hero image `priority` + `fetchpriority="high"`.

---

### 3.7 Social proof

**Include a number only if it strengthens the story.** Small confident numbers beat vague “fast growing.”

| If true | Show |
|---|---|
| Cities live | Named list or minimal NL map outline |
| Rides completed | Only if > meaningful threshold |
| Driver count | Only if defensible |

Testimonials: **2–3 real** beat 6 generic. Name, city, role (chauffeur / ritklant), optional photo.

---

### 3.8 Coverage

Honest geography before download. City chips or simple map — `card` surfaces, `textMid` labels. If not in visitor’s city yet, say so clearly with “Binnenkort” only where true.

---

### 3.9 Final CTA

Repeat audience fork in compact form + store badges. No secondary links, no footer clutter in this band. Background: `bgAlt` or subtle `accentL` wash.

---

## 4. Visual system — platform defaults (mandatory)

The website is a **surface of the same product**. Implement from tokens, not inspiration boards.

### 4.1 Theme choice

| Context | Token set | Why |
|---|---|---|
| **Site default** | `kHeyCabyDaylight` | Signature HeyCaby — Apple-tier neutrals + amber accent |
| **Driver sections** | Daylight base + `kHeyCabyDriverPro` accent for hints/CTAs | Signals driver audience without a second site skin |
| **Rider sections** | Daylight + amber accent | Matches brand icon and wordmark |

**Do not** expose the rider app’s theme picker on the marketing site.

### 4.2 Color tokens → CSS variables

Export from `packages/heycaby_ui/lib/src/theme/color_tokens.dart` (`kHeyCabyDaylight`):

```css
:root {
  /* Surfaces — stacked like iOS system backgrounds */
  --hc-bg: #F5F5F7;
  --hc-bg-alt: #E5E5EA;
  --hc-surface: #E5E5EA;
  --hc-card: #FFFFFF;

  /* Brand */
  --hc-accent: #F4A800;
  --hc-accent-light: #FFF4DC;

  /* Chrome */
  --hc-border: #C6C6C8;

  /* Text hierarchy — near-black, not pure black */
  --hc-text: #1D1D1F;
  --hc-text-mid: #6E6E73;
  --hc-text-soft: #AEAEB2;

  /* Status */
  --hc-success: #248A3D;
  --hc-warning: #F4A800;
  --hc-error: #D70015;

  /* Driver audience accent (sections only) */
  --hc-driver-accent: #00A651;
  --hc-driver-accent-light: #E6F7EE;
}
```

**Rules:**
- Amber accents: CTAs, step markers, key highlights — **not** full-width backgrounds.
- Green: driver-specific labels, success states, “available” hints.
- Red: destructive copy only — rare on marketing site.
- No hardcoded hex in components after `:root` is defined.

### 4.3 Typography

Per `docs/Rebranding.MD` §4 and `typography.dart`:

```css
@import url('https://fonts.googleapis.com/css2?family=Syne:wght@700;800&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap');

:root {
  --font-display: 'Syne', system-ui, sans-serif;
  --font-body: 'Plus Jakarta Sans', system-ui, sans-serif;
}
```

| Role | Family | Weight | Size (mobile → desktop) | Use on site |
|---|---|---|---|---|
| Hero / section titles | Syne | 800 | 32px → 48px | H1, major section headers |
| Subsection titles | Syne | 700 | 22px → 28px | H2 |
| Card titles | Plus Jakarta Sans | 600 | 17px | H3, feature cards |
| Body | Plus Jakarta Sans | 400 | 15–16px | Paragraphs |
| Emphasis | Plus Jakarta Sans | 600 | 15px | Lead sentences |
| UI / buttons | Plus Jakarta Sans | 600 | 13–15px | Labels, nav |
| Caption | Plus Jakarta Sans | 400 | 12px | Legal, hints |
| Fare / stats | Plus Jakarta Sans | 600 | 13–16px | Mono-style numbers (still PJ Sans) |

**Logo wordmark (header/footer):** `hey` = Plus Jakarta Sans 300; `caby` = Syne 800 in `--hc-accent` on light backgrounds (see `docs/Rebranding.MD` §2).

**Note:** Flutter app UI currently uses Plus Jakarta Sans for all in-app text. The **website** uses Syne for display per brand guide — that intentional split is correct for marketing.

### 4.4 Spacing & radius

From `packages/heycaby_ui/lib/src/theme/spacing.dart`:

| Token | px | Web use |
|---|---|---|
| `element` | 8 | Icon-to-text, tight pairs |
| `component` | 16 | Card padding |
| `section` | 24 | Between blocks |
| `sectionLarge` | 30 | Section wrappers |
| `screenEdge` | 20 | Page horizontal padding |
| `modal` | 24 | Hero text block padding |

| Radius | px | Use |
|---|---|---|
| Standard card | 12 | Cards, fork tiles, feature grid |
| Large panel | 16 | Hero device frame, editorial block |
| Pill | 9999 | Tags, chips |

**Shadows:** One level only — soft, low spread: `0 2px 16px rgba(0,0,0,0.06)` on cards and phone frame. No layered drop shadows.

### 4.5 Motion

Per premium product design skill:

| Pattern | Duration | Easing | Use |
|---|---|---|---|
| Section reveal | 200ms | `ease-out` | Fade + 12px translateY on enter viewport |
| Hover (desktop) | 180ms | `ease` | Card border → `accent` tint |
| Anchor scroll | native | `scroll-behavior: smooth` | Audience fork, header links |

**Respect `prefers-reduced-motion`:** disable transforms; opacity-only or no animation.

**Never** gate content behind animation delays.

### 4.6 Components to build once

| Component | Notes |
|---|---|
| `HeyCabyButton` | Filled amber primary; quiet ghost secondary; min height 44px |
| `HeyCabyCard` | `card` bg, `border`, 12px radius, 16px padding |
| `DeviceFrame` | Single iPhone frame component; accepts screenshot slot |
| `StoreBadges` | Official SVG assets, localized per store locale |
| `SectionShell` | max-width 1120px, consistent vertical `section` spacing |
| `TimelineStep` | A→Z rider section |

---

## 5. Screenshot shot list

Capture on **physical device or simulator**, **Daylight/light theme**, realistic Dutch addresses and names (no “Test User”).

Export **@2x and @3x** PNG or WebP. Filenames: `driver-earnings@2x.webp`, etc.

### Driver app (`nl.heycaby.driver.app`)

| Priority | Screen | Why |
|---|---|---|
| P0 | Earnings / payout | Single most important driver proof |
| P0 | Incoming ride request | “You decide” moment |
| P1 | Home / Go Online | Status + cockpit |
| P1 | Taxi Terug / return matching | Differentiator |
| P2 | Platform balance | Flat-fee story |
| P2 | Tariff / schedule control | Autonomy story |

### Rider app (`nl.heycaby.rider.app`)

| Priority | Screen | Why |
|---|---|---|
| P0 | Searching / radar | Booking energy |
| P0 | Live trip map | Tracking proof |
| P0 | Safety sheet | Share / report / 112 |
| P1 | Driver profile pre-pickup | Verification |
| P1 | Trip complete / receipt | Closure |
| P2 | Favorite drivers / My Drivers | Dispatch modes |

---

## 6. Tone of voice

| Do | Don’t |
|---|---|
| Short, plain sentences | Commission platform clichés |
| Specific product facts | “Seamless experience” |
| Driver section: point of view | Neutral corporate voice |
| Rider section: step-by-step care | “Safety is our top priority” |
| Dutch directness | Hype superlatives |

**NL first;** EN mirror in `en.json` content layer if using i18n.

---

## 7. Technical brief

### Stack

| Layer | Choice |
|---|---|
| Framework | **Next.js** (App Router) + TypeScript |
| Hosting | **Vercel** — preview deploys per PR |
| Styling | Tailwind **or** CSS Modules — tokens in `globals.css` from §4.2 |
| Images | `next/image`, WebP + AVIF, explicit `width`/`height` |
| Fonts | `next/font/google` for Syne + Plus Jakarta Sans (no layout shift) |

**Repo suggestion:** `apps/marketing/` or `heycaby-web/` at monorepo root; share tokens via generated `tokens.css` from `heycaby_ui` in CI.

### Performance budget (mobile 4G)

| Metric | Target |
|---|---|
| LCP | < 2.5s |
| CLS | < 0.1 |
| Total page weight | < 1.2 MB first load |
| Hero image | < 120 KB WebP |
| JS (initial) | < 80 KB gzip |

### SEO

- Title: `HeyCaby — Taxi app voor chauffeurs en ritten in Nederland`
- Meta description: one sentence, both audiences, no keyword stuffing
- OG image: real screenshot composite or logo lockup on `bg` — 1200×630
- Semantic headings: one H1, logical H2 per section
- `hreflang` nl + en when EN ships
- Structured data: `Organization`, `MobileApplication` (both apps)

### Legal footer links (existing)

| Page | URL |
|---|---|
| Chauffeur terms | `/chauffeur/voorwaarden` |
| Disclaimer | `/chauffeur/vrijwaring` |
| Support | `/support` |

Serve from existing `heycaby-tos` Vercel project or `public/` — same `www.heycaby.nl` domain.

### Analytics (lightweight)

- Vercel Analytics or Plausible — page views + outbound store clicks
- Events: `store_click_ios`, `store_click_android`, `fork_driver`, `fork_rider`, `section_view_*`
- No cookie banner required if analytics is cookieless

---

## 8. Responsive breakpoints

| Name | Width | Layout notes |
|---|---|---|
| `sm` | 640px | Single column; fork cards stack |
| `md` | 768px | Timeline may go horizontal |
| `lg` | 1024px | Hero side-by-side; zig-zag showcase |
| `xl` | 1280px | Max content 1120px centered |

**Mobile-first.** 70%+ of traffic will be phone — hero must work in one thumb zone without horizontal scroll.

---

## 9. Accessibility (non-negotiable)

- WCAG 2.1 AA contrast on all text pairs (verify `text` on `bg`, `textMid` on `card`)
- Focus rings visible on fork cards and links (`accent` outline)
- 44×44px minimum tap targets (store badges, fork cards, nav)
- Alt text on every screenshot describing the **product state**, not “phone mockup”
- Skip link: “Ga naar inhoud”
- Reduced motion support (§4.5)

---

## 10. Success criteria

| Visitor type | After reading… | They can answer |
|---|---|---|
| Driver recruit | Driver Freedom section alone | *What’s different?* → 100% fare, flat fee, real tools |
| Safety-conscious rider | A→Z timeline alone | *Why trust this over Uber/Bolt?* → visible steps with real UI |
| Either | Full page | Where to download, whether their city is covered |

If either audience section fails the **alone** test, fix copy before polishing visuals.

---

## 11. Delivery checklist

### Design
- [ ] Figma (or code-first) uses CSS variables from §4.2 — no rogue hex
- [ ] Syne only on display; Plus Jakarta everywhere else
- [ ] Daylight surfaces; amber punctuates; driver green only in `#chauffeurs`
- [ ] All screenshots from shot list §5 — no stock photos
- [ ] Official store badges

### Build
- [ ] Next.js project on Vercel
- [ ] `next/font` loaded; no FOUT
- [ ] `next/image` for all screenshots; blur placeholders
- [ ] Anchor scroll + sticky header
- [ ] NL copy; EN scaffold if scoped
- [ ] Footer legal links wired
- [ ] Lighthouse mobile ≥ 90 performance, ≥ 95 accessibility

### Content
- [ ] Hero headline/subhead signed off
- [ ] Founder stance paragraph written by a human
- [ ] Coverage list matches real dispatch geography
- [ ] Testimonials verified real or section omitted

### Launch
- [ ] `www.heycaby.nl` DNS → Vercel
- [ ] OG tags validated (Twitter / WhatsApp / iMessage preview)
- [ ] App Store URLs correct for both apps
- [ ] 301 from bare `heycaby.nl` → `www`

---

## 12. Reference files in this repo

| Topic | Path |
|---|---|
| Color tokens | `packages/heycaby_ui/lib/src/theme/color_tokens.dart` |
| Typography | `packages/heycaby_ui/lib/src/theme/typography.dart` |
| Spacing | `packages/heycaby_ui/lib/src/theme/spacing.dart` |
| Theme registry | `packages/heycaby_ui/lib/src/theme/theme_registry.dart` |
| Brand / logo / web fonts | `docs/Rebranding.MD` |
| Spacing guide | `packages/heycaby_ui/SPACING_GUIDE.md` |
| Premium UI principles | `.codex/skills/heycaby-premium-product-design/SKILL.md` |
| Legal static pages | `heycaby-tos/` |

---

## 13. Open decisions (resolve before build)

1. **Exact launch cities** for coverage section — product owner to confirm.
2. **Founder story** — names/photos available or anonymous quote?
3. **English v1** — ship NL-only at launch or dual language?
4. **Dark mode** — defer (recommended) or ship `prefers-color-scheme` using `kHeyCabyTaxi2` tokens?
5. **Token sync** — manual CSS copy vs CI script generating `tokens.css` from Dart (recommended for long-term).

---

*This brief supersedes informal landing-page notes. Build the site to feel like opening the app — calm, expensive, honest — and get out of the way so the store badges do their job.*
