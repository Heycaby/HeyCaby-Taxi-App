import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/driver_tell_friend_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_invite_url_provider.dart';
import '../providers/driver_locale_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_referral_share_body.dart';

/// TAF — share the HeyCaby homepage so friends can join as drivers (no personalized URL).
class DriverTellFriendScreen extends ConsumerWidget {
  const DriverTellFriendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    final strings = driverTellFriendStringsFor(locale);
    final driverAsync = ref.watch(driverIdProvider);
    final shareUrl = ref.watch(driverInviteShareUrlProvider);

    return driverAsync.when(
      data: (driverId) {
        final hasRef = driverId != null && driverId.isNotEmpty;
        return DriverReferralShareBody(
          colors: colors,
          typography: typography,
          loading: false,
          errorMessage: null,
          headline: strings.headline,
          bullet: strings.bullet1,
          showLinkUnavailable: !hasRef,
          linkUnavailableTitle: strings.linkUnavailable,
          linkUnavailableHint: strings.linkUnavailableHint,
          inviteLinkLabel: strings.inviteLinkLabel,
          shareUrl: shareUrl,
          shareLabel: strings.shareLink,
          copyLabel: strings.copyLink,
          onBack: () {
            if (context.canPop()) {
              Navigator.pop(context);
            } else {
              context.go('/driver');
            }
          },
          onShare: () async {
            final text = '${strings.shareMessage}\n\n$shareUrl';
            final box = context.findRenderObject() as RenderBox?;
            final origin =
                box == null ? null : box.localToGlobal(Offset.zero) & box.size;
            await Share.share(
              text,
              subject: strings.shareSubject,
              sharePositionOrigin: origin,
            );
          },
          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: shareUrl));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(strings.linkCopied),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
      loading: () => DriverReferralShareBody(
        colors: colors,
        typography: typography,
        loading: true,
        errorMessage: null,
        headline: '',
        bullet: '',
        showLinkUnavailable: false,
        linkUnavailableTitle: '',
        linkUnavailableHint: '',
        inviteLinkLabel: '',
        shareUrl: '',
        shareLabel: '',
        copyLabel: '',
        onBack: () => context.pop(),
        onShare: () {},
        onCopy: () {},
      ),
      error: (_, __) => DriverReferralShareBody(
        colors: colors,
        typography: typography,
        loading: false,
        errorMessage: strings.linkUnavailableHint,
        headline: '',
        bullet: '',
        showLinkUnavailable: false,
        linkUnavailableTitle: '',
        linkUnavailableHint: '',
        inviteLinkLabel: '',
        shareUrl: '',
        shareLabel: '',
        copyLabel: '',
        onBack: () => context.pop(),
        onShare: () {},
        onCopy: () {},
      ),
    );
  }
}
