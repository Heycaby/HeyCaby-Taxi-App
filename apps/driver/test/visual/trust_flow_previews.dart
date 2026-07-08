import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_ai_support_chat_body.dart';
import 'package:heycaby_driver/widgets/driver_feedback_loop_body.dart';
import 'package:heycaby_driver/widgets/driver_legal_trust_body.dart';

class DriverFeedbackLoopPreview extends StatefulWidget {
  const DriverFeedbackLoopPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverFeedbackLoopPreview> createState() =>
      _DriverFeedbackLoopPreviewState();
}

class _DriverFeedbackLoopPreviewState extends State<DriverFeedbackLoopPreview> {
  int _stars = 4;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'Friendly passenger');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: DriverFeedbackLoopBody(
        colors: widget.colors,
        typography: widget.typography,
        stars: _stars,
        commentController: _controller,
        maxCommentLength: 100,
        loading: false,
        riderName: 'Sophie van Dijk',
        destinationAddress: 'Schiphol Airport',
        pickupLat: 52.3740,
        pickupLng: 4.8952,
        destLat: 52.3105,
        destLng: 4.7683,
        onStarSelected: (star) => setState(() => _stars = star),
        onSubmit: () {},
        onSkip: () {},
        onClose: () {},
      ),
    );
  }
}

const _termsPreviewSections = [
  DriverLegalTrustSection(
    title: 'Introduction',
    body:
        'These Terms apply to your use of the HeyCaby platform as a Driver. '
        'By using the platform, you agree to these Terms.',
  ),
  DriverLegalTrustSection(
    title: '1. Platform role only',
    body:
        'HeyCaby provides a digital platform that enables independent drivers '
        'and riders to connect.\n\nHeyCaby is not a transport provider, taxi '
        'operator, employer, agent, or intermediary in any transport service.',
  ),
];

class DriverLegalTrustPreview extends StatelessWidget {
  const DriverLegalTrustPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverLegalTrustBody(
      title: 'Driver Terms of Service — Summary',
      colors: colors,
      typography: typography,
      isDutch: false,
      sections: _termsPreviewSections,
      onBack: () {},
      onSelectEnglish: () {},
      onSelectDutch: () {},
      onToggleLanguage: () {},
      onCopy: () {},
    );
  }
}

const _privacyPreviewSections = [
  DriverLegalTrustSection(
    title: 'Effective date',
    body:
        '1 May 2026\n\nThis Privacy Policy explains how HeyCaby processes '
        'your personal data when you use the platform as a driver.',
  ),
  DriverLegalTrustSection(
    title: '1. Data we collect',
    body:
        'HeyCaby may process account data, driver profile data, vehicle data, '
        'compliance data, trip and earnings data, support data, and technical data.',
  ),
];

class DriverPrivacyTrustPreview extends StatelessWidget {
  const DriverPrivacyTrustPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverLegalTrustBody(
      title: 'Privacy Policy',
      colors: colors,
      typography: typography,
      isDutch: false,
      sections: _privacyPreviewSections,
      onBack: () {},
      onSelectEnglish: () {},
      onSelectDutch: () {},
      onToggleLanguage: () {},
      onCopy: () {},
    );
  }
}

class DriverAiSupportChatPreview extends StatefulWidget {
  const DriverAiSupportChatPreview({
    super.key,
    required this.colors,
    required this.typography,
    this.empty = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool empty;

  @override
  State<DriverAiSupportChatPreview> createState() =>
      _DriverAiSupportChatPreviewState();
}

class _DriverAiSupportChatPreviewState extends State<DriverAiSupportChatPreview> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;

  static const _messages = [
    DriverAiChatMessage(
      isUser: true,
      content: 'How do I update my vehicle registration?',
    ),
    DriverAiChatMessage(
      isUser: false,
      content:
          'Open Profile → Vehicle, then edit your kenteken. HeyCaby will fetch RDW details automatically.',
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
    return DriverAiSupportChatBody(
      colors: widget.colors,
      typography: widget.typography,
      messages: widget.empty ? const [] : _messages,
      messageController: _controller,
      sending: false,
      scrollController: _scrollController,
      onBack: () {},
      onSend: () {},
      composerHint: DriverStrings.leeSupportPrompt,
    );
  }
}

class DriverAiSupportEmptyPreview extends StatelessWidget {
  const DriverAiSupportEmptyPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverAiSupportChatPreview(
      colors: colors,
      typography: typography,
      empty: true,
    );
  }
}
