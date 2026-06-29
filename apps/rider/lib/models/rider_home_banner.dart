/// Server-driven home sheet banner from `fn_rider_home_banners`.
class RiderHomeBanner {
  const RiderHomeBanner({
    required this.id,
    required this.slug,
    required this.title,
    this.subtitle,
    required this.variant,
    required this.tapAction,
    this.url,
    this.modalTitle,
    this.modalBody,
    required this.onlyWhenNoSupply,
    required this.priority,
  });

  final String id;
  final String slug;
  final String title;
  final String? subtitle;
  final RiderHomeBannerVariant variant;
  final RiderHomeBannerTapAction tapAction;
  final String? url;
  final String? modalTitle;
  final String? modalBody;
  final bool onlyWhenNoSupply;
  final int priority;

  bool get isTappable => tapAction != RiderHomeBannerTapAction.none;

  factory RiderHomeBanner.fromJson(Map<String, dynamic> json) {
    return RiderHomeBanner(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: _nullableString(json['subtitle']),
      variant: RiderHomeBannerVariant.parse(json['variant']?.toString()),
      tapAction: RiderHomeBannerTapAction.parse(json['tap_action']?.toString()),
      url: _nullableString(json['url']),
      modalTitle: _nullableString(json['modal_title']),
      modalBody: _nullableString(json['modal_body']),
      onlyWhenNoSupply: json['only_when_no_supply'] == true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

enum RiderHomeBannerVariant {
  accent,
  promo,
  info,
  warning;

  static RiderHomeBannerVariant parse(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'promo':
        return RiderHomeBannerVariant.promo;
      case 'info':
        return RiderHomeBannerVariant.info;
      case 'warning':
        return RiderHomeBannerVariant.warning;
      default:
        return RiderHomeBannerVariant.accent;
    }
  }
}

enum RiderHomeBannerTapAction {
  none,
  modal,
  url;

  static RiderHomeBannerTapAction parse(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'modal':
        return RiderHomeBannerTapAction.modal;
      case 'url':
        return RiderHomeBannerTapAction.url;
      default:
        return RiderHomeBannerTapAction.none;
    }
  }
}
