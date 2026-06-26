import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_brand_moment_body.dart';
import 'package:heycaby_driver/widgets/driver_me_community_body.dart';
import 'package:heycaby_driver/widgets/driver_rider_conversation_body.dart';
import 'package:heycaby_driver/widgets/driver_shift_command_flow_common.dart';

class DriverBrandMomentPreview extends StatelessWidget {
  const DriverBrandMomentPreview({
    super.key,
    required this.typography,
  });

  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverBrandMomentBody(
      typography: typography,
      copy: kDriverBrandMomentPreviewCopy,
      isIOS: true,
      exitOpacity: 1,
      logoFade: 1,
      logoScale: 1,
      glowOpacity: 0.14,
      pillar1Opacity: 1,
      pillar1Slide: 0,
      pillar2Opacity: 1,
      pillar2Slide: 0,
      pillar3Opacity: 1,
      pillar3Slide: 0,
      pillar4Opacity: 1,
      pillar4Slide: 0,
      canContinue: true,
      loadingProgress: 1,
      onContinue: () {},
    );
  }
}

class DriverShiftCommandPreview extends StatelessWidget {
  const DriverShiftCommandPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _snapshot = DriverShiftCommandEarningsSnapshot(
    todayAmount: '€142.50',
    weekRides: 18,
    weekAmount: '€892.40',
    avgPerRide: '€49.58',
    todayRideRows: [
      'Centraal → Schiphol · €38.20 · 14:22',
      'Kralingen → Delfshaven · €12.80 · 11:05',
    ],
  );

  @override
  Widget build(BuildContext context) {
    return DriverShiftCommandShellPreview(
      colors: colors,
      typography: typography,
      earningsTab: DriverStrings.earnings,
      availableRidesTab: DriverStrings.availableRides,
      earningsSelected: true,
      content: DriverShiftCommandEarningsPreview(
        colors: colors,
        typography: typography,
        snapshot: _snapshot,
        todayRidesTitle: DriverStrings.todaysRides,
        avgPerRideLabel: DriverStrings.avgPerRide,
      ),
    );
  }
}

class DriverRiderConversationPreview extends StatefulWidget {
  const DriverRiderConversationPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverRiderConversationPreview> createState() =>
      _DriverRiderConversationPreviewState();
}

class _DriverRiderConversationPreviewState
    extends State<DriverRiderConversationPreview> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static const _messages = [
    DriverRiderChatMessage(
      content: 'I am at the main entrance',
      isDriver: false,
      timeLabel: '2m ago',
    ),
    DriverRiderChatMessage(
      content: 'On my way — 3 minutes',
      isDriver: true,
      timeLabel: 'Just now',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverRiderConversationBody(
      colors: widget.colors,
      typography: widget.typography,
      loading: false,
      error: null,
      canUseChat: true,
      messages: _messages,
      messageController: _controller,
      scrollController: _scrollController,
      onBack: () {},
      onSend: () {},
      onBackWhenBlocked: () {},
    );
  }
}

class DriverMeCommunityPreview extends StatelessWidget {
  const DriverMeCommunityPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _channels = [
    DriverMeCommunityChannel(
      id: 'announcements',
      label: DriverStrings.announcements,
      icon: Icons.campaign_outlined,
    ),
    DriverMeCommunityChannel(
      id: 'general',
      label: DriverStrings.driverTalk,
      icon: Icons.chat_bubble_outline_rounded,
    ),
  ];

  static const _posts = [
    DriverMeCommunityPostItem(
      initials: 'HC',
      timeLabel: '19 May, 09:14',
      body: 'Tip: stand near Rotterdam Centraal between 07:30–09:00 for airport runs.',
    ),
    DriverMeCommunityPostItem(
      initials: 'DR',
      timeLabel: '18 May, 21:02',
      body: 'Anyone else seeing more scheduled rides this week?',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverMeCommunityBody(
      colors: colors,
      typography: typography,
      activeChannel: 'general',
      channels: _channels,
      onChannelChanged: (_) {},
      onRefresh: () async {},
      postsLoading: false,
      postsError: null,
      posts: _posts,
      onNewPost: () {},
      floatingActionButton: true,
    );
  }
}
