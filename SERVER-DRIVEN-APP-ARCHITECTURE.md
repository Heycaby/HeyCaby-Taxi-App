# Server-Driven App Architecture (Reference)

This note documents a scalable approach where the app stays stable while content and behavior evolve from backend APIs.

## Core Idea

- **App = stable shell**
  - Navigation, core screens, permissions, security, offline fallback, crash-safe behavior.
- **Backend = dynamic layer**
  - Tasks, content, messaging, rules, feature flags, UI copy, rollout configs.
- **Runtime fetch**
  - App pulls configuration/content from backend and renders based on that data.

## Why Use This Pattern

- Faster iteration without frequent store updates
- Controlled rollouts and A/B testing
- Market/user-specific behavior
- Emergency content/rule updates
- Better operational agility

## iOS/App Store Guardrail

- Safe: updating **content/config/data** from server.
- Not safe: downloading/executing arbitrary new app code that changes core executable behavior at runtime.
- Keep the shipped app executable stable; drive flexible behavior via data/config.

## Recommended Building Blocks

1. **Versioned config endpoint**
   - Include fields like:
     - `schema_version`
     - `min_app_version`
     - `feature_flags`
     - `ui_copy`
     - `rules`

2. **Feature flags**
   - Turn features on/off safely (e.g., receipt flow, rider nudge flow).

3. **Rules via data**
   - Keep thresholds/messages/timeouts server-defined where possible.

4. **Client fallbacks**
   - App must still function if config fetch fails.
   - Use safe defaults in shipped app.

5. **Cache + TTL + last-known-good**
   - Cache server config and reuse if network fails.

6. **Kill switch**
   - Backend can disable risky features immediately.

7. **Observability**
   - Log config version + decisions for debugging and support.

## Where This Fits in HeyCaby

Good candidates for server-driven behavior:

- Driver/rider message templates
- Nudge templates ("driver is outside", "driver nearby")
- Reminder wording and display rules
- Receipt template fields and labels
- Feature toggles per market/language

Keep hard-critical logic local and deterministic:

- Authentication/session safety
- Permission handling
- Safety-critical ride state transitions
- Compliance/legal gating

## Summary

Ship a robust, static app shell once. Evolve content, copy, and configurable behavior from backend with strict guardrails and fallbacks.

