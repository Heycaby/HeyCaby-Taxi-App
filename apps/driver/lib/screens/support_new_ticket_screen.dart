import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

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

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final client = HeyCabySupabase.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final msgId = DateTime.now().millisecondsSinceEpoch.toString();
      final res = await client
          .from('tickets')
          .insert({
            'user_type': 'driver',
            'user_id': userId,
            'category': _category,
            'messages': [
              {
                'id': msgId,
                'sender_type': 'driver',
                'body': text,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'read_at': null,
              }
            ],
          })
          .select('id')
          .single();
      if (mounted) {
        final ticketId = res['id'] as String;
        context.push('/driver/support/chat/$ticketId');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

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
          DriverStrings.nieuwBericht,
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
              'Categorie',
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
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                maxLength: 500,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: typo.bodyMedium.copyWith(color: colors.text),
                decoration: InputDecoration(
                  hintText: DriverStrings.berichtTypen,
                  hintStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
                  filled: true,
                  fillColor: colors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                child: _sending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onAccent,
                        ),
                      )
                    : Text(
                        DriverStrings.versturen,
                        style: typo.labelLarge.copyWith(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}
