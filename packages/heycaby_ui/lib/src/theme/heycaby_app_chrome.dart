import 'package:flutter/material.dart';

/// Binds the active HeyCaby palette theme id to [ThemeData] so widgets use
/// `Theme.of(context)` instead of duplicating [themeProvider] lookups for chrome.
@immutable
class HeyCabyAppChrome extends ThemeExtension<HeyCabyAppChrome> {
  const HeyCabyAppChrome({required this.themeId});

  /// Matches [HeyCabyThemeData.id] from [kThemes].
  final String themeId;

  static HeyCabyAppChrome? maybeOf(BuildContext context) =>
      Theme.of(context).extension<HeyCabyAppChrome>();

  /// Active theme id, or empty if the extension is missing (tests / partial trees).
  static String themeIdOf(BuildContext context) =>
      maybeOf(context)?.themeId ?? '';

  @override
  HeyCabyAppChrome copyWith({String? themeId}) =>
      HeyCabyAppChrome(themeId: themeId ?? this.themeId);

  @override
  HeyCabyAppChrome lerp(
    covariant ThemeExtension<HeyCabyAppChrome>? other,
    double t,
  ) {
    if (other is! HeyCabyAppChrome) return this;
    return t < 0.5 ? this : other;
  }
}
