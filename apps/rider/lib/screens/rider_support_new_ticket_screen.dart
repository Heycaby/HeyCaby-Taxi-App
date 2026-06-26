import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

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
  String _category = 'ride_issue';
  bool _sending = false;

  static const _categories = ['ride_issue', 'payment', 'account', 'other'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showSentSuccessDialog() async {
    if (!mounted) return;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          l10n.supportMessageSentTitle,
          style: typo.titleMedium.copyWith(color: colors.text),
        ),
        content: Text(
          l10n.supportMessageSentBody,
          style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dialogOk),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.push('/support/yaz');
            },
            child: Text(l10n.supportChatWithYaz),
          ),
        ],
      ),
    );
  }

  Future<void> _showSendFailedDialog() async {
    if (!mounted) return;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          l10n.supportMessageSendFailedTitle,
          style: typo.titleMedium.copyWith(color: colors.text),
        ),
        content: Text(
          l10n.supportMessageSendFailedBody,
          style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.growthModalClose),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.push('/support/yaz');
            },
            child: Text(l10n.supportChatWithYaz),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSupportMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final client = HeyCabySupabase.client;
      String? userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        try {
          final authRes = await client.auth.signInAnonymously();
          userId = authRes.user?.id;
        } catch (_) {
          userId = null;
        }
      }

      // Best effort: keep a support ticket in backend for team follow-up.
      if (userId != null && userId.isNotEmpty) {
        final msgTs = DateTime.now().toUtc().toIso8601String();
        await client.from('tickets').insert({
          'user_type': 'rider',
          'user_id': userId,
          'category': _category,
          'status': 'open',
          'ai_handled': false,
          'messages': [
            {
              'role': 'user',
              'content': text,
              'ts': msgTs,
            },
          ],
        });
        _controller.clear();
        await _showSentSuccessDialog();
      } else {
        await _showSendFailedDialog();
      }
    } catch (_) {
      await _showSendFailedDialog();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final categoryLabels = <String, String>{
      'ride_issue': l10n.supportCategoryRideIssue,
      'payment': l10n.supportCategoryPayment,
      'account': l10n.supportCategoryAccount,
      'other': l10n.supportOtherCategory,
    };

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
                  label: Text(categoryLabels[cat] ?? cat),
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
            const SizedBox(height: 10),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending ? null : _sendSupportMessage,
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
                    : Text(l10n.supportSendMessageButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
