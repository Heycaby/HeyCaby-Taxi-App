import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Semantic color accessors for the driver app. Always resolve from theme tokens.
///
/// ```dart
/// final colors = DriverColors.of(ref);
/// Container(color: colors.primary);
/// ```
@immutable
class DriverColors {
  const DriverColors._(this._tokens);

  final HeyCabyColorTokens _tokens;

  /// Brand green — primary CTAs, online state, success highlights.
  Color get primary => _tokens.accent;

  Color get primaryLight => _tokens.accentL;

  Color get onPrimary => _tokens.onAccent;

  Color get background => _tokens.bg;

  Color get backgroundAlt => _tokens.bgAlt;

  Color get surface => _tokens.surface;

  Color get card => _tokens.card;

  Color get border => _tokens.border;

  Color get text => _tokens.text;

  Color get textSecondary => _tokens.textMid;

  Color get textMuted => _tokens.textSoft;

  Color get success => _tokens.success;

  Color get warning => _tokens.warning;

  Color get error => _tokens.error;

  Color get onError => _tokens.onError;

  HeyCabyColorTokens get tokens => _tokens;

  @visibleForTesting
  factory DriverColors.fromTokens(HeyCabyColorTokens tokens) =>
      DriverColors._(tokens);

  /// Wrap shared theme tokens for driver UI.
  factory DriverColors.fromTheme(HeyCabyColorTokens tokens) =>
      DriverColors._(tokens);

  static DriverColors of(WidgetRef ref) =>
      DriverColors._(ref.watch(colorsProvider));

  static DriverColors ofContext(BuildContext context, WidgetRef ref) =>
      DriverColors.of(ref);
}

/// Dark palette tokens — use when dark mode ships (Phase 8).
abstract final class DriverColorsDark {
  static HeyCabyColorTokens get tokens => kHeyCabyDriverProDark;
}
