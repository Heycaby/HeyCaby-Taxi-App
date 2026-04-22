import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../services/sound_service.dart';

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
          .order('created_at', ascending: true);

      final raw = (response as List)
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
      final messages = raw
          .where((m) =>
              !_blockedSenderKeys.contains(_senderKey(m.senderType, m.senderId)))
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
            if (_blockedSenderKeys
                .contains(_senderKey(newMessage.senderType, newMessage.senderId))) {
              return;
            }
            final currentMessages = state.value?.messages ?? [];
            state = AsyncData(
              ChatState(messages: [...currentMessages, newMessage]),
            );
            // Play notification sound only for messages from rider
            if (newMessage.senderType == 'rider') {
              SoundService().playNotification();
            }
          },
        )
        .subscribe();
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

  Future<void> sendMessage(String rideId, String message,
      {required String senderId}) async {
    try {
      await HeyCabySupabase.client.from('messages').insert({
        'ride_request_id': rideId,
        'sender_id': senderId,
        'sender_type': 'driver',
        'content': message,
      });
    } catch (e) {
      state = AsyncData(
        state.value!.copyWith(error: 'Failed to send message'),
      );
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

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(driverChatProvider.notifier).loadMessages(widget.rideId));
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

    _messageController.clear();
    await ref
        .read(driverChatProvider.notifier)
        .sendMessage(widget.rideId, text, senderId: userId);

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<HeyCabyColorTokens>()!;
    final typo = theme.extension<HeyCabyTypography>()!;
    final chatState = ref.watch(driverChatProvider);

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
          DriverStrings.chatWithRiderTitle,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        actions: [
          Builder(
            builder: (ctx) {
              return chatState.maybeWhen(
                data: (s) {
                  final peer = _peerRiderSenderId(s.messages);
                  if (peer == null) return const SizedBox.shrink();
                  return PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: colors.text),
                    onSelected: (v) async {
                      if (v == 'report') {
                        final reason = TextEditingController();
                        final submit = await showDialog<bool>(
                          context: ctx,
                          builder: (dCtx) => AlertDialog(
                            backgroundColor: colors.card,
                            title: Text(
                              DriverStrings.reportRiderTitle,
                              style: typo.bodyLarge.copyWith(color: colors.text),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    DriverStrings.reportRiderBody,
                                    style: typo.bodyMedium
                                        .copyWith(color: colors.textMid),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: reason,
                                    maxLines: 3,
                                    style: typo.bodyMedium
                                        .copyWith(color: colors.text),
                                    decoration: InputDecoration(
                                      hintText: DriverStrings.reportReasonHint,
                                      hintStyle: typo.bodySmall
                                          .copyWith(color: colors.textSoft),
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
                                  style: TextStyle(color: colors.accent),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: Text(
                                  DriverStrings.reportRider,
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (submit != true || !ctx.mounted) return;
                        final sent = await ref
                            .read(driverChatProvider.notifier)
                            .reportRider(
                              rideId: widget.rideId,
                              riderSenderId: peer,
                              reason: reason.text.trim().isEmpty
                                  ? null
                                  : reason.text.trim(),
                            );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              sent
                                  ? DriverStrings.reportSubmitted
                                  : DriverStrings.chatReportFailed,
                            ),
                          ),
                        );
                        return;
                      }
                      if (v != 'block') return;
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (dCtx) => AlertDialog(
                          title: Text(DriverStrings.blockRider,
                              style: typo.bodyLarge.copyWith(color: colors.text)),
                          content: Text(
                            DriverStrings.blockRiderConfirm,
                            style: typo.bodyMedium.copyWith(color: colors.textMid),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: Text(DriverStrings.cancel,
                                  style: TextStyle(color: colors.accent)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: Text(DriverStrings.blockRider,
                                  style: TextStyle(color: colors.error)),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !ctx.mounted) return;
                      final blocked = await ref
                          .read(driverChatProvider.notifier)
                          .blockRider(
                              rideId: widget.rideId, riderSenderId: peer);
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            blocked
                                ? DriverStrings.blockRider
                                : DriverStrings.chatBlockFailed,
                          ),
                        ),
                      );
                    },
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
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
      body: chatState.when(
        data: (state) {
          if (state.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: colors.accent),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final msg = state.messages[index];
                    final isDriver = msg.senderType == 'driver';
                    return _MessageBubble(
                      message: msg.message,
                      isDriver: isDriver,
                      timestamp: msg.createdAt,
                      colors: colors,
                      typo: typo,
                    );
                  },
                ),
              ),
              _MessageInput(
                controller: _messageController,
                onSend: _sendMessage,
                colors: colors,
                typo: typo,
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
        error: (error, _) => Center(
          child: Text(
            'Error: $error',
            style: typo.bodyMedium.copyWith(color: colors.error),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isDriver;
  final DateTime timestamp;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _MessageBubble({
    required this.message,
    required this.isDriver,
    required this.timestamp,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDriver ? colors.accent : colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: typo.bodyMedium.copyWith(
                color: colors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: typo.labelSmall.copyWith(
                color: isDriver
                    ? colors.text.withValues(alpha: 0.72)
                    : colors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  _MessageInput({
    required this.controller,
    required this.onSend,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 2000,
              style: typo.bodyMedium.copyWith(color: colors.text),
              decoration: InputDecoration(
                counterText: '',
                hintText: DriverStrings.chatTypeMessageHint,
                hintStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
                filled: true,
                fillColor: colors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            icon: Icon(Icons.send, color: colors.accent),
            style: IconButton.styleFrom(
              backgroundColor: colors.accentL,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
