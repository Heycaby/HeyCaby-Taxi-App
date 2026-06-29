import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:share_plus/share_plus.dart';

/// Primary share + copy actions for the Grow Your City tab.
class RiderGrowCityShareBlock extends StatelessWidget {
  const RiderGrowCityShareBlock({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.shareUrl,
    required this.shareReady,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String shareUrl;
  final bool shareReady;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (ctx) {
            return FilledButton.icon(
              onPressed: shareReady
                  ? () => _share(ctx)
                  : null,
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: shareReady
                ? () async {
                    await HapticService.selectionClick();
                    await Clipboard.setData(ClipboardData(text: shareUrl));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.tellAFriendLinkCopied)),
                    );
                  }
                : null,
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
        if (!shareReady) ...[
          const SizedBox(height: HeyCabySpacing.component),
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
      ],
    );
  }

  Future<void> _share(BuildContext ctx) async {
    final box = ctx.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await HapticService.mediumTap();
    final text = '${l10n.tellAFriendShareMessage}\n\n$shareUrl';
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
        SnackBar(content: Text(l10n.tellAFriendShareDoneSnackbar)),
      );
    }
  }
}
