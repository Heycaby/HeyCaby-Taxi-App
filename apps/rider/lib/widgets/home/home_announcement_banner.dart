import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../models/rider_home_banner.dart';
import '../../utils/rider_home_banner_actions.dart';
import 'home_inline_banner.dart';

class HomeAnnouncementBanner extends StatelessWidget {
  const HomeAnnouncementBanner({
    super.key,
    required this.banner,
    required this.colors,
    required this.typo,
  });

  final RiderHomeBanner banner;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return HomeInlineBanner(
      colors: colors,
      typo: typo,
      title: banner.title,
      subtitle: banner.subtitle,
      variant: banner.variant,
      icon: iconForRiderHomeBannerVariant(banner.variant),
      onTap: banner.isTappable
          ? () => handleRiderHomeBannerTap(
                context,
                banner: banner,
                colors: colors,
                typo: typo,
              )
          : null,
      trailing: banner.isTappable
          ? Icon(Icons.chevron_right_rounded, color: colors.textSoft, size: 22)
          : null,
    );
  }
}
