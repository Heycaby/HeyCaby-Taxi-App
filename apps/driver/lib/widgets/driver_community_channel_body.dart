import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import 'driver_community_flow_common.dart';

/// **Community Channel** — full scroll list for one channel.
class DriverCommunityChannelBody extends StatelessWidget {
  const DriverCommunityChannelBody({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.onRefresh,
    required this.content,
    this.showNewPostFab = false,
    this.onNewPost,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final Widget content;
  final bool showNewPostFab;
  final VoidCallback? onNewPost;

  @override
  Widget build(BuildContext context) {
    return DriverCommunityFlowScaffold(
      title: title,
      colors: colors,
      typography: typography,
      onBack: onBack,
      floatingActionButton: showNewPostFab && onNewPost != null
          ? DriverCommunityNewPostFab(
              colors: colors,
              typography: typography,
              onPressed: onNewPost!,
            )
          : null,
      body: EasyRefresh(
        onRefresh: onRefresh,
        child: content,
      ),
    );
  }
}
