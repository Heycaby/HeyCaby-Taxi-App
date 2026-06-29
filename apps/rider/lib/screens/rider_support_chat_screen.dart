import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/booking/booking_flow_screen_header.dart';
import '../services/rider_support_chat_service.dart';

class RiderSupportChatScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const RiderSupportChatScreen({super.key, required this.ticketId});

  @override
  ConsumerState<RiderSupportChatScreen> createState() =>
      _RiderSupportChatScreenState();
}

class _RiderSupportChatScreenState extends ConsumerState<RiderSupportChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String _status = 'open';
  String _category = '';
  bool _loading = true;
  bool _sending = false;
  bool _assistantThinking = false;
  bool _aiDisclosureAccepted = false;
  StreamSubscription? _subscription;

  bool _isClosedStatus(String status) {
    final s = status.toLowerCase();
    return s == 'closed' || s == 'resolved' || s == 'auto_resolved';
  }

  @override
  void initState() {
    super.initState();
    _verifyOwnershipAndLoad();
  }

  Future<void> _verifyOwnershipAndLoad() async {
    if (widget.ticketId.trim().isEmpty) {
      if (mounted) context.go('/support');
      return;
    }

    final client = Supabase.instance.client;
    String? userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      try {
        final authRes = await client.auth.signInAnonymously();
        userId = authRes.user?.id;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Rider support chat anonymous sign-in failed: $e');
        }
      }
    }
    if (userId == null) {
      if (mounted) context.go('/home');
      return;
    }

    try {
      final row = await HeyCabySupabase.client
          .from('tickets')
          .select('id')
          .eq('id', widget.ticketId)
          .eq('user_id', userId)
          .eq('user_type', 'rider')
          .maybeSingle();
      if (row == null) {
        if (mounted) context.go('/support');
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Rider ticket ownership check failed: $e');
      if (mounted) context.go('/support');
      return;
    }

    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await HeyCabySupabase.client
          .from('tickets')
          .select('messages, status, category')
          .eq('id', widget.ticketId)
          .single();
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(
              (res['messages'] as List?) ?? []);
          _status = res['status'] as String? ?? 'open';
          _category = res['category'] as String? ?? '';
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _subscription = HeyCabySupabase.client
        .from('tickets')
        .stream(primaryKey: ['id'])
        .eq('id', widget.ticketId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final ticket = data.first;
            setState(() {
              _messages = List<Map<String, dynamic>>.from(
                  (ticket['messages'] as List?) ?? []);
              _status = ticket['status'] as String? ?? 'open';
            });
            _scrollToBottom();
          }
        });
  }

  Future<bool> _ensureAiDisclosureAccepted() async {
    if (_aiDisclosureAccepted) return true;
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.supportAiConsentIntro,
                  style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.supportAiConsentDataSent,
                  style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.supportAiConsentThirdParty,
                  style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.supportAiConsentPolicy,
                  style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.5),
                ),
                const SizedBox(height: 10),
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
              child: Text(l10n.cancel, style: TextStyle(color: colors.textMid)),
            ),
            FilledButton(
              onPressed: consentChecked ? () => Navigator.of(ctx).pop(true) : null,
              child: Text(l10n.supportAiConsentContinue),
            ),
          ],
        ),
      ),
    );
    if (approved != true) return false;
    if (!mounted) return false;
    setState(() => _aiDisclosureAccepted = true);
    return true;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final allowed = await _ensureAiDisclosureAccepted();
    if (!allowed || !mounted) return;
    final optimisticTs = DateTime.now().toUtc().toIso8601String();
    final optimisticMessage = <String, dynamic>{
      'role': 'user',
      'content': text,
      'ts': optimisticTs,
    };
    _controller.clear();
    setState(() {
      _sending = true;
      _assistantThinking = true;
      _messages = [..._messages, optimisticMessage];
    });
    _scrollToBottom();
    try {
      final result = await RiderSupportChatService.sendMessage(
        message: text,
        ticketId: widget.ticketId,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => const RiderSupportChatResult(
          ok: false,
          error: 'timeout',
        ),
      );
      if (!mounted) return;
      if (!result.ok) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _messages = _messages.where((m) => m['ts'] != optimisticTs).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.error == 'timeout'
                  ? l10n.supportChatOfflineSaved
                  : l10n.supportChatSendFailed,
            ),
          ),
        );
        return;
      }
      if (result.usedLocalFallback && mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.supportChatOfflineSaved)),
        );
      }
      await _load();
      if (mounted) {
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages = _messages.where((m) => m['ts'] != optimisticTs).toList();
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.supportChatSendFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _assistantThinking = false;
        });
      }
    }
  }

  Future<void> _markResolved() async {
    if (_sending || _loading) return;
    try {
      await HeyCabySupabase.client.from('tickets').update({
        'status': 'resolved',
        'resolution_summary': 'Resolved by rider.',
        'resolution_outcome': 'user_confirmed_resolved',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.ticketId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.supportTicketResolved)),
      );
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.supportChatSendFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final isClosed = _isClosedStatus(_status);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: _category.isNotEmpty ? _category : l10n.support,
              icon: Icons.support_agent_rounded,
              onBack: () => context.pop(),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isClosed
                      ? colors.success.withValues(alpha: 0.12)
                      : colors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isClosed
                        ? colors.success.withValues(alpha: 0.3)
                        : colors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isClosed ? l10n.supportTicketResolved : l10n.supportTicketOpen,
                  style: typo.labelSmall.copyWith(
                    color: isClosed ? colors.success : colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_assistantThinking ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_assistantThinking && i == _messages.length) {
                        return _AssistantTypingBubble(
                          colors: colors,
                          typo: typo,
                        );
                      }
                      return _SupportBubble(
                        message: _messages[i],
                        colors: colors,
                        typo: typo,
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, mq.padding.bottom + 8),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(
                top: BorderSide(color: colors.border, width: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isClosed) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _markResolved,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        'MARK AS RESOLVED',
                        style: typo.labelLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.success,
                        foregroundColor: colors.card,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLength: 2000,
                        style: typo.bodyMedium.copyWith(color: colors.text),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: isClosed
                              ? 'Send a message to reopen this ticket'
                              : l10n.supportTypeMessage,
                          hintStyle:
                              typo.bodySmall.copyWith(color: colors.textSoft),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: colors.accent),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: Icon(Icons.send, color: colors.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _SupportBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _SupportBubble({
    required this.message,
    required this.colors,
    required this.typo,
  });

  /// AI rows use `role` + `content` + `ts`; legacy uses `sender_type` + `body` + `created_at`.
  static bool _isRiderBubble(Map<String, dynamic> m) {
    final role = m['role'] as String?;
    if (role == 'user') return true;
    if (role == 'assistant' || role == 'system') return false;
    return m['sender_type'] == 'rider';
  }

  static String _bodyText(Map<String, dynamic> m) {
    final c = m['content'] as String?;
    if (c != null && c.isNotEmpty) return c;
    return m['body'] as String? ?? '';
  }

  static DateTime? _messageTime(Map<String, dynamic> m) {
    final ts = m['ts'] as String? ?? m['created_at'] as String?;
    return DateTime.tryParse(ts ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final isRider = _isRiderBubble(message);
    final body = _bodyText(message);
    final createdAt = _messageTime(message);
    final timeStr =
        createdAt != null ? DateFormat('HH:mm').format(createdAt.toLocal()) : '';

    return Align(
      alignment: isRider ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isRider ? colors.accent : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isRider ? 16 : 4),
            bottomRight: Radius.circular(isRider ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              body,
              style: typo.bodyMedium.copyWith(
                color: isRider ? colors.card : colors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: typo.labelSmall.copyWith(
                color: isRider
                    ? colors.card.withValues(alpha: 0.7)
                    : colors.textSoft,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0);
  }
}

class _AssistantTypingBubble extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _AssistantTypingBubble({
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '...',
              style: typo.bodyMedium.copyWith(color: colors.textSoft),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 150.ms);
  }
}
