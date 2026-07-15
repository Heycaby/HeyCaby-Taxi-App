import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'package:heycaby_api/heycaby_api.dart';

import '../widgets/booking/booking_flow_screen_header.dart';

import '../providers/chat_provider.dart';
import '../providers/ride_request_provider.dart';
import '../providers/rider_ride_unread_messages_provider.dart';
import '../utils/ride_chat_allowed.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _retryMessage;
  String? _retryIdempotencyKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final rideId = ref.read(rideRequestProvider).rideRequestId;
      if (rideId != null) {
        await ref.read(chatProvider.notifier).loadMessages(rideId);
        await ref
            .read(riderRideUnreadMessageCountProvider(rideId).notifier)
            .markAllRead();
      }
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
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    final status = ref.read(rideRequestProvider).status;
    if (!isRideChatAllowed(status)) return;

    final identity = ref.read(riderIdentityProvider).valueOrNull;
    final senderId = identity?.identityId ??
        HeyCabySupabase.client.auth.currentUser?.id ??
        '';

    final retryKey = _retryMessage == message ? _retryIdempotencyKey : null;
    _messageController.clear();
    final failedKey = await ref.read(chatProvider.notifier).sendMessage(
          rideId,
          message,
          senderId: senderId,
          idempotencyKey: retryKey,
        );
    if (failedKey == null) {
      _retryMessage = null;
      _retryIdempotencyKey = null;
    } else {
      _retryMessage = message;
      _retryIdempotencyKey = failedKey;
      if (_messageController.text.trim().isEmpty) {
        _messageController.text = message;
        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
      }
    }

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final chatState = ref.watch(chatProvider);
    final rideStatus = ref.watch(rideRequestProvider).status;
    final chatAllowed = isRideChatAllowed(rideStatus);
    ref.listen(chatProvider, (_, next) {
      next.whenData((state) {
        if (state.error == null || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
      });
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.chat,
              subtitle: l10n.driver,
              icon: Icons.chat_bubble_rounded,
              onBack: () => context.pop(),
              trailing: chatState.maybeWhen(
                data: (state) {
                  String? peerDriverId() {
                    for (final m in state.messages) {
                      if (m.senderType == 'driver') return m.senderId;
                    }
                    return null;
                  }

                  final peer = peerDriverId();
                  if (peer == null) return const SizedBox.shrink();
                  return PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: colors.text),
                    onSelected: (v) async {
                      final rideId =
                          ref.read(rideRequestProvider).rideRequestId;
                      if (rideId == null) return;

                      if (v == 'report') {
                        final reason = TextEditingController();
                        final submit = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: colors.card,
                            title: Text(
                              l10n.reportDriverTitle,
                              style:
                                  typo.titleMedium.copyWith(color: colors.text),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l10n.reportDriverBody,
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
                                      hintText: l10n.reportReasonHint,
                                      hintStyle: typo.bodySmall
                                          .copyWith(color: colors.textSoft),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.cancel,
                                    style: TextStyle(color: colors.accent)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(l10n.reportDriver,
                                    style: TextStyle(color: colors.error)),
                              ),
                            ],
                          ),
                        );
                        if (submit != true || !context.mounted) return;
                        final sent =
                            await ref.read(chatProvider.notifier).reportDriver(
                                  rideId: rideId,
                                  driverSenderId: peer,
                                  reason: reason.text.trim().isEmpty
                                      ? null
                                      : reason.text.trim(),
                                );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              sent
                                  ? l10n.chatReportSubmitted
                                  : l10n.chatReportFailed,
                            ),
                          ),
                        );
                        return;
                      }

                      if (v != 'block') return;
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.blockDriver,
                              style: typo.titleMedium
                                  .copyWith(color: colors.text)),
                          content: Text(
                            l10n.blockDriverConfirm,
                            style:
                                typo.bodyMedium.copyWith(color: colors.textMid),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.cancel,
                                  style: TextStyle(color: colors.accent)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l10n.blockDriver,
                                  style: TextStyle(color: colors.error)),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !context.mounted) return;
                      final blocked =
                          await ref.read(chatProvider.notifier).blockDriver(
                                rideId: rideId,
                                driverSenderId: peer,
                              );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            blocked ? l10n.blockDriver : l10n.chatBlockFailed,
                          ),
                        ),
                      );
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'report', child: Text(l10n.reportDriver)),
                      PopupMenuItem(
                          value: 'block', child: Text(l10n.blockDriver)),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: !chatAllowed
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Chat is only available while a ride is active.',
                          textAlign: TextAlign.center,
                          style:
                              typo.bodyMedium.copyWith(color: colors.textMid),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: chatState.when(
                            data: (state) {
                              if (state.isLoading) {
                                return Center(
                                  child: CircularProgressIndicator(
                                      color: colors.accent),
                                );
                              }

                              if (state.messages.isEmpty) {
                                return _EmptyState(
                                    colors: colors, typo: typo, l10n: l10n);
                              }

                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsetsDirectional.all(16),
                                itemCount: state.messages.length,
                                itemBuilder: (context, index) {
                                  final message = state.messages[index];
                                  final isRider = message.senderType == 'rider';
                                  return _MessageBubble(
                                    message: message.message,
                                    isRider: isRider,
                                    timestamp: message.createdAt,
                                    colors: colors,
                                    typo: typo,
                                  );
                                },
                              );
                            },
                            loading: () => Center(
                              child: CircularProgressIndicator(
                                  color: colors.accent),
                            ),
                            error: (e, _) => Center(
                              child: Text(
                                AppLocalizations.of(context)
                                    .errorLoadingMessages,
                                style: typo.bodyMedium
                                    .copyWith(color: colors.error),
                              ),
                            ),
                          ),
                        ),
                        _MessageInput(
                          controller: _messageController,
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                          onSend: _sendMessage,
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

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isRider;
  final DateTime timestamp;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _MessageBubble({
    required this.message,
    required this.isRider,
    required this.timestamp,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isRider ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isRider) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: colors.accent, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsetsDirectional.all(12),
              decoration: BoxDecoration(
                color: isRider ? colors.accent : colors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: typo.bodyMedium.copyWith(
                      color: isRider ? colors.bg : colors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: typo.displayMedium.copyWith(
                      color: isRider
                          ? colors.bg.withValues(alpha: 0.7)
                          : colors.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isRider) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.accentL,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: colors.accent, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
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
                hintText: AppLocalizations.of(context).typeAMessage,
                hintStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
                filled: true,
                fillColor: colors.bgAlt,
                contentPadding: const EdgeInsetsDirectional.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send, color: colors.bg, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _EmptyState({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(24),
            decoration: BoxDecoration(
              color: colors.bgAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: colors.textSoft,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).noMessagesYet,
            style: typo.headingMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).startConversation,
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
        ],
      ),
    );
  }
}
