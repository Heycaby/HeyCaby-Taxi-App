# Design Score — Driver UI

Every redesigned screen targets **≥ 95%** before merge.

Score each category **0–100**, then apply weights.

| Category | Weight | What we measure |
|----------|-------:|-----------------|
| **Visual quality** | 25% | Premium feel, spacing, typography, no clutter |
| **Accessibility** | 15% | Contrast, 48dp targets, dynamic type, semantics |
| **Consistency** | 20% | Tokens + `lib/ui/` only; matches Login/Home gold standard |
| **Driver usability** | 25% | TTU met, one primary action, thumb zone, sunlight |
| **Performance** | 15% | No jank; skeletons not spinners; map chrome lightweight |

## Time to Understand (TTU)

**TTU** = how long a **first-time driver** needs to understand what the screen is for and what to do next.

Measure with a 5-second timer (parked, phone in hand):

1. Show screen cold (no prior context).  
2. Ask: *What is this screen? What would you tap first?*  
3. Stop when both answers are correct without hesitation.

| Screen | Purpose name | TTU target |
|--------|--------------|------------|
| Login | Trust Screen | **&lt; 3 sec** |
| Home | Money Dashboard | **&lt; 1 sec** |
| Ride request | Opportunity Screen | **&lt; 1 sec** |
| Earnings | Earnings Hub | **&lt; 2 sec** |

Shorter TTU → higher **Driver usability** score. Missing TTU target caps that category at **80** until fixed.

Record in PR:

```markdown
TTU: __ sec (target __ sec) — pass/fail
Observer: __
```

## Formula

```
Score = 0.25×Visual + 0.15×A11y + 0.20×Consistency + 0.25×Usability + 0.15×Performance
```

## Rubric (per category)

### Visual quality (25%)

| Score | Criteria |
|------:|----------|
| 95+ | Could ship in Uber/Bolt tier; whitespace intentional |
| 80 | Good but minor polish gaps |
| &lt;80 | Cramped, inconsistent, or cheap-feeling |

### Accessibility (15%)

| Score | Criteria |
|------:|----------|
| 95+ | WCAG AA+, 48dp+, works with larger text |
| 80 | AA on primary content; minor gaps |
| &lt;80 | Fails contrast or touch targets |

### Consistency (20%)

| Score | Criteria |
|------:|----------|
| 95+ | Zero hardcoded colors/sizes; only Driver UI kit |
| 80 | Mostly tokens; 1–2 exceptions documented |
| &lt;80 | Ad-hoc styling or duplicated widgets |

### Driver usability (25%)

| Score | Criteria |
|------:|----------|
| 95+ | Glanceable driving; TTU met; obvious next step; DNA + Commandments pass |
| 80 | Usable but hierarchy could be clearer |
| &lt;80 | Requires reading; primary action unclear |

### Performance (15%)

| Score | Criteria |
|------:|----------|
| 95+ | Smooth scroll/sheets; no unnecessary rebuilds |
| 80 | Acceptable; minor stutter |
| &lt;80 | Noticeable lag or heavy layout |

## PR template

```markdown
## Design score — [Screen name]
| Category | Score |
|----------|------:|
| Visual | /100 |
| Accessibility | /100 |
| Consistency | /100 |
| Driver usability | /100 |
| Performance | /100 |
| **Weighted total** | **/100** |

Million-Dollar Test: pass/fail
TTU: __ sec (target __ sec)
Visual regression: pass / baseline updated
```

## Map surfaces

Map chrome (floating controls, online toggle, earnings chip, ride cards) uses **Driver usability** at **1.25×** weight for that subsection only — map is ~30% of perceived quality.

## Below 95%?

Iterate. Do not merge unless CTO documents exception.
