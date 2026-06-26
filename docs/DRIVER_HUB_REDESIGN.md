# Driver Hub Redesign Design Document

**Date:** April 24, 2026
**Status:** Design Phase
**Priority:** High

## Overview

The Driver Hub is a central dashboard that drivers access from the home screen. The current implementation has too many quick action cards, making it cluttered and hard to find what drivers need right now. This redesign focuses on operational efficiency and reducing cognitive load.

## Current State

### Structure
1. **Header** - Title "Driver Hub" with status badge (online/offline/break)
2. **Live Strip** - Today's earnings, rides, demand indicator, return discount slider, pickup distance slider
3. **Quick Actions (5 cards):**
   - Earnings → Work screen
   - Hotspots → Driver Radar
   - Set your tariff → Tariff screen
   - Set your driving preference → Preferences
   - Suggestion for the app → App suggestion
4. **Safety Section** - 112 button, share trip
5. **Help Section** - Recent tickets, support link

### Problems

1. **Too many quick actions** - 5 separate cards creates clutter and scrolling fatigue
2. **Redundant navigation** - "Earnings" card duplicates the earnings display in Live Strip
3. **Settings scattered** - Tariff and driving preference are separate cards but both are settings
4. **Safety buried** - 112 button is at the bottom, not prominent enough for emergency use
5. **No clear hierarchy** - Everything looks equally important, making it hard to prioritize
6. **Live Strip cluttered** - Two sliders mixed with earnings/demand info

## Proposed Redesign

### Section 1: Live Stats (Hero)
**Purpose:** At-a-glance view of current performance

**Components:**
- Today's earnings (large number)
- Rides completed today
- Demand indicator (High/Normal badge with icon)
- **Tap interaction:** Tapping earnings opens Work screen

**Rationale:** Drivers need to quickly see how they're doing today. This replaces the separate "Earnings" quick action card.

---

### Section 2: Operational Controls
**Purpose:** What drivers need to adjust RIGHT NOW

**Components:**
- **Return discount slider** (0-40%)
  - Shows current percentage
  - Match chance indicator (low/medium/high)
  - "Open return rides" link
- **Pickup distance slider** (5-50 km)
  - Shows current distance
- **Hotspots button** (PROMINENT)
  - Larger than other quick actions
  - "Open Driver Radar and navigate to hot zones"
  - Consider making this a hero card with icon

**Rationale:** These are the most frequently adjusted settings. Drivers change these based on current conditions (time of day, location, demand). Hotspots is especially important as it helps drivers find demand zones.

---

### Section 3: Quick Access (Grouped)
**Purpose:** Less frequently used but still important features

**Structure:** Grouped logically instead of 5 separate cards

#### Work & Money
- **Tariffs** - Navigate to tariff editor (merged with preferences)
- **Earnings** - (Removed - tap Live Stats instead)

#### Navigation
- **Hotspots** - (Already prominent in Section 2)
- **Return trips** - (Link already in Section 2)

#### Settings
- **Preferences** - Includes tariff, driving preferences, account settings
- **Documents** - License, insurance, verification docs

#### Support
- **Support/Help** - Recent tickets, new tickets, FAQ
- **App suggestion** - Feature requests (moved to bottom or into Support)

**Rationale:** Grouping reduces cognitive load. Drivers can find what they need by category instead of scanning 5 separate cards.

---

### Section 4: Safety (Critical)
**Purpose:** Emergency and safety features

**Components:**
- **112 button** (FULL WIDTH, PROMINENT)
  - Red background
  - Larger than current implementation
  - Emergency icon
- **Share trip** (CONDITIONAL)
  - Only show when on a ride
  - Disabled state when not on ride with clear visual feedback

**Rationale:** Safety is critical. The 112 button should be impossible to miss. Share trip is only relevant during rides.

---

### Section 5: Help (Bottom)
**Purpose:** Support and information

**Components:**
- Recent tickets (limit to 3)
- "See all tickets" link
- Support link

**Rationale:** Support is less frequently accessed but still important. Keep it at the bottom for easy access when needed.

---

## What to Remove/Consolidate

### Remove
- **"Earnings" quick action card** - Duplicates Live Stats functionality
- **"Set your tariff" card** - Move to Preferences screen
- **"Set your driving preference" card** - Already in Preferences

### Consolidate
- **Tariff settings** - Merge into Preferences screen
- **App suggestion** - Move to Support section or bottom of hub

### Keep
- **Hotspots** - Make more prominent (operational need)
- **Return discount slider** - Frequently used
- **Pickup distance slider** - Frequently used
- **Safety section** - But make 112 more prominent
- **Help section** - Keep at bottom

---

## Visual Hierarchy

### Size & Prominence (from most to least)
1. **Live Stats** - Large numbers, hero section
2. **Operational Controls** - Sliders, prominent Hotspots button
3. **Safety** - Full-width 112 button
4. **Quick Access** - Grouped, smaller cards
5. **Help** - At bottom, smaller

