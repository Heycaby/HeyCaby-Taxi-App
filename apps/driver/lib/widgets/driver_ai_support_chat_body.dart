import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_trust_flow_common.dart';

/// One message row in the Lee chat transcript.
class DriverAiChatMessage {
  const DriverAiChatMessage({
    required this.isUser,
    required this.content,
  });

  final bool isUser;
  final String content;
}

/// **AI Support Chat** — Lee conversation surface.
class DriverAiSupportChatBody extends StatelessWidget {
  const DriverAiSupportChatBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.messages,
    required this.messageController,
    required this.sending,
    required this.scrollController,
    required this.onBack,
    required this.onSend,
    this.composerHint = 'Message Lee...',
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverAiChatMessage> messages;
  final TextEditingController messageController;
  final bool sending;
  final ScrollController scrollController;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final String composerHint;

  @override
  Widget build(BuildContext context) {
    return DriverTrustFlowScaffold(
      title: DriverStrings.chatWithLee,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? DriverChatEmptyState(
                    icon: Icons.support_agent_rounded,
                    title: DriverStrings.leeSupportAssistant,
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
                      return DriverChatMessageBubble(
                        content: message.content,
                        isUser: message.isUser,
                        colors: colors,
                        typography: typography,
                      );
                    },
                  ),
          ),
          DriverChatComposerBar(
            controller: messageController,
            hint: composerHint,
            sending: sending,
            colors: colors,
            typography: typography,
            onSend: onSend,
          ),
        ],
      ),
    );
  }
}
