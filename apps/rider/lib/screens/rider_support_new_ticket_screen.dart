import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../services/rider_support_chat_service.dart';

/// Aligns with driver support categories (stored on `tickets.category`).
class RiderSupportNewTicketScreen extends ConsumerStatefulWidget {
  const RiderSupportNewTicketScreen({super.key});

  @override
  ConsumerState<RiderSupportNewTicketScreen> createState() =>
      _RiderSupportNewTicketScreenState();
}

class _RiderSupportNewTicketScreenState
    extends ConsumerState<RiderSupportNewTicketScreen> {
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

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final client = HeyCabySupabase.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final result = await RiderSupportChatService.sendMessage(message: text);
      if (!mounted) return;
      if (!result.ok || result.ticketId == null || result.ticketId!.isEmpty) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.supportChatSendFailed)),
        );
        return;
      }
      final ticketId = result.ticketId!;
      await client
          .from('tickets')
          .update({'category': _category})
          .eq('id', ticketId)
          .eq('user_type', 'rider')
          .eq('user_id', userId);
      if (mounted) {
        context.push('/support/chat/$ticketId');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.supportChatSendFailed)),
        );
        debugPrint('support new ticket failed: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.supportNewThread,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportPickCategory,
              style: typo.titleMedium.copyWith(color: colors.text),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final selected = cat == _category;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  selectedColor: colors.accent,
                  backgroundColor: colors.card,
                  labelStyle: typo.bodySmall.copyWith(
                    color: selected ? colors.card : colors.text,
                  ),
                  side: BorderSide(
                    color: selected ? colors.accent : colors.border,
                  ),
                  onSelected: (_) => setState(() => _category = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 6,
              maxLength: 2000,
              style: typo.bodyMedium.copyWith(color: colors.text),
              decoration: InputDecoration(
                hintText: l10n.supportTypeMessage,
                hintStyle: typo.bodySmall.copyWith(color: colors.textSoft),
                filled: true,
                fillColor: colors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.card,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _sending
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.card,
                        ),
                      )
                    : Text(l10n.supportStartChat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
