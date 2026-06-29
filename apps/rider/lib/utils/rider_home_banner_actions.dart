import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/rider_home_banner.dart';

Future<void> handleRiderHomeBannerTap(
  BuildContext context, {
  required RiderHomeBanner banner,
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
}) async {
  switch (banner.tapAction) {
    case RiderHomeBannerTapAction.none:
      return;
    case RiderHomeBannerTapAction.modal:
      await _showModal(context, banner: banner, colors: colors, typo: typo);
      return;
    case RiderHomeBannerTapAction.url:
      await openRiderHomeBannerUrl(context, banner: banner, colors: colors, typo: typo);
      return;
  }
}

Future<void> _showModal(
  BuildContext context, {
  required RiderHomeBanner banner,
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
}) async {
  final title = (banner.modalTitle?.trim().isNotEmpty == true)
      ? banner.modalTitle!.trim()
      : banner.title;
  final body = (banner.modalBody?.trim().isNotEmpty == true)
      ? banner.modalBody!.trim()
      : (banner.subtitle ?? '');
  final l10n = AppLocalizations.of(context);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        title,
        style: typo.titleMedium.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          body,
          style: typo.bodyMedium.copyWith(
            color: colors.textMid,
            height: 1.45,
          ),
        ),
      ),
      actions: [
        if (banner.url != null && banner.url!.trim().isNotEmpty)
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (!context.mounted) return;
              await openRiderHomeBannerUrl(
                context,
                banner: banner,
                colors: colors,
                typo: typo,
              );
            },
            child: Text(l10n.openLinkAction),
          ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.dialogOk),
        ),
      ],
    ),
  );
}

Future<void> openRiderHomeBannerUrl(
  BuildContext context, {
  required RiderHomeBanner banner,
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
}) async {
  final raw = banner.url?.trim();
  if (raw == null || raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null) return;

  final inApp = raw.startsWith('https://heycaby.nl') ||
      raw.startsWith('https://www.heycaby.nl');

  if (inApp && context.mounted) {
    await context.push(
      '/announcement-web',
      extra: RiderAnnouncementWebRouteArgs(
        url: raw,
        title: banner.modalTitle ?? banner.title,
      ),
    );
    return;
  }

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class RiderAnnouncementWebRouteArgs {
  const RiderAnnouncementWebRouteArgs({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;
}