### Color Coding
- **Live Stats** - Accent color for earnings
- **Operational** - Neutral with accent highlights
- **Safety** - Red for 112, neutral for share trip
- **Quick Access** - Neutral with icon colors
- **Help** - Neutral

---

## Premium Design Elements

### Design System Alignment
**IMPORTANT:** Use existing HeyCaby design system (`heycaby_ui` package). Do not introduce new colors, fonts, or hardcoded values.

- **Colors** - Use `HeyCabyColorTokens` from `heycaby_ui` (colors.accent, colors.card, colors.text, etc.)
- **Typography** - Use `HeyCabyTypography` from `heycaby_ui` (typo.displayLarge, typo.titleMedium, etc.)
- **Icons** - Use existing icon set (AppIcons, Material Icons)
- **Border radius** - Use existing tokens (12-20px as per current design)
- **Spacing** - Use existing spacing patterns (16-20px padding)

### Enhanced Interactions (Using Existing Tokens)
- **Smooth animations** - Use existing animation durations (200-300ms) from theme
- **Haptic feedback** - Use `HapticFeedback` from Flutter (light, medium, heavy impact)
- **Card press effect** - Scale transform (0.95) using existing animation curves
- **Slider feedback** - Use existing slider widget with haptic feedback on snap points

### Visual Polish (Within Design System)
- **Elevation** - Use existing shadow patterns from theme
- **Alpha values** - Use `withValues(alpha:)` on existing color tokens
- **Gradients** - Only use if already present in design system, otherwise stick to solid colors
- **Borders** - Use existing border colors (colors.border) with alpha adjustments

### Component Guidelines
- **Keep components under 300 lines** - Split into smaller widgets if needed
- **No hardcoded values** - All colors, fonts, spacing from design tokens
- **Reuse existing widgets** - Leverage `heycaby_ui` components where possible
- **Follow existing patterns** - Match current card, button, and slider implementations

### Specific Enhancements
- **Number animation** - Use simple count-up animation (existing Tween)
- **Badge pulse** - Use existing animation controller for subtle pulse
- **Loading states** - Use existing CircularProgressIndicator or shimmer
- **Error states** - Use existing error card patterns from app

### What NOT to Do
- **NO new color definitions** - Only use existing `HeyCabyColorTokens`
- **NO new font families** - Only use existing `HeyCabyTypography`
- **NO hardcoded hex codes** - All colors from tokens
- **NO hardcoded font sizes** - All sizes from typography tokens
- **NO custom shadows** - Use existing elevation system
- **NO glassmorphism** - Not in current design system
- **NO gradient borders** - Not in current design system
- **NO custom sliders** - Use existing Flutter Slider with theme

### Implementation Approach
- **Extract reusable widgets** - Create small, focused widgets (< 300 lines)
- **Use composition** - Build complex UI from simple components
- **Follow existing patterns** - Look at current hub implementation for style
- **Test with light/dark themes** - Ensure design tokens work in both modes

### Internationalization (i18n) Requirements
**CRITICAL: All text must be internationalized**

- **Use DriverStrings** - All user-facing text from `../l10n/driver_strings.dart`
- **NO hardcoded strings** - Never write text directly in widgets
- **Currency formatting** - Use locale-aware formatters (€, decimal separators)
- **Date/time formatting** - Use `intl` package with locale-aware formats
- **Number formatting** - Use locale-aware formatters (thousands separators)
- **RTL support** - Ensure layout works for right-to-left languages (if needed)
- **Text expansion** - Design for text that may be longer in some languages
- **Pluralization** - Use proper plural forms (ride vs rides)

### i18n Implementation Examples
```dart
// ✅ CORRECT - Use DriverStrings
Text(DriverStrings.earnings)

// ❌ WRONG - Hardcoded text
Text('Earnings')

// ✅ CORRECT - Locale-aware currency
NumberFormat.currency(locale: 'nl_NL', symbol: '€').format(amount)

// ✅ CORRECT - Locale-aware date
DateFormat('d MMM, HH:mm', locale).format(date)

// ✅ CORRECT - Pluralization
Text(rides == 1 ? DriverStrings.ride : DriverStrings.rides)
```

### Adding New Strings
When adding new text to the hub:
1. Add string to `apps/driver/lib/l10n/driver_strings.dart`
2. Provide both English and Dutch translations
3. Use consistent naming convention
4. Document context if ambiguous

---

## Context-Aware Behavior

