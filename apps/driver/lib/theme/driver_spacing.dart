import 'package:heycaby_ui/heycaby_ui.dart';

/// Driver spacing — re-exports shared scale with driver naming.
abstract final class DriverSpacing {
  static const double xs = HeyCabySpacing.elementMin;
  static const double sm = HeyCabySpacing.element;
  static const double md = HeyCabySpacing.elementMax;
  static const double lg = HeyCabySpacing.component;
  static const double xl = HeyCabySpacing.sectionMedium;
  static const double xxl = HeyCabySpacing.section;
  static const double xxxl = HeyCabySpacing.sectionLarge;

  static const double screenEdge = HeyCabySpacing.screenEdge;
  static const double modal = HeyCabySpacing.modal;
  static const double listItem = HeyCabySpacing.listItem;
  static const double formField = HeyCabySpacing.formField;

  /// Minimum touch target (48dp).
  static const double touchTarget = 48;

  /// Ride-critical actions (accept/decline).
  static const double touchTargetLarge = 56;
}
