---
name: rider-file-structure
description: Guides the agent in structuring Rider screens, widgets, and providers so that files and components stay below 300 lines while keeping the booking flow clean and maintainable.
---

# Rider File Structure Skill

## When to use this skill

Use this skill whenever you:
- Create new Rider screens or widgets.
- Refactor existing large Rider files.
- Move logic between screens, widgets, and providers.

## Goals

- Keep every Dart file under roughly 300 lines when practical.
- Keep each widget, class, and function body clearly under 300 lines.
- Maintain the Rider booking flow readability while splitting responsibilities.

## Recommended layout

- Screens:
  - `apps/rider/lib/screens/` contains top-level screens.
  - Each screen file should focus on composition and routing, not all logic.
- Widgets:
  - `apps/rider/lib/widgets/` holds reusable components:
    - Bottom sheet contents.
    - Tiles and list items.
    - Modals and dialogs.
    - Common buttons or info rows.
- Providers and services:
  - `apps/rider/lib/providers/` for Riverpod state (booking, ride request, settings, etc.).
  - `apps/rider/lib/services/` for Rider-specific services that do not belong in shared packages.

## Splitting large screens

- For large map-based screens (for example, home, trip summary):
  - Extract the map section into a dedicated widget (for example, `HomeMapView`, `TripSummaryMapView`).
  - Extract the bottom sheet into its own widget file (for example, `HomeBottomSheet`, `TripSummarySheet`).
  - Keep the main screen widget small, delegating work to these components.
- For configuration screens (booking options, vehicle, payment):
  - Move complex form sections and modals into separate widgets.
  - Keep the screen widget focused on wiring providers, validation, and navigation.

## Refactor approach

- When a file grows beyond 300 lines:
  - Identify logical sections: map, sheet, header, list.
  - Move each section into a separate widget class, ideally in its own file under `widgets/`.
  - Re-import and use those widgets from the original screen.
- Always preserve behavior first; refactors must not change the flow or backend interactions.

