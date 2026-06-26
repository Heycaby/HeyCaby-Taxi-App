import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import 'driver_support_conversation_body.dart';
import 'driver_trust_flow_common.dart';

/// One message in rider ↔ driver chat.
class DriverRiderChatMessage {
  const DriverRiderChatMessage({
    required this.content,
    required this.isDriver,
    required this.timeLabel,
  });

  final String content;
  final bool isDriver;
  final String timeLabel;
}

/// **Rider Conversation** — message rider without distraction.
class DriverRiderConversationBody extends StatelessWidget {
  const DriverRiderConversationBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.error,
    required this.canUseChat,
    required this.messages,
    required this.messageController,
    required this.scrollController,
    required this.onBack,
    required this.onSend,
    required this.onBackWhenBlocked,
    this.menu,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String? error;
  final bool canUseChat;
  final List<DriverRiderChatMessage> messages;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final VoidCallback onBackWhenBlocked;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverTrustFlowScaffold(
      title: DriverStrings.chatWithRiderTitle,
      colors: colors,
      typography: typography,
      onBack: onBack,
      actions: menu != null ? [menu!] : null,
      body: !canUseChat
          ? _BlockedState(
              colors: colors,
              typography: typography,
              onBack: onBackWhenBlocked,
            )
          : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: typography.bodyMedium.copyWith(color: colors.error),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : messages.isEmpty
                              ? DriverChatEmptyState(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  title: DriverStrings.chatWithRiderTitle,
                                  subtitle: DriverStrings.chatTypeMessageHint,
                                  colors: colors,
                                  typography: typography,
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(DriverSpacing.lg),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final message = messages[index];
                                    return DriverSupportTicketBubble(
                                      content: message.content,
                                      isDriver: message.isDriver,
                                      timeLabel: message.timeLabel,
                                      colors: colors,
                                      typography: typography,
                                    );
                                  },
                                ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        DriverSpacing.lg,
                        DriverSpacing.sm,
                        DriverSpacing.lg,
                        bottomPad + DriverSpacing.sm,
                      ),
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
                              controller: messageController,
                              maxLength: 2000,
                              style: typography.bodyMedium.copyWith(
                                color: colors.text,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: DriverStrings.chatTypeMessageHint,
                                hintStyle: typography.bodySmall.copyWith(
                                  color: colors.textMuted,
                                ),
                                filled: true,
                                fillColor: colors.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: DriverSpacing.lg,
                                  vertical: DriverSpacing.md,
                                ),
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
                                  borderSide: BorderSide(
                                    color: colors.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => onSend(),
                            ),
                          ),
                          const SizedBox(width: DriverSpacing.sm),
                          IconButton(
                            onPressed: onSend,
                            icon: Icon(Icons.send_rounded, color: colors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _BlockedState extends StatelessWidget {
  const _BlockedState({
    required this.colors,
    required this.typography,
    required this.onBack,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DriverSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: colors.textMuted,
            ),
            const SizedBox(height: DriverSpacing.sm),
            Text(
              DriverStrings.chatOnlyDuringActiveRideTitle,
              textAlign: TextAlign.center,
              style: typography.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: DriverSpacing.sm),
            Text(
              DriverStrings.chatOnlyDuringActiveRideBody,
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: DriverSpacing.lg),
            DriverButton(
              label: DriverStrings.back,
              colors: colors,
              typography: typography,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats relative time like the legacy chat bubble.
String driverRiderChatTimeLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
}
