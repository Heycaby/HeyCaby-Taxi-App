import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/ui/driver_status_badge.dart';
import 'package:heycaby_driver/widgets/driver_help_hub_body.dart';
import 'package:heycaby_driver/widgets/driver_quick_answers_body.dart';
import 'package:heycaby_driver/widgets/driver_raise_issue_body.dart';
import 'package:heycaby_driver/widgets/driver_support_inbox_body.dart';

class DriverHelpHubPreview extends StatelessWidget {
  const DriverHelpHubPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static final _tickets = [
    DriverHelpHubTicketPreview(
      category: 'Rit probleem',
      statusLabel: DriverStrings.ticketStatusInProgress,
      statusTone: DriverStatusTone.warning,
    ),
    DriverHelpHubTicketPreview(
      category: 'Betaling',
      statusLabel: DriverStrings.ticketStatusResolved,
      statusTone: DriverStatusTone.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverHelpHubBody(
      colors: colors,
      typography: typography,
      ticketsLoading: false,
      tickets: _tickets,
      onBack: () {},
      onViewAllTickets: () {},
      onTicketTap: (_) {},
      onNewMessage: () {},
      onChatWithLee: () {},
      onViewThreads: () {},
      onViewFaq: () {},
    );
  }
}

class DriverQuickAnswersPreview extends StatelessWidget {
  const DriverQuickAnswersPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverQuickAnswersBody(
      colors: colors,
      typography: typography,
      sections: kDriverFaqSections.take(2).toList(),
      onBack: () {},
    );
  }
}

class DriverSupportInboxPreview extends StatelessWidget {
  const DriverSupportInboxPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static final _items = [
    DriverSupportInboxItem(
      category: 'Rit probleem',
      statusLabel: DriverStrings.open,
      statusTone: DriverStatusTone.warning,
      preview: 'Passagier kwam niet opdagen bij pickup',
      timeLabel: '18 mei 14:32',
    ),
    DriverSupportInboxItem(
      category: 'Betaling',
      statusLabel: DriverStrings.ticketStatusResolved,
      statusTone: DriverStatusTone.success,
      preview: 'Bedankt, opgelost!',
      timeLabel: '17 mei 09:10',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverSupportInboxBody(
      colors: colors,
      typography: typography,
      loading: false,
      items: _items,
      onBack: () {},
      onItemTap: (_) {},
    );
  }
}

class DriverRaiseIssuePreview extends StatefulWidget {
  const DriverRaiseIssuePreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverRaiseIssuePreview> createState() => _DriverRaiseIssuePreviewState();
}

class _DriverRaiseIssuePreviewState extends State<DriverRaiseIssuePreview> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DriverRaiseIssueBody(
      colors: widget.colors,
      typography: widget.typography,
      categories: const ['Rit probleem', 'Betaling', 'Account', 'Overige'],
      selectedCategory: 'Rit probleem',
      messageController: _controller,
      sending: false,
      onBack: () {},
      onCategorySelected: (_) {},
      onSend: () {},
    );
  }
}
