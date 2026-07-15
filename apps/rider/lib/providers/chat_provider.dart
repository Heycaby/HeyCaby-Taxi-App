import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sound_service.dart';

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
    this.isRead = false,
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

class ChatNotifier extends AutoDisposeAsyncNotifier<ChatState> {
  RealtimeChannel? _subscription;
  String? _loadedRideId;
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
    if (_loadedRideId == rideId && _subscription != null) {
      await _recoverCanonicalMessages(rideId);
      return;
    }
    state = const AsyncData(ChatState(isLoading: true));

    try {
      await _subscription?.unsubscribe();
      _subscription = null;
      _blockedSenderKeys.clear();
      final identity = await ref.read(riderIdentityProvider.future);
      final blockerId = identity.identityId ?? '';
      if (blockerId.isNotEmpty) {
        final blocks = await HeyCabyRideChatBlocks.listForBlocker(
          rideId: rideId,
          blockerId: blockerId,
          blockerType: 'rider',
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
      _loadedRideId = rideId;
      _subscribeToMessages(rideId);
    } catch (e) {
      state = AsyncData(ChatState(error: e.toString()));
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
            // Play notification sound only for messages from driver
            if (newMessage.senderType == 'driver') {
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
    state = AsyncData(
      ChatState(messages: [...currentMessages, message]),
    );
  }

  /// Blocks the driver’s messages in this ride chat (App Store UGC / messaging).
  Future<bool> blockDriver({
    required String rideId,
    required String driverSenderId,
  }) async {
    final identity = await ref.read(riderIdentityProvider.future);
    final id = identity.identityId;
    if (id == null || id.isEmpty) return false;
    final ok = await HeyCabyRideChatBlocks.blockParticipant(
      rideId: rideId,
      blockerId: id,
      blockerType: 'rider',
      blockedId: driverSenderId,
      blockedType: 'driver',
    );
    if (ok) {
      _blockedSenderKeys.add(_senderKey('driver', driverSenderId));
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

  /// Reports the driver in this ride chat to HeyCaby moderation (UGC / App Review).
  Future<bool> reportDriver({
    required String rideId,
    required String driverSenderId,
    String? reason,
  }) async {
    final identity = await ref.read(riderIdentityProvider.future);
    final id = identity.identityId;
    if (id == null || id.isEmpty) return false;
    return HeyCabyRideChatReports.reportParticipant(
      rideId: rideId,
      reporterId: id,
      reporterType: 'rider',
      reportedId: driverSenderId,
      reportedType: 'driver',
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
        senderType: 'rider',
        message: message,
        createdAt: DateTime.now(),
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
    } catch (e) {
      final current = state.value?.messages ?? [];
      state = AsyncData(
        ChatState(
          messages: current.where((m) => m.id != pendingId).toList(),
          error: 'Failed to send message',
        ),
      );
      return retryKey;
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await HeyCabySupabase.client
          .from('messages')
          .update({'is_read': true}).eq('id', messageId);
      markDriverMessagesReadLocally(messageIds: {messageId});
    } catch (e) {
      // Silent fail
    }
  }

  void markDriverMessagesReadLocally({Set<String>? messageIds}) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages: current.messages.map((message) {
          final shouldMark = message.senderType == 'driver' &&
              !message.isRead &&
              (messageIds == null || messageIds.contains(message.id));
          if (!shouldMark) return message;
          return ChatMessage(
            id: message.id,
            rideId: message.rideId,
            senderId: message.senderId,
            senderType: message.senderType,
            message: message.message,
            createdAt: message.createdAt,
            isRead: true,
          );
        }).toList(growable: false),
      ),
    );
  }
}

final chatProvider = AsyncNotifierProvider.autoDispose<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
