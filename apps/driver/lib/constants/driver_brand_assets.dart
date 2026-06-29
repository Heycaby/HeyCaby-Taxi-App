/// Driver app brand asset paths (App Store icon source + in-app logo).
abstract final class DriverBrandAssets {
  /// Green in-app driver mark.
  static const String logo = 'assets/branding/heycaby_mark.svg';

  /// Square master used for launcher / App Store icons only.
  static const String logoSolid = appIconSource;

  /// Square 1024×1024 master used for iOS/Android launcher icons.
  static const String appIconSource =
      'assets/branding/heycaby_app_icon_source.png';
}
