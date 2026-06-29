import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../ui/driver_chip.dart';

/// Shared scaffold for trust, legal, and feedback screens.
class DriverTrustFlowScaffold extends StatelessWidget {
  const DriverTrustFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.body,
    this.centerTitle = true,
    this.leadingClose = false,
    this.actions,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Widget body;
  final bool centerTitle;
  final bool leadingClose;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: title,
        colors: colors,
        typography: typography,
        centerTitle: centerTitle,
        leading: IconButton(
          icon: Icon(
            leadingClose ? Icons.close_rounded : Icons.arrow_back_rounded,
            color: colors.text,
          ),
          onPressed: onBack,
        ),
        actions: actions,
      ),
      body: body,
    );
  }
}

/// EN / NL chip row + copy-for-translation action.
class DriverLegalLanguageToolbar extends StatelessWidget {
  const DriverLegalLanguageToolbar({
    super.key,
    required this.colors,
    required this.typography,
    required this.isDutch,
    required this.onSelectEnglish,
    required this.onSelectDutch,
    required this.onCopy,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool isDutch;
  final VoidCallback onSelectEnglish;
  final VoidCallback onSelectDutch;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DriverChip(
              label: DriverStrings.english,
              colors: colors,
              typography: typography,
              selected: !isDutch,
              onTap: onSelectEnglish,
            ),
            const SizedBox(width: DriverSpacing.sm),
            DriverChip(
              label: DriverStrings.dutch,
              colors: colors,
              typography: typography,
              selected: isDutch,
              onTap: onSelectDutch,
            ),
          ],
        ),
        const SizedBox(height: DriverSpacing.sm),
        Text(
          DriverStrings.legalDocumentLanguageNotice,
          style: typography.bodySmall.copyWith(
            color: colors.textMuted,
            height: 1.35,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onCopy,
            icon: Icon(Icons.copy_rounded, size: 18, color: colors.textMuted),
            label: Text(
              DriverStrings.legalCopyForTranslation,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// App-bar actions for legal screens — quick language toggle + copy.
List<Widget> driverLegalTrustAppBarActions({
  required DriverColors colors,
  required DriverTypography typography,
  required bool isDutch,
  required VoidCallback onToggleLanguage,
  required VoidCallback onCopy,
}) {
  return [
    TextButton.icon(
      onPressed: onToggleLanguage,
      icon: Icon(Icons.language_rounded, color: colors.primary, size: 18),
      label: Text(
        isDutch ? 'NL' : 'EN',
        style: typography.bodyMedium.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    IconButton(
      icon: Icon(Icons.copy_rounded, color: colors.primary),
      onPressed: onCopy,
      tooltip: DriverStrings.legalCopyAllText,
    ),
    const SizedBox(width: DriverSpacing.sm),
  ];
}

/// One heading + body block in terms / privacy scroll views.
class DriverLegalSectionCard extends StatelessWidget {
  const DriverLegalSectionCard({
    super.key,
    required this.title,
    required this.body,
    required this.colors,
    required this.typography,
    this.onSupportTap,
  });

  final String title;
  final String body;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback? onSupportTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DriverSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.titleLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            body,
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          if (onSupportTap != null) ...[
            const SizedBox(height: DriverSpacing.sm),
            GestureDetector(
              onTap: onSupportTap,
              child: Text(
                DriverStrings.ondersteuning,
                style: typography.bodyMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chat bubble for Lee / support conversation surfaces.
class DriverChatMessageBubble extends StatelessWidget {
  const DriverChatMessageBubble({
    super.key,
    required this.content,
    required this.isUser,
    required this.colors,
    required this.typography,
  });

  final String content;
  final bool isUser;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: DriverSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: DriverSpacing.lg,
          vertical: DriverSpacing.md,
        ),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? colors.primary : colors.card,
          borderRadius: BorderRadius.circular(DriverRadius.lg),
          border: Border.all(
            color: isUser ? colors.primary : colors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          content,
          style: typography.bodyMedium.copyWith(
            color: isUser ? colors.onPrimary : colors.text,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

/// Empty state when AI chat has no messages yet.
class DriverChatEmptyState extends StatelessWidget {
  const DriverChatEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.typography,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DriverSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.primary, size: 44),
            const SizedBox(height: DriverSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: typography.titleMedium.copyWith(color: colors.text),
            ),
            const SizedBox(height: DriverSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom composer row for chat surfaces.
class DriverChatComposerBar extends StatelessWidget {
  const DriverChatComposerBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.sending,
    required this.colors,
    required this.typography,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final bool sending;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DriverSpacing.md,
          DriverSpacing.sm,
          DriverSpacing.md,
          DriverSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                style: typography.bodyMedium.copyWith(color: colors.text),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: typography.bodyMedium.copyWith(
                    color: colors.textMuted,
                  ),
                  filled: true,
                  fillColor: colors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: DriverSpacing.lg,
                    vertical: DriverSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: DriverSpacing.sm),
            FilledButton(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                disabledBackgroundColor: colors.border,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : Icon(Icons.arrow_upward_rounded, color: colors.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
