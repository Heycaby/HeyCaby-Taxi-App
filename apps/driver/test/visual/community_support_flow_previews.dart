import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_community_channel_body.dart';
import 'package:heycaby_driver/widgets/driver_community_hub_body.dart';
import 'package:heycaby_driver/widgets/driver_community_hub_parts.dart';
import 'package:heycaby_driver/widgets/driver_liability_acknowledgment_body.dart';
import 'package:heycaby_driver/widgets/driver_support_conversation_body.dart';

import 'golden_text_theme.dart';

class DriverCommunityHubPreview extends StatelessWidget {
  const DriverCommunityHubPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _items = [
    CommunityTalkItem(
      'post-1',
      'driver-1',
      'Airport queue tips',
      'Anyone know the best pickup spot at Schiphol this week?',
      'general',
      '14:20',
      null,
    ),
    CommunityTalkItem(
      'post-2',
      'driver-2',
      'Night shift fuel',
      'Cheapest diesel near Rotterdam Centrum?',
      'general',
      '13:05',
      null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = colors.tokens;
    final heyTypo = buildDriverGoldenTypography();

    return DriverCommunityHubBody(
      colors: colors,
      typography: typography,
      activeFeed: 'general',
      hasUnreadNotifications: true,
      onNotifications: () {},
      onSearch: () {},
      onAnnouncementsTap: () {},
      onDriverTalkTap: () {},
      onViewAll: () {},
      onNewPost: () {},
      onRefresh: () async {},
      feedSlivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          sliver: SliverList.separated(
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => TalkRow(
              item: _items[i],
              colors: tokens,
              typo: heyTypo,
              likeCount: 3 + i,
              thanksCount: i,
              likedByMe: i == 0,
              thankedByMe: false,
              onLike: () {},
              onThanks: () {},
              canManage: false,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class DriverCommunityChannelPreview extends StatelessWidget {
  const DriverCommunityChannelPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _items = [
    CommunityTalkItem(
      'post-1',
      'driver-1',
      'Rate update',
      'Has anyone adjusted night tariffs after the fuel hike?',
      'general',
      '09:40',
      null,
    ),
    CommunityTalkItem(
      'post-2',
      'driver-2',
      'Document renewal',
      'Reminder to upload insurance before expiry.',
      'general',
      'Yesterday',
      null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = colors.tokens;
    final heyTypo = buildDriverGoldenTypography();

    return DriverCommunityChannelBody(
      title: DriverStrings.driverTalk,
      colors: colors,
      typography: typography,
      onBack: () {},
      showNewPostFab: true,
      onNewPost: () {},
      onRefresh: () async {},
      content: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => TalkRow(
          item: _items[i],
          colors: tokens,
          typo: heyTypo,
          likeCount: 5 - i,
          thanksCount: i + 1,
          likedByMe: false,
          thankedByMe: i == 1,
          onLike: () {},
          onThanks: () {},
          canManage: i == 0,
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
  }
}

class DriverSupportConversationPreview extends StatefulWidget {
  const DriverSupportConversationPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverSupportConversationPreview> createState() =>
      _DriverSupportConversationPreviewState();
}

class _DriverSupportConversationPreviewState
    extends State<DriverSupportConversationPreview> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;

  static const _messages = [
    DriverSupportTicketMessage(
      isDriver: true,
      content: 'My payout for yesterday is missing from the ledger.',
      timeLabel: '14:12',
    ),
    DriverSupportTicketMessage(
      isDriver: false,
      content:
          'Thanks for reaching out — we are checking your billing cycle and will update you shortly.',
      timeLabel: '14:18',
    ),
  ];

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

  @override
  Widget build(BuildContext context) {
    return DriverSupportConversationBody(
      title: 'Betaling',
      colors: widget.colors,
      typography: widget.typography,
      statusLabel: DriverStrings.open,
      statusClosed: false,
      loading: false,
      messages: _messages,
      messageController: _controller,
      sending: false,
      isClosed: false,
      scrollController: _scrollController,
      onBack: () {},
      onSend: () {},
      onMarkResolved: () {},
    );
  }
}

class DriverLiabilityAckPreview extends StatefulWidget {
  const DriverLiabilityAckPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverLiabilityAckPreview> createState() =>
      _DriverLiabilityAckPreviewState();
}

class _DriverLiabilityAckPreviewState extends State<DriverLiabilityAckPreview> {
  bool _checked = true;

  @override
  Widget build(BuildContext context) {
    return DriverLiabilityAcknowledgmentBody(
      title: 'Indemnification Declaration',
      colors: widget.colors,
      typography: widget.typography,
      documentText:
          'HEYCABY — Terms of Service — English (Governing Language)\n'
          'Version 1.0 | Effective Date: 1 May 2026\n\n'
          'Important Notice: These Terms of Service constitute a legally binding '
          'agreement between you and HeyCaby. Read them carefully and completely '
          'before using the platform.\n\n'
          'ARTICLE 1 — DEFINITIONS\n'
          'HeyCaby operates exclusively as a digital directory and communication platform.',
      waiverText:
          'You waive any claim that you were not aware of the contents of these documents, '
          'that you did not understand them, or that you did not have adequate opportunity to review them.',
      checkboxText:
          'I have read and agree to the Terms of Service and the Indemnification & Liability Declaration.',
      isDutch: false,
      isChecked: _checked,
      onBack: () {},
      onSelectEnglish: () {},
      onSelectDutch: () {},
      onToggleLanguage: () {},
      onCopy: () {},
      onCheckedChanged: (value) => setState(() => _checked = value),
    );
  }
}
