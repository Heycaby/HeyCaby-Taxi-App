import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/driver_tell_friend_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_invite_url_provider.dart';
import '../providers/driver_locale_provider.dart';

/// TAF — share the HeyCaby homepage so friends can join as drivers (no personalized URL).
class DriverTellFriendScreen extends ConsumerWidget {
  const DriverTellFriendScreen({super.key});

  static TextStyle _bulletStyle(HeyCabyTypography typo, HeyCabyColorTokens colors) {
    return typo.bodyLarge.copyWith(
      color: colors.textMid,
      height: 1.4,
    );
  }

  static Widget _bulletRow(
    String text,
    HeyCabyTypography typo,
    HeyCabyColorTokens colors,
  ) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6),
            child: Text(
              '•',
              style: _bulletStyle(typo, colors).copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _bulletStyle(typo, colors))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    final strings = driverTellFriendStringsFor(locale);
    final driverAsync = ref.watch(driverIdProvider);
    final shareUrl = ref.watch(driverInviteShareUrlProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          strings.screenTitle,
          style: typo.titleMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: driverAsync.when(
        data: (driverId) {
          final hasRef = driverId != null && driverId.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: TafInviteIllustration(
                    accent: colors.accent,
                    muted: colors.textSoft,
                    nodeFill: colors.card,
                    size: 168,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.headline,
                  textAlign: TextAlign.center,
                  style: typo.headingSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                _bulletRow(strings.bullet1, typo, colors),
                _bulletRow(strings.bullet2, typo, colors),
                _bulletRow(strings.bullet3, typo, colors),
                if (!hasRef) ...[
                  const SizedBox(height: 20),
                  Text(
                    strings.linkUnavailable,
                    style: typo.bodyMedium.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.linkUnavailableHint,
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  strings.inviteLinkLabel,
                  style: typo.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsetsDirectional.all(16),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: SelectableText(
                    shareUrl,
                    style: typo.bodyMedium.copyWith(
                      color: colors.text,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (ctx) {
                    return FilledButton.icon(
                      onPressed: () async {
                              final text = '${strings.shareMessage}\n\n$shareUrl';
                              final box = ctx.findRenderObject() as RenderBox?;
                              final origin = box == null
                                  ? null
                                  : box.localToGlobal(Offset.zero) & box.size;
                              await Share.share(
                                text,
                                subject: strings.shareSubject,
                                sharePositionOrigin: origin,
                              );
                            },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(strings.shareLink),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: shareUrl));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(strings.linkCopied)),
                          );
                        },
                  icon: Icon(Icons.link_rounded, color: colors.accent),
                  label: Text(strings.copyLink),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              strings.linkUnavailableHint,
              textAlign: TextAlign.center,
              style: typo.bodyMedium.copyWith(color: colors.textMid),
            ),
          ),
        ),
      ),
    );
  }
}
