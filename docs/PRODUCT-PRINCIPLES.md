# Product Principles

**Status:** Frozen — one page, permanent  
**Audience:** Product, design, engineering, support, founders  
**When in doubt:** Read this before building anything new.

Technical *how* lives elsewhere. This answers **why** HeyCaby exists and **what we refuse to become**.

| Need | Document |
|------|----------|
| What we build | [New-Backend-Heycaby.md](../New-Backend-Heycaby.md) |
| Build order | [HEYCABY-LAUNCH-ROADMAP.md](./HEYCABY-LAUNCH-ROADMAP.md) |
| Ride behavior | [RIDE_STATE_MACHINE.md](../apps/driver/docs/RIDE_STATE_MACHINE.md) |
| When things break | [OPERATIONS-PLAYBOOK.md](./OPERATIONS-PLAYBOOK.md) |

**Rule:** If the answer is already in one of the core documents, don't write another document — improve that one or write code.

---

## Why HeyCaby exists

Professional taxi drivers in the Netherlands deserve software that respects their craft: fair economics, clear rules, and tools that work on a **12-hour shift** — not a demo.

HeyCaby connects riders with **licensed professional drivers**. We are not a gig-economy race to the bottom. We are infrastructure for drivers who already know how to drive; our job is to remove friction, not replace judgment.

---

## Driver first

Every product decision starts with the driver on a real shift:

- Can they see what they need in **one glance**?
- Can they act with **one hand** while parked or at a light?
- If the phone dies, do they **lose their day**?

Riders matter deeply — but a broken driver experience breaks the marketplace. Ship driver operational readiness before rider polish.

---

## Premium means calm, not flashy

**Premium** is not gradients for their own sake. It is:

- **Predictable** — the same action always does the same thing  
- **Fast** — accept, navigate, complete without hunting  
- **Honest** — status, earnings, and fees are never vague  
- **Quiet** — no clutter, no panic UI, no dark patterns  

If it feels impressive in a screenshot but stressful at 06:00 in Rotterdam rain, it is not premium.

---

## Simplicity over cleverness

We do not solve product problems with more architecture.

| We choose | Over |
|-----------|------|
| One clear screen | Three nested modals |
| Server truth + simple client | Client guessing state |
| Explicit driver action | Magic automation that fails silently |
| Fewer features that work | Feature lists that break on edge cases |

When complexity is unavoidable (billing, compliance, dispatch), **hide it from the driver** — show only the next step.

---

## Economics we protect

These are non-negotiable:

1. **HeyCaby does not take commission on ride payments.** The rider pays the driver directly.  
2. Platform fees are **subscription / tooling**, not a hidden tax on every fare.  
3. Post-ride payment flows are for **driver bookkeeping and tax**, not platform settlement or dispute arbitration.  
4. Drivers keep **pricing autonomy** within market rules (tariffs, profiles, transparency to riders).

Never ship copy or UX that implies HeyCaby is the merchant of the ride.

---

## Trust and safety

- Chat and contact exist **only during an active ride** — not before, not after.  
- Identity and documents are serious; verification UX is boring on purpose.  
- Emergency (112) and safety tools must be **obvious**, not buried in settings.  
- We tell drivers and riders the truth when something fails — no silent failures.

---

## What every feature should feel like

Before shipping, ask:

1. **Would a 20-year veteran driver trust this on shift 8?**  
2. **Does it survive bad GPS, bad signal, and a reboot?**  
3. **Is the happy path ≤ 3 taps?**  
4. **Does the rider see the same reality** (sync contract)?  
5. **Can support explain it in one sentence** ([OPERATIONS-PLAYBOOK.md](./OPERATIONS-PLAYBOOK.md))?

If any answer is no, it is not ready — regardless of how good it looks.

---

## What we refuse to build (for now)

We say **no** until the core loop is proven with real drivers:

- Multi-country expansion before Netherlands works flawlessly  
- AI pricing, surge gamification, and driver leagues before ops readiness  
- Platform-as-payment-processor or escrow for fares  
- Social feeds that distract from earning  
- Voice-first UI before touch flows are complete (design for voice; ship touch first)  
- Infrastructure for millions before **50–100 drivers** in one city love the product  

Scale (Go, Redis, multi-region, advanced dispatch) is **Program 7** — after product–market fit, not before.

---

## How we ship

1. Build one **small, production-safe** change  
2. Smoke test it  
3. Observe in real use  
4. Freeze it  
5. Move on  

Planning and governance are **complete**. Success now is **disciplined execution** — code, observation, iteration.

---

*Drivers earn. Riders arrive. HeyCaby stays out of the way.*
