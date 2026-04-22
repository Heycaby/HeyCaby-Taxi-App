# HeyCaby Spacing System Guide

## Overview

The HeyCaby spacing system is a hierarchical design token system that creates visual harmony and communicates relationships between UI elements through consistent spacing.

## Core Principles

### 1. **Spacing as a Language of Hierarchy**
Each level of spacing signals a relationship between elements. Consistent application creates an intuitive and balanced interface.

### 2. **The 10px Rule**
**Never exceed 10px between individual elements.** Once you cross this threshold, elements feel disjointed rather than related.

### 3. **Nested Spacing**
The deeper a group is nested, the tighter the spacing should become. This creates natural visual grouping.

### 4. **Breathing Room**
At minimum, use 6px between individual elements to create subtle breathing room.

---

## Spacing Hierarchy

### **Element Level (6-10px)**
Individual elements and their immediate relationships.

| Token | Value | Usage |
|-------|-------|-------|
| `HeyCabySpacing.elementMin` | 6px | Icon-to-text, label-to-value, tightly coupled pairs |
| `HeyCabySpacing.element` | 8px | List items, form fields, related content |
| `HeyCabySpacing.elementMax` | 10px | Grouped elements needing slight separation |

**Example:**
```dart
Row(
  children: [
    Icon(Icons.star),
    SizedBox(width: HeyCabySpacing.element), // 8px
    Text('4.5 rating'),
  ],
)
```

---

### **Component Level (12-16px)**
Internal component padding and element groups.

| Token | Value | Usage |
|-------|-------|-------|
| `HeyCabySpacing.buttonHorizontal` | 12px | Button horizontal padding |
| `HeyCabySpacing.buttonVertical` | 8px | Button vertical padding |
| `HeyCabySpacing.componentSmall` | 12px | Chips, tags, small cards |
| `HeyCabySpacing.component` | 16px | Cards, containers, input fields |

**Example:**
```dart
Container(
  padding: EdgeInsets.all(HeyCabySpacing.component), // 16px
  decoration: BoxDecoration(
    color: colors.card,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    children: [
      Text('Card Title'),
      SizedBox(height: HeyCabySpacing.element), // 8px
      Text('Card content'),
    ],
  ),
)
```

---

### **Section Level (20-30px)**
Major sections, wrappers, and screen-level spacing.

| Token | Value | Usage |
|-------|-------|-------|
| `HeyCabySpacing.sectionMedium` | 20px | Between card groups, related sections |
| `HeyCabySpacing.section` | 24px | Major content sections, screen padding |
| `HeyCabySpacing.sectionLarge` | 30px | Top-level wrappers, airy screen sections |

**Example:**
```dart
Column(
  children: [
    ProfileSection(),
    SizedBox(height: HeyCabySpacing.section), // 24px
    SettingsSection(),
    SizedBox(height: HeyCabySpacing.section), // 24px
    ActionsSection(),
  ],
)
```

---

## Specialized Spacing

### Screen Edge Padding
```dart
Padding(
  padding: EdgeInsets.all(HeyCabySpacing.screenEdge), // 20px
  child: YourContent(),
)

// Or use helper
Padding(
  padding: HeyCabyEdgeInsets.screenAll,
  child: YourContent(),
)
```

### Button Padding
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(
      horizontal: HeyCabySpacing.buttonHorizontal, // 12px
      vertical: HeyCabySpacing.buttonVertical,     // 8px
    ),
  ),
  child: Text('Button'),
)

// Or use helper
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: HeyCabyEdgeInsets.button,
  ),
  child: Text('Button'),
)
```

### List Items
```dart
ListView.separated(
  itemBuilder: (context, index) => ListTile(...),
  separatorBuilder: (context, index) => SizedBox(
    height: HeyCabySpacing.listItem, // 8px
  ),
)

