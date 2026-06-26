# Driver Hotspots Map Redesign Plan

## Objective

Reduce visual clutter in Driver Hotspots by replacing "draw every zone as circles" with a zoom-aware, aggregated map that stays readable at city/regional zoom levels.

## Safety Constraints

- Driver app only (`apps/driver`).
- No backend schema changes.
- No changes to Supabase views/functions/contracts:
  - `fn_driver_hotspots_smart`
  - `zone_demand_live`
- No rider app code changes.

## Rendering Strategy

### Mode A: Aggregate Tiles (low zoom)

- Use zone centroids (`center_lat`, `center_lng`) and aggregate into grid cells.
- Merge multiple zones per cell by summing `waiting_passengers`.
- Draw one tile per cell (Mapbox polygon annotations).
- Filter out low-signal cells (e.g. demand < 2).
- At very low zoom, cap to top N cells by demand.

### Mode B: Detail Circles (high zoom)

- Keep current circle rendering per zone.
- Keep pulse/high-demand behavior.
- Keep score labels.

### Mode Switch

- Add hysteresis to avoid flicker:
  - Aggregate mode when zoom < 11.8
  - Detail mode when zoom > 13.2
  - Keep current mode in-between.

## UX Defaults

- Default hotspots filter to `High demand`.
- Preserve current top filter chips and best-zone bottom card.
- Keep recenter + refresh behavior unchanged.

## Performance Policy

- Camera monitor loop reads current zoom and redraws only when zoom change is meaningful.
- Aggregate mode draws fewer overlays than current circles.
- Detail mode remains viewport-focused by zoom policy (and existing filter/pulse behavior).

## Validation Checklist

1. Zoomed-out map is readable (no "green wallpaper").
2. Transition between tile/circle modes is stable (no flicker loops).
3. Filters (`High/Medium/Low/All`) still work as expected.
4. Best-zone card still tracks highest-demand visible logic.
5. Pull-to-refresh / refresh button still updates live data.
6. No backend diffs generated.
7. Rider flows unaffected (manual sanity pass only; no rider code touched).

## Rollout

1. Ship with a local driver-only fallback flag.
2. Validate on physical device.
3. Tune thresholds/cell-size based on real driving sessions.
4. Remove fallback once stable.
