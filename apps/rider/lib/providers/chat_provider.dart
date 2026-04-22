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
            if (_blockedSenderKeys
                .contains(_senderKey(newMessage.senderType, newMessage.senderId))) {
              return;
            }
            final currentMessages = state.value?.messages ?? [];
            state = AsyncData(
              ChatState(messages: [...currentMessages, newMessage]),
            );
            // Play notification sound only for messages from driver
            if (newMessage.senderType == 'driver') {
              SoundService().playNotification();
            }
          },
        )
        .subscribe();
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

  Future<void> sendMessage(String rideId, String message,
      {required String senderId}) async {
    try {
      await HeyCabySupabase.client.from('messages').insert({
        'ride_request_id': rideId,
        'sender_id': senderId,
        'sender_type': 'rider',
        'content': message,
      });
    } catch (e) {
      state = AsyncData(
        state.value!.copyWith(error: 'Failed to send message'),
      );
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await HeyCabySupabase.client
          .from('messages')
          .update({'is_read': true}).eq('id', messageId);
    } catch (e) {
      // Silent fail
    }
  }
}

final chatProvider = AsyncNotifierProvider.autoDispose<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