// Or use helper
separatorBuilder: (context, index) => HeyCabyGaps.vertical,
```

---

## Nested Spacing Levels

Use these tokens to maintain proper hierarchy as nesting increases:

```dart
// Level 1: Outermost wrapper (30px)
Container(
  padding: EdgeInsets.all(HeyCabySpacing.level1),
  child: Column(
    children: [
      // Level 2: Major sections (24px)
      Container(
        padding: EdgeInsets.all(HeyCabySpacing.level2),
        child: Column(
          children: [
            // Level 3: Content blocks (16px)
            Container(
              padding: EdgeInsets.all(HeyCabySpacing.level3),
              child: Row(
                children: [
                  Icon(...),
                  SizedBox(width: HeyCabySpacing.level5), // 8px
                  Text(...),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
)
```

---

## Helper Classes

### HeyCabyEdgeInsets
Pre-defined EdgeInsets for common patterns:

```dart
HeyCabyEdgeInsets.screenAll          // EdgeInsets.all(20)
HeyCabyEdgeInsets.screenHorizontal   // EdgeInsets.symmetric(horizontal: 20)
HeyCabyEdgeInsets.componentAll       // EdgeInsets.all(16)
HeyCabyEdgeInsets.button             // EdgeInsets.symmetric(h: 12, v: 8)
HeyCabyEdgeInsets.modal              // EdgeInsets.all(24)
```

### HeyCabyGaps
Pre-defined SizedBox for common gaps:

```dart
HeyCabyGaps.verticalMin              // SizedBox(height: 6)
HeyCabyGaps.vertical                 // SizedBox(height: 8)
HeyCabyGaps.verticalMax              // SizedBox(height: 10)
HeyCabyGaps.verticalComponent        // SizedBox(height: 16)
HeyCabyGaps.verticalSection          // SizedBox(height: 24)
HeyCabyGaps.verticalSectionLarge     // SizedBox(height: 30)

HeyCabyGaps.horizontalMin            // SizedBox(width: 6)
HeyCabyGaps.horizontal               // SizedBox(width: 8)
HeyCabyGaps.horizontalMax            // SizedBox(width: 10)
HeyCabyGaps.horizontalComponent      // SizedBox(width: 16)
```

---

## Real-World Examples

### Example 1: Card with Proper Hierarchy
```dart
Container(
  padding: HeyCabyEdgeInsets.componentAll, // 16px (Level 3)
  decoration: BoxDecoration(
    color: colors.card,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header with icon and title
      Row(
        children: [
          Icon(Icons.person, size: 24),
          HeyCabyGaps.horizontal, // 8px (Level 5)
          Text('Profile', style: typo.headingMedium),
        ],
      ),
      HeyCabyGaps.verticalMax, // 10px (Level 4)
      
      // Content
      Text('John Doe', style: typo.bodyLarge),
      HeyCabyGaps.verticalMin, // 6px (Level 6)
      Text('john@example.com', style: typo.bodySmall),
    ],
  ),
)
```

### Example 2: Screen Layout
```dart
Scaffold(
  body: SafeArea(
    child: Padding(
      padding: HeyCabyEdgeInsets.screenAll, // 20px
      child: Column(
        children: [
          HeaderSection(),
          HeyCabyGaps.verticalSection, // 24px
          
          StatsCard(),
          HeyCabyGaps.verticalSection, // 24px
          
          ActionButtons(),
        ],
      ),
    ),
  ),
)
```

### Example 3: Form with Proper Spacing
```dart
Column(
  children: [
    TextField(
      decoration: InputDecoration(
        contentPadding: HeyCabyEdgeInsets.componentAll, // 16px
        labelText: 'Email',
      ),
    ),
    SizedBox(height: HeyCabySpacing.formField), // 16px
    
    TextField(
      decoration: InputDecoration(
        contentPadding: HeyCabyEdgeInsets.componentAll, // 16px
        labelText: 'Password',
      ),
    ),
    HeyCabyGaps.verticalSection, // 24px
    
    ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: HeyCabyEdgeInsets.button, // h: 12px, v: 8px
      ),
      child: Text('Sign In'),
    ),
  ],
)
```

---

## Quick Reference Table

| Use Case | Token | Value |
|----------|-------|-------|
| Icon to text | `elementMin` | 6px |
| List item gap | `element` | 8px |
| Group separation | `elementMax` | 10px |
| Button padding (H) | `buttonHorizontal` | 12px |
| Button padding (V) | `buttonVertical` | 8px |
| Card padding | `component` | 16px |
| Form field gap | `formField` | 16px |
| Screen edge | `screenEdge` | 20px |
| Section gap | `section` | 24px |
| Modal padding | `modal` | 24px |
| Large wrapper | `sectionLarge` | 30px |

---

## Migration Guide

### Before (Hardcoded):
```dart
Container(
  padding: EdgeInsets.all(16),
  child: Column(
    children: [
      Row(
        children: [
          Icon(...),
          SizedBox(width: 8),
          Text(...),
        ],
      ),
      SizedBox(height: 12),
      Text(...),
    ],
  ),
)
```

### After (Token-based):
```dart
Container(
  padding: HeyCabyEdgeInsets.componentAll,
  child: Column(
    children: [
      Row(
        children: [
          Icon(...),
          HeyCabyGaps.horizontal,
          Text(...),
        ],
      ),
      HeyCabyGaps.verticalMax,
      Text(...),
    ],
  ),
)
```

---

## Best Practices

1. **Always use tokens** - Never hardcode spacing values
2. **Think hierarchy** - Tighter spacing = closer relationship
3. **Respect the 10px rule** - Don't exceed for individual elements
4. **Use helpers** - `HeyCabyGaps` and `HeyCabyEdgeInsets` for cleaner code
5. **Be consistent** - Same spacing for same relationships across the app
6. **Test on devices** - Ensure spacing feels right on actual screens

---

## Common Mistakes to Avoid

❌ **Don't:** Use random spacing values
```dart
SizedBox(height: 15) // Where did 15 come from?
```

✅ **Do:** Use defined tokens
```dart
HeyCabyGaps.verticalComponent // Clear, consistent
```

❌ **Don't:** Exceed 10px for individual elements
```dart
Row(
  children: [
    Icon(...),
    SizedBox(width: 20), // Too much!
    Text(...),
  ],
)
```

✅ **Do:** Keep individual elements tight
```dart
Row(
  children: [
    Icon(...),
    HeyCabyGaps.horizontal, // 8px - perfect
    Text(...),
  ],
)
```

❌ **Don't:** Use same spacing for all nesting levels
```dart
Container(
  padding: EdgeInsets.all(16),
  child: Container(
    padding: EdgeInsets.all(16), // Same as parent!
    child: ...,
  ),
)
```

✅ **Do:** Decrease spacing as nesting increases
```dart
Container(
  padding: EdgeInsets.all(HeyCabySpacing.level2), // 24px
  child: Container(
    padding: EdgeInsets.all(HeyCabySpacing.level3), // 16px
    child: ...,
  ),
)
```

---

## Summary

The HeyCaby spacing system creates visual harmony through:
- **Hierarchical spacing** (6px → 30px)
- **Consistent relationships** (spacing = meaning)
- **The 10px rule** (individual elements stay tight)
- **Nested tightening** (deeper = tighter)
- **Easy-to-use tokens** (no magic numbers)

Apply these principles consistently, and your app will feel polished, intuitive, and professional.
