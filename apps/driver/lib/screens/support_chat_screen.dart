import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../utils/validation_utils.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const SupportChatScreen({super.key, required this.ticketId});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String _status = 'open';
  String _category = '';
  bool _loading = true;
  bool _sending = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _verifyOwnershipAndLoad();
  }

  Future<void> _verifyOwnershipAndLoad() async {
    if (!isValidUuid(widget.ticketId)) {
      if (mounted) context.go('/driver/support');
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final isOwner = await HeyCabySupabase.client.rpc(
        'fn_verify_ticket_owner',
        params: {
          'p_ticket_id': widget.ticketId,
          'p_user_id': userId,
        },
      );
      if (isOwner != true) {
        if (mounted) context.go('/driver/support');
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Ticket ownership check failed: $e');
      if (mounted) context.go('/driver/support');
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
    setState(() => _sending = true);
    try {
      final result = await ref.read(driverDataServiceProvider).sendDriverSupportChatMessage(
            message: text,
            ticketId: widget.ticketId,
          );
      _controller.clear();
      if (!mounted) return;
      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.supportChatSendFailed)),
        );
        setState(() => _sending = false);
        return;
      }
      // Server persisted user + assistant messages; reload for full history (role/content or legacy).
      await _load();
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.supportChatSendFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final isClosed = _status == 'closed' || _status == 'resolved';

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
          _category.isNotEmpty ? _category : DriverStrings.ondersteuning,
          style: typo.headingMedium.copyWith(color: colors.text),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isClosed
                      ? colors.success.withValues(alpha: 0.1)
                      : colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isClosed ? DriverStrings.ticketStatusResolved : DriverStrings.open,
                  style: typo.labelSmall.copyWith(
                    color: isClosed ? colors.success : colors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _ChatBubble(
                      message: _messages[i],
                      colors: colors,
                      typo: typo,
                    ),
                  ),
          ),
          if (!isClosed)
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(
                  top: BorderSide(color: colors.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 2000,
                      style: typo.bodyMedium.copyWith(color: colors.text),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: DriverStrings.berichtTypen,
                        hintStyle: typo.bodySmall.copyWith(
                            color: colors.textSoft),
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
            ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _ChatBubble({
    required this.message,
    required this.colors,
    required this.typo,
  });

  /// Lee / OpenAI uses `role` + `content` + `ts`; legacy tickets use `sender_type` + `body` + `created_at`.
  static bool _isDriverBubble(Map<String, dynamic> m) {
    final role = m['role'] as String?;
    if (role == 'user') return true;
    if (role == 'assistant' || role == 'system') return false;
    return m['sender_type'] == 'driver';
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
    final isDriver = _isDriverBubble(message);
    final body = _bodyText(message);
    final createdAt = _messageTime(message);
    final timeStr =
        createdAt != null ? DateFormat('HH:mm').format(createdAt.toLocal()) : '';

    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDriver ? colors.accent : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isDriver ? 16 : 4),
            bottomRight: Radius.circular(isDriver ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              body,
              style: typo.bodyMedium.copyWith(
                color: isDriver ? colors.card : colors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: typo.labelSmall.copyWith(
                color: isDriver
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
