import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/booking_provider.dart';

/// Confirmation dialog: owns its [TextEditingController] so overlay dispose
/// does not fight a controller owned by the async helper (avoids framework
/// `_dependents` / wrong build scope issues with [showDialog]).
class _RiderDeleteAccountConfirmDialog extends StatefulWidget {
  const _RiderDeleteAccountConfirmDialog({
    required this.themeColors,
    required this.l10n,
  });

  final HeyCabyColorTokens themeColors;
  final AppLocalizations l10n;

  @override
  State<_RiderDeleteAccountConfirmDialog> createState() =>
      _RiderDeleteAccountConfirmDialogState();
}

class _RiderDeleteAccountConfirmDialogState
    extends State<_RiderDeleteAccountConfirmDialog> {
  late final TextEditingController _controller;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matchesDeletePhrase() =>
      _controller.text.trim().toUpperCase() == 'DELETE';

  void _pop(bool value) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(value);
  }

  void _onConfirmDelete() {
    if (_matchesDeletePhrase()) {
      _pop(true);
      return;
    }
    setState(() {
      _fieldError = widget.l10n.deleteAccountTypeDeleteError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.deleteAccountConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.l10n.deleteAccountConfirmBody),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                hintText: widget.l10n.deleteAccountTypeDeleteHint,
                errorText: _fieldError,
              ),
              onChanged: (_) {
                if (_fieldError != null) {
                  setState(() => _fieldError = null);
                }
              },
              onSubmitted: (_) => _onConfirmDelete(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _pop(false),
          child: Text(widget.l10n.cancel),
        ),
        TextButton(
          onPressed: _onConfirmDelete,
          child: Text(
            widget.l10n.deleteMyAccount,
            style: TextStyle(color: widget.themeColors.error),
          ),
        ),
      ],
    );
  }
}

/// Post-deletion confirmation — calm, clear copy; dismiss before navigating home.
class _AccountDeletionSuccessDialog extends StatelessWidget {
  const _AccountDeletionSuccessDialog({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            24,
            28,
            24,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withValues(alpha: 0.14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    Icons.check_rounded,
                    color: colors.accent,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: HeyCabySpacing.component),
              Text(
                l10n.deleteAccountSuccessModalTitle,
                textAlign: TextAlign.center,
                style: typo.titleLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: HeyCabySpacing.component),
              Text(
                l10n.deleteAccountSuccessModalBody,
                textAlign: TextAlign.center,
                style: typo.bodyMedium.copyWith(
                  color: colors.textMid,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: HeyCabySpacing.sectionMedium),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.deleteAccountSuccessModalCta,
                    style: typo.labelLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// In-app account deletion for App Store Guideline 5.1.1(v).
Future<void> performRiderAccountDeletion(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  // Sync reads only — before any await — so overlay/dialog does not interleave
  // with Riverpod rebuilds from [riderIdentityProvider].
  final themeColors = ref.read(colorsProvider);
  final typography = ref.read(typographyProvider);

  final identity = await ref.read(riderIdentityProvider.future);
  if (!context.mounted) return;

  if (!identity.hasSession || identity.riderToken == null || identity.riderToken!.isEmpty) {
    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deleteMyAccount),
          content: Text(l10n.deleteAccountNoPersonalDataMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.dialogOk),
            ),
          ],
        ),
      );
    }
    return;
  }

  if (identity.email == null || identity.email!.isEmpty) {
    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deleteMyAccount),
          content: Text(l10n.deleteAccountNoEmailMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.dialogOk),
            ),
          ],
        ),
      );
    }
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RiderDeleteAccountConfirmDialog(
      themeColors: themeColors,
      l10n: l10n,
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    // So Postgres sees a valid JWT (auth.uid()) when email riders delete: RPC uses JWT if
    // rider_sessions is missing/out of sync.
    if (HeyCabySupabase.client.auth.currentUser != null) {
      try {
        await HeyCabySupabase.client.auth.refreshSession();
      } catch (_) {}
    }

    final rpc = await HeyCabyRiderAccountDeletion.deleteBySessionToken(
      identity.riderToken!,
      riderIdentityId: identity.identityId,
    );
    if (rpc['success'] != true) {
      throw Exception(rpc['error']?.toString() ?? 'rpc_failed');
    }

    try {
      await HeyCabyFcmRegistration.unregisterAll(appRole: 'rider');
    } catch (_) {}

    final hadAuth = HeyCabySupabase.client.auth.currentUser != null;
    if (hadAuth) {
      try {
        await HeyCabyAccountDeletion.deleteCurrentSupabaseAuthUser();
      } catch (_) {
        await HeyCabySupabase.client.auth.signOut();
      }
    }

    await ref.read(riderIdentityProvider.notifier).clearSession();
    ref.read(bookingProvider.notifier).reset();
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _AccountDeletionSuccessDialog(
          colors: themeColors,
          typo: typography,
          l10n: l10n,
        ),
      );
    }
    if (context.mounted) {
      context.go('/home');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountFailed)),
      );
    }
  }
}
