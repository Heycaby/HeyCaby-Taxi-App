import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import 'driver_community_create_post_body.dart';

Future<void> showCreatePostSheet(
  BuildContext context,
  WidgetRef ref,
  HeyCabyColorTokens colors,
  HeyCabyTypography typo,
) async {
  final driverColors = DriverColors.fromTheme(colors);
  final driverTypography = DriverTypography.fromTheme(typo);
  final message = TextEditingController();
  final pollQuestion = TextEditingController();
  final optionCtrls = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  var type = 'traffic';
  var isPoll = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DriverCommunityCreatePostBody(
          colors: driverColors,
          typography: driverTypography,
          isPoll: isPoll,
          postType: type,
          messageController: message,
          pollQuestionController: pollQuestion,
          pollOptionControllers: optionCtrls,
          onKindChanged: (poll) => setState(() => isPoll = poll),
          onPostTypeChanged: (next) => setState(() => type = next),
          onAddPollOption: () {
            if (optionCtrls.length >= 6) return;
            setState(() => optionCtrls.add(TextEditingController()));
          },
          onSubmit: () async {
            HapticService.mediumTap();
            if (!isPoll) {
              final text = message.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(DriverStrings.communityPostMessageRequired),
                  ),
                );
                return;
              }
              final id = await ref.read(driverIdProvider.future);
              if (id == null) return;
              final payload = '[${type.toLowerCase()}] $text';
              final ok = await ref
                  .read(driverDataServiceProvider)
                  .createCommunityPost(id, 'general', payload);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (ok) {
                ref.invalidate(communityPostsProvider('general'));
                ref.invalidate(communityChannelFeedProvider('general'));
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(DriverStrings.communityPostNotSentSnack),
                  ),
                );
              }
              return;
            }

            final q = pollQuestion.text.trim();
            final opts = optionCtrls
                .map((c) => c.text.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            if (q.length < 3) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text(DriverStrings.communityPostMessageRequired),
                ),
              );
              return;
            }
            if (opts.length < 2) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text(DriverStrings.communityPollNeedTwoOptions),
                ),
              );
              return;
            }
            final postId = await ref
                .read(driverDataServiceProvider)
                .createCommunityPoll(question: q, options: opts);
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (postId != null && postId.isNotEmpty) {
              ref.invalidate(communityPostsProvider('general'));
              ref.invalidate(communityChannelFeedProvider('general'));
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(DriverStrings.communityPostNotSentSnack),
                ),
              );
            }
          },
        ),
      ),
    ),
  );
}
