import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

Future<void> showRiderGrowCityWhySheet(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
  required AppLocalizations l10n,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.growCityWhyHelpTitle,
              style: typo.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.growCityHeroMission,
              style: typo.bodyMedium.copyWith(
                color: colors.textMid,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            for (final bullet in [
              l10n.growCityWhyHelpBullet1,
              l10n.growCityWhyHelpBullet2,
              l10n.growCityWhyHelpBullet3,
              l10n.growCityWhyHelpBullet4,
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bullet,
                        style: typo.bodyMedium.copyWith(
                          color: colors.textMid,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.growCityWhySheetDone),
            ),
          ],
        ),
      );
    },
  );
}
