import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import 'driver_support_flow_common.dart';

/// FAQ content used by [DriverQuickAnswersBody] and the FAQ screen.
List<DriverFaqSectionData> get kDriverFaqSections => [
      DriverFaqSectionData(
        title: DriverStrings.faqGettingStarted,
        items: [
          DriverFaqItemData(
            question: DriverStrings.faqHowGoOnlineQuestion,
            answer: DriverStrings.faqHowGoOnlineAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqRatesQuestion,
            answer: DriverStrings.faqRatesAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqRideRequestsQuestion,
            answer: DriverStrings.faqRideRequestsAnswer,
          ),
        ],
      ),
      DriverFaqSectionData(
        title: DriverStrings.faqRidesEarnings,
        items: [
          DriverFaqItemData(
            question: DriverStrings.faqEarningsQuestion,
            answer: DriverStrings.faqEarningsAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqPaymentQuestion,
            answer: DriverStrings.faqPaymentAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqReturnTripsQuestion,
            answer: DriverStrings.faqReturnTripsAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqMarketplaceQuestion,
            answer: DriverStrings.faqMarketplaceAnswer,
          ),
        ],
      ),
      DriverFaqSectionData(
        title: DriverStrings.faqBreaksShifts,
        items: [
          DriverFaqItemData(
            question: DriverStrings.faqBreakLimitQuestion,
            answer: DriverStrings.faqBreakLimitAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqTakeBreakQuestion,
            answer: DriverStrings.faqTakeBreakAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqEndShiftQuestion,
            answer: DriverStrings.faqEndShiftAnswer,
          ),
        ],
      ),
      DriverFaqSectionData(
        title: DriverStrings.faqSafety,
        items: [
          DriverFaqItemData(
            question: DriverStrings.faqSafetyKitQuestion,
            answer: DriverStrings.faqSafetyKitAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqAudioQuestion,
            answer: DriverStrings.faqAudioAnswer,
          ),
        ],
      ),
      DriverFaqSectionData(
        title: DriverStrings.faqDocumentsCompliance,
        items: [
          DriverFaqItemData(
            question: DriverStrings.faqDocumentsQuestion,
            answer: DriverStrings.faqDocumentsAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqRenewDocumentsQuestion,
            answer: DriverStrings.faqRenewDocumentsAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqExpiredCardQuestion,
            answer: DriverStrings.faqExpiredCardAnswer,
          ),
        ],
      ),
      DriverFaqSectionData(
        title: DriverStrings.faqSupport,
        items: [
          DriverFaqItemData(
            question: DriverStrings.faqContactSupportQuestion,
            answer: DriverStrings.faqContactSupportAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqCallSupportQuestion,
            answer: DriverStrings.faqCallSupportAnswer,
          ),
          DriverFaqItemData(
            question: DriverStrings.faqResponseTimeQuestion,
            answer: DriverStrings.faqResponseTimeAnswer,
          ),
        ],
      ),
    ];

/// One FAQ question + answer.
class DriverFaqItemData {
  const DriverFaqItemData({required this.question, required this.answer});

  final String question;
  final String answer;

  /// Legacy field names for FAQ migration.
  String get q => question;
  String get a => answer;
}

/// FAQ section grouping.
class DriverFaqSectionData {
  const DriverFaqSectionData({
    required this.title,
    required this.items,
  });

  final String title;
  final List<DriverFaqItemData> items;
}

/// **Quick Answers** — FAQ scannable while parked.
class DriverQuickAnswersBody extends StatelessWidget {
  const DriverQuickAnswersBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.sections,
    required this.onBack,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverFaqSectionData> sections;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverSupportFlowScaffold(
      title: DriverStrings.faq,
      colors: colors,
      typography: typography,
      centerTitle: true,
      onBack: onBack,
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          bottomPad + DriverSpacing.lg,
        ),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: DriverSpacing.md),
        itemBuilder: (context, index) {
          final section = sections[index];
          return DriverCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: typography.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                ...section.items.map(
                  (item) => Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: colors.border.withValues(alpha: 0.5),
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(
                        bottom: DriverSpacing.sm,
                      ),
                      title: Text(
                        item.question,
                        style: typography.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      iconColor: colors.primary,
                      collapsedIconColor: colors.textMuted,
                      children: [
                        Text(
                          item.answer,
                          style: typography.bodySmall.copyWith(
                            color: colors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).driverFadeSlideIn(staggerIndex: index);
        },
      ),
    );
  }
}
