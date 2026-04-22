import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final sections = [
      _LegalSection(title: l10n.privacyDataCollected, body: l10n.privacyDataCollectedBody),
      _LegalSection(title: l10n.privacyLocationData, body: l10n.privacyLocationDataBody),
      _LegalSection(title: l10n.privacyDataSharing, body: l10n.privacyDataSharingBody),
      _LegalSection(title: l10n.privacyRetention, body: l10n.privacyRetentionBody),
      _LegalSection(title: l10n.privacyGdpr, body: l10n.privacyGdprBody),
      _LegalSection(title: l10n.privacyNoAds, body: l10n.privacyNoAdsBody),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back, color: colors.text, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    l10n.privacyTitle,
                    style: typo.headingLarge.copyWith(color: colors.text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sections
                      .map((s) => _LegalSectionWidget(
                            section: s,
                            colors: colors,
                            typo: typo,
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String body;
  const _LegalSection({required this.title, required this.body});
}

class _LegalSectionWidget extends StatelessWidget {
  final _LegalSection section;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _LegalSectionWidget({
    required this.section,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: typo.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: typo.bodyMedium.copyWith(
              color: colors.textMid,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