### When On Ride
- Show active ride card in Live Stats
- Enable "Share trip" button
- Hide or disable operational controls (can't change preferences mid-ride)
- Show ride ETA and destination

### When Between Rides
- Show today's performance in Live Stats
- Enable all operational controls
- Disable "Share trip" with clear visual feedback

### When Offline
- Show "Go online" CTA in Live Stats
- Disable operational controls with explanation
- Show "Go online to start earning" message

---

## Additional Improvements

### Quick Stats Row
Add below Live Stats:
- Rides today
- Hours worked today
- Earnings per hour
- Week-to-date earnings

### Smart Suggestions
When demand is high in a zone:
- "High demand in Centrum - want to navigate there?"
- Quick action to open hotspots centered on that zone

### Long-Press Interactions
- Long-press earnings → Open detailed earnings breakdown
- Long-press status → Open status history
- Long-press hotspots → Open hotspots with current location centered

### Progress Indicators
- Add progress bar for daily earnings goal (if set)
- Add progress bar for weekly hours goal (if set)
- Visual feedback for slider values

---

## Implementation Notes

### Critical Constraints
**DO NOT BREAK EXISTING FUNCTIONALITY**

- **All existing cards work** - Only reorganizing layout, not removing features
- **Keep all providers** - Do not change Riverpod providers or data flows
- **Keep all navigation** - All existing routes must continue to work
- **Incremental implementation** - Can implement section by section without breaking app
- **Test each section** - Verify existing functionality still works after each change

### File Changes
- `/apps/driver/lib/widgets/driver_hub_sheet.dart` - Main hub UI (reorganize existing sections)
- `/apps/driver/lib/widgets/driver_hub_sections.dart` - Section components (reuse existing)
- `/apps/driver/lib/screens/driver_preferences_screen.dart` - Add tariff settings (new feature, not breaking)

### What Stays the Same
- **All existing providers** - `driverEarningsProvider`, `zoneDemandProvider`, etc.
- **All existing data services** - `DriverDataService` methods unchanged
- **All existing navigation** - Routes `/driver/tariffs`, `/driver/hotspots`, etc. still work
- **All existing logic** - Slider debouncing, discount calculation, etc. unchanged
- **All existing widgets** - Reuse `_HubQuickActionCard`, `_HubLiveStrip`, etc.

### What Changes
- **Layout reorganization** - Move sections around, change visual hierarchy
- **Remove redundant cards** - "Earnings" card (functionality moved to Live Stats)
- **Group quick actions** - Combine into logical groups instead of 5 separate cards
- **Enhance visual polish** - Add animations, better spacing (using existing design tokens)

### Safe Implementation Approach
1. **Copy existing file** - Backup `driver_hub_sheet.dart` before changes
2. **Implement section by section** - Start with Live Stats, test, then move to next
3. **Keep old code commented** - Comment out instead of delete until verified
4. **Test after each change** - Run app and verify existing features still work
5. **Revert if broken** - If something breaks, revert to previous working state

### Component Structure
```
DriverHubSheet
├── Header (title + status badge)
├── LiveStatsSection
│   ├── Earnings display
│   ├── Rides count
│   ├── Demand indicator
│   └── Quick stats row (optional)
├── OperationalControlsSection
│   ├── Return discount slider
│   ├── Pickup distance slider
│   └── Hotspots button (prominent)
├── QuickAccessSection
│   ├── Preferences card
│   ├── Documents card
│   └── Support card
├── SafetySection
│   ├── 112 button (full width)
│   └── Share trip (conditional)
└── HelpSection
    ├── Recent tickets
    └── Support link
```

### State Management
- Keep existing Riverpod providers
- Add context-aware state (on ride vs between rides)
- Add quick stats provider (hours worked, earnings per hour)

### Navigation
- Remove `/driver/tariffs` quick action (merge into preferences)
- Keep `/driver/hotspots` (make more prominent)
- Keep `/driver/preferences` (add tariff settings)
- Keep `/driver/support` (add app suggestion)

---

## Success Metrics

### Qualitative
- Drivers can find what they need in < 3 seconds
- Drivers report hub is "less cluttered"
- 112 button is easily visible
- Hotspots is more frequently accessed

### Quantitative
- Reduce average time in hub by 30%
- Increase hotspots usage by 20%
- Increase return discount adjustments (if it's easier to find)
- Decrease support tickets about "how do I change X"

---

## Future Enhancements

### Phase 2
- Add personalized recommendations based on driver behavior
- Add earnings projections based on current rates and demand
- Add leaderboards or gamification elements
- Add quick shortcuts for common actions (long press)

### Phase 3
- Add AI-powered suggestions for optimal pickup distance
- Add predictive demand forecasting
- Add route optimization suggestions
- Add fuel cost tracking

---

## References

- Current implementation: `/apps/driver/lib/widgets/driver_hub_sheet.dart`
- Driver home screen: `/apps/driver/lib/screens/driver_home_screen.dart`
- Preferences screen: `/apps/driver/lib/screens/driver_preferences_screen.dart`
- Hotspots screen: `/apps/driver/lib/screens/driver_hotspots_screen.dart`
