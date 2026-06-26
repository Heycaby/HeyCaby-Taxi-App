import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../utils/driver_logout.dart';

bool _sessionRevokeHandled = false;

/// Dedupes duplicate FCM / tap deliveries.
bool markSessionRevokeHandled() {
  if (_sessionRevokeHandled) return false;
  _sessionRevokeHandled = true;
  return true;
}

/// Resets dedupe after a fresh login (call from login success path if needed).
void resetSessionRevokeHandled() {
  _sessionRevokeHandled = false;
}

/// Force logout when another device supersedes this session (FCM `session_revoked`).
Future<void> handleDriverSessionRevoked({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  if (!context.mounted) return;
  if (!markSessionRevokeHandled()) return;

  HapticService.heavyTap();

  if (!context.mounted) return;
  await showDriverSessionRevokedModal(context, ref);
  if (!context.mounted) return;
  await forceDriverLogout(context, ref);
}

Future<void> showDriverSessionRevokedModal(
  BuildContext context,
  WidgetRef ref,
) {
  final themeColors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.phonelink_erase_rounded, color: themeColors.warning, size: 40),
      title: Text(
        DriverStrings.sessionRevokedTitle,
        style: typo.titleMedium.copyWith(
          color: themeColors.text,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        DriverStrings.sessionRevokedBody,
        style: typo.bodyMedium.copyWith(color: themeColors.textMid, height: 1.35),
        textAlign: TextAlign.center,
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(DriverStrings.sessionRevokedCta),
          ),
        ),
      ],
    ),
  );
}
