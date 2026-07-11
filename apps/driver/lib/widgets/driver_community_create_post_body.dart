import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_bottom_sheet.dart';
import '../ui/driver_button.dart';
import '../ui/driver_chip.dart';

/// **Community Create Post** — text or poll composer (presentation only).
class DriverCommunityCreatePostBody extends StatelessWidget {
  const DriverCommunityCreatePostBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.isPoll,
    required this.postType,
    required this.messageController,
    required this.pollQuestionController,
    required this.pollOptionControllers,
    required this.onKindChanged,
    required this.onPostTypeChanged,
    required this.onAddPollOption,
    required this.onSubmit,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool isPoll;
  final String postType;
  final TextEditingController messageController;
  final TextEditingController pollQuestionController;
  final List<TextEditingController> pollOptionControllers;
  final ValueChanged<bool> onKindChanged;
  final ValueChanged<String> onPostTypeChanged;
  final VoidCallback onAddPollOption;
  final VoidCallback onSubmit;

  static const _postTypes = ['traffic', 'tip', 'help', 'general'];

  @override
  Widget build(BuildContext context) {
    return DriverBottomSheet(
      colors: colors,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          MediaQuery.paddingOf(context).bottom + DriverSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DriverStrings.communityNewPost,
                style: typography.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: DriverSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DriverChip(
                      label: DriverStrings.communityCreateKindText,
                      colors: colors,
                      typography: typography,
                      selected: !isPoll,
                      onTap: () => onKindChanged(false),
                    ),
                  ),
                  const SizedBox(width: DriverSpacing.sm),
                  Expanded(
                    child: DriverChip(
                      label: DriverStrings.communityCreateKindPoll,
                      colors: colors,
                      typography: typography,
                      selected: isPoll,
                      onTap: () => onKindChanged(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DriverSpacing.md),
              if (!isPoll) ...[
                Wrap(
                  spacing: DriverSpacing.sm,
                  runSpacing: DriverSpacing.sm,
                  children: [
                    for (final type in _postTypes)
                      DriverChip(
                        label: _labelForType(type),
                        colors: colors,
                        typography: typography,
                        selected: postType == type,
                        onTap: () => onPostTypeChanged(type),
                      ),
                  ],
                ),
                const SizedBox(height: DriverSpacing.md),
                TextField(
                  controller: messageController,
                  minLines: 4,
                  maxLines: 8,
                  style: typography.bodyMedium.copyWith(color: colors.text),
                  decoration: InputDecoration(
                    hintText: DriverStrings.communityPostMessageHint,
                    hintStyle:
                        typography.bodyMedium.copyWith(color: colors.textMuted),
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
              ] else ...[
                TextField(
                  controller: pollQuestionController,
                  minLines: 2,
                  maxLines: 4,
                  style: typography.bodyMedium.copyWith(color: colors.text),
                  decoration: InputDecoration(
                    hintText: DriverStrings.communityPollQuestionHint,
                    filled: true,
                    fillColor: colors.backgroundAlt,
                    border: OutlineInputBorder(
                      borderRadius: DriverRadius.smAll,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                ),
                const SizedBox(height: DriverSpacing.sm),
                for (var i = 0; i < pollOptionControllers.length; i++) ...[
                  TextField(
                    controller: pollOptionControllers[i],
                    style: typography.bodyMedium.copyWith(color: colors.text),
                    decoration: InputDecoration(
                      hintText:
                          '${DriverStrings.communityPollOptionHint} ${i + 1}',
                      filled: true,
                      fillColor: colors.backgroundAlt,
                      border: OutlineInputBorder(
                        borderRadius: DriverRadius.smAll,
                        borderSide: BorderSide(color: colors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                ],
                if (pollOptionControllers.length < 6)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: onAddPollOption,
                      icon: Icon(Icons.add_rounded, color: colors.primary),
                      label: Text(
                        DriverStrings.communityPollAddOption,
                        style: typography.labelMedium
                            .copyWith(color: colors.primary),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: DriverSpacing.md),
              DriverButton(
                label: DriverStrings.communityPostButton,
                colors: colors,
                typography: typography,
                onPressed: onSubmit,
                size: DriverButtonSize.lg,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _labelForType(String type) => switch (type) {
        'traffic' => DriverStrings.communityPostChipTraffic,
        'tip' => DriverStrings.communityPostChipTip,
        'help' => DriverStrings.communityPostChipHelp,
        _ => DriverStrings.communityPostChipGeneral,
      };
}
