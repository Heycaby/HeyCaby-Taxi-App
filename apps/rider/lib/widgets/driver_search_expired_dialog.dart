import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/active_search_provider.dart';

Rect _shareOriginFromContext(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromLTWH(size.width / 2 - 1, size.height / 2 - 1, 2, 2);
}

/// Friendly "we're new, help spread the word" message after a 30 min search window ends.
Future<void> showDriverSearchExpiredDialog(
  BuildContext context,
  WidgetRef ref, {
  bool markGrowthModalDismissedAfter = false,
}) async {
  final colors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);
  final l10n = AppLocalizations.of(context);

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        l10n.noCabyFoundModalTitle,
        style: typo.headingMedium.copyWith(color: colors.text, fontSize: 22),
      ),
      content: SingleChildScrollView(
        child: Text(
          l10n.noCabyFoundModalBody,
          style: typo.bodyLarge.copyWith(
            color: colors.text,
            height: 1.55,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Builder(
            builder: (buttonCtx) => FilledButton(
              onPressed: () async {
                final origin = _shareOriginFromContext(buttonCtx);
                await Share.share(
                  l10n.shareHeyCabyMessage(kAppPublicSiteRoot),
                  sharePositionOrigin: origin,
                );
              },
              child: Text(l10n.shareHeyCabyInvite),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.growthModalClose),
          ),
        ),
      ],
    ),
  );

  if (markGrowthModalDismissedAfter) {
    await ref.read(activeSearchProvider.notifier).markGrowthModalDismissed();
  }
}
