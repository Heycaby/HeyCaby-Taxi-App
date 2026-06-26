import 'package:flutter/animation.dart';

/// Shared motion tokens for tactile, premium interactions.
///
/// Keep rider + driver aligned by reusing these constants for press states,
/// micro-animations, and timing curves.
abstract final class HeyCabyMotion {
  /// Fast touch response timing for press-state animations.
  static const Duration pressDuration = Duration(milliseconds: 95);

  /// Default curve for quick touch feedback.
  static const Curve pressCurve = Curves.easeOut;

  /// Scale for small secondary rows while pressed.
  static const double rowPressScale = 0.985;

  /// Scale for primary action cards while pressed.
  static const double cardPressScale = 0.975;

  /// Subtitle opacity while pressed.
  static const double pressedSubtitleOpacity = 0.88;

  /// Border accent alpha while pressed.
  static const double pressedBorderAlpha = 0.32;

  /// Background alpha while pressed.
  static const double pressedBackgroundAlpha = 0.86;
}
