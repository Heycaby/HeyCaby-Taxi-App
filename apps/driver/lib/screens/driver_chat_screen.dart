import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../providers/driver_ride_unread_messages_provider.dart';
import '../services/sound_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_rider_conversation_body.dart';

String? _peerRiderSenderId(List<ChatMessage> messages) {
  for (final m in messages) {
    if (m.senderType == 'rider') return m.senderId;
  }
  return null;
}

class ChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String senderType;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderType,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rideKey = json['ride_request_id'] ?? json['ride_id'];
    final body = json['content'] ?? json['message'];
    return ChatMessage(
      id: json['id'] as String,
      rideId: rideKey?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderType: json['sender_type'] as String,
      message: body as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class DriverChatNotifier extends AutoDisposeAsyncNotifier<ChatState> {
  RealtimeChannel? _subscription;
  final Set<String> _blockedSenderKeys = {};

  static String _senderKey(String type, String id) => '$type:$id';

  @override
  Future<ChatState> build() async {
    ref.onDispose(() {
      _subscription?.unsubscribe();
    });
    return const ChatState();
  }

  Future<void> loadMessages(String rideId) async {
    state = const AsyncData(ChatState(isLoading: true));

    try {
      await _subscription?.unsubscribe();
      _subscription = null;
      _blockedSenderKeys.clear();
      final uid = HeyCabySupabase.client.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        final blocks = await HeyCabyRideChatBlocks.listForBlocker(
          rideId: rideId,
          blockerId: uid,
          blockerType: 'driver',
        );
        for (final b in blocks) {
          _blockedSenderKeys.add(_senderKey(b.blockedType, b.blockedId));
        }
      }

      final response = await HeyCabySupabase.client
          .from('messages')
          .select()
          .eq('ride_request_id', rideId)
          .order('created_at', ascending: true)
          .order('id', ascending: true);

      final raw = (response as List)
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
      final messages = raw
          .where((m) => !_blockedSenderKeys
              .contains(_senderKey(m.senderType, m.senderId)))
          .toList();

      state = AsyncData(ChatState(messages: messages));
      _subscribeToMessages(rideId);
    } catch (e) {
      if (kDebugMode) debugPrint('Chat load error: $e');
      state = const AsyncData(ChatState(error: 'chat_load_failed'));
    }
  }

  void _subscribeToMessages(String rideId) {
    _subscription = HeyCabySupabase.client
        .channel('messages:$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_request_id',
            value: rideId,
          ),
          callback: (payload) {
            final newMessage = ChatMessage.fromJson(payload.newRecord);
            if (_blockedSenderKeys.contains(
                _senderKey(newMessage.senderType, newMessage.senderId))) {
              return;
            }
            _appendMessage(newMessage);
            // Play notification sound only for messages from rider
            if (newMessage.senderType == 'rider') {
              SoundService().playNotification();
            }
          },
        )
        .subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(_recoverCanonicalMessages(rideId));
      }
    });
  }

  Future<void> _recoverCanonicalMessages(String rideId) async {
    try {
      final response = await HeyCabySupabase.client
          .from('messages')
          .select()
          .eq('ride_request_id', rideId)
          .order('created_at', ascending: true)
          .order('id', ascending: true);
      final recovered = (response as List)
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .where((message) => !_blockedSenderKeys
              .contains(_senderKey(message.senderType, message.senderId)));
      final current = state.value?.messages ?? const <ChatMessage>[];
      final byId = <String, ChatMessage>{
        for (final message in current) message.id: message,
        for (final message in recovered) message.id: message,
      };
      final merged = byId.values.toList()
        ..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
      state = AsyncData(ChatState(messages: merged));
    } catch (_) {
      // The open channel remains usable; the next reconnect retries recovery.
    }
  }

  void _appendMessage(ChatMessage message) {
    final currentMessages = state.value?.messages ?? [];
    if (currentMessages.any((m) => m.id == message.id)) return;
    final messages = [...currentMessages, message]..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    state = AsyncData(ChatState(messages: messages));
  }

  Future<bool> blockRider({
    required String rideId,
    required String riderSenderId,
  }) async {
    final uid = HeyCabySupabase.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return false;
    final ok = await HeyCabyRideChatBlocks.blockParticipant(
      rideId: rideId,
      blockerId: uid,
      blockerType: 'driver',
      blockedId: riderSenderId,
      blockedType: 'rider',
    );
    if (ok) {
      _blockedSenderKeys.add(_senderKey('rider', riderSenderId));
      final current = state.value?.messages ?? [];
      state = AsyncData(
        ChatState(
          messages: current
              .where((m) => !_blockedSenderKeys
                  .contains(_senderKey(m.senderType, m.senderId)))
              .toList(),
        ),
      );
    }
    return ok;
  }

  Future<bool> reportRider({
    required String rideId,
    required String riderSenderId,
    String? reason,
  }) async {
    final uid = HeyCabySupabase.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return false;
    return HeyCabyRideChatReports.reportParticipant(
      rideId: rideId,
      reporterId: uid,
      reporterType: 'driver',
      reportedId: riderSenderId,
      reportedType: 'rider',
      reason: reason,
    );
  }

  Future<String?> sendMessage(
    String rideId,
    String message, {
    required String senderId,
    String? idempotencyKey,
  }) async {
    final retryKey =
        idempotencyKey ?? HeyCabyRideChatMessages.newIdempotencyKey();
    final pendingId = 'pending-$retryKey';
    _appendMessage(
      ChatMessage(
        id: pendingId,
        rideId: rideId,
        senderId: senderId,
        senderType: 'driver',
        message: message,
        createdAt: DateTime.now(),
        isRead: false,
      ),
    );

    try {
      final row = await HeyCabyRideChatMessages.send(
        rideId: rideId,
        idempotencyKey: retryKey,
        content: message,
      );
      final canonical = ChatMessage.fromJson(row);
      final current = state.value?.messages ?? [];
      final messages = current.where((m) => m.id != pendingId).toList();
      if (!messages.any((m) => m.id == canonical.id)) {
        messages.add(canonical);
      }
      messages.sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
      state = AsyncData(
        ChatState(
          messages: messages,
          error: null,
        ),
      );
      return null;
    } catch (_) {
      final afterError = state.value?.messages ?? [];
      state = AsyncData(
        ChatState(
          messages: afterError.where((m) => m.id != pendingId).toList(),
          error: 'Failed to send message',
        ),
      );
      return retryKey;
    }
  }
}

