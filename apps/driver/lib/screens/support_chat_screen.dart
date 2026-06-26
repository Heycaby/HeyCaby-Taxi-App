import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../utils/validation_utils.dart';
import '../widgets/driver_ping_history_section.dart';
import '../widgets/driver_support_conversation_body.dart';

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
  String? _rideRequestId;
  bool _loading = true;
  bool _sending = false;
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
          .select('messages, status, category, ride_request_id')
          .eq('id', widget.ticketId)
          .single();
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(
              (res['messages'] as List?) ?? []);
          _status = res['status'] as String? ?? 'open';
          _category = res['category'] as String? ?? '';
          _rideRequestId = res['ride_request_id'] as String?;
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      unawaited(
        ref.read(driverDataServiceProvider).logClientTelemetry(
              scope: 'support_chat',
              event: 'load_failed',
              detail: e.toString(),
              extra: {'ticket_id': widget.ticketId},
            ),
      );
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
    HapticService.mediumTap();
    final allowed = await _ensureAiDisclosureAccepted();
    if (!allowed || !mounted) return;
    setState(() => _sending = true);
    try {
      final result = await ref.read(driverDataServiceProvider).sendDriverSupportChatMessage(
            message: text,
            ticketId: widget.ticketId,
          );
      _controller.clear();
      if (!mounted) return;
      if (!result.ok) {
        final localSaved = await _appendFallbackSupportMessage(text);
        if (!mounted) return;
        if (localSaved) {
          await _load();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(DriverStrings.supportChatOfflineSaved)),
          );
          setState(() => _sending = false);
          _scrollToBottom();
          return;
        }
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
    } catch (e) {
      unawaited(
        ref.read(driverDataServiceProvider).logClientTelemetry(
              scope: 'support_chat',
              event: 'send_failed_fallback',
              detail: e.toString(),
              extra: {'ticket_id': widget.ticketId},
            ),
      );
      final localSaved = await _appendFallbackSupportMessage(text);
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localSaved
                  ? DriverStrings.supportChatOfflineSaved
                  : DriverStrings.supportChatSendFailed,
            ),
          ),
        );
        if (localSaved) {
          await _load();
          if (!mounted) return;
          _scrollToBottom();
        }
      }
    }
  }

  Future<bool> _appendFallbackSupportMessage(String userText) async {
    unawaited(
      ref.read(driverDataServiceProvider).logClientTelemetry(
            scope: 'support_chat',
            event: 'local_fallback_append_attempt',
            extra: {'ticket_id': widget.ticketId},
          ),
    );
    try {
      final row = await HeyCabySupabase.client
          .from('tickets')
          .select('messages, status')
          .eq('id', widget.ticketId)
          .maybeSingle();
      if (row == null) return false;

      final status = (row['status'] as String? ?? 'open').toLowerCase();
      final shouldReopen =
          status == 'closed' || status == 'resolved' || status == 'auto_resolved';

      final existing = row['messages'];
      final list = existing is List ? List<dynamic>.from(existing) : <dynamic>[];
      final now = DateTime.now().toUtc().toIso8601String();
      list.add(<String, dynamic>{'role': 'user', 'content': userText, 'ts': now});
      list.add(<String, dynamic>{
        'role': 'assistant',
        'content':
            'Je bericht is opgeslagen. Support helpt je verder terwijl de AI-assistent tijdelijk niet beschikbaar is.',
        'ts': DateTime.now().toUtc().toIso8601String(),
      });

      await HeyCabySupabase.client.from('tickets').update({
        'messages': list,
        if (shouldReopen) 'status': 'open',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.ticketId);
      unawaited(
        ref.read(driverDataServiceProvider).logClientTelemetry(
              scope: 'support_chat',
              event: 'local_fallback_append_success',
              extra: {'ticket_id': widget.ticketId},
            ),
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('driver support local fallback failed: $e');
      }
      unawaited(
        ref.read(driverDataServiceProvider).logClientTelemetry(
              scope: 'support_chat',
              event: 'local_fallback_append_failed',
              detail: e.toString(),
              extra: {'ticket_id': widget.ticketId},
            ),
      );
      return false;
    }
  }

  Future<bool> _ensureAiDisclosureAccepted() async {
    if (_aiDisclosureAccepted) return true;
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DriverStrings.supportAiConsentIntro,
                  style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.4),
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),
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
              child: Text(DriverStrings.cancel, style: TextStyle(color: colors.textMid)),
            ),
            FilledButton(
              onPressed: consentChecked
                  ? () {
                      HapticService.mediumTap();
                      Navigator.of(ctx).pop(true);
                    }
                  : null,
              child: Text(DriverStrings.supportAiConsentContinue),
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

  Future<void> _markResolved() async {
    if (_sending || _loading) return;
    HapticService.mediumTap();
    try {
      await HeyCabySupabase.client.from('tickets').update({
        'status': 'resolved',
        'resolution_summary': 'Resolved by driver.',
        'resolution_outcome': 'user_confirmed_resolved',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.ticketId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.ticketStatusResolved)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.supportChatSendFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final isClosed = _isClosedStatus(_status);
    final messages = _messages
        .map(DriverSupportTicketMessageParser.fromMap)
        .toList();
    final rideId = _rideRequestId?.trim();

    return DriverSupportConversationBody(
      title: _category.isNotEmpty ? _category : DriverStrings.ondersteuning,
      colors: colors,
      typography: typography,
      topPanel: rideId != null && rideId.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DriverPingHistorySection(
                rideRequestId: rideId,
                colors: colors,
                typography: typography,
                initiallyExpanded: true,
                collapsible: true,
              ),
            )
          : null,
      statusLabel:
          isClosed ? DriverStrings.ticketStatusResolved : DriverStrings.open,
      statusClosed: isClosed,
      loading: _loading,
      messages: messages,
      messageController: _controller,
      sending: _sending,
      isClosed: isClosed,
      scrollController: _scrollController,
      onBack: () => context.pop(),
      onSend: _send,
      onMarkResolved: _markResolved,
    );
  }
}
