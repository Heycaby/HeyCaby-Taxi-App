import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import 'driver_trust_flow_common.dart';

/// Parses legacy ticket JSON (`sender_type`/`body`) and Lee format (`role`/`content`).
class DriverSupportTicketMessageParser {
  const DriverSupportTicketMessageParser._();

  static bool isDriverBubble(Map<String, dynamic> message) {
    final role = message['role'] as String?;
    if (role == 'user') return true;
    if (role == 'assistant' || role == 'system') return false;
    return message['sender_type'] == 'driver';
  }

  static String bodyText(Map<String, dynamic> message) {
    final content = message['content'] as String?;
    if (content != null && content.isNotEmpty) return content;
    return message['body'] as String? ?? '';
  }

  static String? timeLabel(Map<String, dynamic> message) {
    final ts = message['ts'] as String? ?? message['created_at'] as String?;
    final parsed = DateTime.tryParse(ts ?? '');
    if (parsed == null) return null;
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  static DriverSupportTicketMessage fromMap(Map<String, dynamic> message) {
    return DriverSupportTicketMessage(
      isDriver: isDriverBubble(message),
      content: bodyText(message),
      timeLabel: timeLabel(message),
    );
  }
}

/// One message in a human support ticket thread.
class DriverSupportTicketMessage {
  const DriverSupportTicketMessage({
    required this.isDriver,
    required this.content,
    this.timeLabel,
  });

  final bool isDriver;
  final String content;
  final String? timeLabel;
}

/// **Support Conversation** — human ticket chat with status and resolve CTA.
class DriverSupportConversationBody extends StatelessWidget {
  const DriverSupportConversationBody({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.statusLabel,
    required this.statusClosed,
    required this.loading,
    required this.messages,
    required this.messageController,
    required this.sending,
    required this.isClosed,
    required this.scrollController,
    required this.onBack,
    required this.onSend,
    required this.onMarkResolved,
    this.composerHint,
    this.reopenHint = 'Send a message to reopen this ticket',
    this.topPanel,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final String statusLabel;
  final bool statusClosed;
  final bool loading;
  final List<DriverSupportTicketMessage> messages;
  final TextEditingController messageController;
  final bool sending;
  final bool isClosed;
  final ScrollController scrollController;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final VoidCallback onMarkResolved;
  final String? composerHint;
  final String reopenHint;
  final Widget? topPanel;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final hint =
        composerHint ?? (isClosed ? reopenHint : DriverStrings.berichtTypen);

    return DriverTrustFlowScaffold(
      title: title,
      colors: colors,
      typography: typography,
      onBack: onBack,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: DriverSpacing.lg),
          child: Center(
            child: DriverStatusBadge(
              label: statusLabel,
              colors: colors,
              typography: typography,
              tone: statusClosed
                  ? DriverStatusTone.success
                  : DriverStatusTone.warning,
            ),
          ),
        ),
      ],
      body: Column(
        children: [
          if (topPanel != null) topPanel!,
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? DriverChatEmptyState(
                        icon: Icons.support_agent_rounded,
                        title: DriverStrings.ondersteuning,
                        subtitle: DriverStrings.leeSupportPrompt,
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
              border: Border(top: BorderSide(color: colors.border, width: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isClosed) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: sending ? null : onMarkResolved,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        'MARK AS RESOLVED',
                        style: typography.labelLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.success,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.md),
                ],
                Row(
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
                          hintText: hint,
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
                      onPressed: sending ? null : onSend,
                      icon: Icon(Icons.send_rounded, color: colors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ticket thread bubble with optional timestamp footer.
class DriverSupportTicketBubble extends StatelessWidget {
  const DriverSupportTicketBubble({
    super.key,
    required this.content,
    required this.isDriver,
    required this.colors,
    required this.typography,
    this.timeLabel,
  });

  final String content;
  final bool isDriver;
  final DriverColors colors;
  final DriverTypography typography;
  final String? timeLabel;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;

    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: DriverSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: DriverSpacing.lg,
          vertical: DriverSpacing.md,
        ),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: isDriver ? colors.primary : colors.surface,
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
              content,
              style: typography.bodyMedium.copyWith(
                color: isDriver ? colors.onPrimary : colors.text,
                height: 1.35,
              ),
            ),
            if (timeLabel != null && timeLabel!.isNotEmpty) ...[
              const SizedBox(height: DriverSpacing.xs),
              Text(
                timeLabel!,
                style: typography.labelSmall.copyWith(
                  color: isDriver
                      ? colors.onPrimary.withValues(alpha: 0.72)
                      : colors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
