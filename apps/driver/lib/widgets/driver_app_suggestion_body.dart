import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_badge.dart';
import 'driver_work_flow_common.dart';

/// **App Suggestion** — feature request form + top ideas.
class DriverAppSuggestionBody extends StatelessWidget {
  const DriverAppSuggestionBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.introText,
    required this.hintText,
    required this.controller,
    required this.submitting,
    required this.ideasLoading,
    required this.ideasError,
    required this.ideas,
    required this.onBack,
    required this.onSubmit,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String introText;
  final String hintText;
  final TextEditingController controller;
  final bool submitting;
  final bool ideasLoading;
  final String? ideasError;
  final List<DriverSuggestionIdeaItem> ideas;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverWorkFlowScaffold(
      title: DriverStrings.appSuggestion,
      colors: colors,
      typography: typography,
      onBack: onBack,
      centerTitle: false,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.md,
            DriverSpacing.screenEdge,
            bottomPad + DriverSpacing.lg,
          ),
          children: [
            DriverCard(
              colors: colors,
              padding: const EdgeInsets.all(DriverSpacing.lg),
              child: Text(
                introText,
                style: typography.bodyMedium.copyWith(
                  color: colors.text,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: DriverSpacing.md),
            TextField(
              controller: controller,
              maxLength: 1200,
              minLines: 6,
              maxLines: 10,
              style: typography.bodyMedium.copyWith(color: colors.text),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: typography.bodyMedium.copyWith(
                  color: colors.textMuted,
                ),
                filled: true,
                fillColor: colors.backgroundAlt,
                border: OutlineInputBorder(
                  borderRadius: DriverRadius.smAll,
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: DriverRadius.smAll,
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: DriverRadius.smAll,
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: DriverSpacing.md),
            DriverButton(
              label: DriverStrings.sendSuggestion,
              colors: colors,
              typography: typography,
              loading: submitting,
              onPressed: submitting ? null : onSubmit,
              size: DriverButtonSize.lg,
            ),
            const SizedBox(height: DriverSpacing.xl),
            Text(
              DriverStrings.topRequestedIdeas,
              style: typography.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: DriverSpacing.sm),
            if (ideasLoading)
              const Padding(
                padding: EdgeInsets.all(DriverSpacing.lg),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (ideasError != null)
              Text(
                ideasError!,
                style: typography.bodySmall.copyWith(color: colors.textMuted),
              )
            else if (ideas.isEmpty)
              DriverCard(
                colors: colors,
                padding: const EdgeInsets.all(DriverSpacing.md),
                child: Text(
                  DriverStrings.noPublicIdeasYet,
                  style: typography.bodySmall.copyWith(color: colors.textMuted),
                ),
              )
            else
              ...ideas.map(
                (idea) => Padding(
                  padding: const EdgeInsets.only(bottom: DriverSpacing.md),
                  child: DriverSuggestionIdeaCard(
                    item: idea,
                    colors: colors,
                    typography: typography,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Maps backend suggestion status to display chip metadata.
DriverSuggestionIdeaItem driverSuggestionIdeaFromStatus({
  required String text,
  required String status,
  required String votesLabel,
  required DriverColors colors,
}) {
  final normalized = status.trim().toLowerCase();
  final label = switch (normalized) {
    'planned' => 'Planned',
    'in_progress' => 'In progress',
    'reviewing' => 'Reviewing',
    'done' => 'Done',
    _ => 'New',
  };
  final tone = switch (normalized) {
    'planned' => DriverStatusTone.busy,
    'in_progress' => DriverStatusTone.warning,
    'done' => DriverStatusTone.success,
    'reviewing' => DriverStatusTone.warning,
    _ => DriverStatusTone.neutral,
  };
  return DriverSuggestionIdeaItem(
    text: text,
    statusLabel: label,
    statusTone: tone,
    votesLabel: votesLabel,
  );
}
