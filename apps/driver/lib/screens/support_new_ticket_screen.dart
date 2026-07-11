import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_raise_issue_body.dart';

class SupportNewTicketScreen extends ConsumerStatefulWidget {
  const SupportNewTicketScreen({super.key});

  @override
  ConsumerState<SupportNewTicketScreen> createState() =>
      _SupportNewTicketScreenState();
}

class _SupportNewTicketScreenState
    extends ConsumerState<SupportNewTicketScreen> {
  final _controller = TextEditingController();
  String _category = 'Rit probleem';
  bool _sending = false;

  static const _categories = [
    'Rit probleem',
    'Betaling',
    'Account',
    'Overige',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showSentSuccessDialog() async {
    if (!mounted) return;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          DriverStrings.supportMessageSentTitle,
          style: typo.titleMedium.copyWith(color: colors.text),
        ),
        content: Text(
          DriverStrings.supportMessageSentBody,
          style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(DriverStrings.done),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.push('/driver/support/lee');
            },
            child: Text(DriverStrings.chatWithLee),
          ),
        ],
      ),
    );
  }

  Future<void> _showSendFailedDialog() async {
    if (!mounted) return;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          DriverStrings.supportMessageSendFailedTitle,
          style: typo.titleMedium.copyWith(color: colors.text),
        ),
        content: Text(
          DriverStrings.supportMessageSendFailedBody,
          style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(DriverStrings.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.push('/driver/support/lee');
            },
            child: Text(DriverStrings.chatWithLee),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSupportMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    HapticService.mediumTap();
    setState(() => _sending = true);
    try {
      final client = HeyCabySupabase.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        await _showSendFailedDialog();
        return;
      }
      final msgId = DateTime.now().millisecondsSinceEpoch.toString();
      await client.from('tickets').insert({
        'user_type': 'driver',
        'user_id': userId,
        'category': _category,
        'status': 'open',
        'ai_handled': false,
        'messages': [
          {
            'id': msgId,
            'sender_type': 'driver',
            'role': 'user',
            'body': text,
            'content': text,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'read_at': null,
          }
        ],
      });
      _controller.clear();
      await _showSentSuccessDialog();
    } catch (_) {
      await _showSendFailedDialog();
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverRaiseIssueBody(
      colors: colors,
      typography: typography,
      categories: _categories,
      selectedCategory: _category,
      messageController: _controller,
      sending: _sending,
      onBack: _sending ? () {} : () => context.pop(),
      onCategorySelected: (cat) => setState(() => _category = cat),
      onSend: _sendSupportMessage,
    );
  }
}
