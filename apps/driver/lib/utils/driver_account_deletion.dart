import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';

/// Owns [TextEditingController] so the dialog route does not share a controller
/// with the async caller (avoids dispose / overlay lifecycle issues).
class _DriverDeleteAccountConfirmDialog extends StatefulWidget {
  const _DriverDeleteAccountConfirmDialog({required this.themeColors});

  final HeyCabyColorTokens themeColors;

  @override
  State<_DriverDeleteAccountConfirmDialog> createState() =>
      _DriverDeleteAccountConfirmDialogState();
}

class _DriverDeleteAccountConfirmDialogState
    extends State<_DriverDeleteAccountConfirmDialog> {
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
      _fieldError = DriverStrings.deleteAccountTypeDeleteError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(DriverStrings.deleteAccountConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(DriverStrings.deleteAccountConfirmBody),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                hintText: DriverStrings.deleteAccountTypeDeleteHint,
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
          child: Text(DriverStrings.cancel),
        ),
        TextButton(
          onPressed: _onConfirmDelete,
          child: Text(
            DriverStrings.deleteAccount,
            style: TextStyle(color: widget.themeColors.error),
          ),
        ),
      ],
    );
  }
}

/// Post-deletion confirmation — calm, clear copy; dismiss before navigating away.
class _AccountDeletionSuccessDialog extends StatelessWidget {
  const _AccountDeletionSuccessDialog({
    required this.colors,
    required this.typo,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
                DriverStrings.deleteAccountSuccessModalTitle,
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
                DriverStrings.deleteAccountSuccessModalBody,
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
                    DriverStrings.deleteAccountSuccessModalCta,
                    style:
                        typo.labelLarge.copyWith(fontWeight: FontWeight.w700),
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
Future<void> performDriverAccountDeletion(
  BuildContext context,
  WidgetRef ref,
) async {
  final themeColors = ref.read(colorsProvider);
  final typography = ref.read(typographyProvider);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) =>
        _DriverDeleteAccountConfirmDialog(themeColors: themeColors),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final rpc = await HeyCabyAccountDeletion.deleteDriverOwnedData();
    if (rpc['success'] != true) {
      throw HeyCabyAccountDeletionException(
        rpc['error']?.toString() ?? 'rpc_failed',
      );
    }
    try {
      await HeyCabyFcmRegistration.unregisterAll(appRole: 'driver');
    } catch (_) {}
    await HeyCabyAccountDeletion.deleteCurrentSupabaseAuthUser(
      signOutLocally: false,
    );
  } on HeyCabyAccountDeletionException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${DriverStrings.deleteAccountFailed} (${e.message})')),
      );
    }
    return;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${DriverStrings.deleteAccountFailed} (${e.toString()})')),
      );
    }
    return;
  }

  if (context.mounted) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AccountDeletionSuccessDialog(
        colors: themeColors,
        typo: typography,
      ),
    );
  }
  if (context.mounted) {
    await HeyCabySupabase.client.auth.signOut();
    if (!context.mounted) return;
    ref.read(driverStateProvider.notifier).logout();
    ref.read(foundingDriverPostClaimProvider.notifier).state = null;
    context.go('/login');
  }
}
