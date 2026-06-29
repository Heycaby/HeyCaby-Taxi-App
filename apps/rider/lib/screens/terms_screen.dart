import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../widgets/booking/booking_flow_screen_header.dart';

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final sections = [
      _LegalSection(title: l10n.termsWhatIsHeyCaby, body: l10n.termsWhatIsHeyCabyBody),
      _LegalSection(title: l10n.termsRiderResponsibilities, body: l10n.termsRiderResponsibilitiesBody),
      _LegalSection(title: l10n.termsPayment, body: l10n.termsPaymentBody),
      _LegalSection(title: l10n.termsCancellation, body: l10n.termsCancellationBody),
      _LegalSection(title: l10n.termsSuspension, body: l10n.termsSuspensionBody),
      _LegalSection(title: l10n.termsDisputes, body: l10n.termsDisputesBody),
      _LegalSection(title: l10n.termsGoverningLaw, body: l10n.termsGoverningLawBody),
      _LegalSection(title: l10n.termsContact, body: l10n.termsContactBody),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.termsTitle,
              icon: Icons.gavel_rounded,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 32),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: typo.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
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
