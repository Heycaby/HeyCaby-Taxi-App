import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_ai_support_chat_body.dart';

class SupportLeeScreen extends ConsumerStatefulWidget {
  const SupportLeeScreen({super.key});

  @override
  ConsumerState<SupportLeeScreen> createState() => _SupportLeeScreenState();
}

class _SupportLeeScreenState extends ConsumerState<SupportLeeScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = <Map<String, String>>[];
  bool _sending = false;
  bool _accepted = false;
  String? _ticketId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await _showDisclosure();
      if (!ok && mounted) context.pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _showDisclosure() async {
    if (_accepted) return true;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    bool consentChecked = false;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            DriverStrings.supportAiConsentTitle,
            style: typo.titleMedium.copyWith(color: colors.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DriverStrings.supportAiConsentIntro,
                  style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  DriverStrings.supportAiConsentDataSent,
                  style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  DriverStrings.supportAiConsentThirdParty,
                  style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  DriverStrings.supportAiConsentPolicy,
                  style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  DriverStrings.supportAiConsentEmailOption,
                  style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: consentChecked,
                  onChanged: (v) => setDialogState(() => consentChecked = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    DriverStrings.supportAiConsentCheckbox,
                    style: typo.bodySmall.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(DriverStrings.cancel),
            ),
            FilledButton(
              onPressed: consentChecked ? () => Navigator.of(ctx).pop(true) : null,
              child: const Text(DriverStrings.supportAiConsentContinue),
            ),
          ],
        ),
      ),
    );
    if (approved != true) return false;
    if (!mounted) return false;
    setState(() => _accepted = true);
    return true;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _messages.add({'role': 'user', 'content': text});
    });
    _controller.clear();

    final result = await ref.read(driverDataServiceProvider).sendDriverSupportChatMessage(
          message: text,
          ticketId: _ticketId,
        );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _ticketId = result.ticketId ?? _ticketId;
      if (result.ok && (result.reply ?? '').trim().isNotEmpty) {
        _messages.add({'role': 'assistant', 'content': result.reply!.trim()});
      } else {
        if (kDebugMode) debugPrint('support-lee failed: ${result.error}');
        _messages.add({
          'role': 'assistant',
          'content': 'Lee is tijdelijk niet beschikbaar. Probeer opnieuw over een moment.',
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final messages = _messages
        .map(
          (m) => DriverAiChatMessage(
            isUser: m['role'] == 'user',
            content: m['content'] ?? '',
          ),
        )
        .toList();

    return DriverAiSupportChatBody(
      colors: colors,
      typography: typography,
      messages: messages,
      messageController: _controller,
      sending: _sending,
      scrollController: _scrollController,
      onBack: () => context.pop(),
      onSend: _send,
    );
  }
}

