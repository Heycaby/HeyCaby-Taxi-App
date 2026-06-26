# Driver Profile Vehicle Section Unification

**Date:** April 24, 2026
**Status:** Design Phase
**Priority:** High

## Overview

The driver profile screen currently has duplicate vehicle information:
1. Large vehicle card with plate, vehicle display, photos
2. Vehicle link in preferences section with status badge

This redesign unifies these into a single, expandable vehicle card with all critical information prominently displayed.

## Current State

### Problems
- **Duplicate vehicle info** - Vehicle appears twice (card + preferences)
- **Plate number not prominent enough** - Drivers need it for parking tickets
- **APK expiry not visible** - Critical information missing
- **No expandable UI** - All info always visible, can't collapse

### Current Structure
1. **Profile Card** - Photo, name, email, rating
2. **Vehicle Card** - Plate, vehicle display, photos, verification status
3. **Preferences Section** - Vehicle (with badge), Preferences

## Proposed Redesign

### Unified Vehicle Card (Expandable)

#### Collapsed State (Default)
**Purpose:** Show most critical info at a glance

**Components:**
- **Vehicle photo** (medium size, what riders see)
- **Plate number** (BIG, BOLD - primary focus)
- **Vehicle name** (e.g., "Nissan Leaf")
- **Verification checkmark** (green ✓ if verified taxi)
- **APK expiry** (with warning if expiring soon)
- **Dropdown indicator** (chevron icon, rotates on expand)
- **Tap interaction** - Tapping expands/collapses the card

**Visual Hierarchy:**
1. Plate number (largest, boldest)
2. Vehicle photo
3. Vehicle name
4. APK expiry
5. Verification checkmark

#### Expanded State
**Purpose:** Show additional details when needed

**Additional Components:**
- **Full vehicle photo gallery** (tap to view all photos)
- **APK expiry date** (full date, not just status)
- **Verification status badge** (detailed status text)
- **Vehicle details link** - "Edit vehicle details" button
- **Support link** - "Contact support for vehicle change" (if needed)

**Interaction:**
- Tap card again to collapse
- Tap vehicle photo to open gallery
- Tap "Edit vehicle details" to navigate to vehicle screen

### Removed Elements
- **Vehicle link in preferences section** - No longer needed, unified in vehicle card

## Visual Design

### Collapsed State Layout
```
┌─────────────────────────────────────────┐
│ [Vehicle Photo]  Plate: XX-XX-XX      │
│                  Nissan Leaf            │
│                  ✓ Verified  APK: 12/24│
│                                  [▼]    │
└─────────────────────────────────────────┘
```

### Expanded State Layout
```
┌─────────────────────────────────────────┐
│ [Vehicle Photo]  Plate: XX-XX-XX      │
│                  Nissan Leaf            │
│                  ✓ Verified  APK: 12/24│
│                                  [▲]    │
│                                         │
│ ─────────────────────────────────────  │
│                                         │
│ APK Expiry: 24 December 2026           │
│ Status: Geverifieerd (✓)               │
│                                         │
│ [View All Photos]                       │
│                                         │
│ [Edit Vehicle Details]                  │
│ [Contact Support] (if needed)           │
└─────────────────────────────────────────┘
```

## Design System Alignment

**IMPORTANT:** Use existing HeyCaby design system

- **Colors** - `HeyCabyColorTokens` (colors.success for verified, colors.warning for expiring)
- **Typography** - `HeyCabyTypography` (typo.displayLarge for plate, typo.titleMedium for vehicle name)
- **Icons** - Existing icon set (AppIcons, Material Icons)
- **Animations** - Existing animation curves (200-300ms for expand/collapse)
- **Spacing** - Existing spacing patterns (16-20px padding)

### Plate Number Styling
- **Font size** - `typo.displayLarge` (largest available)
- **Font weight** - `FontWeight.w900` (boldest)
- **Color** - `colors.text` (high contrast)
- **Letter spacing** - Slightly increased for readability
- **Background** - Subtle accent background to make it stand out

### APK Expiry Styling
- **Normal** - `colors.textMid` with neutral background
- **Expiring soon (< 30 days)** - `colors.warning` with warning background
- **Expired** - `colors.error` with error background

### Verification Checkmark
- **Verified taxi** - Green circle with white checkmark
- **Not verified** - Gray circle with question mark
- **Not taxi** - Red circle with X

## Implementation Notes

### File Changes
- `/apps/driver/lib/screens/driver_profile_screen.dart` - Main profile UI
- Remove vehicle link from preferences section
- Create new `_UnifiedVehicleCard` widget

### Component Structure
```
_UnifiedVehicleCard (StatefulWidget)
├── Collapsed state
│   ├── Vehicle photo
│   ├── Plate number (BIG, BOLD)
│   ├── Vehicle name
│   ├── Verification checkmark
│   ├── APK expiry
│   └── Dropdown indicator
└── Expanded state
    ├── All collapsed elements
    ├── APK expiry date (full)
    ├── Verification status badge
    ├── Photo gallery button
    ├── Edit vehicle details button
    └── Contact support button (conditional)
```

### State Management
- Use `bool _isExpanded` in widget state
- Animate expand/collapse with `AnimatedSize` or `AnimatedContainer`
- Keep existing providers (`driverComplianceProvider`, `driverProfileProvider`)

### Data Requirements
- Vehicle photo URL (what riders see)
- License plate (from compliance or profile)
- Vehicle display name
- APK expiry date
- Verification status (rdw_verified_taxi, etc.)
- Vehicle photo URLs (gallery)

### Critical Constraints
**DO NOT BREAK EXISTING FUNCTIONALITY**

- Keep all existing providers
- Keep all navigation routes
- Keep all data services
- Only reorganize UI, not data flow
- Test plate number visibility (parking ticket use case)

## Internationalization (i18n)

### Required Strings
Add to `driver_strings.dart`:
- `vehiclePlate` - "License plate"
- `vehicleApkExpiry` - "APK expiry"
- `vehicleVerified` - "Verified taxi"
- `vehicleNotVerified` - "Not verified"
- `vehicleNotTaxi` - "Not a taxi"
- `vehicleExpandHint` - "Tap for more details"
- `vehicleCollapseHint` - "Tap to collapse"
- `viewAllPhotos` - "View all photos"
- `editVehicleDetails` - "Edit vehicle details"
- `contactSupportVehicle` - "Contact support for vehicle change"
- `apkExpiringSoon` - "Expiring soon"
- `apkExpired` - "Expired"

### Format
- Plate number: No formatting needed, display as-is
- APK date: Locale-aware date format (DD/MM/YYYY)
- All text from `DriverStrings`

## Success Metrics

### Qualitative
- Drivers can find plate number in < 2 seconds
- Plate number is readable from arm's length
- APK expiry is clearly visible
- Verification status is obvious at a glance
- Expand/collapse animation is smooth

### Quantitative
- Reduce profile screen scroll by 20% (collapsed state)
- Increase vehicle details access by 15%
- Decrease support tickets about "where is my plate"

## Future Enhancements

### Phase 2
- Add plate number copy to clipboard (long press)
- Add parking reminder based on location
- Add vehicle maintenance reminders
- Add fuel/charging station finder

### Phase 3
- Show vehicle in map view
- Add vehicle sharing (if applicable)
- Add vehicle history (past vehicles)
- Add vehicle comparison (if multiple vehicles)

## References

- Current implementation: `/apps/driver/lib/screens/driver_profile_screen.dart`
- Vehicle screen: `/apps/driver/lib/screens/driver_vehicle_screen.dart`
- Compliance provider: `/apps/driver/lib/providers/driver_data_providers.dart`
