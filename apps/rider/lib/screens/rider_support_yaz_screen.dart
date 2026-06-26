import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/rider_support_chat_service.dart';

class RiderSupportYazScreen extends ConsumerStatefulWidget {
  const RiderSupportYazScreen({super.key});

  @override
  ConsumerState<RiderSupportYazScreen> createState() => _RiderSupportYazScreenState();
}

class _RiderSupportYazScreenState extends ConsumerState<RiderSupportYazScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = <Map<String, String>>[];
  bool _sending = false;
  bool _accepted = false;
  String? _ticketId;
  String? _blockingError;

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

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'hello@heycaby.nl',
      queryParameters: const <String, String>{
        'subject': 'HeyCaby Rider Support - AI chat fallback',
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _ensureAuthSession() async {
    final l10n = AppLocalizations.of(context);
    final client = HeyCabySupabase.client;
    if (client.auth.currentSession != null) return true;
    try {
      await client.auth.signInAnonymously();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Yaz chat anonymous sign-in failed: $e');
      final text = e.toString();
      if (text.contains('anonymous_provider_disabled')) {
        _blockingError = l10n.supportYazUnavailableGuestAuthDisabled;
      } else {
        _blockingError = l10n.supportYazUnavailableTemporary;
      }
      return false;
    }
  }

  Future<bool> _showDisclosure() async {
    if (_accepted) return true;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final l10n = AppLocalizations.of(context);
    bool consentChecked = false;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.card,
          title: Text(
            l10n.supportAiConsentTitle,
            style: typo.titleMedium.copyWith(color: colors.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.supportAiConsentIntro,
                    style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.4)),
                const SizedBox(height: 8),
                Text(l10n.supportAiConsentDataSent,
                    style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5)),
                const SizedBox(height: 8),
                Text(l10n.supportAiConsentThirdParty,
                    style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5)),
                const SizedBox(height: 8),
                Text(l10n.supportAiConsentPolicy,
                    style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5)),
                const SizedBox(height: 8),
                Text(l10n.supportAiConsentEmailOption,
                    style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5)),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: consentChecked,
                  onChanged: (v) => setDialogState(() => consentChecked = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    l10n.supportAiConsentCheckbox,
                    style: typo.bodySmall.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.supportAiConsentSendEmail),
            ),
            FilledButton(
              onPressed: consentChecked ? () => Navigator.of(ctx).pop(true) : null,
              child: Text(l10n.supportAiConsentContinue),
            ),
          ],
        ),
      ),
    );
    if (approved == null) {
      await _openSupportEmail();
      return false;
    }
    if (approved != true) return false;
    if (!mounted) return false;
    setState(() => _accepted = true);
    return true;
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final signedIn = await _ensureAuthSession();
    if (!signedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_blockingError ?? l10n.supportYazUnavailableTemporary)),
      );
      setState(() {});
      return;
    }

    setState(() {
      _sending = true;
      _messages.add({'role': 'user', 'content': text});
    });
    _controller.clear();

    final result = await RiderSupportChatService.sendMessage(
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
        _messages.add({
          'role': 'assistant',
          'content': l10n.supportYazFallbackReply,
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
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: colors.text),
        ),
        title: Text(l10n.supportChatWithYaz),
      ),
      body: Column(
        children: [
          if (_blockingError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _blockingError!,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                    ),
                  ),
                  TextButton(
                    onPressed: _openSupportEmail,
                    child: Text(l10n.supportEmailSupport),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_taxi_outlined, color: colors.accent, size: 44),
                        const SizedBox(height: 10),
                        Text(
                          l10n.supportYazAssistantTitle,
                          style: typo.titleMedium.copyWith(color: colors.text),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.supportYazAssistantSubtitle,
                          style: typo.bodySmall.copyWith(color: colors.textSoft),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isUser = m['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: isUser ? colors.accent : colors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: colors.border, width: 0.5),
                          ),
                          child: Text(
                            m['content'] ?? '',
                            style: typo.bodyMedium.copyWith(
                              color: isUser ? colors.card : colors.text,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: l10n.supportYazMessageHint,
                        filled: true,
                        fillColor: colors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: _sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.card,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

