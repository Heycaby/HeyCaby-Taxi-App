# Driver Status Control Redesign Handoff

Current reference for the Driver home status control. This supersedes the older
gradient-slider notes in broad design docs. Keep this work presentation-layer
only: do not change status RPCs, driver presence business rules, dispatch logic,
or `driver_locations` write behavior.

## Direction

Use one clear status readout and one clear status input.

- Top status chip is the single source of truth for state and earnings.
- Segmented control is only the input for `Offline`, `Pauze`, and `Online`.
- Hint row and segmented control live in one card because they are one decision.
- Ride actions live under a labeled `Ritten` group.
- Settings live in a labeled list with visible toggle labels.

## Component Shape

```text
DriverStatusHeader
  - status dot
  - state label
  - today's earnings

DriverStatusDecisionCard
  - hint icon
  - contextual hint copy
  - DriverStatusSegmentedControl

RidesActionGrid
  - Geplande ritten
  - Vandaag
  - Ritwissel
  - Retourritten

DriverSettingsList
  - Auto-accept return rides
  - Show rides today on map
```

## Color System

Keep the familiar green palette, but add enough contrast for real driver use:
daylight, glare, one-handed use, and quick glances while parked.

- **Online:** brand/success green is the primary positive accent.
- **Break/Pauze:** use amber as a small semantic cue, not a full orange panel.
- **Offline:** use neutral gray for the status dot and text support; avoid making
  the whole offline state feel like an error.
- **Failure/blocked:** reserve red for failed RPC writes, blocked actions, or
  destructive/end-shift confirmations.
- **Card border:** increase contrast slightly from the mockup so white cards do
  not disappear outdoors.
- **Segment thumb:** use a stronger border/shadow than the outer card, so the
  selected state is visible without reading twice.
- **Settings toggles:** active toggle uses green; inactive uses neutral outline.

Use existing theme tokens, not raw hex values:

- `colors.primary` or `colors.success` for online/active green.
- `colors.warning` for break accents.
- `colors.error` only for failures, destructive confirmations, or blocked
  state feedback.
- `colors.text`, `colors.textSecondary`, and `colors.textSoft` for hierarchy.
- Existing card/surface/border tokens for backgrounds and outlines.

If a token is missing, add it to the theme/token source first. Do not hardcode a
one-off color inside the widget.

## Haptics

Haptics are part of the design, not decoration. The control should feel like it
locks into real positions.

- Tap a segment: `HapticService.selectionClick()` immediately.
- Drag across a segment boundary: one `selectionClick()` per newly crossed
  segment, debounced so it does not chatter.
- Successful move to `Online`: `HapticService.heavyTap()` plus existing online
  sound.
- Successful move to `Pauze`: `HapticService.mediumTap()` plus existing break
  sound.
- Successful move to `Offline`: `HapticService.lightTap()` plus existing offline
  sound.
- Blocked action or failed RPC: `HapticService.error()`, show the existing
  failure UI, and snap the thumb back to the previous confirmed state.

Do not fire success haptics until the backend write confirms. The immediate
selection click is allowed as tactile input feedback, but the stronger haptic
belongs to the confirmed state change.

## Interaction Rules

- Tapping a segment and dragging the thumb should use the same transition path.
- While the status write is in flight, disable the segmented control and show a
  subtle busy state on the thumb.
- If the write fails, restore the thumb to the previous confirmed state.
- Test all transitions after backend fixes: `Offline -> Pauze`,
  `Pauze -> Online`, `Online -> Pauze`, `Pauze -> Offline`, and
  `Online -> Offline`.
- The top chip should update only after confirmed state, not during tentative
  drag.

## Visual Polish

- Keep cards flat and operational; avoid the old red/green blurred gradient.
- Use a slightly heavier border on the status decision card than secondary
  action cards.
- Keep all three segment labels visible at all times.
- The active label uses stronger text weight; inactive labels stay readable.
- Keep icon style consistent across all four ride cards.
- Add enough vertical spacing that `Ritten` and `Settings` scan as separate
  groups, but do not make the page feel like a marketing layout.

## Copy

Dutch copy should stay short and action-oriented:

- Offline: `Ga online om live ritaanvragen in jouw zone te zien.`
- Pauze: `Je pauze is actief. Ga online om ritten te zien.`
- Online: show zone or ride supply context, for example
  `Je bent live in jouw zone.`

## QA Checklist

- iPhone width 375px: no clipped segment labels.
- iPhone width 414px: card spacing still feels dense and operational.
- Outdoor contrast pass: selected segment and top state are visible at a glance.
- Haptic pass: no double buzz on one transition.
- Failure pass: failed Supabase write snaps back and gives error feedback.
- State pass: top chip, segmented control, and backend state agree after every
  transition.
