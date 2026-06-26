import 'package:flutter/animation.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Driver motion tokens — quick, smooth, intentional (Phase 0.75).
abstract final class DriverMotion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration emphasis = Duration(milliseconds: 400);
  static const Duration staggerStep = Duration(milliseconds: 45);

  static Duration staggerDelay(int index) =>
      Duration(milliseconds: staggerStep.inMilliseconds * index);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve sheetCurve = Curves.easeOutCubic;
  static const Curve enterCurve = Curves.easeOut;

  static const Duration pressDuration = HeyCabyMotion.pressDuration;
  static const Curve pressCurve = HeyCabyMotion.pressCurve;
  static const double cardPressScale = HeyCabyMotion.cardPressScale;
}
