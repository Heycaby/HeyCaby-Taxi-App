import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_rider/providers/rider_invite_url_provider.dart';
import 'package:heycaby_rider/providers/rider_invited_friends_count_provider.dart';
import 'package:heycaby_rider/widgets/taf_friends_invited_gauge.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// TAF — share the HeyCaby homepage so friends can join as riders (no personalized URL).
class RiderTellFriendScreen extends ConsumerWidget {
  const RiderTellFriendScreen({super.key});

  static TextStyle _perkLine(
    HeyCabyTypography typo,
    HeyCabyColorTokens colors,
  ) {
    return typo.bodySmall.copyWith(
      color: colors.textMid,
      height: 1.35,
    );
  }

  static Widget _perkRow(
    String text,
    HeyCabyTypography typo,
    HeyCabyColorTokens colors,
  ) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 3),
            child: Icon(
              Icons.check_rounded,
              size: 18,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _perkLine(typo, colors))),
        ],
      ),
    );
  }

  static void _showInviteQrSheet(
    BuildContext context,
    String qrUrl,
    AppLocalizations l10n,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                l10n.tellAFriendQrTitle,
                textAlign: TextAlign.center,
                style: typo.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: qrUrl.trim(),
                size: 220,
                backgroundColor: colors.card,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: colors.text,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.tellAFriendQrHint,
                textAlign: TextAlign.center,
                style: typo.bodySmall.copyWith(color: colors.textMid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final identityAsync = ref.watch(riderIdentityProvider);
    final shareUrl = ref.watch(riderInviteShareUrlProvider);
    final bottomPad =
        MediaQuery.paddingOf(context).bottom + HeyCabySpacing.sectionMedium;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: colors.border),
        ),
        title: Text(
          l10n.tellAFriendScreenTitle,
          style: typo.headingSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.15,
          ),
        ),
      ),
      body: identityAsync.when(
        data: (identity) {
          final id = identity.identityId;
          final hasRef = id != null && id.isNotEmpty;
          final countAsync = hasRef
              ? ref.watch(riderInvitedFriendsCountProvider)
              : const AsyncValue<int>.data(0);

          return SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(
              HeyCabySpacing.screenEdge,
              HeyCabySpacing.component,
              HeyCabySpacing.screenEdge,
              bottomPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: countAsync.when(
                    data: (n) => TafFriendsInvitedGauge(
                      count: n,
                      loading: false,
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                    ),
                    loading: () => TafFriendsInvitedGauge(
                      count: 0,
                      loading: true,
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                    ),
                    error: (_, __) => TafFriendsInvitedGauge(
                      count: 0,
                      loading: false,
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 280.ms, curve: Curves.easeOut),
                SizedBox(height: HeyCabySpacing.component),
                Text(
                  l10n.tellAFriendSharePrompt,
                  textAlign: TextAlign.center,
                  style: typo.bodyMedium.copyWith(
                    color: colors.textMid,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: HeyCabySpacing.sectionMedium),
                Builder(
                  builder: (ctx) {
                    return FilledButton.icon(
                      onPressed: () async {
                              final box = ctx.findRenderObject() as RenderBox?;
                              final origin = box == null
                                  ? null
                                  : box.localToGlobal(Offset.zero) & box.size;
                              await HapticService.mediumTap();
                              final text =
                                  '${l10n.tellAFriendShareMessage}\n\n$shareUrl';
                              final result = await Share.shareWithResult(
                                text,
                                subject: l10n.tellAFriendShareSubject,
                                sharePositionOrigin: origin,
                              );
                              if (!ctx.mounted) return;
                              if (result.status == ShareResultStatus.success) {
                                await HapticService.success();
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.tellAFriendShareDoneSnackbar,
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(l10n.tellAFriendShareLink),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await HapticService.selectionClick();
                          await Clipboard.setData(
                            ClipboardData(text: shareUrl),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.tellAFriendLinkCopied),
                            ),
                          );
                        },
                        icon: Icon(Icons.link_rounded, color: colors.accent),
                        label: Text(l10n.tellAFriendCopyLink),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                                await HapticService.lightTap();
                                if (!context.mounted) return;
                                _showInviteQrSheet(
                                  context,
                                  kAppQrMarketingHomeUrl,
                                  l10n,
                                  colors,
                                  typo,
                                );
                              },
                        icon: Icon(Icons.qr_code_2_rounded, color: colors.accent),
                        label: Text(l10n.tellAFriendShowQr),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: HeyCabySpacing.sectionMedium),
                Text(
                  l10n.tellAFriendInviteLinkLabel,
                  style: typo.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.85),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(14),
                    child: SelectableText(
                      shareUrl,
                      style: typo.bodySmall.copyWith(
                        color: colors.text,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                if (!hasRef) ...[
                  SizedBox(height: HeyCabySpacing.component),
                  Text(
                    l10n.tellAFriendLinkUnavailable,
                    style: typo.bodyMedium.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tellAFriendLinkUnavailableHint,
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                ],
                SizedBox(height: HeyCabySpacing.section),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      14,
                      12,
                      14,
                      10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tellAFriendRewardTitle,
                          style: typo.titleSmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _perkRow(
                          l10n.tellAFriendRewardBullet1,
                          typo,
                          colors,
                        ),
                        _perkRow(
                          l10n.tellAFriendRewardBullet2,
                          typo,
                          colors,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: HeyCabySpacing.component),
                Text(
                  l10n.tellAFriendSocialProof,
                  textAlign: TextAlign.center,
                  style: typo.labelSmall.copyWith(
                    color: colors.textSoft,
                    height: 1.35,
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
              l10n.tellAFriendLinkUnavailableHint,
              textAlign: TextAlign.center,
              style: typo.bodyMedium.copyWith(color: colors.textMid),
            ),
          ),
        ),
      ),
    );
  }
}
