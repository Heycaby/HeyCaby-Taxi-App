import 'package:flutter/widgets.dart';

/// HeyCaby spacing system
/// 
/// A hierarchical spacing system that creates visual harmony and clear relationships
/// between UI elements. Based on design principles where spacing communicates hierarchy.
/// 
/// **Spacing Hierarchy:**
/// - Element Level (6-10px): Individual elements and tight groups
/// - Component Level (12-16px): Component internal spacing
/// - Section Level (20-30px): Major sections and wrappers
/// 
/// **Key Principles:**
/// 1. Never exceed 10px between individual elements
/// 2. Deeper nesting = tighter spacing
/// 3. Spacing signals relationships
/// 4. Consistency creates polish

class HeyCabySpacing {
  HeyCabySpacing._();

  // ============================================================================
  // ELEMENT LEVEL SPACING (6-10px)
  // Individual elements and their immediate relationships
  // ============================================================================

  /// Minimum spacing between individual elements (6px)
  /// Use for: Icon-to-text, label-to-value, tightly coupled pairs
  static const double elementMin = 6.0;

  /// Standard spacing between individual elements (8px)
  /// Use for: List items, form fields, related content
  static const double element = 8.0;

  /// Maximum spacing between individual elements (10px)
  /// Use for: Grouped elements that need slight separation
  /// NEVER exceed this for individual elements
  static const double elementMax = 10.0;

  // ============================================================================
  // COMPONENT LEVEL SPACING (12-16px)
  // Internal component padding and element groups
  // ============================================================================

  /// Button horizontal padding (12px)
  /// Ensures buttons feel tappable but not cramped
  static const double buttonHorizontal = 12.0;

  /// Button vertical padding (8px)
  /// Creates balanced button height
  static const double buttonVertical = 8.0;

  /// Small component padding (12px)
  /// Use for: Chips, tags, small cards
  static const double componentSmall = 12.0;

  /// Standard component padding (16px)
  /// Use for: Cards, containers, input fields
  static const double component = 16.0;

  // ============================================================================
  // SECTION LEVEL SPACING (20-30px)
  // Major sections, wrappers, and screen-level spacing
  // ============================================================================

  /// Medium section spacing (20px)
  /// Use for: Between card groups, related sections
  static const double sectionMedium = 20.0;

  /// Standard section spacing (24px)
  /// Use for: Major content sections, screen padding
  static const double section = 24.0;

  /// Large section spacing (30px)
  /// Use for: Top-level wrappers, screen sections with airy feel
  static const double sectionLarge = 30.0;

  // ============================================================================
  // SPECIALIZED SPACING
  // Context-specific spacing values
  // ============================================================================

  /// Screen edge padding (20px)
  /// Consistent horizontal padding for all screens
  static const double screenEdge = 20.0;

  /// List item spacing (8px)
  /// Vertical spacing between list items
  static const double listItem = 8.0;

  /// Form field spacing (16px)
  /// Spacing between form fields
  static const double formField = 16.0;

  /// Modal padding (24px)
  /// Internal padding for modals and bottom sheets
  static const double modal = 24.0;

  /// Divider spacing (12px)
  /// Space around dividers and separators
  static const double divider = 12.0;

  // ============================================================================
  // NESTED SPACING HELPERS
  // Apply tighter spacing as nesting increases
  // ============================================================================

  /// Level 1: Outermost wrapper (30px)
  static const double level1 = sectionLarge;

  /// Level 2: Major sections (24px)
  static const double level2 = section;

  /// Level 3: Content blocks (16px)
  static const double level3 = component;

  /// Level 4: Element groups (10px)
  static const double level4 = elementMax;

  /// Level 5: Individual elements (8px)
  static const double level5 = element;

  /// Level 6: Tightest spacing (6px)
  static const double level6 = elementMin;

  // ============================================================================
  // USAGE DOCUMENTATION
  // ============================================================================

  /// Example: Card with proper spacing hierarchy
  /// ```dart
  /// Container(
  ///   padding: EdgeInsets.all(HeyCabySpacing.component), // Level 3: 16px
  ///   child: Column(
  ///     children: [
  ///       Row(
  ///         children: [
  ///           Icon(...),
  ///           SizedBox(width: HeyCabySpacing.element), // Level 5: 8px
  ///           Text(...),
  ///         ],
  ///       ),
  ///       SizedBox(height: HeyCabySpacing.elementMax), // Level 4: 10px
  ///       Text(...),
  ///     ],
  ///   ),
  /// )
  /// ```
  /// 
  /// Example: Screen with section spacing
  /// ```dart
  /// Padding(
  ///   padding: EdgeInsets.all(HeyCabySpacing.screenEdge), // 20px
  ///   child: Column(
  ///     children: [
  ///       SectionA(),
  ///       SizedBox(height: HeyCabySpacing.section), // 24px
  ///       SectionB(),
  ///       SizedBox(height: HeyCabySpacing.section), // 24px
  ///       SectionC(),
  ///     ],
  ///   ),
  /// )
  /// ```
  /// 
  /// Example: Button with proper padding
  /// ```dart
  /// ElevatedButton(
  ///   style: ElevatedButton.styleFrom(
  ///     padding: EdgeInsets.symmetric(
  ///       horizontal: HeyCabySpacing.buttonHorizontal, // 12px
  ///       vertical: HeyCabySpacing.buttonVertical,     // 8px
  ///     ),
  ///   ),
  ///   child: Text('Button'),
  /// )
  /// ```
}

/// Edge Insets helpers for common spacing patterns
class HeyCabyEdgeInsets {
  HeyCabyEdgeInsets._();

  // Screen-level padding
  static const screenAll = EdgeInsets.all(HeyCabySpacing.screenEdge);
  static const screenHorizontal = EdgeInsets.symmetric(horizontal: HeyCabySpacing.screenEdge);
  static const screenVertical = EdgeInsets.symmetric(vertical: HeyCabySpacing.screenEdge);

  // Component padding
  static const componentAll = EdgeInsets.all(HeyCabySpacing.component);
  static const componentHorizontal = EdgeInsets.symmetric(horizontal: HeyCabySpacing.component);
  static const componentVertical = EdgeInsets.symmetric(vertical: HeyCabySpacing.component);

  // Button padding
  static const button = EdgeInsets.symmetric(
    horizontal: HeyCabySpacing.buttonHorizontal,
    vertical: HeyCabySpacing.buttonVertical,
  );

  // Modal padding
  static const modal = EdgeInsets.all(HeyCabySpacing.modal);
}

/// SizedBox helpers for common spacing
class HeyCabyGaps {
  HeyCabyGaps._();

  // Vertical gaps
  static const verticalMin = SizedBox(height: HeyCabySpacing.elementMin);
  static const vertical = SizedBox(height: HeyCabySpacing.element);
  static const verticalMax = SizedBox(height: HeyCabySpacing.elementMax);
  static const verticalComponent = SizedBox(height: HeyCabySpacing.component);
  static const verticalSection = SizedBox(height: HeyCabySpacing.section);
  static const verticalSectionLarge = SizedBox(height: HeyCabySpacing.sectionLarge);

  // Horizontal gaps
  static const horizontalMin = SizedBox(width: HeyCabySpacing.elementMin);
  static const horizontal = SizedBox(width: HeyCabySpacing.element);
  static const horizontalMax = SizedBox(width: HeyCabySpacing.elementMax);
  static const horizontalComponent = SizedBox(width: HeyCabySpacing.component);
}
