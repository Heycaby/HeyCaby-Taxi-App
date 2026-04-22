import 'package:flutter/services.dart';

/// Centralised haptic feedback helper used by both rider and driver apps.
///
/// All methods are static — call them from any button / gesture handler:
///
///   onTap: () { HapticService.lightTap(); }
///
/// Uses the native Flutter [HapticFeedback] API so no extra packages are
/// needed. iOS maps to UIImpactFeedbackGenerator styles; Android maps to
/// VibrationEffect where supported (Android 8+).
abstract final class HapticService {
  /// Subtle tap — best for list item selections, chip toggles, icon buttons.
  static Future<void> lightTap() => HapticFeedback.lightImpact();

  /// Moderate tap — best for primary CTAs, payment confirmation, rating submit.
  static Future<void> mediumTap() => HapticFeedback.mediumImpact();

  /// Strong tap — best for going online, major status changes, booking start.
  static Future<void> heavyTap() => HapticFeedback.heavyImpact();

  /// Crisp click — best for segmented controls and star rating taps.
  static Future<void> selectionClick() => HapticFeedback.selectionClick();

  /// Two-pulse "success" pattern — booking confirmed, ride accepted, rating sent.
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.lightImpact();
  }

  /// Three-pulse "error" pattern — failed submission, connection error.
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }
}
