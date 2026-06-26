/// Driver app brand asset paths (App Store icon source + in-app logo).
abstract final class DriverBrandAssets {
  /// Yellow wordmark, transparent background — use in UI overlays.
  static const String logo = 'assets/branding/heycaby_logo_yellow_transparent.png';

  /// Solid black background — source for launcher / App Store icons only.
  static const String logoSolid = 'assets/branding/heycaby_logo_black_yellow.png';

  /// Square 1024×1024 master used for iOS/Android launcher icons.
  static const String appIconSource = 'assets/branding/heycaby_app_icon_source.png';
}
