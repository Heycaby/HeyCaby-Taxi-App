import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../widgets/booking/booking_flow_screen_header.dart';

class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final sections = [
      _FaqSection(title: l10n.faqBookingSection, items: [
        _FaqItem(q: l10n.faqHowToBook, a: l10n.faqHowToBookAnswer),
        _FaqItem(q: l10n.faqInstantVsMarketplace, a: l10n.faqInstantVsMarketplaceAnswer),
        _FaqItem(q: l10n.faqScheduleRide, a: l10n.faqScheduleRideAnswer),
        _FaqItem(q: l10n.faqHowMarketplace, a: l10n.faqHowMarketplaceAnswer),
      ]),
      _FaqSection(title: l10n.faqDriversSection, items: [
        _FaqItem(q: l10n.faqAddFavourite, a: l10n.faqAddFavouriteAnswer),
        _FaqItem(q: l10n.faqWhatAreFavourites, a: l10n.faqWhatAreFavouritesAnswer),
        _FaqItem(q: l10n.faqBlockDriver, a: l10n.faqBlockDriverAnswer),
      ]),
      _FaqSection(title: l10n.faqPaymentSection, items: [
        _FaqItem(q: l10n.faqPaymentMethods, a: l10n.faqPaymentMethodsAnswer),
        _FaqItem(q: l10n.faqWhoPaysWho, a: l10n.faqWhoPaysWhoAnswer),
        _FaqItem(q: l10n.faqWhereSeeCosts, a: l10n.faqWhereSeeCostsAnswer),
      ]),
      _FaqSection(title: l10n.faqSafetySection, items: [
        _FaqItem(q: l10n.faqDriverNoShow, a: l10n.faqDriverNoShowAnswer),
        _FaqItem(q: l10n.faqReportIncident, a: l10n.faqReportIncidentAnswer),
        _FaqItem(q: l10n.faqInsurance, a: l10n.faqInsuranceAnswer),
      ]),
      _FaqSection(title: l10n.faqAccountSection, items: [
        _FaqItem(q: l10n.faqChangeName, a: l10n.faqChangeNameAnswer),
        _FaqItem(q: l10n.faqVerifyEmail, a: l10n.faqVerifyEmailAnswer),
        _FaqItem(q: l10n.faqDeleteAccount, a: l10n.faqDeleteAccountAnswer),
      ]),
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
              title: l10n.faq,
              icon: Icons.help_outline_rounded,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 32),
                itemCount: sections.length,
                itemBuilder: (context, i) => _FaqSectionWidget(
                  section: sections[i],
                  colors: colors,
                  typo: typo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqSection {
  final String title;
  final List<_FaqItem> items;
  const _FaqSection({required this.title, required this.items});
}

class _FaqItem {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});
}

class _FaqSectionWidget extends StatelessWidget {
  final _FaqSection section;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _FaqSectionWidget({
    required this.section,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 12),
          child: Text(
            section.title.toUpperCase(),
            style: typo.labelSmall.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: section.items
                .map((item) => _FaqExpansionTile(
                      item: item,
                      colors: colors,
                      typo: typo,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _FaqExpansionTile extends StatelessWidget {
  final _FaqItem item;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _FaqExpansionTile({
    required this.item,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
        iconColor: colors.accent,
        collapsedIconColor: colors.textSoft,
        title: Text(
          item.q,
          style: typo.bodyLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              item.a,
              style: typo.bodyMedium.copyWith(
                color: colors.textMid,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
