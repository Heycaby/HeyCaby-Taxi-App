import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../models/rider_home_banner.dart';

/// Shared home-sheet inline banner shape (announcements, promos, supply notices).
class HomeInlineBanner extends StatelessWidget {
  const HomeInlineBanner({
    super.key,
    required this.colors,
    required this.typo,
    required this.title,
    this.subtitle,
    this.variant = RiderHomeBannerVariant.accent,
    this.icon = Icons.auto_awesome_rounded,
    this.onTap,
    this.trailing,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String? subtitle;
  final RiderHomeBannerVariant variant;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(colors, variant);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: palette.icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: typo.bodySmall.copyWith(
                    color: colors.textMid,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 0),
      child: Material(
        color: palette.background,
        elevation: 0,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _BannerPalette {
  const _BannerPalette({
    required this.background,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color icon;
}

_BannerPalette _paletteFor(
  HeyCabyColorTokens colors,
  RiderHomeBannerVariant variant,
) {
  switch (variant) {
    case RiderHomeBannerVariant.promo:
      return _BannerPalette(
        background: const Color(0xFFFFF8E8),
        border: const Color(0xFFF4A800).withValues(alpha: 0.35),
        icon: const Color(0xFFC88700),
      );
    case RiderHomeBannerVariant.info:
      return _BannerPalette(
        background: colors.card,
        border: colors.border,
        icon: colors.textMid,
      );
    case RiderHomeBannerVariant.warning:
      return _BannerPalette(
        background: colors.warning.withValues(alpha: 0.12),
        border: colors.warning.withValues(alpha: 0.35),
        icon: colors.warning,
      );
    case RiderHomeBannerVariant.accent:
      return _BannerPalette(
        background: colors.accentL,
        border: colors.accent.withValues(alpha: 0.2),
        icon: colors.accent,
      );
  }
}

IconData iconForRiderHomeBannerVariant(RiderHomeBannerVariant variant) {
  switch (variant) {
    case RiderHomeBannerVariant.promo:
      return Icons.celebration_rounded;
    case RiderHomeBannerVariant.info:
      return Icons.info_outline_rounded;
    case RiderHomeBannerVariant.warning:
      return Icons.warning_amber_rounded;
    case RiderHomeBannerVariant.accent:
      return Icons.auto_awesome_rounded;
  }
}