final driverChatProvider =
    AsyncNotifierProvider.autoDispose<DriverChatNotifier, ChatState>(
  DriverChatNotifier.new,
);

class DriverChatScreen extends ConsumerStatefulWidget {
  const DriverChatScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends ConsumerState<DriverChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _retryMessage;
  String? _retryIdempotencyKey;

  bool _chatAllowedForCurrentState(DriverData driver) {
    final activeRideMatches = driver.activeRideId == widget.rideId;
    if (!activeRideMatches) return false;
    return switch (driver.appState) {
      DriverAppState.assigned ||
      DriverAppState.arrived ||
      DriverAppState.inProgress ||
      DriverAppState.completingRide =>
        true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(driverChatProvider.notifier).loadMessages(widget.rideId);
      await ref
          .read(driverRideUnreadMessageCountProvider(widget.rideId).notifier)
          .markAllRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = HeyCabySupabase.client.auth.currentUser?.id;
    if (userId == null) return;

    final retryKey = _retryMessage == text ? _retryIdempotencyKey : null;
    _messageController.clear();
    final failedKey = await ref.read(driverChatProvider.notifier).sendMessage(
          widget.rideId,
          text,
          senderId: userId,
          idempotencyKey: retryKey,
        );
    if (failedKey == null) {
      _retryMessage = null;
      _retryIdempotencyKey = null;
    } else {
      _retryMessage = text;
      _retryIdempotencyKey = failedKey;
      if (_messageController.text.trim().isEmpty) {
        _messageController.text = text;
        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
      }
    }

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _sendQuickReply(String text) async {
    _messageController.text = text;
    await _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final chatState = ref.watch(driverChatProvider);
    final driver = ref.watch(driverStateProvider);
    final canUseChat = _chatAllowedForCurrentState(driver);
    final quickReplies = [
      DriverStrings.chatQuickImHere,
      DriverStrings.chatQuickOnMyWay,
      DriverStrings.chatQuickTwoMinutes,
    ];
    final chatSubtitle = driver.pickupAddress;

    final menu = chatState.maybeWhen(
      data: (s) {
        final peer = _peerRiderSenderId(s.messages);
        if (peer == null) return null;
        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: colors.text),
          onSelected: (v) => _onChatMenuSelected(v, peer),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'report',
              child: Text(DriverStrings.reportRider),
            ),
            PopupMenuItem(
              value: 'block',
              child: Text(DriverStrings.blockRider),
            ),
          ],
        );
      },
      orElse: () => null,
    );

    return chatState.when(
      data: (state) {
        final messages = state.messages
            .map(
              (m) => DriverRiderChatMessage(
                content: m.message,
                isDriver: m.senderType == 'driver',
                timeLabel: driverRiderChatTimeLabel(m.createdAt),
              ),
            )
            .toList();

        return DriverRiderConversationBody(
          colors: colors,
          typography: typography,
          loading: state.isLoading,
          error: state.error,
          canUseChat: canUseChat,
          messages: messages,
          messageController: _messageController,
          scrollController: _scrollController,
          onBack: () => context.pop(),
          onSend: _sendMessage,
          onBackWhenBlocked: () => context.pop(),
          subtitle: chatSubtitle,
          quickReplies: quickReplies,
          onQuickReply: _sendQuickReply,
          menu: menu != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: menu,
                )
              : null,
        );
      },
      loading: () => DriverRiderConversationBody(
        colors: colors,
        typography: typography,
        loading: true,
        error: null,
        canUseChat: canUseChat,
        messages: const [],
        messageController: _messageController,
        scrollController: _scrollController,
        onBack: () => context.pop(),
        onSend: _sendMessage,
        onBackWhenBlocked: () => context.pop(),
      ),
      error: (error, _) => DriverRiderConversationBody(
        colors: colors,
        typography: typography,
        loading: false,
        error: 'Error: $error',
        canUseChat: canUseChat,
        messages: const [],
        messageController: _messageController,
        scrollController: _scrollController,
        onBack: () => context.pop(),
        onSend: _sendMessage,
        onBackWhenBlocked: () => context.pop(),
      ),
    );
  }

  Future<void> _onChatMenuSelected(String action, String peer) async {
    if (action == 'report') {
      await _reportRider(peer);
      return;
    }
    if (action == 'block') {
      await _blockRider(peer);
    }
  }

  Future<void> _reportRider(String peer) async {
    final reason = TextEditingController();
    final themeColors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final submit = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(
          DriverStrings.reportRiderTitle,
          style: typo.bodyLarge.copyWith(color: themeColors.text),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DriverStrings.reportRiderBody,
                style: typo.bodyMedium.copyWith(color: themeColors.textMid),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLines: 3,
                style: typo.bodyMedium.copyWith(color: themeColors.text),
                decoration: InputDecoration(
                  hintText: DriverStrings.reportReasonHint,
                  hintStyle:
                      typo.bodySmall.copyWith(color: themeColors.textSoft),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(
              DriverStrings.cancel,
              style: TextStyle(color: themeColors.accent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(
              DriverStrings.reportRider,
              style: TextStyle(color: themeColors.error),
            ),
          ),
        ],
      ),
    );
    if (submit != true || !mounted) return;
    final sent = await ref.read(driverChatProvider.notifier).reportRider(
          rideId: widget.rideId,
          riderSenderId: peer,
          reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent ? DriverStrings.reportSubmitted : DriverStrings.chatReportFailed,
        ),
      ),
    );
  }

  Future<void> _blockRider(String peer) async {
    final themeColors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(
          DriverStrings.blockRider,
          style: typo.bodyLarge.copyWith(color: themeColors.text),
        ),
        content: Text(
          DriverStrings.blockRiderConfirm,
          style: typo.bodyMedium.copyWith(color: themeColors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(
              DriverStrings.cancel,
              style: TextStyle(color: themeColors.accent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(
              DriverStrings.blockRider,
              style: TextStyle(color: themeColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final blocked = await ref.read(driverChatProvider.notifier).blockRider(
          rideId: widget.rideId,
          riderSenderId: peer,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          blocked ? DriverStrings.blockRider : DriverStrings.chatBlockFailed,
        ),
      ),
    );
  }
}
